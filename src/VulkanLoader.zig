proc: vk.PfnGetInstanceProcAddr,
handle: Handle,

const HMODULE = *opaque {};

extern "kernel32" fn LoadLibraryA(
    name: [*:0]const u8,
) callconv(.winapi) ?HMODULE;

extern "kernel32" fn GetProcAddress(
    module: HMODULE,
    name: [*:0]const u8,
) callconv(.winapi) ?*const anyopaque;

extern "kernel32" fn FreeLibrary(
    module: HMODULE,
) callconv(.winapi) i32;

const Handle = switch (builtin.os.tag) {
    .windows => HMODULE,
    .linux, .macos => *anyopaque,
    else => @compileError("unsupported"),
};

pub fn open() !VulkanLoader {
    return switch (builtin.os.tag) {
        .windows => openWindows(),
        .linux => openPosix(&.{
            "libvulkan.so.1",
            "libvulkan.so",
        }),
        .macos => openPosix(&.{
            "libvulkan.1.dylib",
            "libvulkan.dylib",
            "libMoltenVK.dylib",
            "/Library/Frameworks/MoltenVK.framework/MoltenVK",
        }),
        else => @compileError("unsupported"),
    };
}

fn openWindows() !VulkanLoader {
    const module = LoadLibraryA("vulkan-1.dll") orelse return error.VulkanLoaderNotFound;
    errdefer _ = FreeLibrary(module);
    const symbol = GetProcAddress(module, "vkGetInstanceProcAddr") orelse return error.GetInstanceProcAddrNotFound;
    return .{
        .proc = @ptrCast(symbol),
        .handle = module,
    };
}

fn openPosix(names: []const [*:0]const u8) !VulkanLoader {
    for (names) |name| {
        const library = std.c.dlopen(name, .{ .LAZY = true }) orelse continue;
        const symbol = std.c.dlsym(library, "vkGetInstanceProcAddr") orelse {
            _ = std.c.dlclose(library);
            continue;
        };
        return .{
            .proc = @ptrCast(symbol),
            .handle = .{ .posix = library },
        };
    }
    return error.VulkanLoaderNotFound;
}

pub fn close(loader: VulkanLoader) void {
    switch (builtin.os.tag) {
        .windows => _ = FreeLibrary(loader.handle),
        .linux, .macos => std.c.dlclose(loader.handle),
        else => @compileError("unsupported"),
    }
}

const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const VulkanLoader = @This();
