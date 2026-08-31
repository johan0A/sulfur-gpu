const std = @import("std");
const gpu = @import("sf_minimal.zig");
const impl = @import("vulkan_implementation.zig");
const symbol_map = @import("loader_symbol_map.zig");

pub export fn sfSymbol(name: [*:0]u8) callconv(gpu.@"callconv") *const anyopaque {
    const map = symbol_map.map(.{
        .Instance = impl.Header(impl.Instance),
        .Adapter = impl.Adapter,
        .Device = impl.Header(impl.Device),
    }, .{
        .createInstance = createInstance,
        .destroyInstance = destroyInstance,
        .getSlot = getSlot,
        .enumerateAdapters = enumerateAdapters,
        .createDevice = createDevice,
        .destroyDevice = destroyDevice,
    });
    return map.get(std.mem.span(name)).?;
}

var slot_index: usize = 0;
var table: [1024]*const anyopaque = undefined;

fn createInstance(allocator: ?*gpu.Allocator) *impl.Header(impl.Instance) {
    const instance = impl.Instance.sfCreateInstance(allocator);
    instance.table = @ptrCast(&table);
    return instance;
}

fn destroyInstance(instance: *impl.Header(impl.Instance)) void {
    impl.Instance.sfDestroyInstance(instance);
}

fn getSlot(instance: *impl.Header(impl.Instance), name: [*:0]const u8) usize {
    _ = instance;
    slot_index += 1;
    table[slot_index] = impl.sfSymbol(name);
    return slot_index;
}

fn enumerateAdapters(
    instance: *impl.Header(impl.Instance),
    adapters_capacity: usize,
    adapters: ?[*]*impl.Adapter,
    adapter_count: *usize,
) void {
    impl.Instance.sfEnumerateAdapters(instance, adapters_capacity, adapters, adapter_count);
}

fn createDevice(instance: *impl.Header(impl.Instance), adapter: *impl.Adapter) *impl.Header(impl.Device) {
    return impl.Device.sfCreateDevice(instance, adapter);
}

fn destroyDevice(device: *impl.Header(impl.Device)) void {
    impl.Device.sfDestroyDevice(device);
}
