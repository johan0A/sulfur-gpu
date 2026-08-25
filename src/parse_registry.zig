const std = @import("std");

pub const JsonRegistry = struct {
    version: []u8,

    fn_prefix: []u8,
    type_prefix: []u8,
    enum_prefix: []u8,

    proc_addr: []u8,
    get_slot: []u8,
    create_instance: []u8,

    constants: []Constant,
    typedefs: []TypeDef,
    opaques: []Opaque,
    function_pointers: []FunctionPointer,
    structs: []Struct,
    enums: []Enum,
    flags: []Flags,

    functions: []Function,

    pub const Constant = struct {
        name: []u8,
        type: []u8,
        value: []u8,
        doc: []u8,
    };

    pub const TypeDef = struct {
        name: []u8,
        type: []u8,
        doc: []u8,
    };

    pub const Opaque = struct {
        name: []u8,
        doc: []u8,
    };

    pub const FunctionPointer = struct {
        name: []u8,
        @"return": Type,
        params: []Param,
        doc: []u8,
    };

    pub const Struct = struct {
        name: []u8,
        platform: ?Platform = null,
        fields: []Field,
        doc: []u8,
    };

    pub const Field = struct {
        name: []u8,
        type: Type,
        default: ?[]u8 = null,
        doc: []u8,
    };

    pub const Type = struct {
        base: []u8,
        ptr: []Ptr = &.{},
        array: ?Array = null,

        pub const Ptr = struct {
            optional: bool = false,
            @"const": bool = false,
            len: ?[]u8 = null,
        };

        pub const Array = union(enum) {
            int: u32,
            constant: []u8,

            pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Array {
                switch (try source.peekNextTokenType()) {
                    .number => return Array{ .int = try std.json.innerParse(u32, allocator, source, options) },
                    .string => return Array{ .constant = try std.json.innerParse([]u8, allocator, source, options) },
                    else => return error.UnexpectedToken,
                }
            }
        };
    };

    pub const Enum = struct {
        name: []u8,
        backing_type: []u8,
        values: []Value,
        doc: []u8,

        const Value = struct {
            name: []u8,
            value: i64,
            doc: []u8,
        };
    };

    pub const Flags = struct {
        name: []u8,
        backing_type: []u8,
        bits: []Bit,
        combinations: []Combination,
        doc: []u8,

        const Bit = struct {
            name: []u8,
            bit: u16,
            doc: []u8,
        };

        const Combination = struct {
            name: []u8,
            bits: [][]u8,
            doc: []u8,
        };
    };

    pub const Function = struct {
        name: []u8,
        platform: ?Platform = null,
        group: ?[]u8 = null,
        dispatch: Dispatch,
        enumerate: bool = false,
        @"return": Type,
        params: []Param,
        doc: []u8,

        const Dispatch = enum {
            proc,
            table,
        };
    };

    pub const Param = struct {
        name: []u8,
        type: Type,
        out: bool = false,
        doc: []u8,
    };

    pub const Platform = enum {
        win32,
        xlib,
    };

    pub fn parse(arena: std.mem.Allocator, bytes: []const u8) !JsonRegistry {
        return try std.json.parseFromSliceLeaky(JsonRegistry, arena, bytes, .{});
    }
};

pub const Registry = struct {
    version: []const u8,

    fn_prefix: []const u8,
    type_prefix: []const u8,
    enum_prefix: []const u8,

    proc_addr: TypeBase,
    get_slot: Function.Index,
    create_instance: Function.Index,

    constants: []const Constant,
    typedefs: []const Typedef,
    opaques: []const Opaque,
    function_pointers: []const FunctionPointer,
    structs: []const Struct,
    enums: []const Enum,
    flags: []const Flags,
    functions: []const Function,

    decl_by_name: std.StringArrayHashMapUnmanaged(TypeBase),
    function_by_name: std.StringArrayHashMapUnmanaged(Function.Index),
    constant_by_name: std.StringArrayHashMapUnmanaged(Constant.Index),

    pub const TypeBase = union(enum) {
        typedef: Typedef.Index,
        @"opaque": Opaque.Index,
        function_pointer: FunctionPointer.Index,
        @"struct": Struct.Index,
        @"enum": Enum.Index,
        flags: Flags.Index,
        builtin: Builtin,
    };

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

    pub const Type = struct {
        base: TypeBase,
        ptrs: []const Pointer = &.{},
        array: ?ArrayLen = null,

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

        pub const ArrayLen = union(enum) {
            int: u32,
            constant: Constant.Index,
        };
    };

    pub const Constant = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        type: TypeBase,
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

        /// `registry.enums[ev.enum].values[ev.value]`.
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
            /// Indices into `Flags.bits`
            bits: []const u32,
            doc: []const u8,
        };
    };

    pub const Function = struct {
        pub const Index = enum(u32) { _ };

        name: []const u8,
        dispatch: Dispatch,
        enumerate: bool,
        return_type: Type,
        params: []const Param,
        doc: []const u8,

        pub const Dispatch = enum { proc, table };
    };

    pub const Param = struct {
        name: []const u8,
        type: Type,
        out: bool,
        doc: []const u8,
    };

    pub fn declName(r: *const Registry, ref: TypeBase) []const u8 {
        return switch (ref) {
            .typedef => |i| r.typedefs[@intFromEnum(i)].name,
            .@"opaque" => |i| r.opaques[@intFromEnum(i)].name,
            .function_pointer => |i| r.function_pointers[@intFromEnum(i)].name,
            .@"struct" => |i| r.structs[@intFromEnum(i)].name,
            .@"enum" => |i| r.enums[@intFromEnum(i)].name,
            .flags => |i| r.flags[@intFromEnum(i)].name,
            .builtin => |builtin| @tagName(builtin),
        };
    }

    pub fn lookupDecl(r: *const Registry, name: []const u8) ?TypeBase {
        return r.decl_by_name.get(name);
    }

    pub fn constant(r: *const Registry, i: Constant.Index) *const Constant {
        return &r.constants[@intFromEnum(i)];
    }

    pub fn function(r: *const Registry, i: Function.Index) *const Function {
        return &r.functions[@intFromEnum(i)];
    }

    pub fn @"enum"(r: *const Registry, i: Enum.Index) *const Enum {
        return &r.enums[@intFromEnum(i)];
    }

    pub fn fromJson(arena: std.mem.Allocator, json: JsonRegistry) !Registry {
        return try convert(arena, json);
    }

    pub fn parse(arena: std.mem.Allocator, bytes: []const u8) !Registry {
        const json_registry: JsonRegistry = try .parse(arena, bytes);
        return try fromJson(arena, json_registry);
    }
};

const DeclByName = std.StringArrayHashMapUnmanaged(Registry.TypeBase);
const FunctionByName = std.StringArrayHashMapUnmanaged(Registry.Function.Index);
const ConstantByName = std.StringArrayHashMapUnmanaged(Registry.Constant.Index);

fn convert(arena: std.mem.Allocator, json: JsonRegistry) !Registry {
    var decl_by_name: DeclByName = .empty;
    var function_by_name: FunctionByName = .empty;
    var constant_by_name: ConstantByName = .empty;

    for (json.typedefs, 0..) |d, i| try putDecl(arena, &decl_by_name, d.name, .{ .typedef = @enumFromInt(i) });
    for (json.opaques, 0..) |d, i| try putDecl(arena, &decl_by_name, d.name, .{ .@"opaque" = @enumFromInt(i) });
    for (json.function_pointers, 0..) |d, i| try putDecl(arena, &decl_by_name, d.name, .{ .function_pointer = @enumFromInt(i) });
    for (json.structs, 0..) |d, i| try putDecl(arena, &decl_by_name, d.name, .{ .@"struct" = @enumFromInt(i) });
    for (json.enums, 0..) |d, i| try putDecl(arena, &decl_by_name, d.name, .{ .@"enum" = @enumFromInt(i) });
    for (json.flags, 0..) |d, i| try putDecl(arena, &decl_by_name, d.name, .{ .flags = @enumFromInt(i) });

    try constant_by_name.ensureTotalCapacity(arena, @intCast(json.constants.len));
    for (json.constants, 0..) |k, i| constant_by_name.putAssumeCapacity(k.name, @enumFromInt(i));

    try function_by_name.ensureTotalCapacity(arena, @intCast(json.functions.len));
    for (json.functions, 0..) |f, i| function_by_name.putAssumeCapacity(f.name, @enumFromInt(i));

    const constants = try arena.alloc(Registry.Constant, json.constants.len);
    for (json.constants, constants) |k, *out| out.* = .{
        .name = k.name,
        .type = try resolveTypeBase(&decl_by_name, k.type),
        .value = k.value,
        .doc = k.doc,
    };

    const enums = try arena.alloc(Registry.Enum, json.enums.len);
    for (json.enums, enums) |json_enum, *out| {
        const values = try arena.alloc(Registry.Enum.Value, json_enum.values.len);
        for (json_enum.values, values) |v, *ov| ov.* = .{ .name = v.name, .value = v.value, .doc = v.doc };
        out.* = .{
            .name = json_enum.name,
            .backing = std.meta.stringToEnum(Registry.Builtin, json_enum.backing_type) orelse return error.UnknownBackingType,
            .values = values,
            .doc = json_enum.doc,
        };
    }

    const flags = try arena.alloc(Registry.Flags, json.flags.len);
    for (json.flags, flags) |json_flags, *out| {
        const bits = try arena.alloc(Registry.Flags.Bit, json_flags.bits.len);
        for (json_flags.bits, bits) |b, *ob| ob.* = .{ .name = b.name, .bit = b.bit, .doc = b.doc };

        const combinations = try arena.alloc(Registry.Flags.Combination, json_flags.combinations.len);
        for (json_flags.combinations, combinations) |json_combination, *combination| {
            const bit_indices = try arena.alloc(u32, json_combination.bits.len);
            for (json_combination.bits, bit_indices) |bit_name, *index| {
                index.* = for (json_flags.bits, 0..) |b, i| {
                    if (std.mem.eql(u8, b.name, bit_name)) break @intCast(i);
                } else return error.UnknownFlagBit;
            }
            combination.* = .{ .name = json_combination.name, .bits = bit_indices, .doc = json_combination.doc };
        }

        out.* = .{
            .name = json_flags.name,
            .backing = std.meta.stringToEnum(Registry.Builtin, json_flags.backing_type) orelse return error.UnknownBackingType,
            .bits = bits,
            .combinations = combinations,
            .doc = json_flags.doc,
        };
    }

    const typedefs = try arena.alloc(Registry.Typedef, json.typedefs.len);
    for (json.typedefs, typedefs) |d, *out| out.* = .{
        .name = d.name,
        .type = .{ .base = try resolveTypeBase(&decl_by_name, d.type) },
        .doc = d.doc,
    };

    const opaques = try arena.alloc(Registry.Opaque, json.opaques.len);
    for (json.opaques, opaques) |d, *out| out.* = .{ .name = d.name, .doc = d.doc };

    const function_pointers = try arena.alloc(Registry.FunctionPointer, json.function_pointers.len);
    for (json.function_pointers, function_pointers) |json_pointer, *out| {
        const param_names = try arena.alloc([]const u8, json_pointer.params.len);
        for (json_pointer.params, param_names) |p, *n| n.* = p.name;

        out.* = .{
            .name = json_pointer.name,
            .return_type = try convertType(arena, &decl_by_name, &constant_by_name, json_pointer.@"return", param_names),
            .params = try convertParams(arena, &decl_by_name, &constant_by_name, json_pointer.params),
            .doc = json_pointer.doc,
        };
    }

    const structs = try arena.alloc(Registry.Struct, json.structs.len);
    for (json.structs, structs) |d, *out| out.* = .{
        .name = d.name,
        .fields = try convertFields(arena, &decl_by_name, &constant_by_name, enums, d.fields),
        .doc = d.doc,
    };

    const functions = try arena.alloc(Registry.Function, json.functions.len);
    for (json.functions, functions) |json_function, *out| out.* = .{
        .name = json_function.name,
        .dispatch = switch (json_function.dispatch) {
            .proc => .proc,
            .table => .table,
        },
        .enumerate = json_function.enumerate,
        .return_type = try convertType(arena, &decl_by_name, &constant_by_name, json_function.@"return", &.{}),
        .params = try convertParams(arena, &decl_by_name, &constant_by_name, json_function.params),
        .doc = json_function.doc,
    };

    return .{
        .version = json.version,
        .fn_prefix = json.fn_prefix,
        .type_prefix = json.type_prefix,
        .enum_prefix = json.enum_prefix,
        .proc_addr = decl_by_name.get(json.proc_addr) orelse return error.UnknownFunction,
        .get_slot = function_by_name.get(json.get_slot) orelse return error.UnknownFunction,
        .create_instance = function_by_name.get(json.create_instance) orelse return error.UnknownFunction,
        .constants = constants,
        .typedefs = typedefs,
        .opaques = opaques,
        .function_pointers = function_pointers,
        .structs = structs,
        .enums = enums,
        .flags = flags,
        .functions = functions,
        .decl_by_name = decl_by_name,
        .function_by_name = function_by_name,
        .constant_by_name = constant_by_name,
    };
}

fn putDecl(arena: std.mem.Allocator, decl_by_name: *DeclByName, name: []const u8, ref: Registry.TypeBase) !void {
    const gop = try decl_by_name.getOrPut(arena, name);
    if (gop.found_existing) return error.DuplicateDecl;
    gop.value_ptr.* = ref;
}

fn resolveTypeBase(decl_by_name: *const DeclByName, name: []const u8) !Registry.TypeBase {
    if (std.meta.stringToEnum(Registry.Builtin, name)) |b| return .{ .builtin = b };
    if (decl_by_name.get(name)) |d| return d;
    return error.UnknownType;
}

fn convertType(
    arena: std.mem.Allocator,
    decl_by_name: *const DeclByName,
    constant_by_name: *const ConstantByName,
    json_type: JsonRegistry.Type,
    args: []const []const u8,
) !Registry.Type {
    const ptrs = try arena.alloc(Registry.Type.Pointer, json_type.ptr.len);
    for (json_type.ptr, ptrs) |json_pointer, *pointer| pointer.* = .{
        .optional = json_pointer.optional,
        .@"const" = json_pointer.@"const",
        .size = blk: {
            const len = json_pointer.len orelse break :blk .one;
            if (std.mem.eql(u8, len, "none")) break :blk .many;
            if (std.mem.eql(u8, len, "null_terminated")) break :blk .null_terminated;
            for (args, 0..) |arg, i| {
                if (std.mem.eql(u8, arg, len)) break :blk .{ .sized_by_arg = @intCast(i) };
            }
            return error.UnknownLen;
        },
    };

    return .{
        .base = try resolveTypeBase(decl_by_name, json_type.base),
        .ptrs = ptrs,
        .array = if (json_type.array) |array| switch (array) {
            .int => |v| .{ .int = v },
            .constant => |name| .{ .constant = constant_by_name.get(name) orelse return error.UnknownConstant },
        } else null,
    };
}

fn convertParams(
    arena: std.mem.Allocator,
    decl_by_name: *const DeclByName,
    constant_by_name: *const ConstantByName,
    json_params: []const JsonRegistry.Param,
) ![]Registry.Param {
    const names = try arena.alloc([]const u8, json_params.len);
    for (json_params, names) |p, *n| n.* = p.name;

    const params = try arena.alloc(Registry.Param, json_params.len);
    for (json_params, params) |json_param, *param| param.* = .{
        .name = json_param.name,
        .type = try convertType(arena, decl_by_name, constant_by_name, json_param.type, names),
        .out = json_param.out,
        .doc = json_param.doc,
    };
    return params;
}

fn convertFields(
    arena: std.mem.Allocator,
    decl_by_name: *const DeclByName,
    constant_by_name: *const ConstantByName,
    enums: []const Registry.Enum,
    json_fields: []const JsonRegistry.Field,
) ![]Registry.Field {
    const names = try arena.alloc([]const u8, json_fields.len);
    for (json_fields, names) |f, *n| n.* = f.name;

    const fields = try arena.alloc(Registry.Field, json_fields.len);
    for (json_fields, fields) |json_field, *field| {
        const @"type" = try convertType(arena, decl_by_name, constant_by_name, json_field.type, names);
        field.* = .{
            .name = json_field.name,
            .type = @"type",
            .default = if (json_field.default) |default| convertDefault(enums, @"type", default) else null,
            .doc = json_field.doc,
        };
    }
    return fields;
}

fn convertDefault(enums: []const Registry.Enum, @"type": Registry.Type, raw: []const u8) Registry.Default {
    if (@"type".ptrs.len == 0 and @"type".array == null and @"type".base == .@"enum") {
        const enum_index = @"type".base.@"enum";
        for (enums[@intFromEnum(enum_index)].values, 0..) |value, i| {
            if (std.mem.eql(u8, value.name, raw)) {
                return .{ .enum_value = .{ .@"enum" = enum_index, .value = @intCast(i) } };
            }
        }
    }
    return .{ .raw = raw };
}
