const std = @import("std");
const builtin = @import("builtin");
const gpu = @import("root.zig");

pub const magic: [4]u8 = "sfir".*;

pub const Version = struct {
    major: u16,
    minor: u16,
};

pub const version: Version = .{ .major = 0, .minor = 1 };

const header_len = 16;
const sampler_len = @sizeOf(u64);

comptime {
    std.debug.assert(@sizeOf(gpu.Sampler) == sampler_len);
}

pub const max_spirv_len = 1 << 30;
pub const max_sampler_count = (1 << 30) / sampler_len;

pub const ParseError = error{
    BadMagic,
    UnsupportedVersion,
    Malformed,
};

pub const Shader = struct {
    file_version: Version,
    spirv: []const u8,
    sampler_bytes: []const u8,
    encoded_len: usize,

    pub fn samplerCount(shader: Shader) usize {
        return shader.sampler_bytes.len / sampler_len;
    }

    pub fn sampler(shader: Shader, index: usize) gpu.Sampler {
        std.debug.assert(index < shader.samplerCount());
        const raw = shader.sampler_bytes[index * sampler_len ..][0..sampler_len];
        return @bitCast(std.mem.readInt(u64, raw, .little));
    }

    pub fn samplerIterator(shader: Shader) SamplerIterator {
        return .{ .shader = shader };
    }

    pub fn spirvWordCount(shader: Shader) usize {
        return shader.spirv.len / 4;
    }

    pub fn spirvWords(shader: Shader) ?[]align(4) const u32 {
        if (!std.mem.isAligned(@intFromPtr(shader.spirv.ptr), 4)) return null;
        return std.mem.bytesAsSlice(u32, @as([]align(4) const u8, @alignCast(shader.spirv)));
    }

    pub fn spirvAlloc(shader: Shader, gpa: std.mem.Allocator) ![]u32 {
        const words = try gpa.alloc(u32, shader.spirvWordCount());
        @memcpy(std.mem.sliceAsBytes(words), shader.spirv);
        return words;
    }
};

pub const SamplerIterator = struct {
    shader: Shader,
    index: usize = 0,

    pub fn next(it: *SamplerIterator) ?gpu.Sampler {
        if (it.index == it.shader.samplerCount()) return null;
        defer it.index += 1;
        return it.shader.sampler(it.index);
    }
};

pub fn parse(bytes: []const u8) ParseError!Shader {
    if (bytes.len < header_len) return error.Malformed;
    if (!std.mem.eql(u8, bytes[0..4], &magic)) return error.BadMagic;

    const file_version: Version = .{
        .major = std.mem.readInt(u16, bytes[4..6], .little),
        .minor = std.mem.readInt(u16, bytes[6..8], .little),
    };
    if (file_version.major != version.major) return error.UnsupportedVersion;

    const spirv_len = std.mem.readInt(u32, bytes[8..12], .little);
    const sampler_count = std.mem.readInt(u32, bytes[12..16], .little);
    if (spirv_len == 0 or spirv_len % 4 != 0) return error.Malformed;
    if (spirv_len > max_spirv_len) return error.Malformed;
    if (sampler_count > max_sampler_count) return error.Malformed;

    const samplers_off = header_len + @as(usize, spirv_len);
    const samplers_len = @as(usize, sampler_count) * sampler_len;
    const end = samplers_off + samplers_len;
    if (bytes.len < end) return error.Malformed;

    return .{
        .file_version = file_version,
        .spirv = bytes[header_len..samplers_off],
        .sampler_bytes = bytes[samplers_off..end],
        .encoded_len = end,
    };
}

pub const EncodeError = error{TooLarge};

pub fn encodedLen(spirv_len: usize, sampler_count: usize) EncodeError!usize {
    if (spirv_len > max_spirv_len) return error.TooLarge;
    if (sampler_count > max_sampler_count) return error.TooLarge;
    return header_len + spirv_len + sampler_count * sampler_len;
}

pub const Encoder = struct {
    w: *std.Io.Writer,
    spirv_left: u32,
    samplers_left: u32,

    pub const Options = struct {
        spirv_len: u32,
        sampler_count: u32 = 0,
    };

    pub fn begin(w: *std.Io.Writer, spirv_len: u32, sampler_count: u32) (EncodeError || std.Io.Writer.Error)!Encoder {
        std.debug.assert(spirv_len != 0);
        std.debug.assert(spirv_len % 4 == 0);
        _ = try encodedLen(spirv_len, sampler_count);

        try w.writeAll(&magic);
        try w.writeInt(u16, version.major, .little);
        try w.writeInt(u16, version.minor, .little);
        try w.writeInt(u32, spirv_len, .little);
        try w.writeInt(u32, sampler_count, .little);

        return .{
            .w = w,
            .spirv_left = spirv_len,
            .samplers_left = sampler_count,
        };
    }

    pub fn spirv(e: *Encoder, bytes: []const u8) std.Io.Writer.Error!void {
        std.debug.assert(bytes.len <= e.spirv_left);
        e.spirv_left -= @intCast(bytes.len);
        try e.w.writeAll(bytes);
    }

    pub fn sampler(e: *Encoder, s: gpu.Sampler) std.Io.Writer.Error!void {
        std.debug.assert(e.spirv_left == 0);
        std.debug.assert(e.samplers_left != 0);
        e.samplers_left -= 1;
        try e.w.writeInt(u64, @bitCast(s), .little);
    }

    pub fn end(e: *Encoder) void {
        std.debug.assert(e.spirv_left == 0);
        std.debug.assert(e.samplers_left == 0);
        e.* = undefined;
    }
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    const out_file = try std.Io.Dir.createFile(.cwd(), init.io, args[1], .{});
    var out_writer_buff: [1024]u8 = undefined;
    var out_writer = out_file.writer(init.io, &out_writer_buff);

    const spirv = try std.Io.Dir.readFileAlloc(.cwd(), init.io, args[2], arena, .unlimited);

    const sampler_args = args[3..];

    var encoder: Encoder = try .begin(&out_writer.interface, @intCast(spirv.len), @intCast(sampler_args.len));
    try encoder.spirv(spirv);

    for (sampler_args) |arg| {
        var out: [1024]u8 = undefined;
        const as_bytes = try std.fmt.hexToBytes(&out, arg);
        const sampler: gpu.Sampler = @bitCast(as_bytes[0..8].*);
        try encoder.sampler(sampler);
    }

    encoder.end();
    try out_writer.flush();
}
