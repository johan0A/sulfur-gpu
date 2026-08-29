const std = @import("std");
const Registry = @import("registry.zig").Registry;

const Command = enum {
    bindings,
    driver_symbol_map,
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    const cwd: std.Io.Dir = .cwd();

    const command_string = args[1];
    const command = std.meta.stringToEnum(Command, command_string[2..]) orelse return error.InvalidCommand;

    const registry_sub_path = args[2];
    const output_sub_path = args[3];

    const input = try std.Io.Dir.readFileAlloc(cwd, io, registry_sub_path, arena, .unlimited);
    const registry = try Registry.parse(arena, input);

    var writer_impl: std.Io.Writer.Allocating = .init(arena);
    switch (command) {
        .bindings => try renderBinding(&writer_impl.writer, registry),
        .driver_symbol_map => try renderSymbolMap(&writer_impl.writer, registry),
    }
    try writer_impl.writer.flush();

    const file = try cwd.createFile(io, output_sub_path, .{});
    var buf: [1024]u8 = undefined;
    var file_writer = file.writer(io, &buf);

    const source = try writer_impl.toOwnedSliceSentinel(0);
    const ast: std.zig.Ast = try .parse(arena, source, .zig);
    try ast.render(arena, &file_writer.interface, .{});
    try file_writer.flush();
}

fn renderSymbolMap(w: *std.Io.Writer, registry: Registry) !void {
    try w.print(
        \\// Generated file, do not edit.
        \\// version: {s}
        \\
        \\const std = @import("std");
        \\const sf = @import("sf_bindings.zig");
        \\
        \\
    , .{registry.version});

    try w.writeAll("const HandleTypes = struct {");
    for (registry.opaques) |@"opaque"| {
        try renderTypeName(w, registry, @"opaque".name);
        try w.writeAll(": type,");
    }
    try w.writeAll("};\n\n");

    try w.writeAll("fn Functions(handle_types: HandleTypes) type { return struct {");
    for (registry.functions) |function| {
        if (function.dispatch != .table) continue;
        try renderFnName(w, registry, function.name);
        try w.writeAll(": *const fn (");
        for (function.params, 0..) |param, i| {
            if (i != 0) try w.writeAll(", ");
            try renderId(w, param.name);
            try w.writeAll(": ");
            const prefix = if (param.type.base != .@"opaque") "sf." else "handle_types.";
            try renderTypePrefix(w, registry, param.type, prefix);
        }
        try w.writeAll(") callconv(sf.@\"callconv\") ");
        const prefix = if (function.return_type.base != .@"opaque") "sf." else "handle_types.";
        try renderTypePrefix(w, registry, function.return_type, prefix);
        try w.writeAll(",");
    }
    try w.writeAll("};}\n\n");

    try w.writeAll(
        \\pub fn map(
        \\    comptime handle_types: HandleTypes,
        \\    comptime functions: Functions(handle_types),
        \\) std.StaticStringMap(*const anyopaque) {
        \\    return .initComptime(@as([]const struct { []const u8, *const anyopaque }, &.{
    );
    for (registry.functions) |function| {
        if (function.dispatch != .table) continue;
        try w.writeAll(".{ \"");
        try w.writeAll(function.name);
        try w.writeAll("\", @ptrCast(functions.");
        try renderFnName(w, registry, function.name);
        try w.writeAll(") },");
    }
    try w.writeAll("}));}\n");
}

fn renderBinding(w: *std.Io.Writer, registry: Registry) !void {
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
        try renderTypeBase(w, registry, constant.type);
        try w.print(" = {s};\n", .{constant.value});
    }
    try w.writeAll("\n");

    for (registry.typedefs) |typedef| {
        try renderDeclStart(w, registry, typedef.doc, typedef.name);
        try renderType(w, registry, typedef.type);
        try w.writeAll(";\n");
    }
    try w.writeAll("\n");

    for (registry.opaques) |@"opaque"| {
        try renderDeclStart(w, registry, @"opaque".doc, @"opaque".name);
        try w.writeAll("opaque {};\n");
    }
    try w.writeAll("\n");

    for (registry.enums) |@"enum"| {
        try renderDeclStart(w, registry, @"enum".doc, @"enum".name);
        try w.writeAll("enum(");
        try renderBuiltinType(w, @"enum".backing);
        try w.writeAll(") {\n");
        for (@"enum".values) |value| {
            try renderDoc(w, value.doc);
            try renderMemberName(w, registry, @"enum".name, value.name);
            try w.print(" = {d},\n", .{value.value});
        }
        try w.writeAll("};\n\n");
    }

    for (registry.flags) |flags| {
        try renderDeclStart(w, registry, flags.doc, flags.name);
        try w.writeAll("packed struct(");
        try renderBuiltinType(w, flags.backing);
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

        const width = try backingBitWidth(flags.backing);
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
                try renderMemberName(w, registry, flags.name, flags.bits[bit].name);
                try w.writeAll(" = true,");
            }
            try w.writeAll(" };\n");
        }

        try w.writeAll("};\n\n");
    }

    for (registry.function_pointers) |function_pointer| {
        try renderDeclStart(w, registry, function_pointer.doc, function_pointer.name);
        try renderFnType(w, registry, function_pointer.params, function_pointer.return_type);
        try w.writeAll(";\n");
    }
    try w.writeAll("\n");

    for (registry.structs) |@"struct"| {
        try renderDeclStart(w, registry, @"struct".doc, @"struct".name);
        try w.writeAll("extern struct {\n");
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

    try w.writeAll(
        \\const internal = struct {
        \\inline fn table(handle: *const anyopaque) [*]const *const anyopaque {
        \\    return @as(*const [*]const *const anyopaque, @ptrCast(@alignCast(handle))).*;
        \\}
        \\
        \\
    );

    for (registry.functions) |function| {
        if (function.dispatch != .symbol) continue;
        try w.writeAll("var ");
        try renderSnakeName(w, registry, function.name);
        try w.writeAll(": ?");
        try renderFnType(w, registry, function.params, function.return_type);
        try w.writeAll(" = null;\n");
    }
    try w.writeAll("\n");

    try w.writeAll("var slots: struct {\n");
    for (registry.functions) |function| {
        if (function.dispatch != .table) continue;
        try renderSnakeName(w, registry, function.name);
        try w.writeAll(": usize = 0,\n");
    }
    try w.writeAll("} = .{};\n\n");

    try w.writeAll("fn loadGlobals(getSymbol: ");
    try renderTypeName(w, registry, registry.declName(registry.symbol));
    try w.writeAll(") void {\n");
    for (registry.functions) |function| {
        if (function.dispatch != .symbol) continue;
        try renderSnakeName(w, registry, function.name);
        try w.print(" = @ptrCast(getSymbol(\"{s}\"));\n", .{function.name});
    }
    try w.writeAll("}\n\n");

    try w.writeAll("fn loadSlots(instance: *Instance) void {\n");
    for (registry.functions) |function| {
        if (function.dispatch != .table) continue;
        try w.writeAll("slots.");
        try renderSnakeName(w, registry, function.name);
        try w.writeAll(" = ");
        try renderSnakeName(w, registry, registry.function(registry.get_slot).name);
        try w.print(".?(instance, \"{s}\");\n", .{function.name});
    }
    try w.writeAll("}\n};\n\n");

    for (registry.functions) |function| {
        if (std.mem.eql(u8, function.name, registry.function(registry.get_slot).name)) continue;
        try renderDoc(w, function.doc);

        const is_create_instance = std.mem.eql(u8, function.name, registry.function(registry.create_instance).name);

        try w.writeAll("pub fn ");
        try renderFnName(w, registry, function.name);
        try w.writeByte('(');
        try renderParams(w, registry, function.params);
        if (is_create_instance) {
            if (function.params.len != 0) try w.writeAll(", ");
            try w.writeAll("getSymbol: ");
            try renderTypeName(w, registry, registry.declName(registry.symbol));
        }
        try w.writeAll(") ");
        try renderType(w, registry, function.return_type);
        try w.writeAll(" {\n");

        if (is_create_instance) try w.writeAll("internal.loadGlobals(getSymbol);\n");

        switch (function.dispatch) {
            .symbol => {
                try w.writeAll("const f = internal.");
                try renderSnakeName(w, registry, function.name);
                try w.writeAll(".?;\n");
            },
            .table => {
                try w.writeAll("const f: ");
                try renderFnType(w, registry, function.params, function.return_type);
                try w.writeAll(" = @ptrCast(internal.table(");
                try renderId(w, function.params[0].name);
                try w.writeAll(")[internal.slots.");
                try renderSnakeName(w, registry, function.name);
                try w.writeAll("]);\n");
            },
        }

        if (is_create_instance) {
            try w.writeAll("const instance = f(");
            try renderArgs(w, function.params);
            try w.writeAll(");\ninternal.loadSlots(instance);\nreturn instance;\n");
        } else {
            try w.writeAll("return f(");
            try renderArgs(w, function.params);
            try w.writeAll(");\n");
        }

        try w.writeAll("}\n\n");
    }
}

fn renderDeclStart(w: *std.Io.Writer, registry: Registry, doc: []const u8, name: []const u8) !void {
    try renderDoc(w, doc);
    try w.writeAll("pub const ");
    try renderTypeName(w, registry, name);
    try w.writeAll(" = ");
}

fn renderParams(w: *std.Io.Writer, registry: Registry, params: []const Registry.Param) !void {
    for (params, 0..) |param, i| {
        if (i != 0) try w.writeAll(", ");
        try renderId(w, param.name);
        try w.writeAll(": ");
        try renderType(w, registry, param.type);
    }
}

fn renderArgs(w: *std.Io.Writer, params: []const Registry.Param) !void {
    for (params, 0..) |param, i| {
        if (i != 0) try w.writeAll(", ");
        try renderId(w, param.name);
    }
}

fn renderType(w: *std.Io.Writer, registry: Registry, @"type": Registry.Type) !void {
    try renderTypePrefix(w, registry, @"type", "");
}

fn renderTypePrefix(w: *std.Io.Writer, registry: Registry, @"type": Registry.Type, prefix: []const u8) !void {
    if (@"type".array) |array| switch (array) {
        .int => |n| try w.print("[{d}]", .{n}),
        .constant => |c| {
            try w.writeByte('[');
            try renderConstName(w, registry, registry.constant(c).name);
            try w.writeByte(']');
        },
    };

    var i = @"type".ptrs.len;
    while (i > 0) {
        i -= 1;
        const ptr = @"type".ptrs[i];
        if (ptr.optional) try w.writeByte('?');
        try w.writeAll(switch (ptr.size) {
            .null_terminated => "[*:0]",
            .many, .sized_by_arg => "[*]",
            .one => "*",
        });
        if (ptr.@"const") try w.writeAll("const ");
    }

    if (@"type".base != .builtin) try w.writeAll(prefix);

    if (@"type".ptrs.len != 0 and @"type".base == .builtin and @"type".base.builtin == .void) {
        try w.writeAll("anyopaque");
    } else {
        try renderTypeBase(w, registry, @"type".base);
    }
}

fn renderFnType(w: *std.Io.Writer, registry: Registry, params: []const Registry.Param, return_type: Registry.Type) !void {
    try w.writeAll("*const fn (");
    try renderParams(w, registry, params);
    try w.writeAll(") callconv(@\"callconv\") ");
    try renderType(w, registry, return_type);
}

fn renderDefault(w: *std.Io.Writer, registry: Registry, @"type": Registry.Type, value: Registry.Default) !void {
    switch (value) {
        .enum_value => |enum_value| {
            try w.writeByte('.');
            const @"enum" = registry.@"enum"(enum_value.@"enum");
            const name = @"enum".values[enum_value.value].name;
            try renderMemberName(w, registry, @"enum".name, name);
        },
        .raw => |raw| {
            if (@"type".ptrs.len != 0) return w.writeAll("null");

            if (@"type".array != null) {
                var element = @"type";
                element.array = null;

                if (raw[0] != '{') {
                    try w.writeAll("@splat(");
                    try renderDefault(w, registry, element, value);
                    try w.writeAll(")");
                    return;
                }

                return error.UnsupportedRegistry;
            }

            for (registry.flags) |flags| {
                if (!std.mem.eql(u8, flags.name, registry.declName(@"type".base))) continue;
                if (std.mem.eql(u8, raw, "0")) return w.writeAll(".{}");

                for (flags.combinations) |combination| {
                    if (!std.mem.eql(u8, combination.name, raw)) continue;
                    try w.writeByte('.');
                    return renderMemberName(w, registry, flags.name, combination.name);
                }

                try w.writeAll(".{");
                var it = std.mem.splitScalar(u8, raw, '|');
                while (it.next()) |bit| {
                    try w.writeAll(" .");
                    try renderMemberName(w, registry, flags.name, std.mem.trim(u8, bit, " \t"));
                    try w.writeAll(" = true,");
                }
                return w.writeAll(" }");
            }

            if (std.mem.startsWith(u8, raw, registry.enum_prefix)) return renderConstName(w, registry, raw);

            try w.writeAll(raw);
        },
    }
}

fn renderDoc(w: *std.Io.Writer, doc: []const u8) !void {
    const trimmed = std.mem.trim(u8, doc, " \t\r\n");
    if (trimmed.len == 0) return;

    var it = std.mem.splitScalar(u8, trimmed, '\n');
    while (it.next()) |line| try w.print("/// {s}\n", .{std.mem.trim(u8, line, " \t\r")});
}

fn renderTypeBase(w: *std.Io.Writer, registry: Registry, type_ref: Registry.TypeBase) !void {
    switch (type_ref) {
        .builtin => |builtin| try renderBuiltinType(w, builtin),
        else => try renderTypeName(w, registry, registry.declName(type_ref)),
    }
}

fn renderBuiltinType(w: *std.Io.Writer, builtin: Registry.Builtin) !void {
    try w.writeAll(switch (builtin) {
        .void => "void",
        .bool => "bool",
        .char => "u8",
        .float => "f32",
        .double => "f64",
        .size_t => "usize",
        .int8_t => "i8",
        .uint8_t => "u8",
        .int16_t => "i16",
        .uint16_t => "u16",
        .int32_t => "i32",
        .uint32_t => "u32",
        .int64_t => "i64",
        .uint64_t => "u64",
    });
}

fn renderTypeName(w: *std.Io.Writer, registry: Registry, type_name: []const u8) !void {
    try w.writeAll(stripPrefix(type_name, registry.type_prefix));
}

fn renderFnName(w: *std.Io.Writer, registry: Registry, name: []const u8) !void {
    const stripped = stripPrefix(name, registry.fn_prefix);
    try w.writeByte(std.ascii.toLower(stripped[0]));
    try renderId(w, stripped[1..]);
}

fn renderSnakeName(w: *std.Io.Writer, registry: Registry, name: []const u8) !void {
    var buf: [256]u8 = undefined;
    const screaming = screamingCase(stripPrefix(name, registry.fn_prefix), &buf);
    try renderLowerIdent(w, screaming);
}

fn renderConstName(w: *std.Io.Writer, registry: Registry, name: []const u8) !void {
    try renderLowerIdent(w, stripPrefix(name, registry.enum_prefix));
}

fn renderMemberName(w: *std.Io.Writer, registry: Registry, owner: []const u8, name: []const u8) !void {
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

fn renderLowerIdent(w: *std.Io.Writer, name: []const u8) !void {
    var buf: [256]u8 = undefined;
    try renderId(w, std.ascii.lowerString(buf[0..name.len], name));
}

fn renderId(w: *std.Io.Writer, name: []const u8) !void {
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

fn backingBitWidth(backing: Registry.Builtin) !u16 {
    return switch (backing) {
        .uint8_t, .int8_t => 8,
        .uint16_t, .int16_t => 16,
        .uint32_t, .int32_t => 32,
        .uint64_t, .int64_t => 64,
        else => error.UnsupportedRegistry,
    };
}
