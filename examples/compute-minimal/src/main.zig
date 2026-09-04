const std = @import("std");
const gpu = @import("sulfur");

extern fn sfSymbol(name: [*:0]const u8) callconv(gpu.@"callconv") *const anyopaque;

const Data = extern struct {
    output_texture: u32,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    const workgroup_size = 8;
    const width = 256;
    const height = 256;

    const instance = gpu.Instance.create(null, &sfSymbol);
    defer instance.destroy();

    const adapters = try instance.enumerateAdaptersAlloc(arena);

    const adapter = adapters[0]; // TODO: pick adapter

    const device = instance.createDevice(adapter);
    defer device.destroy();

    const queue = device.getQueue(.graphics);

    const texture_info: gpu.TextureDesc = .{
        .dimensions = .{ width, height, 1 },
        .format = .rgba8_unorm,
        .usage = .{ .storage = true },
    };
    const texture_size_and_align = device.textureSizeAndAlign(texture_info);
    const texture_gpu = device.malloc(texture_size_and_align.size, texture_size_and_align.alignment, .gpu);
    defer device.free(texture_gpu);
    const texture = try device.createTexture(texture_info, texture_gpu);
    defer texture.destroy();

    const descriptor_size_and_align = device.descriptorSizeAndHeapAlign();
    const heap_gpu = device.malloc(descriptor_size_and_align.size * 65536, descriptor_size_and_align.alignment, .default);
    defer device.free(heap_gpu);
    const heap: [*]u8 = @ptrCast(@alignCast(device.deviceToHostPointer(heap_gpu)));
    const descriptor = try texture.textureStorageDescriptor(.{});
    device.storeDescriptor(&descriptor, heap, 0);

    const data_gpu = device.malloc(@sizeOf(Data), @alignOf(Data), .default);
    defer device.free(data_gpu);
    const data: *Data = @ptrCast(@alignCast(device.deviceToHostPointer(data_gpu)));
    data.* = .{ .output_texture = 0 };

    const pixel_buffer_size = width * height * 4;
    const readback_gpu = device.malloc(pixel_buffer_size, 256, .readback);
    defer device.free(readback_gpu);

    const pipeline = try device.createComputePipeline(@embedFile("generate_texture.spv"));
    defer pipeline.destroy();

    const command_buffer = try queue.startCommandRecording();
    command_buffer.setActiveTextureHeap(heap_gpu);
    command_buffer.setPipeline(pipeline);
    command_buffer.dispatch(
        data_gpu,
        (width + workgroup_size - 1) / workgroup_size,
        (height + workgroup_size - 1) / workgroup_size,
        1,
    );
    command_buffer.barrier(.{ .compute = true }, .{ .transfer = true }, .{});
    command_buffer.copyTextureToBuffer(texture_gpu, readback_gpu, texture);

    const done = try device.createSemaphore(0);
    defer done.destroy();
    try queue.submitAndSignal(&.{command_buffer}, done, 1);
    try done.waitSemaphore(1);

    const readback: [*]const u8 = @ptrCast(device.deviceToHostPointer(readback_gpu));
    const pixels = readback[0..pixel_buffer_size];

    const file = try std.Io.Dir.cwd().createFile(io, "out.bmp", .{});
    defer file.close(io);
    var buffer: [4096]u8 = undefined;
    var file_writer = file.writer(io, &buffer);
    try writeBmp(&file_writer.interface, pixels, width, height);
    try file_writer.flush();
}

pub fn writeBmp(w: *std.Io.Writer, pixels: []const u8, width: u32, height: u32) !void {
    const row_size = std.mem.alignForward(u32, (width * 3), 4);
    const data_size = row_size * height;
    const file_size = 54 + data_size;

    try w.writeAll("BM");
    try w.writeInt(u32, file_size, .little);
    try w.writeInt(u32, 0, .little);
    try w.writeInt(u32, 54, .little);
    try w.writeInt(u32, 40, .little);
    try w.writeInt(i32, @intCast(width), .little);
    try w.writeInt(i32, @intCast(height), .little);
    try w.writeInt(u16, 1, .little);
    try w.writeInt(u16, 24, .little);
    try w.writeInt(u32, 0, .little);
    try w.writeInt(u32, data_size, .little);
    try w.writeInt(i32, 0, .little);
    try w.writeInt(i32, 0, .little);
    try w.writeInt(u32, 0, .little);
    try w.writeInt(u32, 0, .little);

    var y: u32 = height;
    while (y > 0) {
        y -= 1;
        for (0..width) |x| {
            const i = (y * width + x) * 4;
            try w.writeAll(&.{ pixels[i + 2], pixels[i + 1], pixels[i] });
        }
        try w.splatByteAll(0, row_size - width * 3);
    }
    try w.flush();
}
