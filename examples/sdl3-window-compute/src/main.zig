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

    const sdl_required_extensions = blk: {
        var sdl_required_extensions_count: u32 = undefined;
        const sdl_required_extensions_ptr = c.SDL_Vulkan_GetInstanceExtensions(&sdl_required_extensions_count) orelse
            return error.SDL_Vulkan_GetInstanceExtensionsFailed;
        break :blk sdl_required_extensions_ptr[0..sdl_required_extensions_count];
    };

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
        if (f == .rgba8_unorm or f == .bgra8_unorm) break f;
    } else @panic("");

    var frame_semaphore: gpu.Semaphore = try .create(device, 0);
    defer frame_semaphore.destroy(device);
    var frame_index: u64 = 1;

    std.debug.assert(surface_capabilities.usage.storage);
    var swapchain: gpu.Swapchain = try .create(&device, queue, surface, .{
        .format = swapchain_format,
        .usage = .{ .storage = true },
        .present_mode = .fifo,
    });
    defer swapchain.destroy(&device);

    const descriptor_size_and_align = gpu.Texture.Descriptor.sizeAndHeapAlignment(&device);
    const heap_gpu = try gpu_arena.runtimeAlignedAlloc(u8, descriptor_size_and_align.alignment, descriptor_size_and_align.size * 65536, .default);
    const heap = device.deviceToHostPointer(heap_gpu);

    const data_gpu = try gpu_arena.create(Data, .default);
    const data_cpu: *Data = device.deviceToHostPointer(data_gpu);

    const spirv align(@alignOf(u32)) = @embedFile("generate_texture.spv").*;
    var pipeline: gpu.Pipeline = try .createCompute(device, @ptrCast(&spirv));
    defer pipeline.destroy(device);

    var start: std.Io.Timestamp = .now(init.io, .real);

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

        var back_buffer = try swapchain.acquireNextTexture(&device, queue, .{ @intCast(width), @intCast(height) });

        const descriptor = try back_buffer.storageDescriptor(&device, .{});
        const output_texture: u32 = @intCast(frame_index % FRAMES_IN_FLIGHT);
        descriptor.store(&device, heap, output_texture);
        var time: f64 = @floatFromInt(start.untilNow(init.io, .real).toMicroseconds());
        time /= 1e6;
        data_cpu.* = .{
            .output_texture = output_texture,
            .time = @floatCast(time),
        };

        var cb = try queue.startRecording(&device);
        cb.setPipeline(device, pipeline);
        cb.setActiveTextureHeapPtr(device, heap_gpu);
        cb.dispatch(device, .cast(data_gpu), .{
            @intCast(@divFloor((width + 7), 8)),
            @intCast(@divFloor((height + 7), 8)),
            1,
        });

        try queue.submitAndSignal(&device, &.{cb}, frame_semaphore, frame_index);

        try swapchain.present(&device, queue, frame_semaphore, frame_index);

        frame_index += 1;
    }

    try frame_semaphore.wait(device, frame_index - 1);
}

const Data = extern struct {
    output_texture: u32,
    time: f32,
};

const FRAMES_IN_FLIGHT = 2;

const std = @import("std");
const gpu = @import("sulfur");
const VulkanLoader = @import("VulkanLoader");
const c = @import("c");
