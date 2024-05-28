const std = @import("std");

const module_configs = [_]LocalModuleOpts{
    .{
        .name = "gzip-library",
        .modules = &.{"gzip"},
        .test_name = "gzip-tests",
    },
    .{
        .name = "bytecode-library",
        .modules = &.{"bytecode"},
        .test_name = "bytecode-tests",
    },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the binary that is our actual artifact
    const exe = b.addExecutable(.{
        .name = "dependency-analyzer",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    var modules: [module_configs.len]*std.Build.Dependency = undefined;

    installAllDepdendencies(b, &exe.root_module, &module_configs, &modules);

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

    registerAllModuleTests(b, test_step, &module_configs, &modules);
}

const LocalModuleOpts = struct {
    name: []const u8,
    modules: []const []const u8,
    test_name: []const u8,
};

fn installDependency(b: *std.Build, root: *std.Build.Module, opts: LocalModuleOpts) *std.Build.Dependency {
    const dep = b.dependency(opts.name, .{});

    for (opts.modules) |m| {
        const mod = dep.module(m);
        root.*.addImport(m, mod);
    }

    return dep;
}

fn installAllDepdendencies(b: *std.Build, root: *std.Build.Module, configs: []const LocalModuleOpts, modules: []*std.Build.Dependency) void {
    for (configs, 0..) |config, i| {
        modules[i] = installDependency(b, root, config);
    }
}

fn addModuleToTestSuite(b: *std.Build, step: *std.Build.Step, module: *std.Build.Dependency, name: []const u8) void {
    step.dependOn(&b.addRunArtifact(module.artifact(name)).step);
}

fn registerAllModuleTests(b: *std.Build, step: *std.Build.Step, configs: []const LocalModuleOpts, modules: []const *std.Build.Dependency) void {
    for (0..modules.len) |i| {
        addModuleToTestSuite(b, step, modules[i], configs[i].test_name);
    }
}
