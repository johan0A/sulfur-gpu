pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    var loader = try VulkanLoader.open();
    defer loader.close();

    var instance: gpu.Instance = try .create(gpa, loader.proc, &.{});
    defer instance.destroy(gpa);

    const adapters = try instance.enumerateAdaptersAlloc(arena);

    // TODO: pick adapter
    const adapter = adapters[0];

    var device: gpu.Device = try .create(gpa, instance, adapter);
    defer device.destroy();

    const gpu_gpa = gpu.heap.rawDeviceAllocator(&device);
    var gpu_arena_impl: gpu.heap.FixedBufferAllocator = try .initAlloc(gpu_gpa, .{}, 1024 * 1024);
    defer gpu_arena_impl.deinit(gpu_gpa);
    const gpu_arena = gpu_arena_impl.allocator();

    const queue: gpu.Queue = .create(device, .graphics);

    const dimensions: [3]u32 = .{ 256, 256, 1 };
    const texture_info: gpu.Texture.Info = .{
        .dimensions = dimensions,
        .format = .rgba8_unorm,
        .usage = .{ .storage = true },
    };

    const texture_size_align = gpu.Texture.sizeAndAlignment(device, texture_info);
    const texture_gpu = try gpu_arena.runtimeAlignedAlloc(u8, texture_size_align.alignment, texture_size_align.size, .gpu);
    defer gpu_arena.runtimeAlignedfree(texture_gpu, texture_size_align.alignment, .gpu);

    var texture: gpu.Texture = try .create(&device, texture_info, texture_gpu);
    defer texture.destroy(&device);

    const descriptor_size_and_align = gpu.Texture.Descriptor.sizeAndHeapAlignment(&device);
    const heap_gpu = try gpu_arena.runtimeAlignedAlloc(u8, descriptor_size_and_align.alignment, descriptor_size_and_align.size * 65536, .default);
    defer gpu_arena.runtimeAlignedfree(heap_gpu, descriptor_size_and_align.alignment, .default);
    const heap = device.deviceToHostPointer(heap_gpu);

    const descriptor = try texture.storageDescriptor(&device, .{});
    descriptor.store(&device, heap, 0);

    const data_gpu = try gpu_arena.create(Data, .default);
    defer gpu_arena.destroy(data_gpu, .default);
    const data_cpu: *Data = device.deviceToHostPointer(data_gpu);
    data_cpu.output_texture = 0;

    const pixel_buffer_size = dimensions[0] * dimensions[1] * 4;
    const readback_gpu = try gpu_arena.alignedAlloc(u8, .fromByteUnits(256), pixel_buffer_size, .readback);
    defer gpu_arena.free(readback_gpu, .readback);
    const readback_cpu: []u8 = device.deviceToHostPointer(readback_gpu);

    const spirv align(@alignOf(u32)) = @embedFile("generate_texture.spv").*;
    var pipeline: gpu.Pipeline = try .createCompute(device, @ptrCast(&spirv));
    defer pipeline.destroy(device);

    const cb = try queue.startRecording(&device);
    cb.setActiveTextureHeapPtr(device, heap_gpu);
    cb.setPipeline(device, pipeline);
    cb.dispatch(device, .cast(data_gpu), .{
        (dimensions[0] + 7) / 8,
        (dimensions[1] + 7) / 8,
        1,
    });

    cb.barrier(device, .{ .compute = true }, .{ .transfer = true }, .{});
    cb.copyTextureToBuffer(&device, .from(readback_gpu), texture_gpu, texture);

    var done: gpu.Semaphore = try .create(device, 0);
    defer done.destroy(device);
    try queue.submitAndSignal(&device, &.{cb}, done, 1);
    try done.wait(device, 1);

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
    output_texture: u32 align(16),
};

const std = @import("std");
const gpu = @import("sulfur");
const VulkanLoader = @import("VulkanLoader");
