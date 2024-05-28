const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("bytecode", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const unit_tests = b.addTest(.{
        .name = "bytecode-tests",
        .root_source_file = b.path("src/unit_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    const test_run = b.addRunArtifact(unit_tests);

    test_step.dependOn(&test_run.step);
}
