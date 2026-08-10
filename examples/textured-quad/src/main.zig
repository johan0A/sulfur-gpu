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

    const queue: *gpu.Queue = gpu.createQueue(device, .graphics);

    const props = c.SDL_GetWindowProperties(window);
    const surface = switch (target.os.tag) {
        .windows => blk: {
            const hwnd = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null) orelse @panic("TODO");
            const hinstance = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER, null) orelse @panic("TODO");
            const surface_desc: gpu.SurfaceWin32Desc = .{ .hinstance = hinstance, .hwnd = hwnd };
            break :blk gpu.createSurfaceWin32(instance, surface_desc);
        },
        else => blk: {
            const display = c.SDL_GetPointerProperty(props, c.SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null) orelse @panic("TODO");
            const x11_window = c.SDL_GetNumberProperty(props, c.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
            if (x11_window == 0) @panic("TODO");
            const surface_desc: gpu.SurfaceXlibDesc = .{ .display = display, .window = @intCast(x11_window) };
            break :blk gpu.createSurfaceXlib(instance, surface_desc);
        },
    };
    defer gpu.destroySurface(surface, instance);

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
    const heap_gpu_cpu: [*]u8 = @ptrCast(gpu.deviceToHostPointer(device, heap_gpu));

    const vertex_count = 6;

    const positions_gpu = gpu.malloc(device, @sizeOf([3]f32) * vertex_count, @alignOf([3]f32), .default);
    defer gpu.free(device, positions_gpu);
    const positions_cpu: *[vertex_count][3]f32 = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, positions_gpu)));
    positions_cpu.* = .{
        .{ -1, 1, 0 },
        .{ -1, -1, 0 },
        .{ 1, -1, 0 },

        .{ -1, 1, 0 },
        .{ 1, -1, 0 },
        .{ 1, 1, 0 },
    };

    const uvs_gpu = gpu.malloc(device, @sizeOf([2]f32) * vertex_count, @alignOf([2]f32), .default);
    defer gpu.free(device, uvs_gpu);
    const uvs_cpu: *[vertex_count][2]f32 = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, uvs_gpu)));
    uvs_cpu.* = .{
        .{ 0, 0 },
        .{ 0, 1 },
        .{ 1, 1 },

        .{ 0, 0 },
        .{ 1, 1 },
        .{ 1, 0 },
    };

    const data_gpu = gpu.malloc(device, @sizeOf(Data), @alignOf(Data), .default);
    defer gpu.free(device, data_gpu);
    const data_cpu: *Data = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, data_gpu)));
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

    const texture_size_and_align = gpu.textureSizeAndAlign(device, texture_desc);
    const texture_gpu = gpu.malloc(device, texture_size_and_align.size, texture_size_and_align.alignment, .gpu);
    defer gpu.free(device, texture_gpu);

    const texture: *gpu.Texture = gpu.createTexture(device, texture_desc, texture_gpu);
    defer gpu.destroyTexture(texture);

    const texture_upload_size = dimensions[0] * dimensions[1] * 4;
    const texture_upload_gpu = gpu.malloc(device, texture_upload_size, 4, .default);
    defer gpu.free(device, texture_upload_gpu);
    const texture_upload_cpu: [*]u8 = @ptrCast(gpu.deviceToHostPointer(device, texture_upload_gpu));
    @memset(texture_upload_cpu[0..texture_upload_size], 255);

    for (0..@min(dimensions[0], dimensions[1])) |i| {
        const offset = (i * dimensions[0] + i) * 4;

        texture_upload_cpu[offset + 0] = 0;
        texture_upload_cpu[offset + 1] = 0;
        texture_upload_cpu[offset + 2] = 0;
        texture_upload_cpu[offset + 3] = 255;
    }

    const upload_cb = gpu.startCommandRecording(queue);

    gpu.copyBufferToTexture(upload_cb, texture_upload_gpu, texture_gpu, texture);

    const texture_descriptor = gpu.textureViewDescriptor(texture, .{ .format = .rgba8_unorm });
    gpu.storeDescriptor(&texture_descriptor, device, heap_gpu_cpu, 0);

    gpu.barrier(upload_cb, .{ .transfer = true }, .all, .{ .descriptors = true });
    gpu.submit(queue, 1, &.{upload_cb});

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

        gpu.draw(cb, data_gpu, data_gpu, vertex_count, 1);

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
    uvs: gpu.DeviceAddress,
};

const FRAMES_IN_FLIGHT = 2;

const std = @import("std");
const target = @import("builtin").target;
const gpu = @import("sulfur");
const VulkanLoader = @import("VulkanLoader");
const c = @import("c");
