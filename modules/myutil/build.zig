const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("add", .{
        .root_source_file = b.path("src/add.zig"),
    });

    _ = b.addModule("sub", .{
        .root_source_file = b.path("src/sub.zig"),
    });

    const unit_tests = b.addTest(.{
        .name = "myutil-tests",
        .root_source_file = b.path("src/unit_tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(unit_tests);

    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "runs tests");
    test_step.dependOn(&run_tests.step);
}
