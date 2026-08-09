const std = @import("std");
const parse_registry = @import("parse_registry.zig");
const Registry = parse_registry.Registry;

const Writer = std.Io.Writer;
const Error = Writer.Error;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    const cwd: std.Io.Dir = .cwd();

    const input = try std.Io.Dir.readFileAlloc(cwd, io, args[1], arena, .unlimited);
    const registry = try parse_registry.parse(arena, input);

    const file = try cwd.createFile(io, args[2], .{});
    var buf: [1024]u8 = undefined;
    var file_writer = file.writer(io, &buf);
    const w = &file_writer.interface;

    try renderBinding(w, registry);
    try w.flush();
}

fn renderBinding(w: *Writer, registry: Registry) Error!void {
    try w.print(
        \\// Generated file, do not edit.
        \\// version: {s}
        \\
        \\const std = @import("std");
        \\const target = @import("builtin").target;
        \\
        \\pub const @"callconv": std.builtin.CallingConvention = switch (target.os.tag) {{
        \\  .windows => if (target.cpu.arch == .x86) .{{ .x86_stdcall = .{{}} }} else .c,
        \\  else => .c,
        \\}};
        \\
        \\
    , .{registry.version});

    for (registry.constants) |constant| {
        try renderDoc(w, constant.doc);
        try w.writeAll("pub const ");
        try renderConstName(w, registry, constant.name);
        try w.writeAll(": ");
        try renderTypeName(w, registry, constant.type);
        try w.print(" = {s};\n", .{constant.value});
    }
    try w.writeAll("\n");

    for (registry.typedefs) |typedef| {
        try renderDoc(w, typedef.doc);
        try w.writeAll("pub const ");
        try renderTypeName(w, registry, typedef.name);
        try w.writeAll(" = ");
        try renderTypeName(w, registry, typedef.type);
        try w.writeAll(";\n");
    }
    try w.writeAll("\n");

    for (registry.opaques) |@"opaque"| {
        try renderDoc(w, @"opaque".doc);
        try w.writeAll("pub const ");
        try renderTypeName(w, registry, @"opaque".name);
        try w.writeAll(" = opaque {};\n");
    }
    try w.writeAll("\n");

    for (registry.enums) |@"enum"| {
        try renderDoc(w, @"enum".doc);
        try w.writeAll("pub const ");
        try renderTypeName(w, registry, @"enum".name);
        try w.writeAll(" = enum(");
        try renderTypeName(w, registry, @"enum".backing_type);
        try w.writeAll(") {\n");
        for (@"enum".values) |value| {
            try renderDoc(w, value.doc);
            try renderMemberName(w, registry, @"enum".name, value.name);
            try w.print(" = {d},\n", .{value.value});
        }
        try w.writeAll("};\n\n");
    }

    for (registry.flags) |flags| {
        try renderDoc(w, flags.doc);
        try w.writeAll("pub const ");
        try renderTypeName(w, registry, flags.name);
        try w.writeAll(" = packed struct(");
        try renderTypeName(w, registry, flags.backing_type);
        try w.writeAll(") {\n");

        var highest: u16 = 0;
        for (flags.bits) |bit| highest = @max(highest, bit.bit + 1);

        for (0..highest) |slot| {
            const bit = for (flags.bits) |bit| {
                if (bit.bit == slot) break bit;
            } else {
                try w.print("reserved_{d}: bool = false,\n", .{slot});
                continue;
            };
            try renderDoc(w, bit.doc);
            try renderMemberName(w, registry, flags.name, bit.name);
            try w.writeAll(": bool = false,\n");
        }

        const width = bitWidth(flags.backing_type);
        if (highest < width) try w.print("padding: u{d} = 0,\n", .{width - highest});

        for (flags.combinations) |combination| {
            try renderDoc(w, combination.doc);
            try w.writeAll("\npub const ");
            try renderMemberName(w, registry, flags.name, combination.name);
            try w.writeAll(": ");
            try renderTypeName(w, registry, flags.name);
            try w.writeAll(" = .{");
            for (combination.bits) |bit| {
                try w.writeAll(" .");
                try renderMemberName(w, registry, flags.name, bit);
                try w.writeAll(" = true,");
            }
            try w.writeAll(" };\n");
        }

        try w.writeAll("};\n\n");
    }

    for (registry.function_pointers) |function_pointer| {
        try renderDoc(w, function_pointer.doc);
        try w.writeAll("pub const ");
        try renderTypeName(w, registry, function_pointer.name);
        try w.writeAll(" = *const fn (");
        try renderParams(w, registry, function_pointer.params);
        try w.writeAll(") callconv(@\"callconv\") ");
        try renderType(w, registry, function_pointer.@"return");
        try w.writeAll(";\n");
    }
    try w.writeAll("\n");

    for (registry.structs) |@"struct"| {
        try renderDoc(w, @"struct".doc);
        try w.writeAll("pub const ");
        try renderTypeName(w, registry, @"struct".name);
        try w.writeAll(" = extern struct {\n");
        for (@"struct".fields) |field| {
            try renderDoc(w, field.doc);
            try renderId(w, field.name);
            try w.writeAll(": ");
            try renderType(w, registry, field.type);
            if (field.default) |default| {
                try w.writeAll(" = ");
                try renderDefault(w, registry, field.type, default);
            }
            try w.writeAll(",\n");
        }
        try w.writeAll("};\n\n");
    }

    for (registry.functions) |function| {
        try renderDoc(w, function.doc);
        try w.print("extern fn {s}(", .{function.name});
        try renderParams(w, registry, function.params);
        try w.writeAll(") callconv(@\"callconv\") ");
        try renderType(w, registry, function.@"return");
        try w.writeAll(";\n");

        try w.writeAll("pub const ");
        try renderFnName(w, registry, function.name);
        try w.print(" = {s};\n\n", .{function.name});
    }
}

fn renderParams(w: *Writer, registry: Registry, params: []const Registry.Param) Error!void {
    for (params, 0..) |param, i| {
        if (i != 0) try w.writeAll(", ");
        try renderId(w, param.name);
        try w.writeAll(": ");
        try renderType(w, registry, param.type);
    }
}

fn renderType(w: *Writer, registry: Registry, @"type": Registry.Type) Error!void {
    if (@"type".array) |array| switch (array) {
        .int => |n| try w.print("[{d}]", .{n}),
        .constant => |c| {
            try w.writeByte('[');
            try renderConstName(w, registry, c);
            try w.writeByte(']');
        },
    };

    var i = @"type".ptr.len;
    while (i > 0) {
        i -= 1;
        const ptr = @"type".ptr[i];
        if (ptr.optional) try w.writeByte('?');
        if (ptr.len) |len| {
            try w.writeAll(if (std.mem.eql(u8, len, "null_terminated")) "[*:0]" else "[*]");
        } else {
            try w.writeByte('*');
        }
        if (ptr.@"const") try w.writeAll("const ");
    }

    if (@"type".ptr.len != 0 and std.mem.eql(u8, @"type".base, "void")) {
        try w.writeAll("anyopaque");
    } else {
        try renderTypeName(w, registry, @"type".base);
    }
}

fn renderDefault(w: *Writer, registry: Registry, @"type": Registry.Type, value: []const u8) Error!void {
    if (@"type".array != null) {
        var element = @"type";
        element.array = null;

        if (value[0] != '{') {
            try w.writeAll("@splat(");
            try renderDefault(w, registry, element, value);
            try w.writeAll(")");
            return;
        }

        try w.writeAll(".{");
        var it = std.mem.splitScalar(u8, value[1 .. value.len - 1], ',');
        while (it.next()) |item| {
            try renderDefault(w, registry, element, std.mem.trim(u8, item, " \t"));
            try w.writeAll(",");
        }
        try w.writeAll("}");
        return;
    }

    if (@"type".ptr.len != 0) return w.writeAll("null");

    for (registry.enums) |@"enum"| {
        if (!std.mem.eql(u8, @"enum".name, @"type".base)) continue;
        try w.writeByte('.');
        return renderMemberName(w, registry, @"enum".name, value);
    }

    for (registry.flags) |flags| {
        if (!std.mem.eql(u8, flags.name, @"type".base)) continue;
        if (std.mem.eql(u8, value, "0")) return w.writeAll(".{}");

        for (flags.combinations) |combination| {
            if (!std.mem.eql(u8, combination.name, value)) continue;
            try w.writeByte('.');
            return renderMemberName(w, registry, flags.name, combination.name);
        }

        try w.writeAll(".{");
        var it = std.mem.splitScalar(u8, value, '|');
        while (it.next()) |bit| {
            try w.writeAll(" .");
            try renderMemberName(w, registry, flags.name, std.mem.trim(u8, bit, " \t"));
            try w.writeAll(" = true,");
        }
        return w.writeAll(" }");
    }

    if (std.mem.startsWith(u8, value, registry.enum_prefix)) return renderConstName(w, registry, value);

    try w.writeAll(value);
}

fn renderDoc(w: *Writer, doc: []const u8) Error!void {
    const trimmed = std.mem.trim(u8, doc, " \t\r\n");
    if (trimmed.len == 0) return;

    var it = std.mem.splitScalar(u8, trimmed, '\n');
    while (it.next()) |line| try w.print("/// {s}\n", .{std.mem.trim(u8, line, " \t\r")});
}

fn renderTypeName(w: *Writer, registry: Registry, name: []const u8) Error!void {
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

fn renderFnName(w: *Writer, registry: Registry, name: []const u8) Error!void {
    const stripped = stripPrefix(name, registry.fn_prefix);
    try w.writeByte(std.ascii.toLower(stripped[0]));
    try renderId(w, stripped[1..]);
}

fn renderConstName(w: *Writer, registry: Registry, name: []const u8) Error!void {
    try renderLowerIdent(w, stripPrefix(name, registry.enum_prefix));
}

fn renderMemberName(w: *Writer, registry: Registry, owner: []const u8, name: []const u8) Error!void {
    var buf: [256]u8 = undefined;
    const screaming = screamingCase(owner, &buf);

    var rest = if (std.mem.startsWith(u8, name, screaming))
        name[screaming.len..]
    else
        stripPrefix(name, registry.enum_prefix);

    rest = std.mem.trimStart(u8, rest, "_");
    if (std.mem.endsWith(u8, rest, "_BIT")) rest = rest[0 .. rest.len - 4];

    try renderLowerIdent(w, rest);
}

fn renderLowerIdent(w: *Writer, name: []const u8) Error!void {
    var buf: [256]u8 = undefined;
    try renderId(w, std.ascii.lowerString(buf[0..name.len], name));
}

fn renderId(w: *Writer, name: []const u8) Error!void {
    if (std.zig.isValidId(name)) return w.writeAll(name);
    try w.print("@\"{s}\"", .{name});
}

fn stripPrefix(name: []const u8, prefix: []const u8) []const u8 {
    if (std.mem.startsWith(u8, name, prefix)) return name[prefix.len..];
    return name;
}

fn screamingCase(name: []const u8, buf: []u8) []const u8 {
    var len: usize = 0;
    for (name, 0..) |c, i| {
        if (i != 0 and std.ascii.isUpper(c) and !std.ascii.isUpper(name[i - 1])) {
            buf[len] = '_';
            len += 1;
        }
        buf[len] = std.ascii.toUpper(c);
        len += 1;
    }
    return buf[0..len];
}

fn bitWidth(backing_type: []const u8) u16 {
    if (std.mem.eql(u8, backing_type, "uint8_t")) return 8;
    if (std.mem.eql(u8, backing_type, "uint16_t")) return 16;
    if (std.mem.eql(u8, backing_type, "uint64_t")) return 64;
    return 32;
}
