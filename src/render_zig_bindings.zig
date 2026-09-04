const std = @import("std");
const Registry = @import("registry.zig").Registry;

const Command = enum {
    bindings_minimal,
    bindings,
    driver_symbol_map,
    loader_symbol_map,
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    const cwd: std.Io.Dir = .cwd();

    const command = std.meta.stringToEnum(Command, stripPrefix(args[1], "--")) orelse return error.InvalidCommand;
    const registry_path = args[2];
    const output_path = args[3];

    const registry_source = try cwd.readFileAlloc(io, registry_path, arena, .unlimited);
    const registry = try Registry.parse(arena, registry_source);

    var output: std.Io.Writer.Allocating = .init(arena);
    const w = &output.writer;
    switch (command) {
        .bindings_minimal => try renderBindings(w, arena, registry, .minimal),
        .bindings => try renderBindings(w, arena, registry, .normal),
        .driver_symbol_map => try renderSymbolMap(w, arena, registry, .table),
        .loader_symbol_map => try renderSymbolMap(w, arena, registry, .symbol),
    }
    try w.flush();

    const file = try cwd.createFile(io, output_path, .{});
    var buf: [1024]u8 = undefined;
    var file_writer = file.writer(io, &buf);

    const source = try output.toOwnedSliceSentinel(0);
    const ast: std.zig.Ast = try .parse(arena, source, .zig);
    try ast.render(arena, &file_writer.interface, .{});
    try file_writer.flush();
}

fn renderHeader(w: *std.Io.Writer, registry: Registry) !void {
    try w.print(
        \\// Generated file, do not edit.
        \\// version: {s}
    ++ "\n\n", .{registry.version});
}

const BindingStyle = enum {
    minimal,
    normal,
};

fn renderBindings(
    w: *std.Io.Writer,
    arena: std.mem.Allocator,
    registry: Registry,
    style: BindingStyle,
) !void {
    try renderHeader(w, registry);
    try w.writeAll(
        \\const std = @import("std");
        \\const target = @import("builtin").target;
        \\
        \\pub const @"callconv": std.builtin.CallingConvention = switch (target.os.tag) {
        \\    .windows => if (target.cpu.arch == .x86) .{ .x86_stdcall = .{} } else .c,
        \\    else => .c,
        \\};
    ++ "\n\n");

    for (registry.constants) |constant| {
        try renderDoc(w, constant.doc);
        try w.writeAll("pub const ");
        try renderConstName(w, registry, constant.name);
        try w.writeAll(": ");
        try renderType(w, registry, constant.type);
        try w.print(" = {s};\n", .{constant.value});
    }
    try w.writeByte('\n');
    for (registry.typedefs) |typedef| {
        try renderDeclStart(w, registry, typedef.doc, typedef.name);
        try renderType(w, registry, typedef.type);
        try w.writeAll(";\n");
    }
    try w.writeByte('\n');

    for (registry.opaques, 0..) |@"opaque", index| {
        try renderDeclStart(w, registry, @"opaque".doc, @"opaque".name);
        try w.writeAll("opaque {\n");
        if (style == .normal) {
            const type_name = stripPrefix(@"opaque".name, registry.type_prefix);

            for (registry.functions) |function| {
                if (function.role == .get_slot) continue;

                const is_create = std.mem.startsWith(u8, stripPrefix(function.name, registry.fn_prefix), "Create");
                const produces_handle = blk: {
                    if (isHandle(function.return_type, index)) break :blk true;
                    for (function.params) |param| {
                        if (param.out and isHandle(param.type, index)) break :blk true;
                    }
                    break :blk false;
                };

                const creates_handle = is_create and produces_handle;
                const takes_handle_first = function.params.len != 0 and isHandle(function.params[0].type, index);

                if (!creates_handle and !takes_handle_first) continue;
                if (creates_handle and takes_handle_first) continue;

                const method_c_name = try std.mem.replaceOwned(u8, arena, function.name, type_name, "");

                try renderFunction(w, registry, function, method_c_name, .normal);
                if (function.enumerate) try renderEnumerateAlloc(w, registry, function, method_c_name);
            }
        }
        try w.writeAll("};\n");
        if (style != .minimal) try w.writeByte('\n');
    }
    try w.writeByte('\n');

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
    for (registry.flags) |flags| try renderFlags(w, registry, flags);
    for (registry.function_pointers) |function_pointer| {
        try renderDeclStart(w, registry, function_pointer.doc, function_pointer.name);
        try renderFnType(w, registry, function_pointer.params, function_pointer.return_type);
        try w.writeAll(";\n\n");
    }
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

    if (style == .minimal) {
        for (registry.functions) |function| {
            if (function.role == .get_slot) continue;
            try renderFunction(w, registry, function, function.name, .minimal);
        }
    }

    try renderInternal(w, registry);
}

fn isHandle(@"type": Registry.Type, opaque_index: usize) bool {
    return @"type".base == .@"opaque" and opaque_index == @intFromEnum(@"type".base.@"opaque");
}

fn renderEnumerateAlloc(
    w: *std.Io.Writer,
    registry: Registry,
    function: Registry.Function,
    c_name: []const u8,
) !void {
    const out_param_index = try outParamIndex(function) orelse return error.UnsupportedRegistry;
    const count_param = function.params[out_param_index];

    var buffer_index: ?usize = null;
    for (function.params, 0..) |_, param_index| {
        if (paramRole(function, param_index, out_param_index) != .slice) continue;
        if (buffer_index != null) return error.UnsupportedRegistry;
        buffer_index = param_index;
    }
    const buffer_param = function.params[buffer_index orelse return error.UnsupportedRegistry];
    if (!buffer_param.out or buffer_param.type.ptrs[buffer_param.type.ptrs.len - 1].@"const") return error.UnsupportedRegistry;

    var name_buffer: [256]u8 = undefined;
    const alloc_c_name = try std.fmt.bufPrint(&name_buffer, "{s}Alloc", .{c_name});

    try w.writeAll("pub fn ");
    try renderFnName(w, registry, alloc_c_name);
    try w.writeByte('(');
    for (function.params, 0..) |param, param_index| {
        if (paramRole(function, param_index, out_param_index) != .plain) continue;
        try renderId(w, param.name);
        try w.writeAll(": ");
        try renderType(w, registry, param.type);
        try w.writeAll(", ");
    }
    try w.writeAll("gpa: std.mem.Allocator,) error{ OutOfMemory, ");
    for (function.errors) |@"error"| {
        try renderErrorName(w, registry, @"error");
        try w.writeAll(", ");
    }
    try w.writeAll("}![]");
    try renderSliceElementType(w, registry, buffer_param.type);
    try w.writeAll(" {\n");

    try w.writeAll("var ");
    try renderId(w, buffer_param.name);
    try w.writeAll(": []");
    try renderSliceElementType(w, registry, buffer_param.type);
    try w.writeAll(" = &.{};\nerrdefer gpa.free(");
    try renderId(w, buffer_param.name);
    try w.writeAll(");\nwhile (true) {\nconst ");
    try renderId(w, count_param.name);
    try w.writeAll(" = ");
    if (function.errors.len != 0) try w.writeAll("try ");
    try renderFnName(w, registry, c_name);
    try w.writeByte('(');
    for (function.params, 0..) |param, param_index| {
        switch (paramRole(function, param_index, out_param_index)) {
            .plain, .slice => try renderId(w, param.name),
            .returned, .slice_length => continue,
        }
        try w.writeAll(", ");
    }
    try w.writeAll(");\nif (");
    try renderId(w, count_param.name);
    try w.writeAll(" <= ");
    try renderId(w, buffer_param.name);
    try w.writeAll(".len) return gpa.realloc(");
    try renderId(w, buffer_param.name);
    try w.writeAll(", ");
    try renderId(w, count_param.name);
    try w.writeAll(");\n");
    try renderId(w, buffer_param.name);
    try w.writeAll(" = try gpa.realloc(");
    try renderId(w, buffer_param.name);
    try w.writeAll(", ");
    try renderId(w, count_param.name);
    try w.writeAll(");\n}\n}\n\n");
}

fn renderFunction(
    w: *std.Io.Writer,
    registry: Registry,
    function: Registry.Function,
    c_name: []const u8,
    style: BindingStyle,
) !void {
    const normal = style == .normal;
    const is_create_instance = function.role == .create_instance;
    const returns_error = normal and function.errors.len != 0;
    const out_param_index = if (normal) try outParamIndex(function) else null;

    try renderDoc(w, function.doc);
    try w.writeAll("pub fn ");
    try renderFnName(w, registry, c_name);
    try w.writeByte('(');
    for (function.params, 0..) |param, param_index| {
        const role: ParamRole = if (normal) paramRole(function, param_index, out_param_index) else .plain;
        switch (role) {
            .returned, .slice_length => continue,
            .plain => {
                try renderId(w, param.name);
                try w.writeAll(": ");
                try renderType(w, registry, param.type);
            },
            .slice => {
                try renderId(w, param.name);
                try w.writeAll(": ");
                try renderSliceType(w, registry, param.type);
            },
        }
        try w.writeAll(", ");
    }
    if (is_create_instance) {
        try w.writeAll("getSymbol: ");
        try renderType(w, registry, registry.get_symbol_type);
        try w.writeAll(", ");
    }
    try w.writeAll(") ");

    if (returns_error) {
        try renderErrorSet(w, registry, function.errors);
        try w.writeByte('!');
    }
    if (out_param_index) |index| {
        try renderType(w, registry, pointee(function.params[index].type));
    } else if (returns_error) {
        try w.writeAll("void");
    } else {
        try renderType(w, registry, function.return_type);
    }
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

    if (out_param_index) |index| {
        const param = function.params[index];
        try w.writeAll("var ");
        try renderId(w, param.name);
        try w.writeAll(": ");
        try renderType(w, registry, pointee(param.type));
        try w.writeAll(" = undefined;\n");
    }

    if (normal) for (function.params, 0..) |param, param_index| {
        const length_index = sliceLengthIndex(function, param) orelse continue;
        const first_slice_index = sliceIndexForLength(function, length_index).?;
        if (first_slice_index == param_index) continue;
        try w.writeAll("std.debug.assert(");
        try renderSliceField(w, function.params[first_slice_index], .len);
        try w.writeAll(" == ");
        try renderSliceField(w, param, .len);
        try w.writeAll(");\n");
    };

    if (is_create_instance) {
        try w.writeAll("const instance = ");
    } else if (returns_error) {
        try w.writeAll("const result = ");
    } else if (out_param_index == null) {
        try w.writeAll("return ");
    }
    try w.writeAll("f(");
    for (function.params, 0..) |param, param_index| {
        const role: ParamRole = if (normal) paramRole(function, param_index, out_param_index) else .plain;
        switch (role) {
            .plain => try renderId(w, param.name),
            .returned => {
                try w.writeByte('&');
                try renderId(w, param.name);
            },
            .slice => try renderSliceField(w, param, .ptr),
            .slice_length => |slice_index| {
                try w.writeAll("@intCast(");
                try renderSliceField(w, function.params[slice_index], .len);
                try w.writeByte(')');
            },
        }
        try w.writeAll(", ");
    }
    try w.writeAll(");\n");

    if (is_create_instance) try w.writeAll("internal.loadSlots(instance);\nreturn instance;\n");
    if (returns_error) {
        const result_enum = registry.resultEnum();

        try w.writeAll("switch (result) {\n.");
        try renderMemberName(w, registry, result_enum.name, resultOk(registry).name);
        try w.writeAll(" => {},\n");
        for (function.errors) |@"error"| {
            try w.writeByte('.');
            try renderMemberName(w, registry, result_enum.name, @"error".name);
            try w.writeAll(" => return error.");
            try renderErrorName(w, registry, @"error");
            try w.writeAll(",\n");
        }
        if (function.errors.len != resultErrors(registry).len) try w.writeAll("else => unreachable,\n");
        try w.writeAll("}\n");
    }
    if (out_param_index) |index| {
        try w.writeAll("return ");
        try renderId(w, function.params[index].name);
        try w.writeAll(";\n");
    }
    try w.writeAll("}\n\n");
}

const ParamRole = union(enum) {
    plain,
    returned,
    slice: usize,
    slice_length: usize,
};

fn paramRole(function: Registry.Function, param_index: usize, out_param_index: ?usize) ParamRole {
    if (param_index == out_param_index) return .returned;
    if (sliceLengthIndex(function, function.params[param_index])) |length_index| return .{ .slice = length_index };
    if (sliceIndexForLength(function, param_index)) |slice_index| return .{ .slice_length = slice_index };
    return .plain;
}

fn sliceLengthIndex(function: Registry.Function, param: Registry.Param) ?usize {
    if (param.type.ptrs.len == 0) return null;
    const outermost = param.type.ptrs[param.type.ptrs.len - 1];
    if (outermost.size != .sized_by_arg) return null;

    const length_param = function.params[outermost.size.sized_by_arg];
    if (length_param.type.ptrs.len != 0 or length_param.type.array != null) return null;
    return outermost.size.sized_by_arg;
}

fn sliceIndexForLength(function: Registry.Function, length_index: usize) ?usize {
    for (function.params, 0..) |param, param_index| {
        if (sliceLengthIndex(function, param) == length_index) return param_index;
    }
    return null;
}

fn renderSliceField(w: *std.Io.Writer, param: Registry.Param, field: enum { ptr, len }) !void {
    const optional = param.type.ptrs[param.type.ptrs.len - 1].optional;
    if (!optional) {
        try renderId(w, param.name);
        try w.print(".{s}", .{@tagName(field)});
        return;
    }

    try w.writeAll("(if (");
    try renderId(w, param.name);
    try w.print(") |unwrapped| unwrapped.{s} else {s})", .{
        @tagName(field),
        switch (field) {
            .ptr => "null",
            .len => "0",
        },
    });
}

fn renderSliceType(w: *std.Io.Writer, registry: Registry, @"type": Registry.Type) !void {
    const outermost = @"type".ptrs[@"type".ptrs.len - 1];
    if (outermost.optional) try w.writeByte('?');
    try w.writeAll("[]");
    if (outermost.@"const") try w.writeAll("const ");
    try renderSliceElementType(w, registry, @"type");
}

fn renderSliceElementType(w: *std.Io.Writer, registry: Registry, @"type": Registry.Type) !void {
    const element = pointee(@"type");
    const is_untyped = element.ptrs.len == 0 and element.base == .builtin and element.base.builtin == .void;
    if (is_untyped) return w.writeAll("u8");
    try renderType(w, registry, element);
}

fn pointee(@"type": Registry.Type) Registry.Type {
    var result = @"type";
    result.ptrs = result.ptrs[0 .. result.ptrs.len - 1];
    return result;
}

fn renderErrorSet(
    w: *std.Io.Writer,
    registry: Registry,
    errors: []const Registry.Enum.Value,
) !void {
    try w.writeAll("error{");
    for (errors) |@"error"| {
        try renderErrorName(w, registry, @"error");
        try w.writeAll(", ");
    }
    try w.writeByte('}');
}

fn resultOk(registry: Registry) Registry.Enum.Value {
    return registry.resultEnum().values[0];
}

fn resultErrors(registry: Registry) []const Registry.Enum.Value {
    return registry.resultEnum().values[1..];
}

fn functionWithRole(registry: Registry, role: Registry.Function.Role) Registry.Function {
    for (registry.functions) |function| {
        if (function.role == role) return function;
    }
    unreachable;
}

fn outParamIndex(function: Registry.Function) !?usize {
    var found: ?usize = null;
    for (function.params, 0..) |param, index| {
        if (!param.out or param.type.ptrs.len == 0) continue;
        if (param.type.ptrs[param.type.ptrs.len - 1].size != .one) continue;
        if (found != null) return error.UnsupportedRegistry;
        found = index;
    }
    return found;
}

fn renderInternal(w: *std.Io.Writer, registry: Registry) !void {
    try w.writeAll(
        \\const internal = struct {
        \\    inline fn table(handle: *const anyopaque) [*]const *const anyopaque {
        \\        return @as(*const [*]const *const anyopaque, @ptrCast(@alignCast(handle))).*;
        \\    }
    ++ "\n\n");

    for (registry.functions) |function| {
        if (function.dispatch != .symbol) continue;
        try w.writeAll("var ");
        try renderSnakeName(w, registry, function.name);
        try w.writeAll(": ?");
        try renderFnType(w, registry, function.params, function.return_type);
        try w.writeAll(" = null;\n");
    }

    try w.writeAll("\nvar slots: struct {\n");
    for (registry.functions) |function| {
        if (function.dispatch != .table) continue;
        try renderSnakeName(w, registry, function.name);
        try w.writeAll(": usize = 0,\n");
    }
    try w.writeAll("} = .{};\n\n");

    try w.writeAll("fn loadGlobals(getSymbol: ");
    try renderType(w, registry, registry.get_symbol_type);
    try w.writeAll(") void {\n");
    for (registry.functions) |function| {
        if (function.dispatch != .symbol) continue;
        try renderSnakeName(w, registry, function.name);
        try w.print(" = @ptrCast(getSymbol(\"{s}\"));\n", .{function.name});
    }
    try w.writeAll("}\n\n");

    const create_instance = functionWithRole(registry, .create_instance);
    const get_slot = functionWithRole(registry, .get_slot);

    try w.writeAll("fn loadSlots(instance: ");
    try renderType(w, registry, create_instance.return_type);
    try w.writeAll(") void {\n");
    for (registry.functions) |function| {
        if (function.dispatch != .table) continue;
        try w.writeAll("slots.");
        try renderSnakeName(w, registry, function.name);
        try w.writeAll(" = ");
        try renderSnakeName(w, registry, get_slot.name);
        try w.print(".?(instance, \"{s}\");\n", .{function.name});
    }
    try w.writeAll("}\n};\n");
}

fn renderSymbolMap(
    w: *std.Io.Writer,
    arena: std.mem.Allocator,
    registry: Registry,
    dispatch: Registry.Function.Dispatch,
) !void {
    try renderHeader(w, registry);
    try w.writeAll(
        \\const std = @import("std");
        \\const sf = @import("sf_minimal.zig");
    ++ "\n\n");

    const handle_used = try arena.alloc(bool, registry.opaques.len);
    @memset(handle_used, false);
    for (registry.functions) |function| {
        if (function.dispatch != dispatch) continue;
        markHandle(handle_used, function.return_type);
        for (function.params) |param| markHandle(handle_used, param.type);
    }

    try w.writeAll("const HandleTypes = struct {\n");
    for (registry.opaques, handle_used) |@"opaque", used| {
        if (!used) continue;
        try renderTypeName(w, registry, @"opaque".name);
        try w.writeAll(": type,\n");
    }
    try w.writeAll("};\n\n");

    const qualifier: TypeQualifier = .{ .decl = "sf.", .handle = "handle_types." };

    try w.writeAll("fn Functions(handle_types: HandleTypes) type {\nreturn struct {\n");
    for (registry.functions) |function| {
        if (function.dispatch != dispatch) continue;
        try renderFnName(w, registry, function.name);
        try w.writeAll(": fn (");
        try renderParams(w, registry, function.params, qualifier);
        try w.writeAll(") ");
        if (function.errors.len != 0) {
            try renderErrorSet(w, registry, function.errors);
            try w.writeAll("!void");
        } else {
            try renderQualifiedType(w, registry, function.return_type, qualifier);
        }
        try w.writeAll(",\n");
    }
    try w.writeAll("};\n}\n\n");

    const result_enum = registry.resultEnum();
    try w.writeAll("const Error = ");
    try renderErrorSet(w, registry, resultErrors(registry));
    try w.writeAll(";\n\n");

    try w.writeAll("fn cResult(result: anytype) sf.");
    try renderTypeName(w, registry, result_enum.name);
    try w.writeAll(" {\nif (result) return .");
    try renderMemberName(w, registry, result_enum.name, resultOk(registry).name);
    try w.writeAll(" else |err| return switch (@as(Error, err)) {\n");
    for (resultErrors(registry)) |@"error"| {
        try w.writeAll("error.");
        try renderErrorName(w, registry, @"error");
        try w.writeAll(" => .");
        try renderMemberName(w, registry, result_enum.name, @"error".name);
        try w.writeAll(",\n");
    }
    try w.writeAll("};\n}\n\n");

    try w.writeAll("fn CFunctions(comptime handle_types: HandleTypes, comptime functions: Functions(handle_types)) type {\nreturn struct {\n");
    for (registry.functions) |function| {
        if (function.dispatch != dispatch) continue;
        try w.writeAll("pub fn ");
        try renderFnName(w, registry, function.name);
        try w.writeByte('(');
        try renderParams(w, registry, function.params, qualifier);
        try w.writeAll(") callconv(sf.@\"callconv\") ");
        try renderQualifiedType(w, registry, function.return_type, qualifier);
        try w.writeAll(" {\nreturn ");

        const converts_errors = function.errors.len != 0;
        if (converts_errors) try w.writeAll("cResult(");
        try w.writeAll("functions.");
        try renderFnName(w, registry, function.name);
        try w.writeByte('(');
        for (function.params) |param| {
            try renderId(w, param.name);
            try w.writeAll(", ");
        }
        try w.writeByte(')');
        if (converts_errors) try w.writeByte(')');
        try w.writeAll(";\n}\n\n");
    }
    try w.writeAll("};\n}\n\n");

    try w.writeAll(
        \\pub fn map(
        \\    comptime handle_types: HandleTypes,
        \\    comptime functions: Functions(handle_types),
        \\) std.StaticStringMap(*const anyopaque) {
        \\    const c_functions = CFunctions(handle_types, functions);
        \\    return .initComptime(@as([]const struct { []const u8, *const anyopaque }, &.{
        \\
    );
    for (registry.functions) |function| {
        if (function.dispatch != dispatch) continue;
        try w.print(".{{ \"{s}\", @ptrCast(&c_functions.", .{function.name});
        try renderFnName(w, registry, function.name);
        try w.writeAll(") },\n");
    }
    try w.writeAll("}));\n}\n");
}

fn markHandle(handle_used: []bool, @"type": Registry.Type) void {
    if (@"type".base == .@"opaque") handle_used[@intFromEnum(@"type".base.@"opaque")] = true;
}

fn renderDeclStart(
    w: *std.Io.Writer,
    registry: Registry,
    doc: []const u8,
    name: []const u8,
) !void {
    try renderDoc(w, doc);
    try w.writeAll("pub const ");
    try renderTypeName(w, registry, name);
    try w.writeAll(" = ");
}

fn renderFlags(
    w: *std.Io.Writer,
    registry: Registry,
    flags: Registry.Flags,
) !void {
    try renderDeclStart(w, registry, flags.doc, flags.name);
    try w.writeAll("packed struct(");
    try renderBuiltinType(w, flags.backing);
    try w.writeAll(") {\n");

    var bit_count: u16 = 0;
    for (flags.bits) |bit| bit_count = @max(bit_count, bit.bit + 1);

    for (0..bit_count) |position| {
        const bit = for (flags.bits) |bit| {
            if (bit.bit == position) break bit;
        } else {
            try w.print("reserved_{d}: bool = false,\n", .{position});
            continue;
        };
        try renderDoc(w, bit.doc);
        try renderMemberName(w, registry, flags.name, bit.name);
        try w.writeAll(": bool = false,\n");
    }

    const width: u16 = switch (flags.backing) {
        .uint8_t, .int8_t => 8,
        .uint16_t, .int16_t => 16,
        .uint32_t, .int32_t => 32,
        .uint64_t, .int64_t => 64,
        else => return error.UnsupportedRegistry,
    };
    if (bit_count < width) try w.print("padding: u{d} = 0,\n", .{width - bit_count});

    for (flags.combinations) |combination| {
        try w.writeByte('\n');
        try renderDoc(w, combination.doc);
        try w.writeAll("pub const ");
        try renderMemberName(w, registry, flags.name, combination.name);
        try w.writeAll(": ");
        try renderTypeName(w, registry, flags.name);
        try w.writeAll(" = .{");
        for (combination.bits) |bit_index| {
            try w.writeAll(" .");
            try renderMemberName(w, registry, flags.name, flags.bits[bit_index].name);
            try w.writeAll(" = true,");
        }
        try w.writeAll(" };\n");
    }

    try w.writeAll("};\n\n");
}

fn renderDefault(
    w: *std.Io.Writer,
    registry: Registry,
    @"type": Registry.Type,
    default: Registry.Default,
) !void {
    switch (default) {
        .enum_value => |enum_value| {
            const @"enum" = registry.enums[@intFromEnum(enum_value.@"enum")];
            try w.writeByte('.');
            try renderMemberName(w, registry, @"enum".name, @"enum".values[enum_value.value].name);
        },
        .raw => |raw| {
            if (@"type".ptrs.len != 0) return w.writeAll("null");

            if (@"type".array != null) {
                if (raw[0] == '{') return error.UnsupportedRegistry;
                var element_type = @"type";
                element_type.array = null;
                try w.writeAll("@splat(");
                try renderDefault(w, registry, element_type, default);
                return w.writeAll(")");
            }

            if (@"type".base == .flags) {
                if (std.mem.eql(u8, raw, "0")) return w.writeAll(".{}");

                const flags = registry.flags[@intFromEnum(@"type".base.flags)];
                for (flags.combinations) |combination| {
                    if (!std.mem.eql(u8, combination.name, raw)) continue;
                    try w.writeByte('.');
                    return renderMemberName(w, registry, flags.name, combination.name);
                }

                try w.writeAll(".{");
                var bit_names = std.mem.splitScalar(u8, raw, '|');
                while (bit_names.next()) |bit_name| {
                    try w.writeAll(" .");
                    try renderMemberName(w, registry, flags.name, std.mem.trim(u8, bit_name, " \t"));
                    try w.writeAll(" = true,");
                }
                try w.writeAll(" }");
            }

            if (std.mem.startsWith(u8, raw, registry.enum_prefix)) return renderConstName(w, registry, raw);
            try w.writeAll(raw);
        },
    }
}

fn renderDoc(w: *std.Io.Writer, doc: []const u8) !void {
    const trimmed = std.mem.trim(u8, doc, " \t\r\n");
    if (trimmed.len == 0) return;

    var lines = std.mem.splitScalar(u8, trimmed, '\n');
    while (lines.next()) |line| try w.print("/// {s}\n", .{std.mem.trim(u8, line, " \t\r")});
}

const TypeQualifier = struct {
    decl: []const u8 = "",
    handle: []const u8 = "",
};

fn renderType(w: *std.Io.Writer, registry: Registry, @"type": Registry.Type) !void {
    try renderQualifiedType(w, registry, @"type", .{});
}

fn renderQualifiedType(
    w: *std.Io.Writer,
    registry: Registry,
    @"type": Registry.Type,
    qualifier: TypeQualifier,
) !void {
    if (@"type".array) |array| switch (array) {
        .int => |length| try w.print("[{d}]", .{length}),
        .constant => |constant_index| {
            try w.writeByte('[');
            try renderConstName(w, registry, registry.constants[@intFromEnum(constant_index)].name);
            try w.writeByte(']');
        },
    };

    var index = @"type".ptrs.len;
    while (index > 0) {
        index -= 1;
        const pointer = @"type".ptrs[index];
        if (pointer.optional) try w.writeByte('?');
        try w.writeAll(switch (pointer.size) {
            .one => "*",
            .many, .sized_by_arg => "[*]",
            .null_terminated => "[*:0]",
        });
        if (pointer.@"const") try w.writeAll("const ");
    }

    switch (@"type".base) {
        .builtin => |builtin| {
            if (@"type".ptrs.len != 0 and builtin == .void) return w.writeAll("anyopaque");
            try renderBuiltinType(w, builtin);
        },
        .@"opaque" => {
            try w.writeAll(qualifier.handle);
            try renderTypeName(w, registry, registry.declName(@"type".base));
        },
        else => {
            try w.writeAll(qualifier.decl);
            try renderTypeName(w, registry, registry.declName(@"type".base));
        },
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

fn renderFnType(
    w: *std.Io.Writer,
    registry: Registry,
    params: []const Registry.Param,
    return_type: Registry.Type,
) !void {
    try w.writeAll("*const fn (");
    try renderParams(w, registry, params, .{});
    try w.writeAll(") callconv(@\"callconv\") ");
    try renderType(w, registry, return_type);
}

fn renderParams(
    w: *std.Io.Writer,
    registry: Registry,
    params: []const Registry.Param,
    qualifier: TypeQualifier,
) !void {
    for (params) |param| {
        try renderId(w, param.name);
        try w.writeAll(": ");
        try renderQualifiedType(w, registry, param.type, qualifier);
        try w.writeAll(", ");
    }
}

fn renderTypeName(w: *std.Io.Writer, registry: Registry, name: []const u8) !void {
    try w.writeAll(stripPrefix(name, registry.type_prefix));
}

fn renderFnName(w: *std.Io.Writer, registry: Registry, name: []const u8) !void {
    const stripped = stripPrefix(name, registry.fn_prefix);
    var buffer: [256]u8 = undefined;
    const camel = buffer[0..stripped.len];
    @memcpy(camel, stripped);
    camel[0] = std.ascii.toLower(camel[0]);
    try renderId(w, camel);
}

fn renderSnakeName(w: *std.Io.Writer, registry: Registry, name: []const u8) !void {
    var buffer: [256]u8 = undefined;
    try renderLowerIdent(w, screamingCase(stripPrefix(name, registry.fn_prefix), &buffer));
}

fn renderConstName(w: *std.Io.Writer, registry: Registry, name: []const u8) !void {
    try renderLowerIdent(w, stripPrefix(name, registry.enum_prefix));
}

fn renderMemberName(
    w: *std.Io.Writer,
    registry: Registry,
    owner_type_name: []const u8,
    member_name: []const u8,
) !void {
    var buffer: [256]u8 = undefined;
    try renderLowerIdent(w, memberSuffix(registry, owner_type_name, member_name, &buffer));
}

fn renderErrorName(w: *std.Io.Writer, registry: Registry, value: Registry.Enum.Value) !void {
    var buffer: [256]u8 = undefined;
    const suffix = memberSuffix(registry, registry.resultEnum().name, value.name, &buffer);

    var at_word_start = true;
    for (suffix) |char| {
        if (char == '_') {
            at_word_start = true;
            continue;
        }
        try w.writeByte(if (at_word_start) std.ascii.toUpper(char) else std.ascii.toLower(char));
        at_word_start = false;
    }
}

fn memberSuffix(
    registry: Registry,
    owner_type_name: []const u8,
    member_name: []const u8,
    buffer: []u8,
) []const u8 {
    const owner_screaming = screamingCase(owner_type_name, buffer);

    var suffix = if (std.mem.startsWith(u8, member_name, owner_screaming))
        member_name[owner_screaming.len..]
    else
        stripPrefix(member_name, registry.enum_prefix);

    suffix = std.mem.trimStart(u8, suffix, "_");
    if (std.mem.endsWith(u8, suffix, "_BIT")) suffix = suffix[0 .. suffix.len - "_BIT".len];
    return suffix;
}

fn renderLowerIdent(w: *std.Io.Writer, name: []const u8) !void {
    var buffer: [256]u8 = undefined;
    try renderId(w, std.ascii.lowerString(buffer[0..name.len], name));
}

fn renderId(w: *std.Io.Writer, name: []const u8) !void {
    if (std.zig.isValidId(name)) return w.writeAll(name);
    try w.print("@\"{s}\"", .{name});
}

fn stripPrefix(name: []const u8, prefix: []const u8) []const u8 {
    if (std.mem.startsWith(u8, name, prefix)) return name[prefix.len..];
    return name;
}

fn screamingCase(name: []const u8, buffer: []u8) []const u8 {
    var length: usize = 0;
    for (name, 0..) |char, index| {
        const starts_word = index != 0 and std.ascii.isUpper(char) and !std.ascii.isUpper(name[index - 1]);
        if (starts_word) {
            buffer[length] = '_';
            length += 1;
        }
        buffer[length] = std.ascii.toUpper(char);
        length += 1;
    }
    return buffer[0..length];
}
