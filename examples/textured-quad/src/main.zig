const std = @import("std");
const target = @import("builtin").target;
const gpu = @import("sulfur");
const c = @import("c");

const Data = extern struct {
    positions: gpu.DeviceAddress,
    uvs: gpu.DeviceAddress,
};

const frames_in_flight = 2;

const sfSymbol = @extern(gpu.Symbol, .{ .name = "sfSymbol" });

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    var width: c_int = 512;
    var height: c_int = 512;

    const window = c.SDL_CreateWindow("title", width, height, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse @panic("");

    const instance: *gpu.Instance = .create(null, sfSymbol);
    defer instance.destroy();

    const adapters = try instance.enumerateAdaptersAlloc(arena);

    // TODO: pick adapter
    const adapter = adapters[0];

    const device: *gpu.Device = .create(instance, adapter);
    defer device.destroy();

    const queue: *gpu.Queue = device.getQueue(.graphics);

    const props = c.SDL_GetWindowProperties(window);
    const surface: *gpu.Surface = switch (target.os.tag) {
        .windows => blk: {
            const hwnd = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null) orelse @panic("TODO");
            const hinstance = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER, null) orelse @panic("TODO");
            const surface_desc: gpu.SurfaceWin32Desc = .{ .hinstance = hinstance, .hwnd = hwnd };
            break :blk .createWin32(device, surface_desc);
        },
        else => blk: {
            const display = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null) orelse @panic("TODO");
            const x11_window = c.SDL_GetNumberProperty(props, c.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
            if (x11_window == 0) @panic("TODO");
            const surface_desc: gpu.SurfaceXlibDesc = .{ .display = display, .window = @intCast(x11_window) };
            break :blk .createXlib(device, surface_desc);
        },
    };
    defer surface.destroy();

    const surface_formats = try device.surfaceFormatsAlloc(surface, arena);
    const swapchain_format = for (surface_formats) |f| {
        if (f == .rgba8_unorm_srgb or f == .bgra8_unorm_srgb) break f;
    } else @panic("");

    const surface_usage = device.surfaceSupportedUsage(surface);

    const frame_semaphore: *gpu.Semaphore = try .create(device, 0);
    defer frame_semaphore.destroy();
    var frame_index: u64 = 1;

    std.debug.assert(surface_usage.color_attachment);
    const swapchain: *gpu.Swapchain = try .create(queue, surface, .{
        .format = swapchain_format,
        .usage = .{ .color_attachment = true },
        .present_mode = .fifo,
    });
    defer swapchain.destroy();

    const descriptor_size_and_align = device.descriptorSizeAndHeapAlign();
    const heap_gpu = device.malloc(descriptor_size_and_align.size * 65536, descriptor_size_and_align.alignment, .default);
    defer device.free(heap_gpu);
    const heap_gpu_cpu: [*]u8 = @ptrCast(device.toHostPointer(heap_gpu));

    const vertex_count = 6;

    const positions_gpu = device.malloc(@sizeOf([3]f32) * vertex_count, @alignOf([3]f32), .default);
    defer device.free(positions_gpu);
    const positions_cpu: *[vertex_count][3]f32 = @ptrCast(@alignCast(device.toHostPointer(positions_gpu)));
    positions_cpu.* = .{
        .{ -1, 1, 0 },
        .{ -1, -1, 0 },
        .{ 1, -1, 0 },

        .{ -1, 1, 0 },
        .{ 1, -1, 0 },
        .{ 1, 1, 0 },
    };

    const uvs_gpu = device.malloc(@sizeOf([2]f32) * vertex_count, @alignOf([2]f32), .default);
    defer device.free(uvs_gpu);
    const uvs_cpu: *[vertex_count][2]f32 = @ptrCast(@alignCast(device.toHostPointer(uvs_gpu)));
    uvs_cpu.* = .{
        .{ 0, 0 },
        .{ 0, 1 },
        .{ 1, 1 },

        .{ 0, 0 },
        .{ 1, 1 },
        .{ 1, 0 },
    };

    const data_gpu = device.malloc(@sizeOf(Data), @alignOf(Data), .default);
    defer device.free(data_gpu);
    const data_cpu: *Data = @ptrCast(@alignCast(device.toHostPointer(data_gpu)));
    data_cpu.* = .{
        .positions = positions_gpu,
        .uvs = uvs_gpu,
    };

    const dimensions: [3]u32 = .{ 256, 256, 1 };
    const texture_desc: gpu.TextureDesc = .{
        .dimensions = dimensions,
        .format = .rgba8_unorm,
        .usage = .{ .sampled = true },
    };

    const texture_size_and_align = device.textureSizeAndAlign(texture_desc);
    const texture_gpu = device.malloc(texture_size_and_align.size, texture_size_and_align.alignment, .gpu);
    defer device.free(texture_gpu);

    const texture: *gpu.Texture = try .create(device, texture_desc, texture_gpu);
    defer texture.destroy();

    const texture_upload_size = dimensions[0] * dimensions[1] * 4;
    const texture_upload_gpu = device.malloc(texture_upload_size, 4, .default);
    defer device.free(texture_upload_gpu);
    const texture_upload_cpu: [*]u8 = @ptrCast(device.toHostPointer(texture_upload_gpu));
    @memset(texture_upload_cpu[0..texture_upload_size], 255);

    for (0..@min(dimensions[0], dimensions[1])) |i| {
        const offset = (i * dimensions[0] + i) * 4;

        texture_upload_cpu[offset + 0] = 0;
        texture_upload_cpu[offset + 1] = 0;
        texture_upload_cpu[offset + 2] = 0;
        texture_upload_cpu[offset + 3] = 255;
    }

    const upload_cb = try queue.startCommandRecording();

    upload_cb.copyBufferToTexture(texture_upload_gpu, texture_gpu, texture);

    const texture_descriptor = try texture.viewDescriptor(.{ .format = .rgba8_unorm });
    device.storeDescriptor(&texture_descriptor, heap_gpu_cpu, 0);

    upload_cb.barrier(.{ .transfer = true }, .all, .{ .descriptors = true });
    try queue.submit(&.{upload_cb});

    const vert = @embedFile("vert.spv");
    const frag = @embedFile("frag.spv");
    const pipeline: *gpu.Pipeline = try .createGraphics(device, vert, frag, .{
        .color_target_count = 1,
        .color_targets = &.{.{ .format = swapchain_format }},
    });
    defer pipeline.destroy();

    var quit: bool = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != false) switch (event.type) {
            c.SDL_EVENT_QUIT => quit = true,
            else => {},
        };

        std.debug.assert(c.SDL_GetWindowSizeInPixels(window, &width, &height));

        if (frame_index > frames_in_flight)
            try frame_semaphore.wait(frame_index - frames_in_flight);

        const back_buffer = try swapchain.acquireBackBuffer(@intCast(width), @intCast(height));

        const cb = try queue.startCommandRecording();

        cb.setActiveTextureHeap(heap_gpu);
        cb.beginRenderPass(.{
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
        cb.setPipeline(pipeline);
        cb.draw(data_gpu, data_gpu, vertex_count, 1);
        cb.endRenderPass();

        try queue.submitAndSignal(&.{cb}, frame_semaphore, frame_index);
        try swapchain.present();

        frame_index += 1;
    }

    try frame_semaphore.wait(frame_index - 1);
}
