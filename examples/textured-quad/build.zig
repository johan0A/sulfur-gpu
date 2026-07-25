const std = @import("std");
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
    root_module.addImport("VulkanLoader", sulfur_dep.module("VulkanLoader"));

    const frag = compileShader(b, "src/shaders/frag.slang", "main");
    root_module.addAnonymousImport("frag.spv", .{ .root_source_file = frag });

    const vert = compileShader(b, "src/shaders/vert.slang", "main");
    root_module.addAnonymousImport("vert.spv", .{ .root_source_file = vert });

    {
        const sdl_dep = b.dependency("sdl", .{
            .target = target,
            .optimize = optimize,
            .preferred_link_mode = .static,
        });
        const sdl_lib = sdl_dep.artifact("SDL3");
        root_module.linkLibrary(sdl_lib);

        const translate_c = b.addTranslateC(.{
            .root_source_file = b.addWriteFiles().add("stub.h",
                \\#include <SDL3/SDL.h>
                \\#include <SDL3/SDL_vulkan.h>
            ),
            .target = target,
            .optimize = optimize,
        });
        translate_c.addIncludePath(sdl_lib.getEmittedIncludeTree());
        root_module.addImport("c", translate_c.createModule());
    }

    {
        const exe = b.addExecutable(.{ .name = @tagName(zon.name), .root_module = root_module });
        b.installArtifact(exe);

        const run = b.addRunArtifact(exe);
        const run_step = b.step("run", "");
        run_step.dependOn(&run.step);
        run_step.dependOn(b.getInstallStep());
    }
}

fn compileShader(
    b: *std.Build,
    src: []const u8,
    entry: []const u8,
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
    command.addFileArg(b.path(src));
    command.addArg("-o");
    return command.addOutputFileArg("shader.spv");
}
