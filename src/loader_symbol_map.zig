// Generated file, do not edit.
// version: 0.1.0

const std = @import("std");
const sf = @import("sf_minimal.zig");

const HandleTypes = struct {
    Instance: type,
    Adapter: type,
    Device: type,
};

fn Functions(handle_types: HandleTypes) type {
    return struct {
        createInstance: fn (
            allocator: ?*sf.Allocator,
        ) *handle_types.Instance,
        destroyInstance: fn (
            instance: *handle_types.Instance,
        ) void,
        getSlot: fn (
            instance: *handle_types.Instance,
            name: [*:0]const u8,
        ) usize,
        enumerateAdapters: fn (
            instance: *handle_types.Instance,
            adapters_capacity: usize,
            adapters: ?[*]*handle_types.Adapter,
            adapter_count: *usize,
        ) void,
        createDevice: fn (
            instance: *handle_types.Instance,
            adapter: *handle_types.Adapter,
        ) *handle_types.Device,
        destroyDevice: fn (
            device: *handle_types.Device,
        ) void,
    };
}

const Error = error{
    OutOfMemory,
    OutOfDeviceMemory,
    DeviceLost,
    SurfaceLost,
    Unknown,
};

fn cResult(result: anytype) sf.Result {
    if (result) return .ok else |err| return switch (@as(Error, err)) {
        error.OutOfMemory => .out_of_memory,
        error.OutOfDeviceMemory => .out_of_device_memory,
        error.DeviceLost => .device_lost,
        error.SurfaceLost => .surface_lost,
        error.Unknown => .unknown,
    };
}

fn CFunctions(comptime handle_types: HandleTypes, comptime functions: Functions(handle_types)) type {
    return struct {
        pub fn createInstance(
            allocator: ?*sf.Allocator,
        ) callconv(sf.@"callconv") *handle_types.Instance {
            return functions.createInstance(
                allocator,
            );
        }

        pub fn destroyInstance(
            instance: *handle_types.Instance,
        ) callconv(sf.@"callconv") void {
            return functions.destroyInstance(
                instance,
            );
        }

        pub fn getSlot(
            instance: *handle_types.Instance,
            name: [*:0]const u8,
        ) callconv(sf.@"callconv") usize {
            return functions.getSlot(
                instance,
                name,
            );
        }

        pub fn enumerateAdapters(
            instance: *handle_types.Instance,
            adapters_capacity: usize,
            adapters: ?[*]*handle_types.Adapter,
            adapter_count: *usize,
        ) callconv(sf.@"callconv") void {
            return functions.enumerateAdapters(
                instance,
                adapters_capacity,
                adapters,
                adapter_count,
            );
        }

        pub fn createDevice(
            instance: *handle_types.Instance,
            adapter: *handle_types.Adapter,
        ) callconv(sf.@"callconv") *handle_types.Device {
            return functions.createDevice(
                instance,
                adapter,
            );
        }

        pub fn destroyDevice(
            device: *handle_types.Device,
        ) callconv(sf.@"callconv") void {
            return functions.destroyDevice(
                device,
            );
        }
    };
}

pub fn map(
    comptime handle_types: HandleTypes,
    comptime functions: Functions(handle_types),
) std.StaticStringMap(*const anyopaque) {
    const c_functions = CFunctions(handle_types, functions);
    return .initComptime(@as([]const struct { []const u8, *const anyopaque }, &.{
        .{ "sfCreateInstance", @ptrCast(&c_functions.createInstance) },
        .{ "sfDestroyInstance", @ptrCast(&c_functions.destroyInstance) },
        .{ "sfGetSlot", @ptrCast(&c_functions.getSlot) },
        .{ "sfEnumerateAdapters", @ptrCast(&c_functions.enumerateAdapters) },
        .{ "sfCreateDevice", @ptrCast(&c_functions.createDevice) },
        .{ "sfDestroyDevice", @ptrCast(&c_functions.destroyDevice) },
    }));
}
