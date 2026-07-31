pub fn main(init: std.process.Init) !void {
    var loader = try VulkanLoader.open();
    defer loader.close();

    var instance: *gpu.Instance = .sfCreateInstance(null, loader.proc, 0, &.{});
    defer instance.sfDestroyInstance();

    var adapters_buff: [64]*gpu.Adapter = undefined;
    var adapters: []*gpu.Adapter = adapters_buff[0..0];
    instance.sfEnumerateAdapters(adapters_buff.len, &adapters_buff, &adapters.len);

    // TODO: pick adapter
    const adapter = adapters[0];

    var device: *gpu.Device = .sfCreateDevice(instance, adapter);
    defer device.sfDestroyDevice();

    const queue: *gpu.Queue = .sfCreateQueue(device, .graphics);

    const dimensions: [3]u32 = .{ 256, 256, 1 };
    const texture_info: gpu.Texture.Desc = .{
        .dimensions = dimensions,
        .format = .rgba8_unorm,
        .usage = .{ .storage = true },
    };

    const texture_size_align = gpu.Texture.sfTextureSizeAndAlign(device, texture_info);
    const texture_gpu = device.sfMalloc(texture_size_align.size, texture_size_align.@"align", .gpu);
    defer device.sfFree(texture_gpu);

    var texture: *gpu.Texture = .sfCreateTexture(device, texture_info, texture_gpu);
    defer texture.sfDestroyTexture(device);

    const descriptor_size_and_align = gpu.Texture.Descriptor.sfDescriptorSizeAndHeapAlign(device);
    const heap_gpu = device.sfMalloc(descriptor_size_and_align.size * 65536, descriptor_size_and_align.@"align", .default);
    defer device.sfFree(heap_gpu);
    const heap: [*]u8 = @ptrCast(@alignCast(device.sfDeviceToHostPointer(heap_gpu)));

    const descriptor = texture.sfTextureStorageDescriptor(device, .{});
    descriptor.store(device, heap[0 .. descriptor_size_and_align.size * 65536], 0);

    const data_gpu = device.sfMalloc(@sizeOf(Data), @alignOf(Data), .default);
    defer device.sfFree(data_gpu);
    const data_cpu: *Data = @ptrCast(@alignCast(device.sfDeviceToHostPointer(data_gpu)));
    data_cpu.output_texture = 0;

    const pixel_buffer_size = dimensions[0] * dimensions[1] * 4;
    const readback_gpu = device.sfMalloc(pixel_buffer_size, 256, .readback);
    defer device.sfFree(readback_gpu);
    const readback_cpu: [*]u8 = @ptrCast(device.sfDeviceToHostPointer(readback_gpu));

    const spv = @embedFile("generate_texture.spv");
    var pipeline: *gpu.Pipeline = .sfCreateComputePipeline(device, spv.len, spv);
    defer pipeline.sfDestroyPipeline(device);

    var cb = queue.sfStartCommandRecording(device);
    cb.sfSetActiveTextureHeapPtr(device, heap_gpu);
    cb.sfSetPipeline(device, pipeline);
    cb.sfDispatch(
        device,
        data_gpu,
        (dimensions[0] + 7) / 8,
        (dimensions[1] + 7) / 8,
        1,
    );

    cb.sfBarrier(device, .{ .compute = true }, .{ .transfer = true }, .{});
    cb.sfCopyTextureToBuffer(device, readback_gpu, texture_gpu, texture);

    var done: *gpu.Semaphore = .sfCreateSemaphore(device, 0);
    defer done.sfDestroySemaphore(device);
    queue.sfSubmitAndSignal(device, 1, &.{cb}, done, 1);
    done.sfWaitSemaphore(device, 1);

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
