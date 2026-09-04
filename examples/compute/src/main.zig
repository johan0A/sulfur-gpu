extern fn sfSymbol(name: [*:0]const u8) callconv(sf.@"callconv") *const anyopaque;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    var width: c_int = 512;
    var height: c_int = 512;

    const window = c.SDL_CreateWindow("title", width, height, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse @panic("");

    const instance: *sf.Instance = .create(null, sfSymbol);
    defer instance.destroy();

    const adapters = try instance.enumerateAdaptersAlloc(arena);

    // TODO: pick adapter
    const adapter = adapters[0];

    const device: *sf.Device = .create(instance, adapter);
    defer device.destroy();

    const queue: *sf.Queue = device.getQueue(.graphics);

    const props = c.SDL_GetWindowProperties(window);
    const surface = switch (target.os.tag) {
        .windows => blk: {
            const hwnd = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null) orelse @panic("TODO");
            const hinstance = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER, null) orelse @panic("TODO");
            const surface_desc: sf.SurfaceWin32Desc = .{ .hinstance = hinstance, .hwnd = hwnd };
            break :blk sf.Surface.createWin32(device, surface_desc);
        },
        else => blk: {
            const display = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null) orelse @panic("TODO");
            const x11_window = c.SDL_GetNumberProperty(props, c.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
            if (x11_window == 0) @panic("TODO");
            const surface_desc: sf.SurfaceXlibDesc = .{ .display = display, .window = @intCast(x11_window) };
            break :blk sf.createSurfaceXlib(device, surface_desc);
        },
    };
    defer surface.destroy();

    const surface_formats = try device.surfaceFormatsAlloc(surface, arena);
    const swapchain_format = for (surface_formats) |f| {
        if (f == .rgba8_unorm or f == .bgra8_unorm) break f;
    } else @panic("");

    const surface_usage = device.surfaceSupportedUsage(surface);

    const frame_semaphore: *sf.Semaphore = try .create(device, 0);
    defer frame_semaphore.destroy();
    var frame_index: u64 = 1;

    std.debug.assert(surface_usage.storage);
    const swapchain: *sf.Swapchain = try .create(queue, surface, .{
        .format = swapchain_format,
        .usage = .{ .storage = true },
        .present_mode = .fifo,
    });
    defer swapchain.destroy();

    const descriptor_size_and_align = device.descriptorSizeAndHeapAlign();
    const heap_gpu = device.malloc(descriptor_size_and_align.size * 65536, descriptor_size_and_align.alignment, .default);
    defer device.free(heap_gpu);
    const heap: [*]u8 = @ptrCast(@alignCast(device.deviceToHostPointer(heap_gpu)));

    const data_gpu = device.malloc(@sizeOf(Data), @alignOf(Data), .default);
    defer device.free(data_gpu);
    const data_cpu: *Data = @ptrCast(@alignCast(device.deviceToHostPointer(data_gpu)));

    const spv = @embedFile("generate_texture.spv");
    const pipeline: *sf.Pipeline = try .createCompute(device, spv);
    defer pipeline.destroy();

    const start: std.Io.Timestamp = .now(init.io, .real);

    var quit: bool = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != false) switch (event.type) {
            c.SDL_EVENT_QUIT => quit = true,
            else => {},
        };

        std.debug.assert(c.SDL_GetWindowSizeInPixels(window, &width, &height));

        if (frame_index > FRAMES_IN_FLIGHT)
            _ = try frame_semaphore.waitSemaphore(frame_index - FRAMES_IN_FLIGHT);

        const back_buffer: *sf.Texture = try swapchain.swapchainAcquireNextTexture(queue, @intCast(width), @intCast(height));

        var descriptor: sf.Descriptor = try back_buffer.textureStorageDescriptor(.{});
        const output_texture: u32 = @intCast(frame_index % FRAMES_IN_FLIGHT);
        device.storeDescriptor(&descriptor, heap, output_texture);

        var time: f64 = @floatFromInt(start.untilNow(init.io, .real).toMicroseconds());
        time /= 1e6;
        data_cpu.* = .{
            .output_texture = output_texture,
            .time = @floatCast(time),
        };

        const cb: *sf.CommandBuffer = try queue.startCommandRecording();
        cb.setPipeline(pipeline);
        cb.setActiveTextureHeap(heap_gpu);
        cb.dispatch(
            data_gpu,
            @intCast(@divFloor((width + 7), 8)),
            @intCast(@divFloor((height + 7), 8)),
            1,
        );

        try queue.submitAndSignal(&.{cb}, frame_semaphore, frame_index);
        try swapchain.swapchainPresent(queue, frame_semaphore, frame_index);

        frame_index += 1;
    }

    try frame_semaphore.waitSemaphore(frame_index - 1);
}

const Data = extern struct {
    output_texture: u32,
    time: f32,
};

const FRAMES_IN_FLIGHT = 2;

const std = @import("std");
const target = @import("builtin").target;
const sf = @import("sulfur");
const c = @import("c");
