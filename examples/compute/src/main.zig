extern fn sfSymbol(name: [*:0]const u8) callconv(gpu.@"callconv") *const anyopaque;

pub fn main(init: std.process.Init) !void {
    var width: c_int = 512;
    var height: c_int = 512;

    const window = c.SDL_CreateWindow("title", width, height, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse @panic("");

    const instance: *gpu.Instance = gpu.createInstance(null, sfSymbol);
    defer gpu.destroyInstance(instance);

    var adapters_buf: [64]*gpu.Adapter = undefined;
    var adapters: []*gpu.Adapter = adapters_buf[0..0];
    gpu.enumerateAdapters(instance, adapters_buf.len, &adapters_buf, &adapters.len);

    // TODO: pick adapter
    const adapter = adapters[0];

    const device: *gpu.Device = gpu.createDevice(instance, adapter);
    defer gpu.destroyDevice(device);

    const queue: *gpu.Queue = gpu.createQueue(device, .graphics);

    const props = c.SDL_GetWindowProperties(window);
    const surface = switch (target.os.tag) {
        .windows => blk: {
            const hwnd = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null) orelse @panic("TODO");
            const hinstance = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER, null) orelse @panic("TODO");
            const surface_desc: gpu.SurfaceWin32Desc = .{ .hinstance = hinstance, .hwnd = hwnd };
            break :blk gpu.createSurfaceWin32(device, surface_desc);
        },
        else => blk: {
            const display = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null) orelse @panic("TODO");
            const x11_window = c.SDL_GetNumberProperty(props, c.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
            if (x11_window == 0) @panic("TODO");
            const surface_desc: gpu.SurfaceXlibDesc = .{ .display = display, .window = @intCast(x11_window) };
            break :blk gpu.createSurfaceXlib(device, surface_desc);
        },
    };
    defer gpu.destroySurface(surface);

    var surface_formats_buf: [256]gpu.Format = undefined;
    var surface_formats: []gpu.Format = surface_formats_buf[0..0];
    gpu.surfaceFormats(device, surface, surface_formats_buf.len, &surface_formats_buf, &surface_formats.len);
    const swapchain_format = for (surface_formats) |f| {
        if (f == .rgba8_unorm or f == .bgra8_unorm) break f;
    } else @panic("");

    const surface_usage = gpu.surfaceSupportedUsage(device, surface);

    const frame_semaphore: *gpu.Semaphore = gpu.createSemaphore(device, 0);
    defer gpu.destroySemaphore(frame_semaphore);
    var frame_index: u64 = 1;

    std.debug.assert(surface_usage.storage);
    const swapchain: *gpu.Swapchain = gpu.createSwapchain(queue, surface, .{
        .format = swapchain_format,
        .usage = .{ .storage = true },
        .present_mode = .fifo,
    });
    defer gpu.destroySwapchain(swapchain);

    const descriptor_size_and_align = gpu.descriptorSizeAndHeapAlign(device);
    const heap_gpu = gpu.malloc(device, descriptor_size_and_align.size * 65536, descriptor_size_and_align.alignment, .default);
    defer gpu.free(device, heap_gpu);
    const heap: [*]u8 = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, heap_gpu)));

    const data_gpu = gpu.malloc(device, @sizeOf(Data), @alignOf(Data), .default);
    defer gpu.free(device, data_gpu);
    const data_cpu: *Data = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, data_gpu)));

    const spv = @embedFile("generate_texture.spv");
    const pipeline: *gpu.Pipeline = gpu.createComputePipeline(device, spv.len, spv);
    defer gpu.destroyPipeline(pipeline);

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
            gpu.waitSemaphore(frame_semaphore, frame_index - FRAMES_IN_FLIGHT);

        const back_buffer = gpu.swapchainAcquireNextTexture(swapchain, queue, @intCast(width), @intCast(height));

        const descriptor = gpu.textureStorageDescriptor(back_buffer, .{});
        const output_texture: u32 = @intCast(frame_index % FRAMES_IN_FLIGHT);
        gpu.storeDescriptor(device, &descriptor, heap, output_texture);

        var time: f64 = @floatFromInt(start.untilNow(init.io, .real).toMicroseconds());
        time /= 1e6;
        data_cpu.* = .{
            .output_texture = output_texture,
            .time = @floatCast(time),
        };

        const cb = gpu.startCommandRecording(queue);
        gpu.setPipeline(cb, pipeline);
        gpu.setActiveTextureHeap(cb, heap_gpu);
        gpu.dispatch(
            cb,
            data_gpu,
            @intCast(@divFloor((width + 7), 8)),
            @intCast(@divFloor((height + 7), 8)),
            1,
        );

        gpu.submitAndSignal(queue, 1, &.{cb}, frame_semaphore, frame_index);
        gpu.swapchainPresent(swapchain, queue, frame_semaphore, frame_index);

        frame_index += 1;
    }

    gpu.waitSemaphore(frame_semaphore, frame_index - 1);
}

const Data = extern struct {
    output_texture: u32,
    time: f32,
};

const FRAMES_IN_FLIGHT = 2;

const std = @import("std");
const target = @import("builtin").target;
const gpu = @import("sulfur");
const VulkanLoader = @import("VulkanLoader");
const c = @import("c");
