const std = @import("std");
const gpu = @import("src/root.zig");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const validation_layers = b.option(bool, "validation-layers", "") orelse (optimize == .Debug);

    const root_module = b.addModule("sulfur", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    var options = b.addOptions();
    options.addOption(bool, "validation_layers", validation_layers);
    root_module.addOptions("options", options);

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
    root_module.addImport("vulkan", vulkan.module("vulkan-zig"));
    vulkan_loader_module.addImport("vulkan", vulkan.module("vulkan-zig"));

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
    samplers: []const gpu.Sampler,
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
