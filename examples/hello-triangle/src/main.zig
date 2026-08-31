pub fn main(init: std.process.Init) !void {
    var width: c_int = 512;
    var height: c_int = 512;

    const window = c.SDL_CreateWindow("title", width, height, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse @panic("");

    const instance: *gpu.Instance = gpu.createInstance(null);
    defer gpu.destroyInstance(instance);

    var adapters_buf: [64]*gpu.Adapter = undefined;
    var adapters: []*gpu.Adapter = adapters_buf[0..0];
    gpu.enumerateAdapters(instance, adapters_buf.len, &adapters_buf, &adapters.len);

    // TODO: pick adapter
    const adapter = adapters[0];

    const device: *gpu.Device = gpu.createDevice(instance, adapter);
    defer gpu.destroyDevice(device);

    const queue: *gpu.Queue = gpu.getQueue(device, .graphics);

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
        if (f == .rgba8_unorm_srgb or f == .bgra8_unorm_srgb) break f;
    } else @panic("");

    const surface_usage = gpu.surfaceSupportedUsage(device, surface);

    const frame_semaphore: *gpu.Semaphore = gpu.createSemaphore(device, 0);
    defer gpu.destroySemaphore(frame_semaphore);
    var frame_index: u64 = 1;

    std.debug.assert(surface_usage.color_attachment);
    const swapchain: *gpu.Swapchain = gpu.createSwapchain(queue, surface, .{
        .format = swapchain_format,
        .usage = .{ .color_attachment = true },
        .present_mode = .fifo,
    });
    defer gpu.destroySwapchain(swapchain);

    const descriptor_size_and_align = gpu.descriptorSizeAndHeapAlign(device);
    const heap_gpu = gpu.malloc(device, descriptor_size_and_align.size * 65536, descriptor_size_and_align.alignment, .default);
    defer gpu.free(device, heap_gpu);

    const positions_gpu = gpu.malloc(device, @sizeOf([3]f32) * 3, @alignOf([3]f32), .default);
    defer gpu.free(device, positions_gpu);
    const positions_cpu: *[3][3]f32 = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, positions_gpu)));
    positions_cpu.* = .{
        .{ -1, 1, 0 },
        .{ 0, -1, 0 },
        .{ 1, 1, 0 },
    };

    const colors_gpu = gpu.malloc(device, @sizeOf([3]f32) * 3, @alignOf([3]f32), .default);
    defer gpu.free(device, colors_gpu);
    const colors_cpu: *[3][3]f32 = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, colors_gpu)));
    colors_cpu.* = .{
        .{ 0, 0, 1 },
        .{ 0, 1, 0 },
        .{ 1, 0, 0 },
    };

    const data_gpu = gpu.malloc(device, @sizeOf(Data), @alignOf(Data), .default);
    defer gpu.free(device, data_gpu);
    const data_cpu: *Data = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, data_gpu)));
    data_cpu.* = .{
        .positions = positions_gpu,
        .colors = colors_gpu,
    };

    const vert = @embedFile("vert.spv");
    const frag = @embedFile("frag.spv");
    const pipeline: *gpu.Pipeline = gpu.createGraphicsPipeline(device, vert.len, vert, frag.len, frag, .{
        .color_target_count = 1,
        .color_targets = &.{.{ .format = swapchain_format }},
    });
    defer gpu.destroyPipeline(pipeline);

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

        const cb = gpu.startCommandRecording(queue);

        gpu.setActiveTextureHeap(cb, heap_gpu);

        gpu.beginRenderPass(cb, .{
            .stencil_attachment = .{},
            .depth_attachment = .{},
            .color_attachment_count = 1,
            .color_attachments = &.{.{
                .texture = back_buffer,
                .load_op = .clear,
                .store_op = .store,
                .clear_color = .{ 0, 0, 0, 1 },
            }},
        });

        gpu.setPipeline(cb, pipeline);

        gpu.draw(cb, data_gpu, data_gpu, 3, 1);

        gpu.endRenderPass(cb);

        gpu.submitAndSignal(queue, 1, &.{cb}, frame_semaphore, frame_index);
        gpu.swapchainPresent(swapchain, queue, frame_semaphore, frame_index);

        frame_index += 1;
    }

    gpu.waitSemaphore(frame_semaphore, frame_index - 1);
    _ = init;
}

const Data = extern struct {
    positions: gpu.DeviceAddress,
    colors: gpu.DeviceAddress,
};

const FRAMES_IN_FLIGHT = 2;

const std = @import("std");
const target = @import("builtin").target;
const gpu = @import("sulfur");
const VulkanLoader = @import("VulkanLoader");
const c = @import("c");
