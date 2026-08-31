const std = @import("std");

pub const Registry = struct {
    version: []const u8,

    fn_prefix: []const u8,
    type_prefix: []const u8,
    enum_prefix: []const u8,

    result: Enum.Index,
    get_symbol_type: Type,

    constants: []const Constant,
    typedefs: []const Typedef,
    opaques: []const Opaque,
    function_pointers: []const FunctionPointer,
    structs: []const Struct,
    enums: []const Enum,
    flags: []const Flags,
    functions: []const Function,

    pub const Builtin = enum {
        void,
        bool,
        char,
        uint8_t,
        int8_t,
        uint16_t,
        int16_t,
        uint32_t,
        int32_t,
        uint64_t,
        int64_t,
        size_t,
        float,
        double,
    };

    pub const TypeBase = union(enum) {
        typedef: Typedef.Index,
        @"opaque": Opaque.Index,
        function_pointer: FunctionPointer.Index,
        @"struct": Struct.Index,
        @"enum": Enum.Index,
        flags: Flags.Index,
        builtin: Builtin,

        pub const Tag = std.meta.Tag(TypeBase);
    };

    pub const Type = struct {
        base: TypeBase,
        ptrs: []const Pointer = &.{},
        array: ?Array = null,

        pub const Pointer = struct {
            optional: bool,
            @"const": bool,
            size: Size,

            pub const Size = union(enum) {
                one,
                many,
                sized_by_arg: u32,
                null_terminated,
            };
        };

        pub const Array = union(enum) {
            int: u32,
            constant: Constant.Index,
        };
    };

    pub const Constant = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        type: Type,
        value: []const u8,
        doc: []const u8,
    };

    pub const Typedef = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        type: Type,
        doc: []const u8,
    };

    pub const Opaque = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        doc: []const u8,
    };

    pub const FunctionPointer = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        return_type: Type,
        params: []const Param,
        doc: []const u8,
    };

    pub const Struct = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        fields: []const Field,
        doc: []const u8,
    };

    pub const Field = struct {
        name: []const u8,
        type: Type,
        default: ?Default,
        doc: []const u8,
    };

    pub const Default = union(enum) {
        enum_value: EnumValue,
        raw: []const u8,

        pub const EnumValue = struct {
            @"enum": Enum.Index,
            value: u32,
        };
    };

    pub const Enum = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        backing: Builtin,
        values: []const Value,
        doc: []const u8,

        pub const Value = struct {
            name: []const u8,
            value: i64,
            doc: []const u8,
        };
    };

    pub const Flags = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        backing: Builtin,
        bits: []const Bit,
        combinations: []const Combination,
        doc: []const u8,

        pub const Bit = struct {
            name: []const u8,
            bit: u16,
            doc: []const u8,
        };

        pub const Combination = struct {
            name: []const u8,
            bits: []const u32,
            doc: []const u8,
        };
    };

    pub const Function = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        dispatch: Dispatch,
        role: Role,
        enumerate: bool,
        return_type: Type,
        errors: []const Enum.Value,
        params: []const Param,
        doc: []const u8,

        pub const Dispatch = enum {
            symbol,
            table,
        };

        pub const Role = enum {
            normal,
            create_instance,
            get_slot,
        };
    };

    pub const Param = struct {
        name: []const u8,
        type: Type,
        out: bool,
        doc: []const u8,
    };

    pub fn resultEnum(registry: Registry) Enum {
        return registry.enums[@intFromEnum(registry.result)];
    }

    pub fn declName(registry: Registry, base: TypeBase) []const u8 {
        return switch (base) {
            .typedef => |index| registry.typedefs[@intFromEnum(index)].name,
            .@"opaque" => |index| registry.opaques[@intFromEnum(index)].name,
            .function_pointer => |index| registry.function_pointers[@intFromEnum(index)].name,
            .@"struct" => |index| registry.structs[@intFromEnum(index)].name,
            .@"enum" => |index| registry.enums[@intFromEnum(index)].name,
            .flags => |index| registry.flags[@intFromEnum(index)].name,
            .builtin => |builtin| @tagName(builtin),
        };
    }

    pub fn parse(arena: std.mem.Allocator, bytes: []const u8) !Registry {
        const json = try JsonRegistry.parse(arena, bytes);
        return convert(arena, json);
    }
};

pub const JsonRegistry = struct {
    version: []const u8,

    fn_prefix: []const u8,
    type_prefix: []const u8,
    enum_prefix: []const u8,

    result: []const u8,
    symbol: []const u8,
    get_slot: []const u8,
    create_instance: []const u8,

    constants: []const Constant,
    typedefs: []const Typedef,
    opaques: []const Registry.Opaque,
    function_pointers: []const FunctionPointer,
    structs: []const Struct,
    enums: []const Enum,
    flags: []const Flags,
    functions: []const Function,

    pub const Constant = struct {
        name: []const u8,
        type: []const u8,
        value: []const u8,
        doc: []const u8,
    };

    pub const Typedef = struct {
        name: []const u8,
        type: []const u8,
        doc: []const u8,
    };

    pub const FunctionPointer = struct {
        name: []const u8,
        @"return": Type,
        params: []const Param,
        doc: []const u8,
    };

    pub const Struct = struct {
        name: []const u8,
        platform: ?Platform = null,
        fields: []const Field,
        doc: []const u8,
    };

    pub const Field = struct {
        name: []const u8,
        type: Type,
        default: ?[]const u8 = null,
        doc: []const u8,
    };

    pub const Type = struct {
        base: []const u8,
        ptr: []const Ptr = &.{},
        array: ?Array = null,

        pub const Ptr = struct {
            optional: bool = false,
            @"const": bool = false,
            len: ?[]const u8 = null,
        };

        pub const Array = union(enum) {
            int: u32,
            constant: []const u8,

            pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Array {
                switch (try source.peekNextTokenType()) {
                    .number => return .{ .int = try std.json.innerParse(u32, allocator, source, options) },
                    .string => return .{ .constant = try std.json.innerParse([]const u8, allocator, source, options) },
                    else => return error.UnexpectedToken,
                }
            }
        };
    };

    pub const Enum = struct {
        name: []const u8,
        backing_type: Registry.Builtin,
        values: []const Registry.Enum.Value,
        doc: []const u8,
    };

    pub const Flags = struct {
        name: []const u8,
        backing_type: Registry.Builtin,
        bits: []const Registry.Flags.Bit,
        combinations: []const Combination,
        doc: []const u8,

        pub const Combination = struct {
            name: []const u8,
            bits: []const []const u8,
            doc: []const u8,
        };
    };

    pub const Function = struct {
        name: []const u8,
        platform: ?Platform = null,
        group: ?[]const u8 = null,
        dispatch: Registry.Function.Dispatch,
        enumerate: bool = false,
        @"return": Type,
        errors: []const []const u8 = &.{},
        params: []const Param,
        doc: []const u8,
    };

    pub const Param = struct {
        name: []const u8,
        type: Type,
        out: bool = false,
        doc: []const u8,
    };

    pub const Platform = enum {
        win32,
        xlib,
    };

    pub fn parse(arena: std.mem.Allocator, bytes: []const u8) !JsonRegistry {
        return std.json.parseFromSliceLeaky(JsonRegistry, arena, bytes, .{});
    }
};

const DeclByName = std.StringArrayHashMapUnmanaged(Registry.TypeBase);

const Context = struct {
    arena: std.mem.Allocator,
    json: JsonRegistry,
    decl_by_name: DeclByName,
    result_enum: JsonRegistry.Enum,
};

fn convert(arena: std.mem.Allocator, json: JsonRegistry) !Registry {
    var decl_by_name: DeclByName = .empty;
    try addDecls(arena, &decl_by_name, json.typedefs, .typedef);
    try addDecls(arena, &decl_by_name, json.opaques, .@"opaque");
    try addDecls(arena, &decl_by_name, json.function_pointers, .function_pointer);
    try addDecls(arena, &decl_by_name, json.structs, .@"struct");
    try addDecls(arena, &decl_by_name, json.enums, .@"enum");
    try addDecls(arena, &decl_by_name, json.flags, .flags);

    const result_base = decl_by_name.get(json.result) orelse return error.UnknownType;
    if (result_base != .@"enum") return error.ResultNotAnEnum;
    const result_index = result_base.@"enum";

    const context: Context = .{
        .arena = arena,
        .json = json,
        .decl_by_name = decl_by_name,
        .result_enum = json.enums[@intFromEnum(result_index)],
    };

    const constants = try arena.alloc(Registry.Constant, json.constants.len);
    for (json.constants, constants) |json_constant, *constant| constant.* = .{
        .name = json_constant.name,
        .type = .{ .base = try resolveTypeBase(context, json_constant.type) },
        .value = json_constant.value,
        .doc = json_constant.doc,
    };

    const typedefs = try arena.alloc(Registry.Typedef, json.typedefs.len);
    for (json.typedefs, typedefs) |json_typedef, *typedef| typedef.* = .{
        .name = json_typedef.name,
        .type = .{ .base = try resolveTypeBase(context, json_typedef.type) },
        .doc = json_typedef.doc,
    };

    const enums = try arena.alloc(Registry.Enum, json.enums.len);
    for (json.enums, enums) |json_enum, *@"enum"| @"enum".* = .{
        .name = json_enum.name,
        .backing = json_enum.backing_type,
        .values = json_enum.values,
        .doc = json_enum.doc,
    };

    const flags = try arena.alloc(Registry.Flags, json.flags.len);
    for (json.flags, flags) |json_flags, *flags_decl| flags_decl.* = .{
        .name = json_flags.name,
        .backing = json_flags.backing_type,
        .bits = json_flags.bits,
        .combinations = try convertCombinations(context, json_flags),
        .doc = json_flags.doc,
    };

    const function_pointers = try arena.alloc(Registry.FunctionPointer, json.function_pointers.len);
    for (json.function_pointers, function_pointers) |json_function_pointer, *function_pointer| function_pointer.* = .{
        .name = json_function_pointer.name,
        .return_type = try convertType(context, json_function_pointer.@"return", json_function_pointer.params),
        .params = try convertParams(context, json_function_pointer.params),
        .doc = json_function_pointer.doc,
    };

    const structs = try arena.alloc(Registry.Struct, json.structs.len);
    for (json.structs, structs) |json_struct, *@"struct"| @"struct".* = .{
        .name = json_struct.name,
        .fields = try convertFields(context, json_struct.fields),
        .doc = json_struct.doc,
    };

    _ = findByName(json.functions, json.get_slot) orelse return error.UnknownFunction;
    _ = findByName(json.functions, json.create_instance) orelse return error.UnknownFunction;

    const functions = try arena.alloc(Registry.Function, json.functions.len);
    for (json.functions, functions) |json_function, *function| {
        function.* = .{
            .name = json_function.name,
            .dispatch = json_function.dispatch,
            .role = blk: {
                if (std.mem.eql(u8, json_function.name, context.json.create_instance)) break :blk .create_instance;
                if (std.mem.eql(u8, json_function.name, context.json.get_slot)) break :blk .get_slot;
                break :blk .normal;
            },
            .enumerate = json_function.enumerate,
            .return_type = try convertType(context, json_function.@"return", json_function.params),
            .errors = try convertErrors(context, json_function.errors),
            .params = try convertParams(context, json_function.params),
            .doc = json_function.doc,
        };
    }

    return .{
        .version = json.version,
        .fn_prefix = json.fn_prefix,
        .type_prefix = json.type_prefix,
        .enum_prefix = json.enum_prefix,
        .result = result_index,
        .get_symbol_type = .{ .base = decl_by_name.get(json.symbol) orelse return error.UnknownType },
        .constants = constants,
        .typedefs = typedefs,
        .opaques = json.opaques,
        .function_pointers = function_pointers,
        .structs = structs,
        .enums = enums,
        .flags = flags,
        .functions = functions,
    };
}

fn addDecls(
    arena: std.mem.Allocator,
    decl_by_name: *DeclByName,
    decls: anytype,
    comptime tag: Registry.TypeBase.Tag,
) !void {
    const Index = @FieldType(Registry.TypeBase, @tagName(tag));
    for (decls, 0..) |decl, index| {
        const entry = try decl_by_name.getOrPut(arena, decl.name);
        if (entry.found_existing) return error.DuplicateDecl;
        entry.value_ptr.* = @unionInit(Registry.TypeBase, @tagName(tag), @as(Index, @enumFromInt(index)));
    }
}

fn findByName(items: anytype, name: []const u8) ?usize {
    for (items, 0..) |item, index| {
        if (std.mem.eql(u8, item.name, name)) return index;
    }
    return null;
}

fn resolveTypeBase(context: Context, name: []const u8) !Registry.TypeBase {
    if (std.meta.stringToEnum(Registry.Builtin, name)) |builtin| return .{ .builtin = builtin };
    return context.decl_by_name.get(name) orelse error.UnknownType;
}

fn convertType(
    context: Context,
    json_type: JsonRegistry.Type,
    siblings: anytype,
) !Registry.Type {
    const pointers = try context.arena.alloc(Registry.Type.Pointer, json_type.ptr.len);
    for (json_type.ptr, pointers) |json_pointer, *pointer| pointer.* = .{
        .optional = json_pointer.optional,
        .@"const" = json_pointer.@"const",
        .size = blk: {
            const len_name = json_pointer.len orelse break :blk .one;
            if (std.mem.eql(u8, len_name, "none")) break :blk .many;
            if (std.mem.eql(u8, len_name, "null_terminated")) break :blk .null_terminated;
            const sibling_index = findByName(siblings, len_name) orelse return error.UnknownLen;
            break :blk .{ .sized_by_arg = @intCast(sibling_index) };
        },
    };

    return .{
        .base = try resolveTypeBase(context, json_type.base),
        .ptrs = pointers,
        .array = if (json_type.array) |array| switch (array) {
            .int => |length| .{ .int = length },
            .constant => |name| .{
                .constant = @enumFromInt(findByName(context.json.constants, name) orelse return error.UnknownConstant),
            },
        } else null,
    };
}

fn convertParams(context: Context, json_params: []const JsonRegistry.Param) ![]const Registry.Param {
    const params = try context.arena.alloc(Registry.Param, json_params.len);
    for (json_params, params) |json_param, *param| param.* = .{
        .name = json_param.name,
        .type = try convertType(context, json_param.type, json_params),
        .out = json_param.out,
        .doc = json_param.doc,
    };
    return params;
}

fn convertFields(context: Context, json_fields: []const JsonRegistry.Field) ![]const Registry.Field {
    const fields = try context.arena.alloc(Registry.Field, json_fields.len);
    for (json_fields, fields) |json_field, *field| {
        const @"type" = try convertType(context, json_field.type, json_fields);
        field.* = .{
            .name = json_field.name,
            .type = @"type",
            .default = if (json_field.default) |default| convertDefault(context, @"type", default) else null,
            .doc = json_field.doc,
        };
    }
    return fields;
}

fn convertDefault(
    context: Context,
    @"type": Registry.Type,
    raw: []const u8,
) Registry.Default {
    const is_plain_enum = @"type".ptrs.len == 0 and @"type".array == null and @"type".base == .@"enum";
    if (!is_plain_enum) return .{ .raw = raw };

    const enum_index = @"type".base.@"enum";
    const json_enum = context.json.enums[@intFromEnum(enum_index)];
    const value_index = findByName(json_enum.values, raw) orelse return .{ .raw = raw };
    return .{ .enum_value = .{ .@"enum" = enum_index, .value = @intCast(value_index) } };
}

fn convertCombinations(context: Context, json_flags: JsonRegistry.Flags) ![]const Registry.Flags.Combination {
    const combinations = try context.arena.alloc(Registry.Flags.Combination, json_flags.combinations.len);
    for (json_flags.combinations, combinations) |json_combination, *combination| {
        const bit_indices = try context.arena.alloc(u32, json_combination.bits.len);
        for (json_combination.bits, bit_indices) |bit_name, *bit_index| {
            bit_index.* = @intCast(findByName(json_flags.bits, bit_name) orelse return error.UnknownFlagBit);
        }
        combination.* = .{
            .name = json_combination.name,
            .bits = bit_indices,
            .doc = json_combination.doc,
        };
    }
    return combinations;
}

fn convertErrors(context: Context, error_names: []const []const u8) ![]const Registry.Enum.Value {
    const errors = try context.arena.alloc(Registry.Enum.Value, error_names.len);
    for (error_names, errors) |error_name, *@"error"| {
        const value_index = findByName(context.result_enum.values, error_name) orelse return error.UnknownResultValue;
        @"error".* = context.result_enum.values[value_index];
    }
    return errors;
}
