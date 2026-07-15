pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    const window = c.SDL_CreateWindow(
        "title",
        100,
        100,
        c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE,
    ) orelse @panic("");
    _ = window; // autofix

    const sdl_required_extensions = blk: {
        var sdl_required_extensions_count: u32 = undefined;
        const sdl_required_extensions_ptr = c.SDL_Vulkan_GetInstanceExtensions(&sdl_required_extensions_count) orelse
            return error.SDL_Vulkan_GetInstanceExtensionsFailed;
        break :blk sdl_required_extensions_ptr[0..sdl_required_extensions_count];
    };

    const instance: gpu.Instance = try .create(
        gpa,
        @ptrCast(c.SDL_Vulkan_GetVkGetInstanceProcAddr()),
        @ptrCast(sdl_required_extensions),
    );
    defer instance.destroy(gpa);

    const adapters = try gpu.enumerateAdapters(arena, instance);

    // TODO: pick adapter
    const adapter = adapters[0];

    var device: gpu.Device = try .create(gpa, instance, adapter);
    defer device.destroy();

    const queue: gpu.Queue = .create(device, .graphics);

    const texture_config: gpu.Texture.Config = .{
        .dimensions = .{ 512, 512, 1 },
        .format = .rgba8_unorm,
        .usage = .{ .sampled = true },
    };
    const texture_size_align = gpu.Texture.sizeAndAlign(device, texture_config);
    const texture_ptr = try device.rawAlloc(texture_size_align.size, texture_size_align.alignement, .gpu);
    defer device.rawFree(texture_ptr);
    var texture: gpu.Texture = try .create(&device, texture_config, texture_ptr);
    defer texture.destroy(device);

    const descriptor_size_and_align = gpu.Texture.Descriptor.sizeAndHeapAlign(&device);
    const heap_gpu = try device.rawAlloc(descriptor_size_and_align.size * 1024, descriptor_size_and_align.alignement, .default);
    defer device.rawFree(heap_gpu);
    const heap = device.deviceToHostPointer(heap_gpu);

    const descriptor = try texture.RwTextureViewDescriptor(&device, .{});
    descriptor.store(&device, heap, 0);

    const data_gpu = try device.rawAlloc(@sizeOf(Data), .of(Data), .default);
    defer device.rawFree(data_gpu);
    const data_cpu: *Data = @ptrCast(@alignCast(device.deviceToHostPointer(data_gpu)));
    data_cpu.output_texture = 0;

    const spirv align(@alignOf(u32)) = @embedFile("generate_texture.spv").*;
    const pipeline: gpu.Pipeline = try .createCompute(device, @ptrCast(&spirv));
    defer pipeline.destroy(device);

    const cb: gpu.CommandBuffer = try .startRecording(queue, device);
    cb.setActiveTextureHeapPtr(device, heap_gpu);
}

const Data = extern struct {
    output_texture: u32 align(16),
};

const FRAMES_IN_FLIGHT = 2;

const std = @import("std");
const gpu = @import("sulfur");
const c = @import("c");
