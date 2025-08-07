// build.zig — Build configuration for lexcore
//
// repo   : https://github.com/scoomboot/lexcore
// docs   : https://scoomboot.github.io/lexcore
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.



// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const Build = std.Build;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝



// ╔══════════════════════════════════════ BUILD ═════════════════════════════════════╗

    pub fn build(b: *Build) void {
        const target            = b.standardTargetOptions(.{});
        const optimize          = b.standardOptimizeOption(.{});

        // Library module
        const lib_mod           = b.addModule("lexcore", .{
            .root_source_file   = b.path("lib/root.zig"),
            .target             = target,
            .optimize           = optimize,
        });

        // Executable
        const exe               = b.addExecutable(.{
            .name               = "lexcore",
            .root_source_file   = b.path("src/main.zig"),
            .target             = target,
            .optimize           = optimize,
        });

        exe.root_module.addImport("lexcore", lib_mod);
        b.installArtifact(exe);

        // Run command
        const run_cmd           = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step          = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        // Tests
        const test_step         = b.step("test", "Run all tests");

        // Library tests
        const lib_tests         = b.addTest(.{
            .root_source_file   = b.path("lib/root.zig"),
            .target             = target,
            .optimize           = optimize,
        });

        const run_lib_tests     = b.addRunArtifact(lib_tests);
        test_step.dependOn(&run_lib_tests.step);

        // Executable tests
        const exe_tests         = b.addTest(.{
            .root_source_file   = b.path("src/main.zig"),
            .target             = target,
            .optimize           = optimize,
        });

        exe_tests.root_module.addImport("lexcore", lib_mod);

        const run_exe_tests     = b.addRunArtifact(exe_tests);
        test_step.dependOn(&run_exe_tests.step);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝