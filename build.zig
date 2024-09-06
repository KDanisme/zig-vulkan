const std = @import("std");
const vkgen = @import("vulkan_zig");
const ShaderCompileStep = vkgen.ShaderCompileStep;

const sdl = @import("sdl"); // Replace with the actual name in your build.zig.zon

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = addExecutable(b, target, optimize);

    const sdk = sdl.init(b, .{});
    // sdk.link(exe, .dynamic, sdl.Library.SDL2); // link SDL2 as a shared library
    // sdk.link(exe, .dynamic, sdl.Library.SDL2_ttf); // link SDL2 as a shared library
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_ttf");

    const shaderModule = getShaderModule(b);
    const vkModule = try getVkModule(b);

    exe.root_module.addImport("shaders", shaderModule);
    exe.root_module.addImport("vulkan-zig", vkModule);
    exe.root_module.addImport("sdl2", sdk.getWrapperModuleVulkan(vkModule));

    addRunStep(b, exe);
    addTestStep(b, target, optimize);
}
fn addRunStep(b: *std.Build, step: *std.Build.Step.Compile) void {
    const run_cmd = b.addRunArtifact(step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
fn addTestStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
fn addExecutable(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "zig-vulkan",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    b.installArtifact(exe);
    return exe;
}
fn getVkModule(b: *std.Build) !*std.Build.Module {
    const maybe_override_registry = b.option([]const u8, "override-registry", "Override the path to the Vulkan registry used for the examples");
    const registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml");
    const vk_gen = b.dependency("vulkan_zig", .{}).artifact("vulkan-zig-generator");
    const vk_generate_cmd = b.addRunArtifact(vk_gen);
    if (maybe_override_registry) |override_registry| {
        vk_generate_cmd.addFileArg(.{ .cwd_relative = override_registry });
    } else {
        vk_generate_cmd.addFileArg(registry);
    }
    return b.addModule("vulkan-zig", .{
        .root_source_file = vk_generate_cmd.addOutputFileArg("vk.zig"),
    });
}
fn getShaderModule(b: *std.Build) *std.Build.Module {
    const shaders = ShaderCompileStep.create(
        b,
        .{ .real_path = "glslc" },
        &[_][]const u8{"--target-env=vulkan1.2"},
        "-o",
    );
    shaders.add("triangle_vert", "src/shaders/triangle.vert", .{});
    shaders.add("triangle_frag", "src/shaders/triangle.frag", .{});
    return shaders.getModule();
}
