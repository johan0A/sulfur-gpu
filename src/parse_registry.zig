const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const parsed = try std.json.parseFromSlice(Registry, arena, @embedFile("sulfur.json"), .{});
    _ = parsed; // autofix
}

const Registry = struct {
    registry: []u8,
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

    const Constant = struct {
        name: []u8,
        type: []u8,
        value: []u8,
        doc: []u8,
    };

    const TypeDef = struct {
        name: []u8,
        underlying: []u8,
        doc: []u8,
    };

    const Opaque = struct {
        name: []u8,
        doc: []u8,
    };

    const FunctionPointer = struct {
        name: []u8,
        @"return": Type,
        params: []Param,
        doc: []u8,
    };

    const Struct = struct {
        name: []u8,
        platform: ?Platform = null,
        fields: []Field,
        doc: []u8,
    };

    const Field = struct {
        name: []u8,
        type: Type,
        default: ?[]u8 = null,
        doc: []u8,
    };

    const Type = struct {
        base: []u8,
        ptr: []Ptr = &.{},
        array: ?Array = null,

        const Ptr = struct {
            optional: bool = false,
            @"const": bool = false,
            len: ?[]u8 = null,
        };

        const Array = union(enum) {
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

    const Enum = struct {
        name: []u8,
        underlying: []u8,
        values: []Value,
        doc: []u8,

        const Value = struct {
            name: []u8,
            value: i64,
            doc: []u8,
        };
    };

    const Flags = struct {
        name: []u8,
        underlying: []u8,
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

    const Function = struct {
        name: []u8,
        platform: ?Platform = null,
        group: []u8,
        enumerate: bool = false,
        @"return": Type,
        params: []Param,
        doc: []u8,
    };

    const Param = struct {
        name: []u8,
        type: Type,
        out: bool = false,
        doc: []u8,
    };

    const Platform = enum {
        win32,
    };
};
