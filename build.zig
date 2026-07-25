const std = @import("std");

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
