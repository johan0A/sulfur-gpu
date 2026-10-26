const std = @import("std");
const target = @import("builtin").target;
const sf = @import("sulfur");
const c = @import("c");

const sfSymbol = @extern(sf.Symbol, .{ .name = "sfSymbol" });

const Data = extern struct {
    output_texture: u32,
    time: f32,
};

const frames_in_fligt = 2;
const workgroup_size = 8;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) @panic("SDL_Init failed");
    defer c.SDL_Quit();

    var width: c_int = 512;
    var height: c_int = 512;

    const window = c.SDL_CreateWindow("title", width, height, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse @panic("SDL_CreateWindow failed");
    defer c.SDL_DestroyWindow(window);

    const instance = sf.Instance.create(null, sfSymbol);
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

    const gpu_gpa = sf.heap.rawDeviceAllocator(device);
    var fix_buffer_allocator: sf.heap.FixedBufferAllocator = try .initAlloc(gpu_gpa, .initFill(1024 * 1024 * 64));
    defer fix_buffer_allocator.deinit(gpu_gpa);
    const gpu_arena = fix_buffer_allocator.allocator();

    const queue = device.getQueue(.graphics);

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
            break :blk sf.Surface.createXlib(device, surface_desc);
        },
    };
    defer surface.destroy();

    const surface_formats = try device.surfaceFormatsAlloc(surface, arena);
    const swapchain_format = for (surface_formats) |f| {
        if (f == .rgba8_unorm or f == .bgra8_unorm) break f;
    } else return error.NoSupportedSurfaceFormat;

    const surface_usage = device.surfaceSupportedUsage(surface);
    if (!surface_usage.storage) return error.SurfaceStorageUnsupported;

    const frame_semaphore = try device.createSemaphore(0);
    defer frame_semaphore.destroy();
    var frame_index: u64 = 1;

    const swapchain: *sf.Swapchain = try .create(queue, surface, .{
        .format = swapchain_format,
        .usage = .{ .storage = true },
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

    var data_maps: [frames_in_fligt]@TypeOf(try gpu_arena.create(Data, .upload)) = undefined;
    for (&data_maps) |*d| d.* = try gpu_arena.create(Data, .upload);

    const pipeline = try device.createComputePipeline(@embedFile("generate_texture.sfir"));
    defer pipeline.destroy();

    const start: std.Io.Timestamp = .now(io, .real);

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

        if (frame_index > frames_in_fligt)
            try frame_semaphore.wait(frame_index - frames_in_fligt);

        const slot: u32 = @intCast(frame_index % frames_in_fligt);

        const back_buffer: *sf.Texture = try swapchain.acquireBackBuffer(@intCast(width), @intCast(height));

        const descriptor = try back_buffer.storageDescriptor(.{});
        device.storeDescriptor(&descriptor, descriptor_heap.host_ptr, slot);

        const elapsed_us: f64 = @floatFromInt(start.untilNow(io, .real).toMicroseconds());
        const data_map = data_maps[slot];
        data_map.host.* = .{
            .output_texture = slot,
            .time = @floatCast(elapsed_us / 1e6),
        };

        const w: u32 = @intCast(width);
        const h: u32 = @intCast(height);

        const command_buffer = try queue.startCommandRecording();
        command_buffer.setActiveTextureHeap(descriptor_heap.device_ptr.addr);
        command_buffer.setPipeline(pipeline);
        command_buffer.dispatch(
            data_map.device.addr,
            (w + workgroup_size - 1) / workgroup_size,
            (h + workgroup_size - 1) / workgroup_size,
            1,
        );

        try queue.submitAndSignal(&.{command_buffer}, frame_semaphore, frame_index);
        try swapchain.present();

        frame_index += 1;
    }

    if (frame_index > 1) try frame_semaphore.wait(frame_index - 1);
}
