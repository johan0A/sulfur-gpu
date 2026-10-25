const std = @import("std");
const sf = @import("sulfur");

const sfSymbol = @extern(sf.Symbol, .{ .name = "sfSymbol" });

const Data = extern struct {
    output_texture: u32,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    const workgroup_size = 8;
    const width = 256;
    const height = 256;

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

    const texture_info: sf.TextureDesc = .{
        .dimensions = .{ width, height, 1 },
        .format = .rgba8_unorm,
        .usage = .{ .storage = true },
    };
    const texture_size_and_align = device.textureSizeAndAlign(texture_info);
    const texture_map = try gpu_arena.runtimeAlignedAlloc(u8, texture_size_and_align.alignment(), texture_size_and_align.size, .device_local);
    const texture = try device.createTexture(texture_info, texture_map.device_ptr);
    defer texture.destroy();

    const descriptor_size_and_align = device.descriptorSizeAndHeapAlign();
    const descriptor_heap = try gpu_arena.runtimeAlignedAlloc(u8, descriptor_size_and_align.alignment(), descriptor_size_and_align.size * 65536, .upload);
    const descriptor = try texture.storageDescriptor(.{});
    device.storeDescriptor(&descriptor, descriptor_heap.host_ptr, 0);

    const data_map = try gpu_arena.create(Data, .upload);
    data_map.host.* = .{ .output_texture = 0 };

    const pixel_buffer_size = width * height * 4;
    const readback = try gpu_arena.alignedAlloc(u8, .fromByteUnits(256), pixel_buffer_size, .readback);

    const pipeline = try device.createComputePipeline(@embedFile("generate_texture.sfir"));
    defer pipeline.destroy();

    const command_buffer = try queue.startCommandRecording();
    command_buffer.setActiveTextureHeap(descriptor_heap.device_ptr);
    command_buffer.setPipeline(pipeline);
    command_buffer.dispatch(
        .from(data_map.device),
        (width + workgroup_size - 1) / workgroup_size,
        (height + workgroup_size - 1) / workgroup_size,
        1,
    );
    command_buffer.barrier(.{ .compute = true }, .{ .transfer = true }, .{});
    command_buffer.copyTextureToBuffer(texture, .from(readback.device_ptr));

    const done = try device.createSemaphore(0);
    defer done.destroy();
    try queue.submitAndSignal(&.{command_buffer}, done, 1);
    try done.wait(1);

    const file = try std.Io.Dir.cwd().createFile(io, "out.bmp", .{});
    defer file.close(io);
    var buffer: [4096]u8 = undefined;
    var file_writer = file.writer(io, &buffer);
    try writeBmp(&file_writer.interface, readback.host(), width, height);
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
