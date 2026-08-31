const gpu = @import("sf_minimal.zig");

pub const CompareOp = enum(u3) {
    never = 0,
    less = 1,
    equal = 2,
    less_equal = 3,
    greater = 4,
    not_equal = 5,
    greater_equal = 6,
    always = 7,
};

pub const Filter = enum(u1) {
    nearest = 0,
    linear = 1,
};

pub const MipFilter = enum(u2) {
    none = 0,
    nearest = 1,
    linear = 2,
};

pub const AddressUVW = packed struct(u9) {
    u: Address = .clamp_to_edge,
    v: Address = .clamp_to_edge,
    w: Address = .clamp_to_edge,

    pub fn all(a: Address) AddressUVW {
        return .{ .u = a, .v = a, .w = a };
    }
};

pub const Address = enum(u3) {
    repeat = 0,
    mirrored_repeat = 1,
    clamp_to_edge = 2,
    clamp_to_border = 3,
};

pub const Coord = enum(u1) {
    normalized = 0,
    pixel = 1,
};

pub const BorderColor = enum(u2) {
    transparent_black = 0,
    opaque_black = 1,
    opaque_white = 2,
};

pub const Reduction = enum(u2) {
    weighted_average = 0,
    minimum = 1,
    maximum = 2,
};

pub const Anisotropy = enum(u3) {
    x1 = 0,
    x2 = 1,
    x4 = 2,
    x8 = 3,
    x16 = 4,
};

pub const Compare = packed struct(u4) {
    enable: bool = false,
    op: CompareOp = .never,
};

pub const Lod = enum(u12) {
    min = 0,
    max = 0xFFF,
    _,
    pub fn of(x: f32) Lod {
        return @enumFromInt(@as(u12, @intFromFloat(@min(x, 15.996) * 256.0)));
    }
    pub fn toF32(self: Lod) f32 {
        return @as(f32, @floatFromInt(@intFromEnum(self))) / 256.0;
    }
};

pub const Bias = enum(i14) {
    none = 0,
    _,
    pub fn of(x: f32) Bias {
        return @enumFromInt(@as(i14, @intFromFloat(x * 256)));
    }
    pub fn toF32(self: Bias) f32 {
        return @as(f32, @floatFromInt(@intFromEnum(self))) / 256;
    }
};

pub const SamplerDesc = packed struct(u64) {
    min_filter: Filter = .linear,
    mag_filter: Filter = .linear,
    mip_filter: MipFilter = .linear,

    address: AddressUVW = .{},

    coord: Coord = .normalized,
    border_color: BorderColor = .transparent_black,
    reduction: Reduction = .weighted_average,
    max_anisotropy: Anisotropy = .x1,

    compare: Compare = .{},

    lod_min: Lod = .min,
    lod_max: Lod = .max,
    lod_bias: Bias = .none,

    _pad: u1 = 0,
};
