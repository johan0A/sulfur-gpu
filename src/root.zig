const std = @import("std");
const impl = @import("vulkan_implementation.zig");
pub const vk = @import("vulkan");

pub const Allocator = @import("DeviceAllocator.zig");

pub const SizeAndAlignment = struct {
    size: usize,
    alignment: std.mem.Alignment,
};

pub const Memory = enum(u8) {
    default,
    gpu,
    readback,
};

pub const Format = enum(u32) {
    none,
    r8_unorm,
    r8_snorm,
    r8_uint,
    r8_sint,
    r16_unorm,
    r16_snorm,
    r16_uint,
    r16_sint,
    r16_float,
    rg8_unorm,
    rg8_snorm,
    rg8_uint,
    rg8_sint,
    r32_float,
    r32_uint,
    r32_sint,
    rg16_unorm,
    rg16_snorm,
    rg16_uint,
    rg16_sint,
    rg16_float,
    rgba8_unorm,
    rgba8_unorm_srgb,
    rgba8_snorm,
    rgba8_uint,
    rgba8_sint,
    bgra8_unorm,
    bgra8_unorm_srgb,
    rgb10a2_uint,
    rgb10a2_unorm,
    rg11b10_ufloat,
    rgb9e5_ufloat,
    rg32_float,
    rg32_uint,
    rg32_sint,
    rgba16_unorm,
    rgba16_snorm,
    rgba16_uint,
    rgba16_sint,
    rgba16_float,
    rgba32_float,
    rgba32_uint,
    rgba32_sint,
    stencil8,
    depth16_unorm,
    depth24_plus,
    depth24_plus_stencil8,
    depth32_float,
    depth32_float_stencil8,
    bc1rgba_unorm,
    bc1rgba_unorm_srgb,
    bc2rgba_unorm,
    bc2rgba_unorm_srgb,
    bc3rgba_unorm,
    bc3rgba_unorm_srgb,
    bc4r_unorm,
    bc4r_snorm,
    bc5rg_unorm,
    bc5rg_snorm,
    bc6hrgb_ufloat,
    bc6hrgb_float,
    bc7rgba_unorm,
    bc7rgba_unorm_srgb,
    etc2rgb8_unorm,
    etc2rgb8_unorm_srgb,
    etc2rgb8a1_unorm,
    etc2rgb8a1_unorm_srgb,
    etc2rgba8_unorm,
    etc2rgba8_unorm_srgb,
    eacr11_unorm,
    eacr11_snorm,
    eacrg11_unorm,
    eacrg11_snorm,
    astc4x4_unorm,
    astc4x4_unorm_srgb,
    astc5x4_unorm,
    astc5x4_unorm_srgb,
    astc5x5_unorm,
    astc5x5_unorm_srgb,
    astc6x5_unorm,
    astc6x5_unorm_srgb,
    astc6x6_unorm,
    astc6x6_unorm_srgb,
    astc8x5_unorm,
    astc8x5_unorm_srgb,
    astc8x6_unorm,
    astc8x6_unorm_srgb,
    astc8x8_unorm,
    astc8x8_unorm_srgb,
    astc10x5_unorm,
    astc10x5_unorm_srgb,
    astc10x6_unorm,
    astc10x6_unorm_srgb,
    astc10x8_unorm,
    astc10x8_unorm_srgb,
    astc10x10_unorm,
    astc10x10_unorm_srgb,
    astc12x10_unorm,
    astc12x10_unorm_srgb,
    astc12x12_unorm,
    astc12x12_unorm_srgb,
};

pub const PresentMode = enum(u8) {
    immediate,
    mailbox,
    fifo,
    fifo_relaxed,
};

pub const Op = enum(u3) {
    never = 0,
    less = 1,
    equal = 2,
    less_equal = 3,
    greater = 4,
    not_equal = 5,
    greater_equal = 6,
    always = 7,
};

pub const Sampler = packed struct(u64) {
    min_filter: Filter = .linear,
    mag_filter: Filter = .linear,
    mip_filter: MipFilter = .linear,

    address: AddressUVW = .{},

    coord: Coord = .normalized,
    border_color: BorderColor = .transparent_black,
    reduction: Reduction = .weighted_average,
    max_anisotropy: Anisotropy = .x1,

    compare: Compare = .{},

    lod_min: Lod = .min,
    lod_max: Lod = .max,
    lod_bias: Bias = .none,

    _pad: u1 = 0,

    pub const Filter = enum(u1) {
        nearest = 0,
        linear = 1,
    };

    pub const MipFilter = enum(u2) {
        none = 0,
        nearest = 1,
        linear = 2,
    };

    pub const AddressUVW = packed struct(u9) {
        u: Address = .clamp_to_edge,
        v: Address = .clamp_to_edge,
        w: Address = .clamp_to_edge,

        pub fn all(a: Address) AddressUVW {
            return .{ .u = a, .v = a, .w = a };
        }
    };

    pub const Address = enum(u3) {
        repeat = 0,
        mirrored_repeat = 1,
        clamp_to_edge = 2,
        clamp_to_border = 3,
    };

    pub const Coord = enum(u1) {
        normalized = 0,
        pixel = 1,
    };

    pub const BorderColor = enum(u2) {
        transparent_black = 0,
        opaque_black = 1,
        opaque_white = 2,
    };

    pub const Reduction = enum(u2) {
        weighted_average = 0,
        minimum = 1,
        maximum = 2,
    };

    pub const Anisotropy = enum(u3) {
        x1 = 0,
        x2 = 1,
        x4 = 2,
        x8 = 3,
        x16 = 4,
    };

    pub const Compare = packed struct(u4) {
        enable: bool = false,
        op: Op = .never,
    };

    pub const Lod = enum(u12) {
        min = 0,
        max = 0xFFF,
        _,
        pub fn of(x: f32) Lod {
            return @enumFromInt(@as(u12, @intFromFloat(@min(x, 15.996) * 256.0)));
        }
        pub fn toF32(self: Lod) f32 {
            return @as(f32, @floatFromInt(@intFromEnum(self))) / 256.0;
        }
    };

    pub const Bias = enum(i14) {
        none = 0,
        _,
        pub fn of(x: f32) Bias {
            return @enumFromInt(@as(i14, @intFromFloat(x * 256)));
        }
        pub fn toF32(self: Bias) f32 {
            return @as(f32, @floatFromInt(@intFromEnum(self))) / 256;
        }
    };
};

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
        addr: u64,

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

        pub const @"null": @This() =
            if (attributes.optional) .{ .addr = 0 } else @compileError("pointer is not optional");

        pub const alignement: ?std.mem.Alignment = if (attributes.@"align") |a| a else switch (Element) {
            anyopaque => null,
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

        const dangling_ptr: Pointer = .fromInt(
            (Pointer.alignement orelse .@"1").backward(std.math.maxInt(u64)),
        );

        pub const empty: @This() = .{ .ptr = dangling_ptr, .len = 0 };

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

pub const Instance = opaque {
    pub const create: fn (
        gpa: std.mem.Allocator,
        proc: vk.PfnGetInstanceProcAddr,
        required_surface_extensions: []const [*:0]const u8,
    ) *Instance = impl.Instance.create;

    pub const destroy: fn (
        instance: *Instance,
        gpa: std.mem.Allocator,
    ) void = impl.Instance.destroy;

    pub const enumerateAdaptersAlloc: fn (
        instance: *Instance,
        gpa: std.mem.Allocator,
    ) []*Adapter = impl.Instance.enumerateAdaptersAlloc;

    pub const SurfaceDescWin32 = struct {
        hinstance: *anyopaque,
        hwnd: *anyopaque,
    };
};

pub const Surface = opaque {
    pub const Win32Desc = struct {
        hinstance: *anyopaque,
        hwnd: *anyopaque,
    };

    pub const createWin32: fn (
        instance: *Instance,
        desc: Win32Desc,
        gpa: std.mem.Allocator,
    ) *Surface = impl.Surface.createWin32;

    pub const destroy: fn (
        surface: *Surface,
        instance: *Instance,
        gpa: std.mem.Allocator,
    ) void = impl.Surface.destroy;
};

pub const Adapter = opaque {};

pub const SurfaceCapabilities = struct {
    usage: Texture.Usage,
    formats: []const Format,
    present_modes: []const PresentMode,
};

pub const Device = opaque {
    pub const create: fn (
        gpa: std.mem.Allocator,
        instance: *Instance,
        adapter: *Adapter,
    ) *Device = impl.Device.create;

    pub const destroy: fn (
        d: *Device,
    ) void = impl.Device.destroy;

    pub const surfaceCapabilities: fn (
        d: *Device,
        gpa: std.mem.Allocator,
        surface: *Surface,
    ) SurfaceCapabilities = impl.Device.surfaceCapabilities;

    // pub const deviceToHostPointer: fn (
    //     d: *Device,
    //     ptr: anytype,
    // ) @TypeOf(ptr).Host = impl.Device.deviceToHostPointer;

    pub const deviceToHostPointer = impl.Device.deviceToHostPointer;
};

pub const Queue = opaque {
    pub const Type = enum {
        graphics,
        compute,
        transfer,
    };

    pub const create: fn (
        d: *Device,
        queue_type: Type,
    ) *Queue = impl.Queue.create;

    pub const startRecording: fn (
        queue: *Queue,
        d: *Device,
    ) *CommandBuffer = impl.Queue.startRecording;

    pub const submit: fn (
        queue: *Queue,
        d: *Device,
        command_buffers: []const *CommandBuffer,
    ) void = impl.Queue.submit;

    pub const submitAndSignal: fn (
        queue: *Queue,
        d: *Device,
        command_buffers: []const *CommandBuffer,
        signal_semaphore: *Semaphore,
        signal_value: u64,
    ) void = impl.Queue.submitAndSignal;
};

pub const Semaphore = opaque {
    pub const create: fn (
        d: *Device,
        init_value: u64,
    ) *Semaphore = impl.Semaphore.create;

    pub const destroy: fn (
        semaphore: *Semaphore,
        d: *Device,
    ) void = impl.Semaphore.destroy;

    pub const wait: fn (
        semaphore: *Semaphore,
        d: *Device,
        value: u64,
    ) void = impl.Semaphore.wait;
};

pub const Swapchain = opaque {
    pub const Desc = struct {
        format: Format,
        present_mode: PresentMode,
        usage: Texture.Usage,
    };

    pub const create: fn (
        d: *Device,
        queue: *Queue,
        surface: *Surface,
        options: Desc,
    ) *Swapchain = impl.Swapchain.create;

    pub const destroy: fn (
        swapchain: *Swapchain,
        d: *Device,
    ) void = impl.Swapchain.destroy;

    pub const acquireNextTexture: fn (
        swapchain: *Swapchain,
        d: *Device,
        queue: *Queue,
        extent: [2]u32,
    ) *Texture = impl.Swapchain.acquireNextTexture;

    pub const present: fn (
        swapchain: *Swapchain,
        d: *Device,
        queue: *Queue,
        semaphore: *Semaphore,
        semaphore_value: u64,
    ) void = impl.Swapchain.present;
};

pub const Stage = packed struct {
    transfer: bool = false,
    compute: bool = false,
    raster_color_out: bool = false,
    raster_depth_out: bool = false,
    pixel_shader: bool = false,
    vertex_shader: bool = false,

    pub const all: Stage = .{
        .transfer = true,
        .compute = true,
        .raster_color_out = true,
        .raster_depth_out = true,
        .pixel_shader = true,
        .vertex_shader = true,
    };
};

pub const Hazard = packed struct {
    draw_arguments: bool = false,
    descriptors: bool = false,
    depth_stencil: bool = false,
};

pub const CommandBuffer = opaque {
    pub const RenderPassDesc = struct {
        depth_target: DepthTarget = .{},
        stencil_target: StencilTarget = .{},
        color_targets: []const ColorTarget = &.{},
    };

    pub const DepthTarget = struct {
        texture: ?*const Texture = null,
        load_op: LoadOp = .load,
        store_op: StoreOp = .store,
        clear_value: f32 = 1,
    };

    pub const StencilTarget = struct {
        texture: ?*const Texture = null,
        load_op: LoadOp = .load,
        store_op: StoreOp = .store,
        clear_value: u32 = 0,
    };

    pub const ColorTarget = struct {
        texture: *const Texture,
        load_op: LoadOp = .load,
        store_op: StoreOp = .store,
        clear_color: [4]f32 = .{ 0, 0, 0, 0 },
    };

    pub const LoadOp = enum {
        load,
        clear,
        dont_care,
    };

    pub const StoreOp = enum {
        store,
        dont_care,
    };

    pub const IndexType = enum {
        u16,
        u32,
    };

    pub const DrawIndexedArgs = extern struct {
        index_count: u32,
        instance_count: u32 = 1,
        first_index: u32 = 0,
        vertex_offset: i32 = 0,
        first_instance: u32 = 0,
    };

    pub const setActiveTextureHeapPtr: fn (
        command_buffer: *CommandBuffer,
        d: *Device,
        heap_ptr: Slice(u8, .{}),
    ) void = impl.CommandBuffer.setActiveTextureHeapPtr;

    pub const setPipeline: fn (
        command_buffer: *CommandBuffer,
        d: *Device,
        pipeline: *Pipeline,
    ) void = impl.CommandBuffer.setPipeline;

    pub const dispatch: fn (
        command_buffer: *CommandBuffer,
        d: *Device,
        data: Ptr(.one, anyopaque, .{}),
        grid_dimensions: [3]u32,
    ) void = impl.CommandBuffer.dispatch;

    pub const barrier: fn (
        command_buffer: *CommandBuffer,
        d: *Device,
        before: Stage,
        after: Stage,
        hazard: Hazard,
    ) void = impl.CommandBuffer.barrier;

    /// 256 bytes is a typical optimal alignment for dest
    pub const copyTextureToBuffer: fn (
        command_buffer: *CommandBuffer,
        d: *Device,
        dest: Slice(u8, .{ .@"align" = .@"16" }),
        src: Slice(u8, .{}),
        texture: *Texture,
    ) void = impl.CommandBuffer.copyTextureToBuffer;

    pub const copyBufferToTexture: fn (
        command_buffer: *CommandBuffer,
        d: *Device,
        dest: Slice(u8, .{}),
        src: Slice(u8, .{}),
        texture: *Texture,
    ) void = impl.CommandBuffer.copyBufferToTexture;

    pub const beginRenderPass: fn (
        cb: *CommandBuffer,
        d: *Device,
        desc: RenderPassDesc,
    ) void = impl.CommandBuffer.beginRenderPass;

    pub const endRenderPass: fn (
        cb: *CommandBuffer,
        d: *Device,
    ) void = impl.CommandBuffer.endRenderPass;

    pub const draw: fn (
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: Ptr(.one, anyopaque, .{}),
        pixel_data: Ptr(.one, anyopaque, .{}),
        vertex_count: u32,
        instance_count: u32,
    ) void = impl.CommandBuffer.draw;

    // pub const drawIndexed: fn (
    //     cb: *CommandBuffer,
    //     d: *Device,
    //     vertex_data: Ptr(.one, anyopaque, .{}),
    //     pixel_data: Ptr(.one, anyopaque, .{}),
    //     comptime index_type: IndexType,
    //     indices: switch (index_type) {
    //         .u16 => Ptr(.many, u16, .{ .@"const" = true }),
    //         .u32 => Ptr(.many, u32, .{ .@"const" = true }),
    //     },
    //     index_count: u32,
    // ) void = impl.CommandBuffer.drawIndexed;

    pub const drawIndexed = impl.CommandBuffer.drawIndexed;

    // pub const drawIndexedInstanced: fn (
    //     cb: *CommandBuffer,
    //     d: *Device,
    //     vertex_data: Ptr(.one, anyopaque, .{}),
    //     pixel_data: Ptr(.one, anyopaque, .{}),
    //     comptime index_type: IndexType,
    //     indices: switch (index_type) {
    //         .u16 => Ptr(.many, u16, .{ .@"const" = true }),
    //         .u32 => Ptr(.many, u32, .{ .@"const" = true }),
    //     },
    //     index_count: u32,
    //     instance_count: u32,
    // ) void = impl.CommandBuffer.drawIndexedInstanced;

    pub const drawIndexedInstanced = impl.CommandBuffer.drawIndexedInstanced;

    // pub const drawIndexedInstancedIndirect: fn (
    //     cb: *CommandBuffer,
    //     d: *Device,
    //     vertex_data: Ptr(.one, anyopaque, .{}),
    //     pixel_data: Ptr(.one, anyopaque, .{}),
    //     comptime index_type: IndexType,
    //     indices: switch (index_type) {
    //         .u16 => Ptr(.many, u16, .{ .@"const" = true }),
    //         .u32 => Ptr(.many, u32, .{ .@"const" = true }),
    //     },
    //     args: Ptr(.one, DrawIndexedArgs, .{ .@"const" = true }),
    // ) void = impl.CommandBuffer.drawIndexedInstancedIndirect;

    pub const drawIndexedInstancedIndirect = impl.CommandBuffer.drawIndexedInstancedIndirect;
};

pub const Texture = opaque {
    pub const Type = enum {
        @"1d",
        @"2d",
        @"3d",
    };

    pub const Usage = packed struct(u16) {
        sampled: bool = false,
        storage: bool = false,
        color_attachment: bool = false,
        depth_stencil_attachment: bool = false,
        padding: u12 = 0,
    };

    pub const Desc = struct {
        type: Type = .@"2d",
        dimensions: [3]u32,
        mip_count: u32 = 1,
        layer_count: u32 = 1,
        // sample_count: u32 = 1, TODO
        format: Format = .none,
        usage: Usage = .{},
    };

    pub const ViewInfo = struct {
        pub const all_mips = std.math.maxInt(u8);
        pub const all_layers = std.math.maxInt(u16);

        format: Format = .none,
        base_mip: u8 = 0,
        mip_count: u8 = all_mips,
        base_layer: u16 = 0,
        layer_count: u16 = all_layers,
    };

    pub const Descriptor = struct {
        data: [64]u8,

        pub const sizeAndHeapAlignment: fn (
            d: *Device,
        ) SizeAndAlignment = impl.Texture.Descriptor.sizeAndHeapAlignment;

        pub fn store(descriptor: Descriptor, d: *Device, heap_ptr: []u8, index: usize) void {
            const size_align = Descriptor.sizeAndHeapAlignment(d);
            @memcpy(
                @as([*]u8, @ptrCast(heap_ptr)) + size_align.size * index,
                descriptor.data[0..size_align.size],
            );
        }
    };

    pub const sizeAndAlignment: fn (
        d: *Device,
        info: Desc,
    ) SizeAndAlignment = impl.Texture.sizeAndAlignment;

    pub const create: fn (
        d: *Device,
        info: Desc,
        texture_data: Slice(u8, .{}),
    ) *Texture = impl.Texture.create;

    pub const destroy: fn (
        texture: *Texture,
        d: *Device,
    ) void = impl.Texture.destroy;

    pub const storageDescriptor: fn (
        texture: *Texture,
        d: *Device,
        view_info: ViewInfo,
    ) Descriptor = impl.Texture.storageDescriptor;

    pub const viewDescriptor: fn (
        texture: *Texture,
        d: *Device,
        view_info: ViewInfo,
    ) Descriptor = impl.Texture.viewDescriptor;
};

pub const Pipeline = opaque {
    pub const RasterDesc = struct {
        topology: Topology = .triangle_list,
        cull: Cull = .none,
        alpha_to_coverage: bool = false,
        support_dual_source_blending: bool = false,
        sample_count: u8 = 1,
        depth_format: Format = .none,
        stencil_format: Format = .none,
        color_targets: []const ColorTarget = &.{},
        /// optional embedded blend state
        blend_state: ?BlendDesc = null,
    };

    pub const Topology = enum {
        triangle_list,
        triangle_strip,
        triangle_fan,
    };

    pub const Cull = enum {
        ccw,
        cw,
        all,
        none,
    };

    pub const ColorTarget = struct {
        format: Format = .none,
        write_mask: RgbaWriteMask = .all,
    };

    pub const BlendDesc = struct {
        color_op: Blend = .add,
        src_color_factor: Factor = .one,
        dst_color_factor: Factor = .zero,
        alpha_op: Blend = .add,
        src_alpha_factor: Factor = .one,
        dst_alpha_factor: Factor = .zero,
        color_write_mask: RgbaWriteMask = .all,
    };

    pub const RgbaWriteMask = packed struct(u4) {
        r: bool,
        g: bool,
        b: bool,
        a: bool,

        pub const all: RgbaWriteMask = .{
            .r = true,
            .g = true,
            .b = true,
            .a = true,
        };

        pub fn toInt(self: RgbaWriteMask) u4 {
            return @bitCast(self);
        }
        pub fn fromInt(flags: u4) RgbaWriteMask {
            return @bitCast(flags);
        }
        pub fn merge(lhs: RgbaWriteMask, rhs: RgbaWriteMask) RgbaWriteMask {
            return fromInt(toInt(lhs) | toInt(rhs));
        }
    };

    pub const Blend = enum {
        add,
        subtract,
        reverse_subtract,
        min,
        max,
    };

    pub const Factor = enum {
        zero,
        one,
        src_color,
        dst_color,
        src_alpha,
    };

    pub const createCompute: fn (
        d: *Device,
        ir: []const u8,
    ) *Pipeline = impl.Pipeline.createCompute;

    pub const createGraphics: fn (
        d: *Device,
        vertex_ir: []const u8,
        pixel_ir: []const u8,
        desc: RasterDesc,
    ) *Pipeline = impl.Pipeline.createGraphics;

    pub const destroy: fn (
        pipeline: *Pipeline,
        d: *Device,
    ) void = impl.Pipeline.destroy;
};

pub const heap = struct {
    pub fn rawDeviceAllocator(d: *Device) Allocator {
        return .{
            .ptr = @ptrCast(d),
            .vtable = &.{
                .alloc = raw_device_allocator.alloc,
                .resize = Allocator.noResize, // TODO
                .remap = Allocator.noRemap, // TODO
                .free = raw_device_allocator.free,
            },
        };
    }

    pub const raw_device_allocator = struct {
        pub fn alloc(
            self: *anyopaque,
            len: usize,
            alignment: std.mem.Alignment,
            memory_type: Memory,
            ret_addr: usize,
        ) Ptr(.many, u8, .{ .optional = true }) {
            _ = ret_addr;
            const device: *Device = @ptrCast(@alignCast(self));
            // return .cast(rawAlloc(device, len, alignment, memory_type) catch return .null);
            return .cast(rawAlloc(device, len, alignment, memory_type));
        }

        pub fn free(
            self: *anyopaque,
            memory: Slice(u8, .{}),
            alignment: std.mem.Alignment,
            memory_type: Memory,
            ret_addr: usize,
        ) void {
            _ = alignment;
            _ = memory_type;
            _ = ret_addr;
            const device: *Device = @ptrCast(@alignCast(self));
            return rawFree(device, .cast(memory.ptr));
        }

        pub const rawAlloc: fn (
            d: *Device,
            bytes: usize,
            alignment: std.mem.Alignment,
            memory: Memory,
        ) Ptr(.one, anyopaque, .{}) = impl.heap.rawAlloc;

        pub const rawFree: fn (
            d: *Device,
            ptr: Ptr(.one, anyopaque, .{}),
        ) void = impl.heap.rawFree;
    };

    pub const FixedBufferAllocator = struct {
        regions: std.EnumArray(Memory, Region),

        const Region = struct {
            buffer: Slice(u8, .{}),
            end_index: u64,

            const empty: Region = .{ .buffer = .empty, .end_index = 0 };

            fn ownsAddr(r: *const Region, addr: u64) bool {
                return addr >= r.buffer.ptr.addr and addr < r.buffer.ptr.addr + r.buffer.len;
            }

            fn isLastAllocation(r: *const Region, memory: Slice(u8, .{})) bool {
                return memory.ptr.addr + memory.len == r.buffer.ptr.addr + r.end_index;
            }

            fn alloc(
                r: *Region,
                len: usize,
                alignment: std.mem.Alignment,
            ) Ptr(.many, u8, .{ .optional = true }) {
                if (r.buffer.len == 0) return .null;
                const addr = std.mem.alignForward(
                    u64,
                    r.buffer.ptr.addr + r.end_index,
                    alignment.toByteUnits(),
                );
                const new_end = addr + len - r.buffer.ptr.addr;
                if (new_end > r.buffer.len) return .null;
                r.end_index = new_end;
                return .fromInt(addr);
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
                std.debug.assert(r.ownsAddr(memory.ptr.addr));
                if (r.isLastAllocation(memory)) r.end_index -= memory.len;
            }
        };

        pub fn init(buffers: std.EnumArray(Memory, Slice(u8, .{}))) FixedBufferAllocator {
            var fba: FixedBufferAllocator = .{ .regions = .initFill(.empty) };
            for (std.enums.values(Memory)) |m| {
                fba.regions.getPtr(m).* = .{ .buffer = buffers.get(m), .end_index = 0 };
            }
            return fba;
        }

        pub fn initAlloc(
            gpa: Allocator,
            sizes: std.enums.EnumFieldStruct(Memory, ?usize, @as(?usize, null)),
            default_size: usize,
        ) !FixedBufferAllocator {
            var fba: FixedBufferAllocator = .{ .regions = .initFill(.empty) };
            errdefer fba.deinit(gpa);
            inline for (comptime std.enums.values(Memory)) |memory| {
                const size = @field(sizes, @tagName(memory)) orelse default_size;
                const buffer = try gpa.alloc(u8, size, memory);
                if (size > 0) {
                    fba.regions.getPtr(memory).* = .{
                        .buffer = buffer,
                        .end_index = 0,
                    };
                }
            }
            return fba;
        }

        pub fn deinit(fba: *FixedBufferAllocator, gpa: Allocator) void {
            var it = fba.regions.iterator();
            while (it.next()) |item| {
                if (item.value.buffer.len > 0) gpa.free(item.value.buffer, item.key);
                item.value.* = .empty;
            }
        }

        pub fn reset(fba: *FixedBufferAllocator) void {
            for (&fba.regions.values) |*r| r.end_index = 0;
        }

        pub fn allocator(fba: *FixedBufferAllocator) Allocator {
            return .{
                .ptr = @ptrCast(fba),
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .remap = remap,
                    .free = free,
                },
            };
        }

        fn alloc(
            self: *anyopaque,
            len: usize,
            alignment: std.mem.Alignment,
            memory_type: Memory,
            ret_addr: usize,
        ) Ptr(.many, u8, .{ .optional = true }) {
            _ = ret_addr;
            const fba: *FixedBufferAllocator = @ptrCast(@alignCast(self));
            return fba.regions.getPtr(memory_type).alloc(len, alignment);
        }

        fn resize(
            self: *anyopaque,
            memory: Slice(u8, .{}),
            alignment: std.mem.Alignment,
            new_len: usize,
            memory_type: Memory,
            ret_addr: usize,
        ) bool {
            _ = alignment;
            _ = ret_addr;
            const fba: *FixedBufferAllocator = @ptrCast(@alignCast(self));
            return fba.regions.getPtr(memory_type).resize(memory, new_len);
        }

        fn remap(
            self: *anyopaque,
            memory: Slice(u8, .{}),
            alignment: std.mem.Alignment,
            new_len: usize,
            memory_type: Memory,
            ret_addr: usize,
        ) Ptr(.many, u8, .{ .optional = true }) {
            return if (resize(self, memory, alignment, new_len, memory_type, ret_addr)) .{ .addr = memory.ptr.addr } else .null;
        }

        fn free(
            self: *anyopaque,
            memory: Slice(u8, .{}),
            alignment: std.mem.Alignment,
            memory_type: Memory,
            ret_addr: usize,
        ) void {
            _ = alignment;
            _ = ret_addr;
            const fba: *FixedBufferAllocator = @ptrCast(@alignCast(self));
            fba.regions.getPtr(memory_type).free(memory);
        }
    };
};
