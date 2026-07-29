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

    var instance: *gpu.Instance = .create(
        gpa,
        @ptrCast(c.SDL_Vulkan_GetVkGetInstanceProcAddr()),
        @ptrCast(sdl_required_extensions),
    );
    defer instance.destroy(gpa);

    const adapters = instance.enumerateAdaptersAlloc(arena);

    // TODO: pick adapter
    const adapter = adapters[0];

    const device: *gpu.Device = .create(gpa, instance, adapter);
    defer device.destroy();

    const gpu_gpa = gpu.heap.rawDeviceAllocator(device);
    var gpu_arena_impl: gpu.heap.FixedBufferAllocator = try .initAlloc(gpu_gpa, .{}, 1024 * 1024);
    defer gpu_arena_impl.deinit(gpu_gpa);
    const gpu_arena = gpu_arena_impl.allocator();

    const queue: *gpu.Queue = .create(device, .graphics);

    const props = c.SDL_GetWindowProperties(window);
    const hwnd = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null) orelse @panic("TODO");
    const hinstance = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER, null) orelse @panic("TODO");

    const surface_desc: gpu.Surface.Win32Desc = .{ .hinstance = hinstance, .hwnd = hwnd };
    const surface: *gpu.Surface = .createWin32(instance, surface_desc, gpa);
    defer surface.destroy(instance, gpa);

    const surface_capabilities = device.surfaceCapabilities(arena, surface);
    const swapchain_format = for (surface_capabilities.formats) |f| {
        if (f == .rgba8_unorm_srgb or f == .bgra8_unorm_srgb) break f;
    } else @panic("");

    var frame_semaphore: *gpu.Semaphore = .create(device, 0);
    defer frame_semaphore.destroy(device);
    var frame_index: u64 = 1;

    std.debug.assert(surface_capabilities.usage.color_attachment);
    var swapchain: *gpu.Swapchain = .create(device, queue, surface, .{
        .format = swapchain_format,
        .usage = .{ .color_attachment = true },
        .present_mode = .fifo,
    });
    defer swapchain.destroy(device);

    const descriptor_size_and_align = gpu.Texture.Descriptor.sizeAndHeapAlignment(device);
    const heap_gpu = try gpu_arena.runtimeAlignedAlloc(u8, descriptor_size_and_align.alignment, descriptor_size_and_align.size * 65536, .default);

    const positions_gpu = try gpu_arena.alloc([3]f32, 3, .default);
    const positions_cpu: [][3]f32 = device.deviceToHostPointer(positions_gpu);
    @memcpy(positions_cpu, @as([]const [3]f32, &.{
        .{ -1, 1, 0 },
        .{ 0, -1, 0 },
        .{ 1, 1, 0 },
    }));

    const colors_gpu = try gpu_arena.alloc([3]f32, 3, .default);
    const colors_cpu: [][3]f32 = device.deviceToHostPointer(colors_gpu);
    @memcpy(colors_cpu, @as([]const [3]f32, &.{
        .{ 0, 0, 1 },
        .{ 0, 1, 0 },
        .{ 1, 0, 0 },
    }));

    const data_gpu = try gpu_arena.create(Data, .default);
    const data_cpu: *Data = device.deviceToHostPointer(data_gpu);
    data_cpu.* = .{
        .positions = positions_gpu.ptr,
        .colors = colors_gpu.ptr,
    };

    var pipeline: *gpu.Pipeline = .createGraphics(device, @embedFile("vert.spv"), @embedFile("frag.spv"), .{
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
            frame_semaphore.wait(device, frame_index - FRAMES_IN_FLIGHT);

        const back_buffer = swapchain.acquireNextTexture(device, queue, .{ @intCast(width), @intCast(height) });

        var cb = queue.startRecording(device);

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

        queue.submitAndSignal(device, &.{cb}, frame_semaphore, frame_index);
        swapchain.present(device, queue, frame_semaphore, frame_index);

        frame_index += 1;
    }

    frame_semaphore.wait(device, frame_index - 1);
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
