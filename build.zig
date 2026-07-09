const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const root_module = b.addModule("sulfur", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    const vulkan_headers_dep = b.dependency("vulkan_headers", .{});

    const vulkan = b.dependency("vulkan", .{
        .registry = vulkan_headers_dep.path("registry/vk.xml"),
    });
    root_module.addImport("vulkan", vulkan.module("vulkan-zig"));

    {
        const sdl_dep = b.dependency("sdl", .{
            .target = target,
            .optimize = optimize,
            .preferred_link_mode = .static,
        });
        const sdl_lib = sdl_dep.artifact("SDL3");
        root_module.linkLibrary(sdl_lib);

        const vulkan_include_path = vulkan_headers_dep.path("include");
        const vma_dep = b.dependency("VulkanMemoryAllocator", .{
            .target = target,
            .optimize = optimize,
            .@"vulkan-include-path" = vulkan_include_path,
            .VMA_DYNAMIC_VULKAN_FUNCTIONS = true,
            .VMA_STATIC_VULKAN_FUNCTIONS = false,
        });
        const vma_lib = vma_dep.artifact("VulkanMemoryAllocator");
        root_module.linkLibrary(vma_lib);

        const translate_c = b.addTranslateC(.{
            .root_source_file = b.addWriteFiles().add("stub.h",
                \\#include <SDL3/SDL.h>
                \\#include <SDL3/SDL_vulkan.h>
                \\#include <vk_mem_alloc_config.h>
                \\#include <vk_mem_alloc.h>
            ),
            .target = target,
            .optimize = optimize,
        });
        translate_c.addIncludePath(vulkan_include_path);
        translate_c.addIncludePath(sdl_lib.getEmittedIncludeTree());
        translate_c.addIncludePath(vma_lib.getEmittedIncludeTree());
        root_module.addImport("c", translate_c.createModule());
    }

    {
        const tests = b.addTest(.{ .name = "test", .root_module = root_module });
        const run_tests = b.addRunArtifact(tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_tests.step);
    }
}
