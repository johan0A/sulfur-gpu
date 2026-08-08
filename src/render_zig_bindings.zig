const std = @import("std");
const parse_registry = @import("parse_registry.zig");
const Registry = parse_registry.Registry;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const parsed = try std.json.parseFromSlice(Registry, arena, @embedFile("sulfur.json"), .{});
    const registry = parsed.value;

    var buf: [4096]u8 = undefined;
    var file_writer = std.Io.File.stdout().writer(init.io, &buf);
    try renderBinding(&file_writer.interface, registry);
    try file_writer.interface.flush();
}

fn renderBinding(w: *std.Io.Writer, registry: Registry) !void {
    try w.print(
        \\// Generated file do not edit.
        \\// version: {s}
        \\
    , .{registry.version});
    try w.writeAll(
        \\const std = @import("std");
        \\
        \\const target = @import("builtin").target;
        \\const sf_callconv: std.builtin.CallingConvention = switch (target.os.tag) {
        \\    .windows => if (target.cpu.arch.isX86()) .{ .x86_stdcall = .{} } else .c,
        \\    else => .c,
        \\};
        \\
        \\
    );

    try sectionHeader(w, "Constants");
    for (registry.constants) |constant| {
        try renderDoc(w, constant.doc, 0);
        try w.writeAll("pub const ");
        try writeLowerIdent(w, stripPrefix(constant.name, registry.enum_prefix));
        try w.writeAll(": ");
        try writeTypeName(w, registry, constant.type);
        try w.print(" = {s};\n", .{constant.value});
    }
    try w.writeByte('\n');

    try sectionHeader(w, "Type aliases");
    for (registry.typedefs) |typedef| {
        try renderDoc(w, typedef.doc, 0);
        try w.writeAll("pub const ");
        try writeTypeName(w, registry, typedef.name);
        try w.writeAll(" = ");
        try writeTypeName(w, registry, typedef.type);
        try w.writeAll(";\n");
    }
    try w.writeByte('\n');

    try sectionHeader(w, "Opaque handles");
    for (registry.opaques) |@"opaque"| {
        try renderDoc(w, @"opaque".doc, 0);
        try w.writeAll("pub const ");
        try writeTypeName(w, registry, @"opaque".name);
        try w.writeAll(" = opaque {};\n");
    }
    try w.writeByte('\n');

    try sectionHeader(w, "Enums");
    for (registry.enums) |@"enum"| {
        try renderDoc(w, @"enum".doc, 0);
        try w.writeAll("pub const ");
        try writeTypeName(w, registry, @"enum".name);
        try w.writeAll(" = enum(");
        try writeTypeName(w, registry, @"enum".backing_type);
        try w.writeAll(") {\n");
        for (@"enum".values) |v| {
            try renderDoc(w, v.doc, 1);
            try w.writeAll("    ");
            try writeMemberName(w, registry, @"enum".name, v.name);
            try w.print(" = {d},\n", .{v.value});
        }
        try w.writeAll("    _,\n};\n\n");
    }

    try sectionHeader(w, "Flags");
    for (registry.flags) |flags| {
        const width = bitWidth(flags.backing_type);

        try renderDoc(w, flags.doc, 0);
        try w.writeAll("pub const ");
        try writeTypeName(w, registry, flags.name);
        try w.writeAll(" = packed struct(");
        try writeTypeName(w, registry, flags.backing_type);
        try w.writeAll(") {\n");

        var highest: u16 = 0;
        for (flags.bits) |b| highest = @max(highest, b.bit + 1);

        var slot: u16 = 0;
        while (slot < highest) : (slot += 1) {
            const bit = for (flags.bits) |b| {
                if (b.bit == slot) break b;
            } else null;

            if (bit) |b| {
                try renderDoc(w, b.doc, 1);
                try w.writeAll("    ");
                try writeMemberName(w, registry, flags.name, b.name);
                try w.writeAll(": bool = false,\n");
            } else {
                try w.print("    reserved_{d}: bool = false,\n", .{slot});
            }
        }
        if (highest < width) {
            try w.print("    padding: u{d} = 0,\n", .{width - highest});
        }

        for (flags.combinations) |combination| {
            try renderDoc(w, combination.doc, 1);
            try w.writeAll("\n    pub const ");
            try writeMemberName(w, registry, flags.name, combination.name);
            try w.writeAll(": ");
            try writeTypeName(w, registry, flags.name);
            try w.writeAll(" = .{");
            for (combination.bits, 0..) |bit, i| {
                if (i != 0) try w.writeByte(',');
                try w.writeAll(" .");
                try writeMemberName(w, registry, flags.name, bit);
                try w.writeAll(" = true");
            }
            try w.writeAll(if (combination.bits.len == 0) "};\n" else " };\n");
        }

        try w.writeAll("};\n\n");
    }

    try sectionHeader(w, "Function pointers");
    for (registry.function_pointers) |function_pointer| {
        try renderDoc(w, function_pointer.doc, 0);
        try w.writeAll("pub const ");
        try writeTypeName(w, registry, function_pointer.name);
        try w.writeAll(" = *const fn (");
        try renderParams(w, registry, function_pointer.params);
        try w.writeAll(") callconv(sf_callconv) ");
        try renderType(w, registry, function_pointer.@"return");
        try w.writeAll(";\n");
    }
    try w.writeByte('\n');

    try sectionHeader(w, "Structs");
    for (registry.structs) |@"struct"| {
        try renderDoc(w, @"struct".doc, 0);
        try w.writeAll("pub const ");
        try writeTypeName(w, registry, @"struct".name);
        try w.writeAll(" = extern struct {\n");
        for (@"struct".fields) |field| {
            try renderDoc(w, field.doc, 1);
            try w.writeAll("    ");
            try writeId(w, field.name);
            try w.writeAll(": ");
            try renderType(w, registry, field.type);
            try w.writeAll(",\n");
        }
        try w.writeAll("};\n\n");
    }

    try sectionHeader(w, "Functions");
    for (registry.functions) |function| {
        try renderDoc(w, function.doc, 0);
        try w.print("extern fn {s}(", .{function.name});
        try renderParams(w, registry, function.params);
        try w.writeAll(") callconv(sf_callconv) ");
        try renderType(w, registry, function.@"return");
        try w.writeAll(";\n");
        try w.writeAll("pub const ");

        var buff: [1024]u8 = undefined;
        var name: std.ArrayList(u8) = .initBuffer(&buff);
        name.appendSliceAssumeCapacity(stripPrefix(function.name, registry.fn_prefix));
        name.items[0] = std.ascii.toLower(buff[0]);
        try writeId(w, name.items);

        try w.print(" = {s};\n\n", .{function.name});
    }
}

fn renderParams(w: *std.Io.Writer, registry: Registry, params: []const Registry.Param) !void {
    for (params, 0..) |p, i| {
        if (i != 0) try w.writeAll(", ");
        try writeId(w, p.name);
        try w.writeAll(": ");
        try renderType(w, registry, p.type);
    }
}

fn renderType(w: *std.Io.Writer, registry: Registry, @"type": Registry.Type) !void {
    if (@"type".array) |array| switch (array) {
        .int => |n| try w.print("[{d}]", .{n}),
        .constant => |c| {
            try w.writeByte('[');
            try writeLowerIdent(w, stripPrefix(c, registry.enum_prefix));
            try w.writeByte(']');
        },
    };

    var i = @"type".ptr.len;
    while (i > 0) {
        i -= 1;
        const ptr = @"type".ptr[i];
        if (ptr.optional) try w.writeByte('?');
        if (ptr.len) |len| {
            if (std.mem.eql(u8, len, "null_terminated")) {
                try w.writeAll("[*:0]");
            } else {
                try w.writeAll("[*]");
            }
        } else {
            try w.writeByte('*');
        }
        if (ptr.@"const") try w.writeAll("const ");
    }

    try writeTypeName(w, registry, @"type".base);
}

fn renderDoc(w: *std.Io.Writer, doc: []const u8, indent: usize) !void {
    const trimmed = std.mem.trim(u8, doc, " \t\r\n");
    if (trimmed.len == 0) return;

    var it = std.mem.splitScalar(u8, trimmed, '\n');
    while (it.next()) |line| {
        try writeIndent(w, indent);
        try w.print("/// {s}\n", .{std.mem.trim(u8, line, " \t\r")});
    }
}

fn writeTypeName(w: *std.Io.Writer, registry: Registry, name: []const u8) !void {
    const primitives = .{
        .{ "void", "void" },   .{ "bool", "bool" },
        .{ "char", "u8" },     .{ "float", "f32" },
        .{ "double", "f64" },  .{ "size_t", "usize" },
        .{ "int8_t", "i8" },   .{ "uint8_t", "u8" },
        .{ "int16_t", "i16" }, .{ "uint16_t", "u16" },
        .{ "int32_t", "i32" }, .{ "uint32_t", "u32" },
        .{ "int64_t", "i64" }, .{ "uint64_t", "u64" },
        .{ "int", "c_int" },   .{ "unsigned int", "c_uint" },
    };
    inline for (primitives) |primitive| {
        if (std.mem.eql(u8, name, primitive[0])) return w.writeAll(primitive[1]);
    }
    try w.writeAll(stripPrefix(name, registry.type_prefix));
}

fn writeMemberName(w: *std.Io.Writer, registry: Registry, owner: []const u8, name: []const u8) !void {
    var buf: [256]u8 = undefined;
    var rest = name;

    const screaming = screamingCaseBuf(owner, &buf);
    if (std.mem.startsWith(u8, rest, screaming) and rest.len > screaming.len) {
        rest = rest[screaming.len..];
    } else {
        rest = stripPrefix(rest, registry.enum_prefix);
    }
    rest = std.mem.trimStart(u8, rest, "_");
    if (std.mem.endsWith(u8, rest, "_BIT")) rest = rest[0 .. rest.len - 4];
    if (rest.len == 0) rest = name;

    try writeLowerIdent(w, rest);
}

fn writeLowerIdent(w: *std.Io.Writer, name: []const u8) !void {
    var buf: [256]u8 = undefined;
    const lowered = std.ascii.lowerString(buf[0..name.len], name);
    try writeId(w, lowered);
}

fn writeId(w: *std.Io.Writer, name: []const u8) !void {
    if (std.zig.isValidId(name)) return w.writeAll(name);
    try w.print("@\"{s}\"", .{name});
}

fn stripPrefix(name: []const u8, prefix: []const u8) []const u8 {
    if (prefix.len != 0 and std.mem.startsWith(u8, name, prefix) and name.len > prefix.len) {
        return name[prefix.len..];
    }
    return name;
}

fn bitWidth(underlying: []const u8) u16 {
    if (std.mem.eql(u8, underlying, "uint8_t")) return 8;
    if (std.mem.eql(u8, underlying, "uint16_t")) return 16;
    if (std.mem.eql(u8, underlying, "uint64_t")) return 64;
    std.debug.assert(std.mem.eql(u8, underlying, "uint32_t"));
    return 32;
}

fn writeIndent(w: *std.Io.Writer, indent: usize) !void {
    try w.splatByteAll(' ', indent * 4);
}

fn sectionHeader(w: *std.Io.Writer, title: []const u8) !void {
    try w.print("// {s}\n\n", .{title});
}

fn screamingCase(name: []const u8) ScreamingCase {
    return .{ .name = name };
}

fn screamingCaseBuf(name: []const u8, buf: []u8) []const u8 {
    return std.fmt.bufPrint(buf, "{f}", .{screamingCase(name)}) catch unreachable;
}

const ScreamingCase = struct {
    name: []const u8,

    pub fn format(self: ScreamingCase, w: *std.Io.Writer) std.Io.Writer.Error!void {
        for (self.name, 0..) |c, i| {
            if (i != 0 and std.ascii.isUpper(c) and !std.ascii.isUpper(self.name[i - 1])) {
                try w.writeByte('_');
            }
            try w.writeByte(std.ascii.toUpper(c));
        }
    }
};
