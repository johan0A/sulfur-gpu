pub fn main(init: std.process.Init) !void {
    var debug_allocator: std.heap.DebugAllocator(.{
        .stack_trace_frames = 16,
    }) = .init;
    defer _ = debug_allocator.deinit();

    const gpa = debug_allocator.allocator();
    const arena = init.arena.allocator();

    var width: c_int = 512;
    var height: c_int = 512;

    const window = c.SDL_CreateWindow("title", width, height, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse @panic("");

    var sdl_required_extensions_count: u32 = undefined;
    const sdl_required_extensions_ptr = c.SDL_Vulkan_GetInstanceExtensions(&sdl_required_extensions_count) orelse
        return error.SDL_Vulkan_GetInstanceExtensionsFailed;
    const sdl_required_extensions = sdl_required_extensions_ptr[0..sdl_required_extensions_count];

    var instance: gpu.Instance = try .create(
        gpa,
        @ptrCast(c.SDL_Vulkan_GetVkGetInstanceProcAddr()),
        @ptrCast(sdl_required_extensions),
    );
    defer instance.destroy(gpa);

    const adapters = try instance.enumerateAdaptersAlloc(arena);

    // TODO: pick adapter
    const adapter = adapters[0];

    var device: gpu.Device = try .create(gpa, instance, adapter);
    defer device.destroy();

    const gpu_gpa = gpu.heap.rawDeviceAllocator(&device);
    var gpu_arena_impl: gpu.heap.FixedBufferAllocator = try .initAlloc(gpu_gpa, .{}, 1024 * 1024);
    defer gpu_arena_impl.deinit(gpu_gpa);
    const gpu_arena = gpu_arena_impl.allocator();

    const queue: gpu.Queue = .create(device, .graphics);

    var surface: gpu.vk.SurfaceKHR = undefined;
    if (!c.SDL_Vulkan_CreateSurface(window, @ptrFromInt(@intFromEnum(device.instance.handle)), null, @ptrCast(&surface))) return error.engine_init_failure;
    defer c.SDL_Vulkan_DestroySurface(@ptrFromInt(@intFromEnum(device.instance.handle)), @ptrFromInt(@intFromEnum(surface)), null);

    const surface_capabilities = try device.surfaceCapabilities(arena, surface);
    const swapchain_format = for (surface_capabilities.formats) |f| {
        if (f == .rgba8_unorm_srgb or f == .bgra8_unorm_srgb) break f;
    } else @panic("");

    var frame_semaphore: gpu.Semaphore = try .create(device, 0);
    defer frame_semaphore.destroy(device);
    var frame_index: u64 = 1;

    std.debug.assert(surface_capabilities.usage.color_attachment);
    var swapchain: gpu.Swapchain = try .create(&device, queue, surface, .{
        .format = swapchain_format,
        .usage = .{ .color_attachment = true },
        .present_mode = .fifo,
    });
    defer swapchain.destroy(&device);

    const descriptor_size_and_align = gpu.Texture.Descriptor.sizeAndHeapAlignment(&device);
    const heap_gpu = try gpu_arena.runtimeAlignedAlloc(u8, descriptor_size_and_align.alignment, descriptor_size_and_align.size * 65536, .default);

    const positions_gpu = try gpu_arena.alloc([3]f32, 3, .default);
    const positions_cpu: [][3]f32 = device.deviceToHostPointer(positions_gpu);
    @memcpy(positions_cpu, @as([]const [3]f32, &.{
        .{ -1.0, 1.0, 0.0 },
        .{ 0.0, -1.0, 0.0 },
        .{ 1.0, 1.0, 0.0 },
    }));

    const colors_gpu = try gpu_arena.alloc([3]f32, 3, .default);
    const colors_cpu: [][3]f32 = device.deviceToHostPointer(colors_gpu);
    @memcpy(colors_cpu, @as([]const [3]f32, &.{
        .{ 0.0, 0.0, 1.0 },
        .{ 0.0, 1.0, 0.0 },
        .{ 1.0, 0.0, 0.0 },
    }));

    const data_gpu = try gpu_arena.create(Data, .default);
    const data_cpu: *Data = device.deviceToHostPointer(data_gpu);
    data_cpu.* = .{
        .positions = positions_gpu.ptr,
        .colors = colors_gpu.ptr,
    };

    const frag align(@alignOf(u32)) = @embedFile("frag.spv").*;
    const vert align(@alignOf(u32)) = @embedFile("vert.spv").*;

    var pipeline: gpu.Pipeline = try .createGraphics(device, @ptrCast(&vert), @ptrCast(&frag), .{
        .color_targets = &.{.{ .format = swapchain_format }},
    });
    defer pipeline.destroy(device);

    var quit: bool = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != false) switch (event.type) {
            c.SDL_EVENT_QUIT => quit = true,
            else => {},
        };

        std.debug.assert(c.SDL_GetWindowSizeInPixels(window, &width, &height));

        if (frame_index > FRAMES_IN_FLIGHT)
            try frame_semaphore.wait(device, frame_index - FRAMES_IN_FLIGHT);

        const back_buffer = try swapchain.acquireNextTexture(&device, queue, .{ @intCast(width), @intCast(height) });

        const cb = try queue.startRecording(&device);

        cb.setActiveTextureHeapPtr(device, heap_gpu);

        cb.beginRenderPass(device, .{
            .color_targets = &.{.{
                .texture = back_buffer,
                .load_op = .clear,
                .store_op = .store,
                .clear_color = .{ 0, 0, 0, 1 },
            }},
        });

        cb.setPipeline(device, pipeline);

        cb.draw(device, .cast(data_gpu), .cast(data_gpu), 3, 1);

        cb.endRenderPass(device);

        try queue.submitAndSignal(&device, &.{cb}, frame_semaphore, frame_index);
        try swapchain.present(&device, queue, frame_semaphore, frame_index);

        frame_index += 1;
    }

    try frame_semaphore.wait(device, frame_index - 1);
}

const Data = extern struct {
    positions: gpu.Ptr(.many, [3]f32, .{}),
    colors: gpu.Ptr(.many, [3]f32, .{}),
};

const FRAMES_IN_FLIGHT = 2;

const std = @import("std");
const gpu = @import("sulfur");
const VulkanLoader = @import("VulkanLoader");
const c = @import("c");
