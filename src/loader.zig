const std = @import("std");
const gpu = @import("sf_bindings.zig");
const impl = @import("vulkan_implementation.zig");

pub export fn sfProcAddr(name: [*:0]u8) callconv(gpu.@"callconv") *const anyopaque {
    const map: std.StaticStringMap(*const anyopaque) = .initComptime(@as([]const struct { []const u8, *const anyopaque }, &.{
        .{ "sfCreateInstance", @ptrCast(&createInstance) },
        .{ "sfGetSlot", @ptrCast(&getSlot) },
        .{ "sfEnumerateAdapters", @ptrCast(&enumerateAdapters) },
        .{ "sfCreateDevice", @ptrCast(&createDevice) },
        .{ "sfDestroyDevice", @ptrCast(&destroyDevice) },
    }));
    return map.get(std.mem.span(name)) orelse undefined;
}

var slot_index: usize = 0;
var table: [1024]*const anyopaque = undefined;

fn createInstance(allocator: ?*gpu.Allocator) callconv(gpu.@"callconv") *impl.Header(impl.Instance) {
    const instance = impl.Instance.sfCreateInstance(allocator);
    instance.table = @ptrCast(&table);
    return instance;
}

fn getSlot(instance: *impl.Header(impl.Instance), name: [*:0]u8) callconv(gpu.@"callconv") usize {
    _ = instance;
    slot_index += 1;
    table[slot_index] = impl.sfProcAddr(name);
    return slot_index;
}

fn enumerateAdapters(
    instance: *impl.Header(impl.Instance),
    adapters_capacity: usize,
    adapters: ?[*]*impl.Adapter,
    adapter_count: *usize,
) callconv(gpu.@"callconv") void {
    impl.Instance.sfEnumerateAdapters(instance, adapters_capacity, adapters, adapter_count);
}

fn createDevice(instance: *impl.Header(impl.Instance), adapter: *impl.Adapter) callconv(gpu.@"callconv") *impl.Header(impl.Device) {
    return impl.Device.sfCreateDevice(instance, adapter);
}

fn destroyDevice(device: *impl.Header(impl.Device)) callconv(gpu.@"callconv") void {
    impl.Device.sfDestroyDevice(device);
}
