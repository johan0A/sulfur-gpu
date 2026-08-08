const std = @import("std");

pub fn parse(arena: std.mem.Allocator, bytes: []const u8) Registry {
    return try std.json.parseFromSliceLeaky(Registry, arena, bytes, .{});
}

pub const Registry = struct {
    version: []u8,

    fn_prefix: []u8,
    type_prefix: []u8,
    enum_prefix: []u8,

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
        group: []u8,
        enumerate: bool = false,
        @"return": Type,
        params: []Param,
        doc: []u8,
    };

    pub const Param = struct {
        name: []u8,
        type: Type,
        out: bool = false,
        doc: []u8,
    };

    pub const Platform = enum {
        win32,
    };
};
