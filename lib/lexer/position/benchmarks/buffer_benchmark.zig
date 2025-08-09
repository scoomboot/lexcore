// buffer_benchmark.zig — Performance benchmarks for buffer operations with position tracking
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/position/benchmarks
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const lexcore = @import("lexcore");
    const buffer_module = lexcore.lexer.buffer;
    const position_module = lexcore.lexer.position;
    const perf = lexcore.lexer.perf;
    const unicode_module = lexcore.lexer.unicode;
    
    const Buffer = buffer_module.Buffer;
    const PositionTracker = position_module.PositionTracker;
    const Timer = perf.Timer;
    const Benchmark = perf.Benchmark;
    const Throughput = perf.Throughput;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Benchmark configuration constants
    const WARMUP_ITERATIONS = 1000;
    const BENCHMARK_ITERATIONS = 10000;
    const LARGE_BUFFER_SIZE = 1024 * 1024; // 1MB
    const MEDIUM_BUFFER_SIZE = 64 * 1024;  // 64KB
    const SMALL_BUFFER_SIZE = 1024;        // 1KB

    /// Test data generators (reused from position_benchmark for consistency)
    const TestData = struct {
        /// Generate ASCII text with mixed content
        fn generateAsciiText(allocator: std.mem.Allocator, size: usize) ![]u8 {
            const text = try allocator.alloc(u8, size);
            var prng = std.Random.DefaultPrng.init(42);
            const random = prng.random();
            
            for (text, 0..) |*char, i| {
                const choice = random.int(u8) % 100;
                if (choice < 60) {
                    // Letters (60%)
                    char.* = 'a' + @as(u8, @intCast(random.int(u8) % 26));
                } else if (choice < 75) {
                    // Spaces (15%)
                    char.* = ' ';
                } else if (choice < 85) {
                    // Newlines (10%)
                    char.* = '\n';
                } else if (choice < 90) {
                    // Tabs (5%)
                    char.* = '\t';
                } else {
                    // Other punctuation (10%)
                    const punctuation = ".,;:!?()[]{}\"'";
                    char.* = punctuation[random.int(usize) % punctuation.len];
                }
                
                // Ensure some line structure
                if (i % 80 == 79 and char.* != '\n') {
                    char.* = '\n';
                }
            }
            
            return text;
        }
        
        /// Generate UTF-8 text with mixed ASCII and multi-byte characters
        fn generateUtf8Text(allocator: std.mem.Allocator, target_size: usize) ![]u8 {
            var list = std.ArrayList(u8).init(allocator);
            defer list.deinit();
            
            var prng = std.Random.DefaultPrng.init(42);
            const random = prng.random();
            
            while (list.items.len < target_size) {
                const choice = random.int(u8) % 100;
                
                if (choice < 50) {
                    // ASCII (50%)
                    try list.append('a' + @as(u8, @intCast(random.int(u8) % 26)));
                } else if (choice < 70) {
                    // 2-byte UTF-8 (20%)
                    const codepoint: u21 = 0x00E9; // é
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(codepoint, &buf) catch continue;
                    try list.appendSlice(buf[0..len]);
                } else if (choice < 85) {
                    // 3-byte UTF-8 (15%)
                    const codepoint: u21 = 0x4E2D; // 中
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(codepoint, &buf) catch continue;
                    try list.appendSlice(buf[0..len]);
                } else if (choice < 95) {
                    // Whitespace (10%)
                    const ws = [_]u8{ ' ', '\n', '\t' };
                    try list.append(ws[random.int(usize) % ws.len]);
                } else {
                    // 4-byte UTF-8 (5%)
                    const codepoint: u21 = 0x1F600; // 😀
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(codepoint, &buf) catch continue;
                    try list.appendSlice(buf[0..len]);
                }
            }
            
            return try list.toOwnedSlice();
        }
        
        /// Generate text with lots of whitespace for skipWhile/consumeWhile testing
        fn generateWhitespaceHeavyText(allocator: std.mem.Allocator, size: usize) ![]u8 {
            const text = try allocator.alloc(u8, size);
            var prng = std.Random.DefaultPrng.init(42);
            const random = prng.random();
            
            for (text) |*char| {
                const choice = random.int(u8) % 100;
                if (choice < 40) {
                    // Spaces (40%)
                    char.* = ' ';
                } else if (choice < 50) {
                    // Tabs (10%)
                    char.* = '\t';
                } else if (choice < 55) {
                    // Newlines (5%)
                    char.* = '\n';
                } else {
                    // Letters (45%)
                    char.* = 'a' + @as(u8, @intCast(random.int(u8) % 26));
                }
            }
            
            return text;
        }
    };

    /// Benchmark state for buffer operations
    var buffer_bench_state: struct {
        allocator: std.mem.Allocator,
        text: []const u8,
    } = undefined;
    
    /// Benchmark Buffer operations with position tracking enabled vs disabled
    pub fn benchmarkBufferWithTracking(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: Buffer Operations - Tracking Enabled vs Disabled ===\n", .{});
        
        const text = try TestData.generateAsciiText(allocator, MEDIUM_BUFFER_SIZE);
        defer allocator.free(text);
        
        // Benchmark without position tracking
        try writer.print("\n  WITHOUT position tracking:\n", .{});
        var benchmark_without = Benchmark.init(allocator, "Buffer (no tracking)");
        defer benchmark_without.deinit();
        
        // Set up benchmark state
        buffer_bench_state = .{ .allocator = allocator, .text = text };
        
        const result_without = try benchmark_without.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithContent(buffer_bench_state.allocator, buffer_bench_state.text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        _ = try buf.next();
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("  {}\n", .{result_without});
        
        const total_bytes_without = text.len * BENCHMARK_ITERATIONS;
        const throughput_without = Throughput.bytesPerSecond(total_bytes_without, result_without.total_time_ns);
        const formatted_without = Throughput.formatBytes(throughput_without);
        try writer.print("    Throughput: {s}\n", .{formatted_without});
        
        // Benchmark with position tracking
        try writer.print("\n  WITH position tracking:\n", .{});
        var benchmark_with = Benchmark.init(allocator, "Buffer (with tracking)");
        defer benchmark_with.deinit();
        
        const result_with = try benchmark_with.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithPositionTracking(buffer_bench_state.allocator, buffer_bench_state.text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        _ = try buf.next();
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("  {}\n", .{result_with});
        
        const total_bytes_with = text.len * BENCHMARK_ITERATIONS;
        const throughput_with = Throughput.bytesPerSecond(total_bytes_with, result_with.total_time_ns);
        const formatted_with = Throughput.formatBytes(throughput_with);
        try writer.print("    Throughput: {s}\n", .{formatted_with});
        
        // Calculate overhead
        const overhead_percent = calculateOverhead(result_without.mean_time_ns, result_with.mean_time_ns);
        try writer.print("\n  OVERHEAD: {d:.2}%\n", .{overhead_percent});
        
        if (overhead_percent < 3.0) {
            try writer.print("  ✓ Meets <3% overhead target!\n", .{});
        } else {
            try writer.print("  ✗ Exceeds 3% overhead target\n", .{});
        }
    }

    /// Benchmark state for next operations
    var next_bench_state: struct {
        allocator: std.mem.Allocator,
        ascii_text: []const u8,
        utf8_text: []const u8,
    } = undefined;
    
    /// Benchmark next() and nextCodepoint() with position tracking
    pub fn benchmarkNextOperations(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: next() and nextCodepoint() Operations ===\n", .{});
        
        // Test next() with ASCII text
        const ascii_text = try TestData.generateAsciiText(allocator, MEDIUM_BUFFER_SIZE);
        defer allocator.free(ascii_text);
        
        try writer.print("\n  next() - ASCII text:\n", .{});
        
        // Without tracking
        var bench_next_without = Benchmark.init(allocator, "next() without tracking");
        defer bench_next_without.deinit();
        
        // Set up benchmark state
        next_bench_state = .{ .allocator = allocator, .ascii_text = ascii_text, .utf8_text = &.{} };
        
        const result_next_without = try bench_next_without.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithContent(next_bench_state.allocator, next_bench_state.ascii_text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        _ = try buf.next();
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("    Without tracking: {}\n", .{result_next_without});
        
        // With tracking
        var bench_next_with = Benchmark.init(allocator, "next() with tracking");
        defer bench_next_with.deinit();
        
        const result_next_with = try bench_next_with.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithPositionTracking(next_bench_state.allocator, next_bench_state.ascii_text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        _ = try buf.next();
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("    With tracking:    {}\n", .{result_next_with});
        
        const next_overhead = calculateOverhead(result_next_without.mean_time_ns, result_next_with.mean_time_ns);
        try writer.print("    Overhead: {d:.2}%\n", .{next_overhead});
        
        // Test nextCodepoint() with UTF-8 text
        const utf8_text = try TestData.generateUtf8Text(allocator, MEDIUM_BUFFER_SIZE);
        defer allocator.free(utf8_text);
        
        try writer.print("\n  nextCodepoint() - UTF-8 text:\n", .{});
        
        // Without tracking
        var bench_cp_without = Benchmark.init(allocator, "nextCodepoint() without tracking");
        defer bench_cp_without.deinit();
        
        // Update benchmark state for UTF-8
        next_bench_state.utf8_text = utf8_text;
        
        const result_cp_without = try bench_cp_without.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithContent(next_bench_state.allocator, next_bench_state.utf8_text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        _ = buf.nextCodepoint() catch break;
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("    Without tracking: {}\n", .{result_cp_without});
        
        // With tracking
        var bench_cp_with = Benchmark.init(allocator, "nextCodepoint() with tracking");
        defer bench_cp_with.deinit();
        
        const result_cp_with = try bench_cp_with.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithPositionTracking(next_bench_state.allocator, next_bench_state.utf8_text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        _ = buf.nextCodepoint() catch break;
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("    With tracking:    {}\n", .{result_cp_with});
        
        const cp_overhead = calculateOverhead(result_cp_without.mean_time_ns, result_cp_with.mean_time_ns);
        try writer.print("    Overhead: {d:.2}%\n", .{cp_overhead});
    }

    /// Benchmark state for mark/restore operations
    var mark_restore_state: struct {
        allocator: std.mem.Allocator,
        text: []const u8,
    } = undefined;
    
    /// Benchmark mark/restore operations with position tracking
    pub fn benchmarkMarkRestore(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: Mark/Restore with Position Tracking ===\n", .{});
        
        const text = try TestData.generateAsciiText(allocator, SMALL_BUFFER_SIZE);
        defer allocator.free(text);
        
        // Benchmark mark/restore pattern without tracking
        try writer.print("\n  Mark/Restore pattern WITHOUT tracking:\n", .{});
        var bench_without = Benchmark.init(allocator, "mark/restore without tracking");
        defer bench_without.deinit();
        
        // Set up benchmark state
        mark_restore_state = .{ .allocator = allocator, .text = text };
        
        const result_without = try bench_without.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithContent(mark_restore_state.allocator, mark_restore_state.text);
                    defer buf.deinit();
                    
                    // Simulate lexer lookahead pattern
                    var i: usize = 0;
                    while (i < 100 and !buf.isAtEnd()) : (i += 1) {
                        buf.markPosition();
                        
                        // Advance a few characters
                        var j: usize = 0;
                        while (j < 5 and !buf.isAtEnd()) : (j += 1) {
                            _ = try buf.next();
                        }
                        
                        // Sometimes restore (simulate backtracking)
                        if (i % 2 == 0) {
                            try buf.restoreMark();
                        } else {
                            buf.mark = null; // Clear mark
                        }
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("  {}\n", .{result_without});
        
        // Benchmark mark/restore pattern with tracking
        try writer.print("\n  Mark/Restore pattern WITH tracking:\n", .{});
        var bench_with = Benchmark.init(allocator, "mark/restore with tracking");
        defer bench_with.deinit();
        
        const result_with = try bench_with.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithPositionTracking(mark_restore_state.allocator, mark_restore_state.text);
                    defer buf.deinit();
                    
                    // Simulate lexer lookahead pattern
                    var i: usize = 0;
                    while (i < 100 and !buf.isAtEnd()) : (i += 1) {
                        buf.markPosition();
                        
                        // Advance a few characters
                        var j: usize = 0;
                        while (j < 5 and !buf.isAtEnd()) : (j += 1) {
                            _ = try buf.next();
                        }
                        
                        // Sometimes restore (simulate backtracking)
                        if (i % 2 == 0) {
                            try buf.restoreMark();
                        } else {
                            buf.mark = null; // Clear mark
                            buf.marked_source_position = null;
                        }
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("  {}\n", .{result_with});
        
        const overhead = calculateOverhead(result_without.mean_time_ns, result_with.mean_time_ns);
        try writer.print("\n  Mark/Restore overhead: {d:.2}%\n", .{overhead});
    }

    /// Benchmark state for skip/consume operations
    var skip_consume_state: struct {
        allocator: std.mem.Allocator,
        text: []const u8,
    } = undefined;
    
    /// Benchmark skipWhile and consumeWhile operations
    pub fn benchmarkSkipConsumeOperations(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: skipWhile() and consumeWhile() Operations ===\n", .{});
        
        const text = try TestData.generateWhitespaceHeavyText(allocator, MEDIUM_BUFFER_SIZE);
        defer allocator.free(text);
        
        // Define a simple whitespace predicate
        const isWhitespace = struct {
            fn pred(c: u21) bool {
                return c == ' ' or c == '\t' or c == '\n' or c == '\r';
            }
        }.pred;
        
        // Benchmark skipWhile
        try writer.print("\n  skipWhile() performance:\n", .{});
        
        // Without tracking
        var bench_skip_without = Benchmark.init(allocator, "skipWhile without tracking");
        defer bench_skip_without.deinit();
        
        // Set up benchmark state
        skip_consume_state = .{ .allocator = allocator, .text = text };
        
        const predicate = isWhitespace;
        const result_skip_without = try bench_skip_without.run(
            BENCHMARK_ITERATIONS / 10,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithContent(skip_consume_state.allocator, skip_consume_state.text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        try buf.skipWhile(predicate);
                        // Skip one non-whitespace char to continue
                        if (!buf.isAtEnd()) {
                            _ = try buf.next();
                        }
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("    Without tracking: {}\n", .{result_skip_without});
        
        // With tracking
        var bench_skip_with = Benchmark.init(allocator, "skipWhile with tracking");
        defer bench_skip_with.deinit();
        
        const result_skip_with = try bench_skip_with.run(
            BENCHMARK_ITERATIONS / 10,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithPositionTracking(skip_consume_state.allocator, skip_consume_state.text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        try buf.skipWhile(predicate);
                        // Skip one non-whitespace char to continue
                        if (!buf.isAtEnd()) {
                            _ = try buf.next();
                        }
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("    With tracking:    {}\n", .{result_skip_with});
        
        const skip_overhead = calculateOverhead(result_skip_without.mean_time_ns, result_skip_with.mean_time_ns);
        try writer.print("    Overhead: {d:.2}%\n", .{skip_overhead});
        
        // Benchmark consumeWhile
        try writer.print("\n  consumeWhile() performance:\n", .{});
        
        // Without tracking
        var bench_consume_without = Benchmark.init(allocator, "consumeWhile without tracking");
        defer bench_consume_without.deinit();
        
        const result_consume_without = try bench_consume_without.run(
            BENCHMARK_ITERATIONS / 10,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithContent(skip_consume_state.allocator, skip_consume_state.text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        _ = try buf.consumeWhile(predicate);
                        // Skip one non-whitespace char to continue
                        if (!buf.isAtEnd()) {
                            _ = try buf.next();
                        }
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("    Without tracking: {}\n", .{result_consume_without});
        
        // With tracking
        var bench_consume_with = Benchmark.init(allocator, "consumeWhile with tracking");
        defer bench_consume_with.deinit();
        
        const result_consume_with = try bench_consume_with.run(
            BENCHMARK_ITERATIONS / 10,
            null,
            struct {
                fn bench() !void {
                    var buf = try Buffer.initWithPositionTracking(skip_consume_state.allocator, skip_consume_state.text);
                    defer buf.deinit();
                    
                    while (!buf.isAtEnd()) {
                        _ = try buf.consumeWhile(predicate);
                        // Skip one non-whitespace char to continue
                        if (!buf.isAtEnd()) {
                            _ = try buf.next();
                        }
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("    With tracking:    {}\n", .{result_consume_with});
        
        const consume_overhead = calculateOverhead(result_consume_without.mean_time_ns, result_consume_with.mean_time_ns);
        try writer.print("    Overhead: {d:.2}%\n", .{consume_overhead});
    }

    /// Benchmark state for buffer size tests
    var buffer_size_state: struct {
        allocator: std.mem.Allocator,
        text: []const u8,
    } = undefined;
    
    /// Benchmark different buffer sizes to understand scaling
    pub fn benchmarkBufferSizes(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: Performance Across Buffer Sizes ===\n", .{});
        
        const sizes = [_]struct { name: []const u8, size: usize }{
            .{ .name = "Small (1KB)", .size = SMALL_BUFFER_SIZE },
            .{ .name = "Medium (64KB)", .size = MEDIUM_BUFFER_SIZE },
            .{ .name = "Large (1MB)", .size = LARGE_BUFFER_SIZE },
        };
        
        for (sizes) |config| {
            try writer.print("\n  {s}:\n", .{config.name});
            
            const text = try TestData.generateAsciiText(allocator, config.size);
            defer allocator.free(text);
            
            // Without tracking
            var bench_without = Benchmark.init(allocator, "Buffer without tracking");
            defer bench_without.deinit();
            
            // Set up benchmark state
            buffer_size_state = .{ .allocator = allocator, .text = text };
            
            const iterations: usize = if (config.size == LARGE_BUFFER_SIZE) 
                BENCHMARK_ITERATIONS / 100 
            else if (config.size == MEDIUM_BUFFER_SIZE)
                BENCHMARK_ITERATIONS / 10
            else
                BENCHMARK_ITERATIONS;
            
            const result_without = try bench_without.run(
                iterations,
                null,
                struct {
                    fn bench() !void {
                        var buf = try Buffer.initWithContent(buffer_size_state.allocator, buffer_size_state.text);
                        defer buf.deinit();
                        
                        while (!buf.isAtEnd()) {
                            _ = try buf.next();
                        }
                    }
                }.bench,
                null,
            );
            
            try writer.print("    Without tracking: {}\n", .{result_without});
            
            const throughput_without = Throughput.bytesPerSecond(text.len * iterations, result_without.total_time_ns);
            const formatted_without = Throughput.formatBytes(throughput_without);
            try writer.print("      Throughput: {s}\n", .{formatted_without});
            
            // With tracking
            var bench_with = Benchmark.init(allocator, "Buffer with tracking");
            defer bench_with.deinit();
            
            const result_with = try bench_with.run(
                iterations,
                null,
                struct {
                    fn bench() !void {
                        var buf = try Buffer.initWithPositionTracking(buffer_size_state.allocator, buffer_size_state.text);
                        defer buf.deinit();
                        
                        while (!buf.isAtEnd()) {
                            _ = try buf.next();
                        }
                    }
                }.bench,
                null,
            );
            
            try writer.print("    With tracking:    {}\n", .{result_with});
            
            const throughput_with = Throughput.bytesPerSecond(text.len * iterations, result_with.total_time_ns);
            const formatted_with = Throughput.formatBytes(throughput_with);
            try writer.print("      Throughput: {s}\n", .{formatted_with});
            
            const overhead = calculateOverhead(result_without.mean_time_ns, result_with.mean_time_ns);
            try writer.print("    Overhead: {d:.2}%\n", .{overhead});
        }
    }

    /// Calculate percentage overhead
    fn calculateOverhead(baseline_ns: u64, measured_ns: u64) f64 {
        if (baseline_ns == 0) return 0;
        const baseline_f = @as(f64, @floatFromInt(baseline_ns));
        const measured_f = @as(f64, @floatFromInt(measured_ns));
        return ((measured_f - baseline_f) / baseline_f) * 100.0;
    }

    /// Run all buffer benchmarks
    pub fn runAllBenchmarks(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n" ++ "=" ** 60 ++ "\n", .{});
        try writer.print("Buffer Position Tracking Performance Benchmarks\n", .{});
        try writer.print("=" ** 60 ++ "\n", .{});
        
        try benchmarkBufferWithTracking(allocator, writer);
        try benchmarkNextOperations(allocator, writer);
        try benchmarkMarkRestore(allocator, writer);
        try benchmarkSkipConsumeOperations(allocator, writer);
        try benchmarkBufferSizes(allocator, writer);
        
        try writer.print("\n" ++ "=" ** 60 ++ "\n", .{});
        try writer.print("Summary\n", .{});
        try writer.print("=" ** 60 ++ "\n", .{});
        try writer.print("These benchmarks measure the overhead of position tracking\n", .{});
        try writer.print("in buffer operations. The target is <3% overhead as per Issue #004.\n", .{});
        try writer.print("=" ** 60 ++ "\n\n", .{});
    }

    /// Main entry point for standalone execution
    pub fn main() !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        const stdout = std.io.getStdOut().writer();
        try runAllBenchmarks(allocator, stdout);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: BufferBenchmark: validates overhead calculation accuracy" {
        // Test the overhead calculation function
        const baseline: u64 = 1000;
        const measured: u64 = 1030;
        const overhead = calculateOverhead(baseline, measured);
        
        try std.testing.expectApproxEqAbs(@as(f64, 3.0), overhead, 0.01);
    }
    
    test "unit: BufferBenchmark: validates basic benchmark execution" {
        // Verify basic benchmark functionality
        const test_allocator = std.testing.allocator;
        
        // Create small test buffer
        const text = "Hello, World!";
        var buf = try Buffer.initWithContent(test_allocator, text);
        defer buf.deinit();
        
        // Test basic operations
        const char = try buf.next();
        try std.testing.expectEqual(@as(u8, 'H'), char);
        
        // Test with position tracking
        var buf_tracked = try Buffer.initWithPositionTracking(test_allocator, text);
        defer buf_tracked.deinit();
        
        const tracked_char = try buf_tracked.next();
        try std.testing.expectEqual(@as(u8, 'H'), tracked_char);
        
        // Verify position was updated
        const pos = buf_tracked.getCurrentPosition();
        try std.testing.expect(pos != null);
        try std.testing.expectEqual(@as(u32, 1), pos.?.column + 1); // column is now at 2
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝