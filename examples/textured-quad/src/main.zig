const std = @import("std");
const target = @import("builtin").target;
const gpu = @import("sulfur");
const c = @import("c");

const sfSymbol = @extern(gpu.Symbol, .{ .name = "sfSymbol" });

const Data = extern struct {
    positions: gpu.DeviceAddress,
    uvs: gpu.DeviceAddress,
};

const frames_in_flight = 2;
const vertex_count = 6;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) @panic("SDL_Init failed");
    defer c.SDL_Quit();

    var width: c_int = 512;
    var height: c_int = 512;

    const window = c.SDL_CreateWindow("title", width, height, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse @panic("SDL_CreateWindow failed");
    defer c.SDL_DestroyWindow(window);

    const instance = gpu.Instance.create(null, sfSymbol);
    defer instance.destroy();

    const adapters = try instance.enumerateAdaptersAlloc(arena);
    if (adapters.len == 0) return error.NoAdapter;
    const adapter = for (adapters) |adapter| {
        if (instance.adapterInfo(adapter).type == .discrete_gpu) break adapter;
    } else adapters[0];
    const adapter_info = instance.adapterInfo(adapter);
    std.log.info("selected device: {s}", .{adapter_info.name[0..adapter_info.name_lenght]});

    const device = instance.createDevice(adapter);
    defer device.destroy();

    const gpu_gpa = gpu.heap.rawDeviceAllocator(device);
    var fix_buffer_allocator: gpu.heap.FixedBufferAllocator = try .initAlloc(gpu_gpa, .initFill(1024 * 1024 * 64));
    defer fix_buffer_allocator.deinit(gpu_gpa);
    const gpu_arena = fix_buffer_allocator.allocator();

    const queue = device.getQueue(.graphics);

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
    } else return error.NoSupportedSurfaceFormat;

    const surface_usage = device.surfaceSupportedUsage(surface);
    if (!surface_usage.color_attachment) return error.SurfaceColorAttachmentUnsupported;

    const frame_semaphore = try device.createSemaphore(0);
    defer frame_semaphore.destroy();
    var frame_index: u64 = 1;

    const swapchain: *gpu.Swapchain = try .create(queue, surface, .{
        .format = swapchain_format,
        .usage = .{ .color_attachment = true },
        .present_mode = .fifo,
    });
    defer swapchain.destroy();

    const descriptor_size_and_align = device.descriptorSizeAndHeapAlign();
    const descriptor_heap = try gpu_arena.runtimeAlignedAlloc(
        u8,
        descriptor_size_and_align.alignment(),
        descriptor_size_and_align.size * 65536,
        .upload,
    );

    const positions_map = try gpu_arena.create([vertex_count][3]f32, .upload);
    positions_map.host.* = .{
        .{ -1, 1, 0 },
        .{ -1, -1, 0 },
        .{ 1, -1, 0 },

        .{ -1, 1, 0 },
        .{ 1, -1, 0 },
        .{ 1, 1, 0 },
    };

    const uvs_map = try gpu_arena.create([vertex_count][2]f32, .upload);
    uvs_map.host.* = .{
        .{ 0, 0 },
        .{ 0, 1 },
        .{ 1, 1 },

        .{ 0, 0 },
        .{ 1, 1 },
        .{ 1, 0 },
    };

    const data_map = try gpu_arena.create(Data, .upload);
    data_map.host.* = .{
        .positions = positions_map.device.addr,
        .uvs = uvs_map.device.addr,
    };

    const dimensions: [3]u32 = .{ 256, 256, 1 };
    const texture_desc: gpu.TextureDesc = .{
        .dimensions = dimensions,
        .format = .rgba8_unorm,
        .usage = .{ .sampled = true },
    };
    const texture_size_and_align = device.textureSizeAndAlign(texture_desc);
    const texture_map = try gpu_arena.runtimeAlignedAlloc(u8, texture_size_and_align.alignment(), texture_size_and_align.size, .device_local);
    const texture = try device.createTexture(texture_desc, texture_map.device_ptr.addr);
    defer texture.destroy();

    const texture_upload_size = dimensions[0] * dimensions[1] * 4;
    const texture_upload = try gpu_arena.alignedAlloc(u8, .fromByteUnits(256), texture_upload_size, .upload);
    const pixels = texture_upload.host();
    @memset(pixels, 255);
    for (0..@min(dimensions[0], dimensions[1])) |i| {
        const offset = (i * dimensions[0] + i) * 4;
        pixels[offset + 0] = 0;
        pixels[offset + 1] = 0;
        pixels[offset + 2] = 0;
        pixels[offset + 3] = 255;
    }

    const texture_descriptor = try texture.viewDescriptor(.{ .format = .rgba8_unorm });
    device.storeDescriptor(&texture_descriptor, descriptor_heap.host_ptr, 0);

    const upload_cb = try queue.startCommandRecording();
    upload_cb.copyBufferToTexture(texture_upload.device_ptr.addr, texture_map.device_ptr.addr, texture);
    upload_cb.barrier(.{ .transfer = true }, .all, .{ .descriptors = true });
    try queue.submit(&.{upload_cb});

    const pipeline = try device.createGraphicsPipeline(
        @embedFile("vert.sfir"),
        @embedFile("frag.sfir"),
        .{
            .color_target_count = 1,
            .color_targets = &.{.{ .format = swapchain_format }},
        },
    );
    defer pipeline.destroy();

    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) switch (event.type) {
            c.SDL_EVENT_QUIT => quit = true,
            else => {},
        };

        if (!c.SDL_GetWindowSizeInPixels(window, &width, &height)) @panic("SDL_GetWindowSizeInPixels failed");
        if (width == 0 or height == 0) {
            c.SDL_Delay(16);
            continue;
        }

        if (frame_index > frames_in_flight)
            try frame_semaphore.wait(frame_index - frames_in_flight);

        const back_buffer = try swapchain.acquireBackBuffer(@intCast(width), @intCast(height));

        const cb = try queue.startCommandRecording();
        cb.setActiveTextureHeap(descriptor_heap.device_ptr.addr);
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
        cb.draw(data_map.device.addr, data_map.device.addr, vertex_count, 1);
        cb.endRenderPass();

        try queue.submitAndSignal(&.{cb}, frame_semaphore, frame_index);
        try swapchain.present();

        frame_index += 1;
    }

    if (frame_index > 1) try frame_semaphore.wait(frame_index - 1);
}
