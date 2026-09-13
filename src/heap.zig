const std = @import("std");
const sf = @import("sf.zig");
const Alignment = std.mem.Alignment;

pub const PointerAttributes = struct {
    @"const": bool = false,
    @"volatile": bool = false,
    @"align": ?std.mem.Alignment = null,
    optional: bool = false,
};

pub const PointerInfo = struct {
    pub const Size = enum {
        one,
        many,
    };
    size: Size,
    Element: type,
    attributes: PointerAttributes,
};

pub fn Ptr(
    size: PointerInfo.Size,
    Element: type,
    attributes: PointerAttributes,
) type {
    return extern struct {
        addr: sf.DeviceAddress,

        pub const empty: @This() = .{ .addr = if (alignement) |a| a.toByteUnits() else 1 };

        pub const @"null": @This() =
            if (attributes.optional) .{ .addr = 0 } else @compileError("pointer is not optional");

        pub const Host = blk: {
            const H = @Pointer(switch (size) {
                .one => .one,
                .many => .many,
            }, .{
                .@"const" = attributes.@"const",
                .@"volatile" = attributes.@"volatile",
                .@"align" = if (attributes.@"align") |a| a.toByteUnits() else null,
            }, Element, null);
            break :blk if (attributes.optional) ?H else H;
        };

        pub const info: PointerInfo = .{
            .size = size,
            .Element = Element,
            .attributes = attributes,
        };

        pub const alignement: ?std.mem.Alignment = if (attributes.@"align") |a| a else switch (Element) {
            anyopaque => null, // TODO: replace with @compileError("no align available for uninstantiable type 'anyopaque'")
            else => .of(Element),
        };

        const unwrapped_attributes: PointerAttributes = blk: {
            var a = attributes;
            a.optional = false;
            break :blk a;
        };

        pub fn fromInt(addr: u64) @This() {
            const result: @This() = .{ .addr = addr };
            result.assertAlignment();
            result.assertZero();
            return result;
        }

        pub fn from(ptr: anytype) @This() {
            const Src = @TypeOf(ptr);
            comptime {
                if (!isDevicePtr(Src))
                    @compileError("expected a device pointer, found '" ++ @typeName(Src) ++ "'");
                _ = @as(Host, @as(Src.Host, undefined));
            }
            return .{ .addr = ptr.addr };
        }

        pub fn cast(ptr: anytype) @This() {
            comptime blk: {
                if (!isDevicePtr(@TypeOf(ptr)))
                    @compileError("expected a device pointer, found '" ++ @typeName(@TypeOf(ptr)) ++ "'");
                const ptr_align = @TypeOf(ptr).alignement orelse break :blk;
                const this_align = alignement orelse break :blk;
                if (this_align.compare(.gt, ptr_align))
                    @compileError("cast increases pointer alignment; use alignCast");
            }
            return .{ .addr = ptr.addr };
        }

        pub fn alignCast(ptr: anytype) @This() {
            const Src = @TypeOf(ptr);
            comptime {
                if (!isDevicePtr(Src))
                    @compileError("expected a device pointer, found '" ++ @typeName(Src) ++ "'");
                var a = Src.info.attributes;
                a.@"align" = attributes.@"align";
                _ = @as(Host, @as(Ptr(Src.info.size, Src.info.Element, a).Host, undefined));
            }
            return .fromInt(ptr.addr);
        }

        pub fn isNull(ptr: @This()) bool {
            comptime std.debug.assert(attributes.optional);
            return ptr.addr == 0;
        }

        pub fn unwrap(ptr: @This()) ?Ptr(size, Element, unwrapped_attributes) {
            if (ptr.addr == 0) return null;
            return .fromInt(ptr.addr);
        }

        pub fn slice(ptr: @This(), len: u64) Slice(Element, unwrapped_attributes) {
            comptime std.debug.assert(size == .many);
            ptr.assertZero();
            return .{ .ptr = .fromInt(ptr.addr), .len = len };
        }

        fn assertAlignment(ptr: @This()) void {
            if (alignement != null) std.debug.assert(std.mem.isAligned(ptr.addr, alignement.?.toByteUnits()));
        }

        fn assertZero(ptr: @This()) void {
            if (!attributes.optional) std.debug.assert(ptr.addr != 0);
        }
    };
}

pub const SliceInfo = struct {
    Element: type,
    attributes: PointerAttributes,
};

pub fn Slice(
    Element: type,
    attributes: PointerAttributes,
) type {
    return extern struct {
        ptr: Pointer,
        len: u64,

        const Pointer = Ptr(.many, Element, attributes);

        pub const info: SliceInfo = .{
            .Element = Element,
            .attributes = attributes,
        };

        pub const Host = blk: {
            const H = @Pointer(.slice, .{
                .@"const" = attributes.@"const",
                .@"volatile" = attributes.@"volatile",
                .@"align" = if (attributes.@"align") |a| a.toByteUnits() else null,
            }, Element, null);
            break :blk if (attributes.optional) ?H else H;
        };

        pub const empty: @This() = .{ .ptr = .empty, .len = 0 };

        pub fn from(src: anytype) @This() {
            const Src = @TypeOf(src);
            comptime {
                if (!isDeviceSlice(Src) and !isDevicePtr(Src))
                    @compileError("expected a device pointer or slice, found '" ++ @typeName(Src) ++ "'");
                _ = @as(Host, @as(Src.Host, undefined));
            }
            if (comptime isDeviceSlice(Src)) {
                return .{ .ptr = .{ .addr = src.ptr.addr }, .len = src.len };
            } else {
                return .{
                    .ptr = .{ .addr = src.addr },
                    .len = @typeInfo(Src.info.Element).array.len,
                };
            }
        }

        pub fn cast(src: anytype) @This() {
            const Src = @TypeOf(src);
            comptime if (!isDeviceSlice(Src))
                @compileError("expected a device slice, found '" ++ @typeName(Src) ++ "'");
            const byte_len = src.len * @sizeOf(Src.info.Element);
            std.debug.assert(byte_len % @sizeOf(Element) == 0);
            return .{
                .ptr = .cast(src.ptr),
                .len = byte_len / @sizeOf(Element),
            };
        }

        pub fn alignCast(src: anytype) @This() {
            const Src = @TypeOf(src);
            comptime {
                if (!isDeviceSlice(Src))
                    @compileError("expected a device slice, found '" ++ @typeName(Src) ++ "'");
                var a = Src.info.attributes;
                a.@"align" = attributes.@"align";
                _ = @as(Host, @as(Slice(Src.info.Element, a).Host, undefined));
            }
            return .{ .ptr = .fromInt(src.ptr.addr), .len = src.len };
        }

        pub fn asBytes(self: @This()) Slice(u8, blk: {
            var a = attributes;
            a.@"align" = @TypeOf(self.ptr).alignement;
            break :blk a;
        }) {
            return .{
                .ptr = .{ .addr = self.ptr.addr },
                .len = self.len * @sizeOf(Element),
            };
        }
    };
}

fn isDevicePtr(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    if (!@hasDecl(T, "info")) return false;
    return @TypeOf(T.info) == PointerInfo;
}

fn isDeviceSlice(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    if (!@hasDecl(T, "info")) return false;
    return @TypeOf(T.info) == SliceInfo;
}

pub fn AllocationOne(Element: type, @"align": ?Alignment) type {
    const alignment = if (@"align") |a| a.toByteUnits() else @alignOf(Element);
    return struct {
        device: Ptr(.one, Element, .{ .@"align" = @"align" }),
        host: *align(alignment) Element,
    };
}

pub fn Allocation(Element: type, @"align": ?Alignment) type {
    const alignment = if (@"align") |a| a.toByteUnits() else @alignOf(Element);
    return struct {
        device: Ptr(.many, Element, .{ .@"align" = @"align" }),
        host: [*]align(alignment) Element,
        len: usize,

        pub const empty: @This() = .{
            .device = .empty,
            .host = &.{},
            .len = 0,
        };

        pub fn deviceSlice(allocation: @This()) Slice(Element, .{ .@"align" = @"align" }) {
            return allocation.device.slice(allocation.len);
        }
    };
}

const DeviceAllocator = struct {
    pub const Error = error{
        OutOfDeviceMemory,
        OutOfMemory,
    };

    pub const BytePtr = Ptr(.many, u8, .{});
    pub const ByteSlice = Slice(u8, .{});

    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        alloc: *const fn (*anyopaque, len: usize, alignment: Alignment, memory_type: sf.MemoryType, ret_addr: usize) Error!sf.HostDeviceAddress,
        free: *const fn (*anyopaque, memory: ByteSlice, alignment: Alignment, memory_type: sf.MemoryType, ret_addr: usize) void,
    };

    pub fn noAlloc(
        self: *anyopaque,
        len: usize,
        alignment: Alignment,
        memory_type: sf.MemoryType,
        ret_addr: usize,
    ) Error!sf.HostDeviceAddress {
        _ = self;
        _ = len;
        _ = alignment;
        _ = memory_type;
        _ = ret_addr;
        return error.OutOfDeviceMemory;
    }

    pub fn noFree(
        self: *anyopaque,
        memory: ByteSlice,
        alignment: Alignment,
        memory_type: sf.MemoryType,
        ret_addr: usize,
    ) void {
        _ = self;
        _ = memory;
        _ = alignment;
        _ = memory_type;
        _ = ret_addr;
    }

    pub inline fn rawAlloc(a: DeviceAllocator, len: usize, alignment: Alignment, memory_type: sf.MemoryType, ret_addr: usize) Error!sf.HostDeviceAddress {
        return a.vtable.alloc(a.ptr, len, alignment, memory_type, ret_addr);
    }

    pub inline fn rawFree(a: DeviceAllocator, memory: ByteSlice, alignment: Alignment, memory_type: sf.MemoryType, ret_addr: usize) void {
        return a.vtable.free(a.ptr, memory, alignment, memory_type, ret_addr);
    }

    pub fn create(a: DeviceAllocator, comptime T: type, memory: sf.MemoryType) Error!AllocationOne(T, null) {
        if (@sizeOf(T) == 0) {
            return .{
                .device = .fromInt((Ptr(.one, T, .{}).alignement orelse .@"1").backward(std.math.maxInt(u64))),
                .host = undefined,
            };
        }
        const result = try a.allocBytesWithAlignment(.of(T), @sizeOf(T), memory, @returnAddress());
        return .{
            .device = .fromInt(result.device),
            .host = @ptrCast(@alignCast(result.host)),
        };
    }

    pub fn destroy(self: DeviceAllocator, allocation: anytype, memory: sf.MemoryType) void {
        const info = @TypeOf(allocation).info;
        if (info.size != .one) @compileError("owned.device must be a single item device pointer");
        const T = info.Element;
        if (@sizeOf(T) == 0) return;
        self.rawFree(
            .{ .ptr = .{ .addr = allocation.addr }, .len = @sizeOf(T) },
            comptime info.attributes.@"align" orelse .of(T),
            memory,
            @returnAddress(),
        );
    }

    pub fn alloc(self: DeviceAllocator, comptime T: type, n: usize, memory: sf.MemoryType) Error!Allocation(T, null) {
        return self.alignedAllocWithRetAddr(T, null, n, memory, @returnAddress());
    }

    pub fn alignedAlloc(
        self: DeviceAllocator,
        comptime T: type,
        comptime alignment: ?Alignment,
        n: usize,
        memory: sf.MemoryType,
    ) Error!Allocation(T, alignment) {
        return self.alignedAllocWithRetAddr(T, alignment, n, memory, @returnAddress());
    }

    pub fn runtimeAlignedAlloc(
        self: DeviceAllocator,
        comptime T: type,
        alignment: Alignment,
        n: usize,
        memory: sf.MemoryType,
    ) Error!Allocation(T, null) {
        return self.runtimeAlignedAllocWithRetAddr(T, alignment, n, memory, @returnAddress());
    }

    pub inline fn alignedAllocWithRetAddr(
        self: DeviceAllocator,
        comptime T: type,
        comptime alignment: ?Alignment,
        n: usize,
        memory: sf.MemoryType,
        return_address: usize,
    ) Error!Allocation(T, alignment) {
        const a: Alignment = alignment orelse comptime .of(T);
        const owned = try self.runtimeAlignedAllocWithRetAddr(T, a, n, memory, return_address);
        return .{ .device = .alignCast(owned.device), .host = @alignCast(owned.host), .len = owned.len };
    }

    pub inline fn runtimeAlignedAllocWithRetAddr(
        self: DeviceAllocator,
        comptime T: type,
        alignment: Alignment,
        n: usize,
        memory: sf.MemoryType,
        return_address: usize,
    ) Error!Allocation(T, null) {
        const byte_count = std.math.mul(usize, @sizeOf(T), n) catch return error.OutOfDeviceMemory;
        const result = try self.allocBytesWithAlignment(alignment, byte_count, memory, return_address);
        const host_ptr: [*]T = @ptrCast(@alignCast(result.host));
        return .{
            .device = .fromInt(result.device),
            .host = host_ptr,
            .len = n,
        };
    }

    fn allocBytesWithAlignment(
        self: DeviceAllocator,
        alignment: Alignment,
        byte_count: usize,
        memory: sf.MemoryType,
        return_address: usize,
    ) Error!sf.HostDeviceAddress {
        if (byte_count == 0) return .{
            .device = alignment.backward(std.math.maxInt(u64)),
            .host = undefined,
        };
        return try self.rawAlloc(byte_count, alignment, memory, return_address);
    }

    pub fn free(self: DeviceAllocator, allocation: anytype, memory_type: sf.MemoryType) void {
        const info = @TypeOf(allocation).info;
        const T = info.Element;
        const bytes = allocation.asBytes();
        if (bytes.len == 0) return;
        self.rawFree(
            .from(bytes),
            comptime info.attributes.@"align" orelse .of(T),
            memory_type,
            @returnAddress(),
        );
    }

    pub fn runtimeAlignedfree(self: DeviceAllocator, allocation: anytype, alignment: Alignment, memory_type: sf.MemoryType) void {
        const bytes = allocation.asBytes();
        if (bytes.len == 0) return;
        self.rawFree(
            .from(bytes),
            alignment,
            memory_type,
            @returnAddress(),
        );
    }

    pub const failing: DeviceAllocator = .{
        .ptr = undefined,
        .vtable = &.{
            .alloc = noAlloc,
            .free = unreachableFree,
        },
    };

    fn unreachableFree(
        self: *anyopaque,
        memory: ByteSlice,
        alignment: Alignment,
        memory_type: sf.MemoryType,
        ret_addr: usize,
    ) void {
        _ = self;
        _ = memory;
        _ = alignment;
        _ = memory_type;
        _ = ret_addr;
        unreachable;
    }
};

pub fn rawDeviceAllocator(d: *sf.Device) DeviceAllocator {
    return .{
        .ptr = @ptrCast(d),
        .vtable = &.{
            .alloc = raw_device_allocator.alloc,
            .free = raw_device_allocator.free,
        },
    };
}

pub const raw_device_allocator = struct {
    pub fn alloc(
        self: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        memory_type: sf.MemoryType,
        ret_addr: usize,
    ) DeviceAllocator.Error!sf.HostDeviceAddress {
        _ = ret_addr;
        const device: *sf.Device = @ptrCast(@alignCast(self));
        return try device.alloc(len, alignment.toByteUnits(), memory_type);
    }

    pub fn free(
        self: *anyopaque,
        memory: Slice(u8, .{}),
        alignment: std.mem.Alignment,
        memory_type: sf.MemoryType,
        ret_addr: usize,
    ) void {
        _ = alignment;
        _ = memory_type;
        _ = ret_addr;
        const device: *sf.Device = @ptrCast(@alignCast(self));
        return device.free(memory.ptr.addr);
    }
};

pub const FixedBufferAllocator = struct {
    regions: std.EnumArray(sf.MemoryType, Region),

    const Region = struct {
        buffer: Allocation(u8, null),
        end_index: u64,

        const empty: Region = .{ .buffer = .empty, .end_index = 0 };

        fn base(r: *const Region) u64 {
            return r.buffer.device.addr;
        }

        fn ownsAddr(r: *const Region, addr: u64) bool {
            return addr >= r.base() and addr < r.base() + r.buffer.len;
        }

        fn isLastAllocation(r: *const Region, memory: Slice(u8, .{})) bool {
            return memory.ptr.addr + memory.len == r.base() + r.end_index;
        }

        fn alloc(
            r: *Region,
            len: usize,
            alignment: std.mem.Alignment,
        ) DeviceAllocator.Error!sf.HostDeviceAddress {
            if (r.buffer.len == 0) return error.OutOfMemory;

            const addr = alignment.forward(r.base() + r.end_index);
            const start = addr - r.base();
            const new_end = std.math.add(u64, start, len) catch return error.OutOfMemory;
            if (new_end > r.buffer.len) return error.OutOfMemory;
            r.end_index = new_end;

            return .{
                .device = addr,
                .host = @ptrCast(r.buffer.host + start),
            };
        }

        fn resize(r: *Region, memory: Slice(u8, .{}), new_len: usize) bool {
            std.debug.assert(r.ownsAddr(memory.ptr.addr));
            if (!r.isLastAllocation(memory)) return new_len <= memory.len;
            if (new_len <= memory.len) {
                r.end_index -= memory.len - new_len;
                return true;
            }
            const grow = new_len - memory.len;
            if (r.end_index + grow > r.buffer.len) return false;
            r.end_index += grow;
            return true;
        }

        fn free(r: *Region, memory: Slice(u8, .{})) void {
            if (memory.len == 0) return;
            std.debug.assert(r.ownsAddr(memory.ptr.addr));
            if (r.isLastAllocation(memory)) r.end_index -= memory.len;
        }
    };

    pub fn init(buffers: std.EnumArray(sf.MemoryType, Allocation(u8, null))) FixedBufferAllocator {
        var fba: FixedBufferAllocator = .{ .regions = .initFill(.empty) };
        for (std.enums.values(sf.MemoryType)) |m| {
            fba.regions.getPtr(m).* = .{ .buffer = buffers.get(m), .end_index = 0 };
        }
        return fba;
    }

    pub fn initAlloc(
        gpa: DeviceAllocator,
        sizes: std.EnumArray(sf.MemoryType, usize),
    ) DeviceAllocator.Error!FixedBufferAllocator {
        var fba: FixedBufferAllocator = .{ .regions = .initFill(.empty) };
        errdefer fba.deinit(gpa);
        for (std.enums.values(sf.MemoryType)) |m| {
            fba.regions.getPtr(m).* = .{
                .buffer = try gpa.alloc(u8, sizes.get(m), m),
                .end_index = 0,
            };
        }
        return fba;
    }

    pub fn deinit(fba: *FixedBufferAllocator, gpa: DeviceAllocator) void {
        for (std.enums.values(sf.MemoryType)) |m| {
            const buffer = &fba.regions.getPtr(m).buffer;
            if (buffer.len > 0) gpa.free(buffer.deviceSlice(), m);
            buffer.* = .empty;
        }
    }

    pub fn reset(fba: *FixedBufferAllocator) void {
        for (&fba.regions.values) |*r| r.end_index = 0;
    }

    pub fn allocator(fba: *FixedBufferAllocator) DeviceAllocator {
        return .{
            .ptr = @ptrCast(fba),
            .vtable = &.{
                .alloc = alloc,
                .free = free,
            },
        };
    }

    fn alloc(
        self: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        memory_type: sf.MemoryType,
        ret_addr: usize,
    ) DeviceAllocator.Error!sf.HostDeviceAddress {
        _ = ret_addr;
        const fba: *FixedBufferAllocator = @ptrCast(@alignCast(self));
        return fba.regions.getPtr(memory_type).alloc(len, alignment);
    }

    fn free(
        self: *anyopaque,
        memory: Slice(u8, .{}),
        alignment: std.mem.Alignment,
        memory_type: sf.MemoryType,
        ret_addr: usize,
    ) void {
        _ = alignment;
        _ = ret_addr;
        const fba: *FixedBufferAllocator = @ptrCast(@alignCast(self));
        fba.regions.getPtr(memory_type).free(memory);
    }
};
