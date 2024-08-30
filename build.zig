const std = @import("std");
const vkgen = @import("vulkan_zig");
const ShaderCompileStep = vkgen.ShaderCompileStep;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = addExecutable(b, target, optimize);
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
    exe.linkSystemLibrary("glfw");
    const vk_generate_command = try createVkGenerateCommand(b);
    exe.root_module.addAnonymousImport("vulkan", .{
        .root_source_file = vk_generate_command.addOutputFileArg("vk.zig"),
    });

    const shaderStep = createShaderCompileStep(b);
    exe.root_module.addImport("shaders", shaderStep.getModule());

    b.installArtifact(exe);
    return exe;
}
fn createVkGenerateCommand(b: *std.Build) !*std.Build.Step.Run {
    const maybe_override_registry = b.option([]const u8, "override-registry", "Override the path to the Vulkan registry used for the examples");
    const registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml");
    const vk_gen = b.dependency("vulkan_zig", .{}).artifact("vulkan-zig-generator");
    const vk_generate_cmd = b.addRunArtifact(vk_gen);
    if (maybe_override_registry) |override_registry| {
        vk_generate_cmd.addFileArg(.{ .cwd_relative = override_registry });
    } else {
        vk_generate_cmd.addFileArg(registry);
    }
    return vk_generate_cmd;
}
fn createShaderCompileStep(b: *std.Build) *vkgen.ShaderCompileStep {
    const shaders = ShaderCompileStep.create(
        b,
        .{ .real_path = "glslc" },
        &[_][]const u8{"--target-env=vulkan1.2"},
        "-o",
    );
    shaders.add("triangle_vert", "src/shaders/triangle.vert", .{});
    shaders.add("triangle_frag", "src/shaders/triangle.frag", .{});
    return shaders;
}
