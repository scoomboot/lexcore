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

        // Benchmarks
        const bench_step        = b.step("bench", "Run all benchmarks");

        // Main benchmark runner
        const bench_exe         = b.addExecutable(.{
            .name               = "benchmark",
            .root_source_file   = b.path("lib/lexer/position/benchmarks/main.zig"),
            .target             = target,
            .optimize           = .ReleaseFast, // Always use ReleaseFast for benchmarks
        });

        // Add the library module to the benchmark executable so it can access lexer components
        bench_exe.root_module.addImport("lexcore", lib_mod);

        const run_bench         = b.addRunArtifact(bench_exe);
        bench_step.dependOn(&run_bench.step);

        // Position-specific benchmarks
        const bench_position_step = b.step("bench-position", "Run position benchmarks only");
        const position_bench_exe = b.addExecutable(.{
            .name               = "position_benchmark",
            .root_source_file   = b.path("lib/lexer/position/benchmarks/position_benchmark.zig"),
            .target             = target,
            .optimize           = .ReleaseFast,
        });

        position_bench_exe.root_module.addImport("lexcore", lib_mod);

        const run_position_bench = b.addRunArtifact(position_bench_exe);
        bench_position_step.dependOn(&run_position_bench.step);

        // Buffer-specific benchmarks
        const bench_buffer_step = b.step("bench-buffer", "Run buffer benchmarks only");
        const buffer_bench_exe  = b.addExecutable(.{
            .name               = "buffer_benchmark",
            .root_source_file   = b.path("lib/lexer/position/benchmarks/buffer_benchmark.zig"),
            .target             = target,
            .optimize           = .ReleaseFast,
        });

        buffer_bench_exe.root_module.addImport("lexcore", lib_mod);

        const run_buffer_bench  = b.addRunArtifact(buffer_bench_exe);
        bench_buffer_step.dependOn(&run_buffer_bench.step);

        // Scenario benchmarks
        const bench_scenarios_step = b.step("bench-scenarios", "Run scenario benchmarks only");
        
        // Small file scenario
        const small_file_exe    = b.addExecutable(.{
            .name               = "small_file_benchmark",
            .root_source_file   = b.path("lib/lexer/position/benchmarks/scenarios/small_file.zig"),
            .target             = target,
            .optimize           = .ReleaseFast,
        });

        small_file_exe.root_module.addImport("lexcore", lib_mod);

        const run_small_file    = b.addRunArtifact(small_file_exe);
        
        // Medium file scenario
        const medium_file_exe   = b.addExecutable(.{
            .name               = "medium_file_benchmark",
            .root_source_file   = b.path("lib/lexer/position/benchmarks/scenarios/medium_file.zig"),
            .target             = target,
            .optimize           = .ReleaseFast,
        });

        medium_file_exe.root_module.addImport("lexcore", lib_mod);

        const run_medium_file   = b.addRunArtifact(medium_file_exe);
        
        // Large file scenario
        const large_file_exe    = b.addExecutable(.{
            .name               = "large_file_benchmark",
            .root_source_file   = b.path("lib/lexer/position/benchmarks/scenarios/large_file.zig"),
            .target             = target,
            .optimize           = .ReleaseFast,
        });

        large_file_exe.root_module.addImport("lexcore", lib_mod);

        const run_large_file    = b.addRunArtifact(large_file_exe);
        
        // Add all scenarios to the scenarios step
        bench_scenarios_step.dependOn(&run_small_file.step);
        bench_scenarios_step.dependOn(&run_medium_file.step);
        bench_scenarios_step.dependOn(&run_large_file.step);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝