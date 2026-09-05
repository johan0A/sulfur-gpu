const std = @import("std");
const target = @import("builtin").target;
const gpu = @import("sulfur");
const c = @import("c");

const sfSymbol = @extern(gpu.Symbol, .{ .name = "sfSymbol" });

const frames_in_flight = 2;

const Data = extern struct {
    positions: gpu.DeviceAddress,
    colors: gpu.DeviceAddress,
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    var width: c_int = 512;
    var height: c_int = 512;
    const window = c.SDL_CreateWindow("title", width, height, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse
        return error.SdlCreateWindow;

    const instance = gpu.Instance.create(null, sfSymbol);
    defer instance.destroy();

    const adapters = try instance.enumerateAdaptersAlloc(arena);

    const adapter = adapters[0]; // TODO: pick adapter

    const device = instance.createDevice(adapter);
    defer device.destroy();

    const queue = device.getQueue(.graphics);

    const surface = try createSurface(device, window);
    defer surface.destroy();

    const surface_formats = try device.surfaceFormatsAlloc(surface, arena);
    const swapchain_format = for (surface_formats) |format| {
        if (format == .rgba8_unorm_srgb or format == .bgra8_unorm_srgb) break format;
    } else return error.NoSrgbSurfaceFormat;

    const swapchain = try queue.createSwapchain(surface, .{
        .format = swapchain_format,
        .usage = .{ .color_attachment = true },
        .present_mode = .fifo,
    });
    defer swapchain.destroy();

    const frame_semaphore = try device.createSemaphore(0);
    defer frame_semaphore.destroy();
    var frame_index: u64 = 1;

    const descriptor_size_and_align = device.descriptorSizeAndHeapAlign();
    const descriptor_heap = device.malloc(descriptor_size_and_align.size * 65536, descriptor_size_and_align.alignment, .default);
    defer device.free(descriptor_heap);

    const positions = allocMapped(device, [3][3]f32);
    defer device.free(positions.gpu);
    positions.cpu.* = .{
        .{ -1, 1, 0 },
        .{ 0, -1, 0 },
        .{ 1, 1, 0 },
    };

    const colors = allocMapped(device, [3][3]f32);
    defer device.free(colors.gpu);
    colors.cpu.* = .{
        .{ 0, 0, 1 },
        .{ 0, 1, 0 },
        .{ 1, 0, 0 },
    };

    const data = allocMapped(device, Data);
    defer device.free(data.gpu);
    data.cpu.* = .{
        .positions = positions.gpu,
        .colors = colors.gpu,
    };

    const pipeline = try device.createGraphicsPipeline(@embedFile("vert.spv"), @embedFile("frag.spv"), .{
        .color_target_count = 1,
        .color_targets = &.{.{ .format = swapchain_format }},
    });
    defer pipeline.destroy();

    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) switch (event.type) {
            c.SDL_EVENT_QUIT => quit = true,
            else => {},
        };

        if (!c.SDL_GetWindowSizeInPixels(window, &width, &height)) return error.SdlWindowSize;

        if (frame_index > frames_in_flight) try frame_semaphore.wait(frame_index - frames_in_flight);

        const back_buffer = try swapchain.acquireBackBuffer(@intCast(width), @intCast(height));

        const command_buffer = try queue.startCommandRecording();
        command_buffer.setActiveTextureHeap(descriptor_heap);
        command_buffer.beginRenderPass(.{
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
        command_buffer.setPipeline(pipeline);
        command_buffer.draw(data.gpu, data.gpu, 3, 1);
        command_buffer.endRenderPass();

        try queue.submitAndSignal(&.{command_buffer}, frame_semaphore, frame_index);
        try swapchain.present();

        frame_index += 1;
    }

    try frame_semaphore.wait(frame_index - 1);
}

fn createSurface(device: *gpu.Device, window: *c.SDL_Window) !*gpu.Surface {
    const properties = c.SDL_GetWindowProperties(window);
    switch (target.os.tag) {
        .windows => {
            const hwnd = c.SDL_GetPointerProperty(properties, c.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null) orelse
                return error.SdlWindowHandle;
            const hinstance = c.SDL_GetPointerProperty(properties, c.SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER, null) orelse
                return error.SdlWindowHandle;
            return device.createSurfaceWin32(.{ .hinstance = hinstance, .hwnd = hwnd });
        },
        else => {
            const display = c.SDL_GetPointerProperty(properties, c.SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null) orelse
                return error.SdlWindowHandle;
            const x11_window = c.SDL_GetNumberProperty(properties, c.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
            if (x11_window == 0) return error.SdlWindowHandle;
            return device.createSurfaceXlib(.{ .display = display, .window = @intCast(x11_window) });
        },
    }
}

fn Mapped(comptime T: type) type {
    return struct {
        gpu: gpu.DeviceAddress,
        cpu: *T,
    };
}

fn allocMapped(device: *gpu.Device, comptime T: type) Mapped(T) {
    const memory = device.malloc(@sizeOf(T), @alignOf(T), .default);
    return .{
        .gpu = memory,
        .cpu = @ptrCast(@alignCast(device.toHostPointer(memory))),
    };
}
