pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    const window_width = 720;
    const window_height = 720;

    const window = c.SDL_CreateWindow(
        "title",
        window_width,
        window_height,
        c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE,
    ) orelse @panic("");

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

    const adapters = try gpu.enumerateAdapters(arena, instance);

    // TODO: pick adapter
    const adapter = adapters[0];

    const device = try gpu.Device.create(gpa, instance, adapter);
    defer device.destroy();

    var surface: gpu.vk.SurfaceKHR = undefined;
    if (!c.SDL_Vulkan_CreateSurface(window, @ptrFromInt(@intFromEnum(device.instance.handle)), null, @ptrCast(&surface))) return error.engine_init_failure;

    const queue: gpu.Queue = .create(device, .graphics);

    const surface_capabilities = try device.surfaceCapabilities(arena, surface);
    const swapchain_format = for (surface_capabilities.formats) |f| {
        if (f == .rgba8_unorm_srgb or f == .bgra8_unorm_srgb) {
            break f;
        }
    } else surface_capabilities.formats[0];

    const swapchain: gpu.Swapchain = try .create(device, queue, surface, .{
        .format = swapchain_format,
        .present_mode = .fifo,
        .min_image_count = 3,
    });
    _ = swapchain; // autofix

    const frame_semaphore: gpu.Semaphore = try .create(device, 0);
    _ = frame_semaphore; // autofix
    var frame_index: u64 = 1;

    _ = try device.rawAlloc(1024, .@"32", .default);
    _ = try device.rawAlloc(1024, .@"32", .gpu);
    _ = try device.rawAlloc(1024, .@"32", .readback);

    var quit: bool = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != false) switch (event.type) {
            c.SDL_EVENT_QUIT => quit = true,
            else => {},
        };

        // if (frame_index > FRAMES_IN_FLIGHT)
        //     try frame_semaphore.wait(device, frame_index - FRAMES_IN_FLIGHT);

        frame_index += 1;
    }
}

const FRAMES_IN_FLIGHT = 2;

const std = @import("std");
const gpu = @import("sulfur");
const c = @import("c");
