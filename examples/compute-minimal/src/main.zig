extern fn sfProcAddr(name: [*:0]const u8) callconv(gpu.@"callconv") *const anyopaque;

pub fn main(init: std.process.Init) !void {
    const instance: *gpu.Instance = gpu.createInstance(null, &sfProcAddr);
    defer gpu.destroyInstance(instance);

    var adapters_buff: [64]*gpu.Adapter = undefined;
    var adapters: []*gpu.Adapter = adapters_buff[0..0];
    gpu.enumerateAdapters(instance, adapters_buff.len, &adapters_buff, &adapters.len);

    // TODO: pick adapter
    const adapter = adapters[0];

    const device: *gpu.Device = gpu.createDevice(instance, adapter);
    defer gpu.destroyDevice(device);

    const queue: *gpu.Queue = gpu.createQueue(device, .graphics);

    const dimensions: [3]u32 = .{ 256, 256, 1 };
    const texture_info: gpu.TextureDesc = .{
        .dimensions = dimensions,
        .format = .rgba8_unorm,
        .usage = .{ .storage = true },
    };

    const texture_size_align = gpu.textureSizeAndAlign(device, texture_info);
    const texture_gpu = gpu.malloc(device, texture_size_align.size, texture_size_align.alignment, .gpu);
    defer gpu.free(device, texture_gpu);

    const texture: *gpu.Texture = gpu.createTexture(device, texture_info, texture_gpu);
    defer gpu.destroyTexture(texture);

    const descriptor_size_and_align = gpu.descriptorSizeAndHeapAlign(device);
    const heap_gpu = gpu.malloc(device, descriptor_size_and_align.size * 65536, descriptor_size_and_align.alignment, .default);
    defer gpu.free(device, heap_gpu);
    const heap: [*]u8 = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, heap_gpu)));

    const descriptor = gpu.textureStorageDescriptor(texture, .{});
    gpu.storeDescriptor(device, &descriptor, heap, 0);

    const data_gpu = gpu.malloc(device, @sizeOf(Data), @alignOf(Data), .default);
    defer gpu.free(device, data_gpu);
    const data_cpu: *Data = @ptrCast(@alignCast(gpu.deviceToHostPointer(device, data_gpu)));
    data_cpu.output_texture = 0;

    const pixel_buffer_size = dimensions[0] * dimensions[1] * 4;
    const readback_gpu = gpu.malloc(device, pixel_buffer_size, 256, .readback);
    defer gpu.free(device, readback_gpu);
    const readback_cpu: [*]u8 = @ptrCast(gpu.deviceToHostPointer(device, readback_gpu));

    const spv = @embedFile("generate_texture.spv");
    const pipeline: *gpu.Pipeline = gpu.createComputePipeline(device, spv.len, spv);
    defer gpu.destroyPipeline(pipeline);

    const cb = gpu.startCommandRecording(queue);
    gpu.setActiveTextureHeap(cb, heap_gpu);
    gpu.setPipeline(cb, pipeline);
    gpu.dispatch(
        cb,
        data_gpu,
        (dimensions[0] + 7) / 8,
        (dimensions[1] + 7) / 8,
        1,
    );

    gpu.barrier(cb, .{ .compute = true }, .{ .transfer = true }, .{});
    gpu.copyTextureToBuffer(cb, texture_gpu, readback_gpu, texture);

    const done: *gpu.Semaphore = gpu.createSemaphore(device, 0);
    defer gpu.destroySemaphore(done);
    gpu.submitAndSignal(queue, 1, &.{cb}, done, 1);
    gpu.waitSemaphore(done, 1);

    const pixel_buffer = readback_cpu[0..pixel_buffer_size];

    var file = try std.Io.Dir.cwd().createFile(init.io, "out.bmp", .{});
    defer file.close(init.io);
    var buf: [4096]u8 = undefined;
    var fw = file.writer(init.io, &buf);
    try writeBmp(&fw.interface, pixel_buffer, dimensions[0], dimensions[1]);
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

const Data = extern struct {
    output_texture: u32,
};

const std = @import("std");
const gpu = @import("sulfur");
const VulkanLoader = @import("VulkanLoader");
