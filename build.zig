const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const validation_layers = b.option(bool, "validation-layers", "") orelse (optimize == .Debug);

    const lib = b.addLibrary(.{
        .name = "sulfur",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/loader.zig"),
            .optimize = optimize,
            .target = target,
            .link_libc = switch (target.result.os.tag) {
                .windows => false,
                else => true,
            },
        }),
    });
    b.installArtifact(lib);

    const root_module = b.addModule("sulfur", .{
        .root_source_file = b.path("src/sf_bindings.zig"),
        .optimize = optimize,
        .target = target,
    });
    root_module.linkLibrary(lib);

    var options = b.addOptions();
    options.addOption(bool, "validation_layers", validation_layers);
    lib.root_module.addOptions("options", options);

    const vulkan_loader_module = b.addModule("VulkanLoader", .{
        .root_source_file = b.path("src/VulkanLoader.zig"),
        .optimize = optimize,
        .target = target,
        .link_libc = true,
    });

    const vulkan_headers_dep = b.dependency("vulkan_headers", .{});

    const vulkan = b.dependency("vulkan", .{
        .registry = vulkan_headers_dep.path("registry/vk.xml"),
    });
    vulkan_loader_module.addImport("vulkan", vulkan.module("vulkan-zig"));
    root_module.addImport("vulkan", vulkan.module("vulkan-zig"));
    lib.root_module.addImport("vulkan", vulkan.module("vulkan-zig"));

    {
        const generate_sf_bindings = b.step("generate-sf-bindings", "");

        const generate_sf_bindings_exe = b.addExecutable(.{
            .name = "generate-sf-bindings",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/render_zig_bindings.zig"),
                .optimize = .Debug,
                .target = b.graph.host,
            }),
        });

        const generate = b.addRunArtifact(generate_sf_bindings_exe);
        generate.addFileArg(b.path("src/sulfur.json"));
        const bindings = generate.addOutputFileArg("sf_bindings.zig");

        const update_source_files = b.addUpdateSourceFiles();
        update_source_files.addCopyFileToSource(bindings, "src/sf_bindings.zig");
        generate_sf_bindings.dependOn(&update_source_files.step);
    }

    {
        const tests = b.addTest(.{ .name = "test", .root_module = root_module });
        const run_tests = b.addRunArtifact(tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_tests.step);
    }
}

pub fn compileShader(
    sulfur_dep: *std.Build.Dependency,
    b: *std.Build,
    src: std.Build.LazyPath,
    entry: []const u8,
    samplers: []const Sampler,
) std.Build.LazyPath {
    const command = b.addSystemCommand(&.{
        "slangc",
        "-target",
        "spirv",
        "-profile",
        "spirv_1_6",
        "-fvk-use-entrypoint-name",
        "-fvk-use-scalar-layout",
        "-entry",
        entry,
    });
    command.addFileArg(src);
    command.addArg("-o");
    const spirv = command.addOutputFileArg("shader.spv");

    const sfir = b.addExecutable(.{
        .name = "sfir",
        .root_module = b.createModule(.{
            .root_source_file = sulfur_dep.path("src/sfir.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
    const run_sfir = b.addRunArtifact(sfir);

    const shader = run_sfir.addOutputFileArg("shader.sfir");
    run_sfir.addFileArg(spirv);
    for (samplers) |sampler| {
        const as_int: u64 = @bitCast(sampler);
        run_sfir.addArg(&std.fmt.hex(as_int));
    }

    return shader;
}

pub const Op = enum(u3) {
    never = 0,
    less = 1,
    equal = 2,
    less_equal = 3,
    greater = 4,
    not_equal = 5,
    greater_equal = 6,
    always = 7,
};

pub const Sampler = packed struct(u64) {
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
        op: Op = .never,
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
};
