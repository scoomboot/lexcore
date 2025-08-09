// main.zig — Main benchmark runner for position tracking performance analysis
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/position/benchmarks
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const lexcore = @import("lexcore");
    const position_benchmark = @import("position_benchmark.zig");
    const buffer_benchmark = @import("buffer_benchmark.zig");
    const small_file = @import("scenarios/small_file.zig");
    const medium_file = @import("scenarios/medium_file.zig");
    const large_file = @import("scenarios/large_file.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Color codes for terminal output
    const Colors = struct {
        const reset = "\x1b[0m";
        const bold = "\x1b[1m";
        const green = "\x1b[32m";
        const yellow = "\x1b[33m";
        const red = "\x1b[31m";
        const cyan = "\x1b[36m";
        const magenta = "\x1b[35m";
    };

    /// Run all benchmarks and generate summary report
    pub fn main() !void {
        const stdout = std.io.getStdOut().writer();

        // Print header
        printHeader();

        // Print section separator
        try stdout.print("\n{s}════════════════════════════════════════════════════════════════════════════{s}\n\n", .{ Colors.cyan, Colors.reset });
        
        // Run all benchmark suites
        try stdout.print("{s}Running Position Tracking Performance Benchmarks...{s}\n", .{ Colors.bold, Colors.reset });
        try stdout.print("This suite validates that position tracking adds <3% overhead.\n\n", .{});

        // Position benchmarks
        try stdout.print("{s}╔══════════════════════════════════════════════════════════════════════════════╗{s}\n", .{ Colors.cyan, Colors.reset });
        try stdout.print("{s}║                           POSITION BENCHMARKS                               ║{s}\n", .{ Colors.cyan, Colors.reset });
        try stdout.print("{s}╚══════════════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ Colors.cyan, Colors.reset });
        
        // Call position benchmarks directly
        try position_benchmark.main();

        // Buffer benchmarks
        try stdout.print("\n{s}╔══════════════════════════════════════════════════════════════════════════════╗{s}\n", .{ Colors.cyan, Colors.reset });
        try stdout.print("{s}║                            BUFFER BENCHMARKS                                ║{s}\n", .{ Colors.cyan, Colors.reset });
        try stdout.print("{s}╚══════════════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ Colors.cyan, Colors.reset });
        
        // Call buffer benchmarks directly
        try buffer_benchmark.main();

        // Scenario benchmarks
        try stdout.print("\n{s}╔══════════════════════════════════════════════════════════════════════════════╗{s}\n", .{ Colors.cyan, Colors.reset });
        try stdout.print("{s}║                          SCENARIO BENCHMARKS                                ║{s}\n", .{ Colors.cyan, Colors.reset });
        try stdout.print("{s}╚══════════════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ Colors.cyan, Colors.reset });

        try stdout.print("\n{s}=== Small File Scenarios ==={s}\n", .{ Colors.bold, Colors.reset });
        try small_file.main();
        
        try stdout.print("\n{s}=== Medium File Scenarios ==={s}\n", .{ Colors.bold, Colors.reset });
        try medium_file.main();
        
        try stdout.print("\n{s}=== Large File Scenarios ==={s}\n", .{ Colors.bold, Colors.reset });
        try large_file.main();

        // Final summary
        try stdout.print("\n{s}╔══════════════════════════════════════════════════════════════════════════════╗{s}\n", .{ Colors.magenta, Colors.reset });
        try stdout.print("{s}║                          BENCHMARK SUITE COMPLETE                           ║{s}\n", .{ Colors.magenta, Colors.reset });
        try stdout.print("{s}╚══════════════════════════════════════════════════════════════════════════════╝{s}\n", .{ Colors.magenta, Colors.reset });
        
        try stdout.print("\n{s}✓ All benchmarks completed successfully!{s}\n", .{ Colors.green, Colors.reset });
        try stdout.print("{s}  Review the results above to validate the <3% overhead claim.{s}\n\n", .{ Colors.green, Colors.reset });
    }

    /// Print benchmark header
    fn printHeader() void {
        std.debug.print("\n", .{});
        std.debug.print("{s}╔══════════════════════════════════════════════════════════════════════════════╗{s}\n", .{ Colors.cyan, Colors.reset });
        std.debug.print("{s}║                    LexCore Position Tracking Benchmarks                     ║{s}\n", .{ Colors.cyan, Colors.reset });
        std.debug.print("{s}╚══════════════════════════════════════════════════════════════════════════════╝{s}\n", .{ Colors.cyan, Colors.reset });
        std.debug.print("\n", .{});
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: BenchmarkMain: validates header printing" {
        // Simple validation that header prints without error
        printHeader();
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝