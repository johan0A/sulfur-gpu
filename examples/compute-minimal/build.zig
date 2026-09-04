const std = @import("std");
const sulfur = @import("sulfur");
const zon = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const sulfur_dep = b.dependency("sulfur", .{
        .target = target,
        .optimize = optimize,
    });
    root_module.addImport("sulfur", sulfur_dep.module("sulfur"));

    const compute = sulfur.compileShader(sulfur_dep, b, b.path("src/shaders/generate_texture.slang"), "main", &.{});
    root_module.addAnonymousImport("generate_texture.spv", .{ .root_source_file = compute });

    {
        const exe = b.addExecutable(.{ .name = @tagName(zon.name), .root_module = root_module });
        b.installArtifact(exe);

        const run = b.addRunArtifact(exe);
        const run_step = b.step("run", "");
        run_step.dependOn(&run.step);
        run_step.dependOn(b.getInstallStep());
    }
}
