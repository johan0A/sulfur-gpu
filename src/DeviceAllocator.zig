const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const Alignment = std.mem.Alignment;

const gpu = @import("root.zig");
const Ptr = gpu.Ptr;
const Slice = gpu.Slice;

const Allocator = @This();

pub const Error = error{OutOfDeviceMemory};

pub const BytePtr = Ptr(.many, u8, .{});
pub const OptionalBytePtr = Ptr(.many, u8, .{ .optional = true });
pub const ByteSlice = Slice(u8, .{});

/// The type erased pointer to the allocator implementation.
///
/// Any comparison of this field may result in illegal behavior, since it may
/// be set to `undefined` in cases where the allocator implementation does not
/// have any associated state.
ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Return a device address of `len` bytes with specified `alignment`, or
    /// return `.null` indicating the allocation failed.
    ///
    /// `ret_addr` is optionally provided as the first return address of the
    /// allocation call stack. If the value is `0` it means no return address
    /// has been provided.
    alloc: *const fn (*anyopaque, len: usize, alignment: Alignment, memory_type: gpu.Memory, ret_addr: usize) OptionalBytePtr,

    /// Attempt to expand or shrink memory in place.
    ///
    /// `memory.len` must equal the length requested from the most recent
    /// successful call to `alloc`, `resize`, or `remap`. `alignment` must
    /// equal the same value that was passed as the `alignment` parameter to
    /// the original `alloc` call.
    ///
    /// A result of `true` indicates the resize was successful and the
    /// allocation now has the same address but a size of `new_len`. `false`
    /// indicates the resize could not be completed without moving the
    /// allocation to a different address.
    ///
    /// `new_len` must be greater than zero.
    resize: *const fn (*anyopaque, memory: ByteSlice, alignment: Alignment, new_len: usize, memory_type: gpu.Memory, ret_addr: usize) bool,

    /// Attempt to expand or shrink memory, allowing relocation.
    ///
    /// `memory.len` must equal the length requested from the most recent
    /// successful call to `alloc`, `resize`, or `remap`. `alignment` must
    /// equal the same value that was passed as the `alignment` parameter to
    /// the original `alloc` call.
    ///
    /// A non-`.null` return value indicates the resize was successful. The
    /// allocation may have same address, or may have been relocated. In
    /// either case, the allocation now has size of `new_len`. A `.null`
    /// return value indicates that the resize would be equivalent to
    /// allocating new memory, copying the bytes from the old memory (on the
    /// device), and then freeing the old memory. In such case, the caller
    /// must perform that copy itself with a device transfer.
    ///
    /// `new_len` must be greater than zero.
    remap: *const fn (*anyopaque, memory: ByteSlice, alignment: Alignment, new_len: usize, memory_type: gpu.Memory, ret_addr: usize) OptionalBytePtr,

    /// Free and invalidate a region of device memory.
    ///
    /// `memory.len` must equal the length requested from the most recent
    /// successful call to `alloc`, `resize`, or `remap`. `alignment` must
    /// equal the same value that was passed as the `alignment` parameter to
    /// the original `alloc` call.
    free: *const fn (*anyopaque, memory: ByteSlice, alignment: Alignment, memory_type: gpu.Memory, ret_addr: usize) void,
};

pub fn noAlloc(
    self: *anyopaque,
    len: usize,
    alignment: Alignment,
    memory_type: gpu.Memory,
    ret_addr: usize,
) OptionalBytePtr {
    _ = self;
    _ = len;
    _ = alignment;
    _ = memory_type;
    _ = ret_addr;
    return .null;
}

pub fn noResize(
    self: *anyopaque,
    memory: ByteSlice,
    alignment: Alignment,
    new_len: usize,
    memory_type: gpu.Memory,
    ret_addr: usize,
) bool {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = new_len;
    _ = memory_type;
    _ = ret_addr;
    return false;
}

pub fn noRemap(
    self: *anyopaque,
    memory: ByteSlice,
    alignment: Alignment,
    new_len: usize,
    memory_type: gpu.Memory,
    ret_addr: usize,
) OptionalBytePtr {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = new_len;
    _ = memory_type;
    _ = ret_addr;
    return .null;
}

pub fn noFree(
    self: *anyopaque,
    memory: ByteSlice,
    alignment: Alignment,
    memory_type: gpu.Memory,
    ret_addr: usize,
) void {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = memory_type;
    _ = ret_addr;
}

/// This function is not intended to be called except from within the
/// implementation of an `Allocator`.
pub inline fn rawAlloc(a: Allocator, len: usize, alignment: Alignment, memory_type: gpu.Memory, ret_addr: usize) OptionalBytePtr {
    return a.vtable.alloc(a.ptr, len, alignment, memory_type, ret_addr);
}

/// This function is not intended to be called except from within the
/// implementation of an `Allocator`.
pub inline fn rawResize(a: Allocator, memory: ByteSlice, alignment: Alignment, new_len: usize, memory_type: gpu.Memory, ret_addr: usize) bool {
    return a.vtable.resize(a.ptr, memory, alignment, new_len, memory_type, ret_addr);
}

/// This function is not intended to be called except from within the
/// implementation of an `Allocator`.
pub inline fn rawRemap(a: Allocator, memory: ByteSlice, alignment: Alignment, new_len: usize, memory_type: gpu.Memory, ret_addr: usize) OptionalBytePtr {
    return a.vtable.remap(a.ptr, memory, alignment, new_len, memory_type, ret_addr);
}

/// This function is not intended to be called except from within the
/// implementation of an `Allocator`.
pub inline fn rawFree(a: Allocator, memory: ByteSlice, alignment: Alignment, memory_type: gpu.Memory, ret_addr: usize) void {
    return a.vtable.free(a.ptr, memory, alignment, memory_type, ret_addr);
}

/// Returns a device pointer to uninitialized memory for one `T`.
/// Call `destroy` with the result to free the memory.
pub fn create(a: Allocator, comptime T: type, memory: gpu.Memory) Error!Ptr(.one, T, .{}) {
    if (@sizeOf(T) == 0) return .fromInt(
        (Ptr(.one, T, .{}).alignement orelse .@"1").backward(std.math.maxInt(u64)),
    );
    const byte_ptr = try a.allocBytesWithAlignment(.of(T), @sizeOf(T), memory, @returnAddress());
    return .fromInt(byte_ptr.addr);
}

/// `ptr` should be the return value of `create`, or otherwise
/// have the same address and alignment property.
pub fn destroy(self: Allocator, ptr: anytype, memory: gpu.Memory) void {
    const info = @TypeOf(ptr).info;
    if (info.size != .one) @compileError("ptr must be a single item device pointer");
    const T = info.Element;
    if (@sizeOf(T) == 0) return;
    self.rawFree(
        .{ .ptr = .{ .addr = ptr.addr }, .len = @sizeOf(T) },
        comptime info.attributes.@"align" orelse .of(T),
        memory,
        @returnAddress(),
    );
}

/// Allocates a device slice of `n` uninitialized items of type `T`.
/// Depending on the Allocator implementation, it may be required to call
/// `free` once the memory is no longer needed, to avoid a resource leak. If
/// the `Allocator` implementation is unknown, then correct code will call
/// `free` when done.
///
/// For allocating a single item, see `create`.
pub fn alloc(self: Allocator, comptime T: type, n: usize, memory: gpu.Memory) Error!Slice(T, .{}) {
    return self.alignedAllocWithRetAddr(T, null, n, memory, @returnAddress());
}

pub fn alignedAlloc(
    self: Allocator,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?Alignment,
    n: usize,
    memory: gpu.Memory,
) Error!Slice(T, .{ .@"align" = alignment }) {
    return self.alignedAllocWithRetAddr(T, alignment, n, memory, @returnAddress());
}

pub fn runtimeAlignedAlloc(
    self: Allocator,
    comptime T: type,
    alignment: Alignment,
    n: usize,
    memory: gpu.Memory,
) Error!Slice(T, .{}) {
    return self.runtimeAlignedAllocWithRetAddr(T, alignment, n, memory, @returnAddress());
}

pub inline fn alignedAllocWithRetAddr(
    self: Allocator,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?Alignment,
    n: usize,
    memory: gpu.Memory,
    return_address: usize,
) Error!Slice(T, .{ .@"align" = alignment }) {
    const a: Alignment = alignment orelse comptime .of(T);
    return .alignCast(try self.runtimeAlignedAllocWithRetAddr(T, a, n, memory, return_address));
}

pub inline fn runtimeAlignedAllocWithRetAddr(
    self: Allocator,
    comptime T: type,
    alignment: Alignment,
    n: usize,
    memory: gpu.Memory,
    return_address: usize,
) Error!Slice(T, .{}) {
    const byte_count = math.mul(usize, @sizeOf(T), n) catch return error.OutOfDeviceMemory;
    const byte_ptr = try self.allocBytesWithAlignment(alignment, byte_count, memory, return_address);
    return .{ .ptr = .fromInt(byte_ptr.addr), .len = n };
}

fn allocBytesWithAlignment(
    self: Allocator,
    alignment: Alignment,
    byte_count: usize,
    memory: gpu.Memory,
    return_address: usize,
) Error!Ptr(.many, u8, .{}) {
    if (byte_count == 0) return .fromInt(
        alignment.backward(std.math.maxInt(u64)),
    );
    const byte_ptr = self.rawAlloc(byte_count, alignment, memory, return_address);
    if (byte_ptr.isNull()) return error.OutOfDeviceMemory;
    return .fromInt(byte_ptr.addr);
}

/// Request to modify the size of an allocation.
///
/// It is guaranteed to not move the address, however the allocator
/// implementation may refuse the resize request by returning `false`.
///
/// `allocation` may be an empty slice, in which case `false` is returned,
/// unless `new_len` is also 0, in which case `true` is returned.
///
/// `new_len` may be zero, in which case the allocation is freed.
pub fn resize(self: Allocator, allocation: anytype, new_len: usize, memory: gpu.Memory) bool {
    const info = @TypeOf(allocation).info;
    comptime assert(info.size == .slice);
    const T = info.Element;
    if (new_len == 0) {
        self.free(allocation, memory);
        return true;
    }
    if (allocation.len == 0) {
        return false;
    }
    const new_len_bytes = math.mul(usize, @sizeOf(T), new_len) catch return false;
    return self.rawResize(
        allocation.asBytes(),
        comptime info.attributes.@"align" orelse .of(T),
        new_len_bytes,
        memory,
        @returnAddress(),
    );
}

/// Request to modify the size of an allocation, allowing relocation.
///
/// A non-`null` return value indicates the resize was successful. The
/// allocation may have same address, or may have been relocated. In either
/// case, the allocation now has size of `new_len`. A `null` return value
/// indicates that the resize would be equivalent to allocating new memory,
/// copying the bytes from the old memory with a device transfer, and then
/// freeing the old memory. The caller must perform those operations itself,
/// since this interface cannot copy device memory.
///
/// `allocation` may be an empty slice, in which case `null` is returned,
/// unless `new_len` is also 0, in which case `allocation` is returned.
///
/// `new_len` may be zero, in which case the allocation is freed.
///
/// If the allocation's elements' type is zero bytes sized, `allocation.len`
/// is set to `new_len`.
pub fn remap(self: Allocator, allocation: anytype, new_len: usize, memory: gpu.Memory) ?@TypeOf(allocation) {
    const info = @TypeOf(allocation).info;
    comptime assert(info.size == .slice);
    const T = info.Element;

    if (new_len == 0) {
        self.free(allocation, memory);
        return .{ .ptr = allocation.ptr, .len = 0 };
    }
    if (allocation.len == 0) {
        return null;
    }
    if (@sizeOf(T) == 0) {
        return .{ .ptr = allocation.ptr, .len = new_len };
    }
    const new_len_bytes = math.mul(usize, @sizeOf(T), new_len) catch return null;
    const new_ptr = self.rawRemap(
        allocation.asBytes(),
        comptime info.attributes.@"align" orelse .of(T),
        new_len_bytes,
        memory,
        @returnAddress(),
    );
    if (new_ptr.isNull()) return null;
    return .{ .ptr = .fromInt(new_ptr.addr), .len = new_len };
}

/// Free a device slice allocated with `alloc`.
/// If memory has length 0, free is a no-op.
/// To free a single item, see `destroy`.
pub fn free(self: Allocator, allocation: anytype, memory_type: gpu.Memory) void {
    const info = @TypeOf(allocation.ptr).info;
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

pub fn runtimeAlignedfree(self: Allocator, allocation: anytype, alignment: Alignment, memory_type: gpu.Memory) void {
    const bytes = allocation.asBytes();
    if (bytes.len == 0) return;
    self.rawFree(
        .from(bytes),
        alignment,
        memory_type,
        @returnAddress(),
    );
}

/// An allocator that always fails to allocate.
pub const failing: Allocator = .{
    .ptr = undefined,
    .vtable = &.{
        .alloc = noAlloc,
        .resize = unreachableResize,
        .remap = unreachableRemap,
        .free = unreachableFree,
    },
};

fn unreachableResize(
    self: *anyopaque,
    memory: ByteSlice,
    alignment: Alignment,
    new_len: usize,
    memory_type: gpu.Memory,
    ret_addr: usize,
) bool {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = new_len;
    _ = memory_type;
    _ = ret_addr;
    unreachable;
}

fn unreachableRemap(
    self: *anyopaque,
    memory: ByteSlice,
    alignment: Alignment,
    new_len: usize,
    memory_type: gpu.Memory,
    ret_addr: usize,
) OptionalBytePtr {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = new_len;
    _ = memory_type;
    _ = ret_addr;
    unreachable;
}

fn unreachableFree(
    self: *anyopaque,
    memory: ByteSlice,
    alignment: Alignment,
    memory_type: gpu.Memory,
    ret_addr: usize,
) void {
    _ = self;
    _ = memory;
    _ = alignment;
    _ = memory_type;
    _ = ret_addr;
    unreachable;
}

test failing {
    const f: Allocator = .failing;
    try std.testing.expectError(error.OutOfDeviceMemory, f.alloc(u8, 123, .gpu));
}
