// Generated file, do not edit.
// version: 0.1.0

const std = @import("std");
const sf = @import("sf_bindings.zig");

const HandleTypes = struct {
    Instance: type,
    Adapter: type,
    Device: type,
};

fn Functions(handle_types: HandleTypes) type {
    return struct {
        createInstance: *const fn (allocator: ?*sf.Allocator) callconv(sf.@"callconv") *handle_types.Instance,
        destroyInstance: *const fn (instance: *handle_types.Instance) callconv(sf.@"callconv") void,
        getSlot: *const fn (instance: *handle_types.Instance, name: [*:0]const u8) callconv(sf.@"callconv") usize,
        enumerateAdapters: *const fn (instance: *handle_types.Instance, adapters_capacity: usize, adapters: ?[*]*handle_types.Adapter, adapter_count: *usize) callconv(sf.@"callconv") void,
        createDevice: *const fn (instance: *handle_types.Instance, adapter: *handle_types.Adapter) callconv(sf.@"callconv") *handle_types.Device,
        destroyDevice: *const fn (device: *handle_types.Device) callconv(sf.@"callconv") void,
    };
}

pub fn map(
    comptime handle_types: HandleTypes,
    comptime functions: Functions(handle_types),
) std.StaticStringMap(*const anyopaque) {
    return .initComptime(@as([]const struct { []const u8, *const anyopaque }, &.{
        .{ "sfCreateInstance", @ptrCast(functions.createInstance) },
        .{ "sfDestroyInstance", @ptrCast(functions.destroyInstance) },
        .{ "sfGetSlot", @ptrCast(functions.getSlot) },
        .{ "sfEnumerateAdapters", @ptrCast(functions.enumerateAdapters) },
        .{ "sfCreateDevice", @ptrCast(functions.createDevice) },
        .{ "sfDestroyDevice", @ptrCast(functions.destroyDevice) },
    }));
}
