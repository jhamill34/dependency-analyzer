const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the binary that is our actual artifact
    const exe = b.addExecutable(.{
        .name = "zig-learning",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Pull in the myutil package as a dependency
    const myutil = b.dependency("myutil", .{});

    // Add the add module as an import
    const add = myutil.module("add");
    exe.root_module.addImport("add", add);

    // Add the sub module as an import
    const sub = myutil.module("sub");
    exe.root_module.addImport("sub", sub);

    // Create the actual artifact
    b.installArtifact(exe);

    // Allow the run step to be executed after building
    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    // Create a test step
    const test_step = b.step("test", "Run unit tests");

    // Add the root tests as part of test suite
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/unit_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    // This lets us run the tests in myutil as part of the high level build process
    test_step.dependOn(&b.addRunArtifact(myutil.artifact("myutil-tests")).step);
}
