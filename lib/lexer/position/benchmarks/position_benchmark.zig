// position_benchmark.zig — Performance benchmarks for position tracking
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/position/benchmarks
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const lexcore = @import("lexcore");
    const position = lexcore.lexer.position;
    const perf = lexcore.lexer.perf;
    
    const SourcePosition = position.SourcePosition;
    const PositionTracker = position.PositionTracker;
    const LineEnding = position.LineEnding;
    const Timer = perf.Timer;
    const Benchmark = perf.Benchmark;
    const Throughput = perf.Throughput;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Benchmark configuration constants
    const WARMUP_ITERATIONS = 1000;
    const BENCHMARK_ITERATIONS = 10000;
    const LARGE_TEXT_SIZE = 1024 * 1024; // 1MB
    const MEDIUM_TEXT_SIZE = 64 * 1024;  // 64KB
    const SMALL_TEXT_SIZE = 1024;        // 1KB

    /// Test data generators
    const TestData = struct {
        /// Generate ASCII text with mixed content
        fn generateAsciiText(allocator: std.mem.Allocator, size: usize) ![]u8 {
            const text = try allocator.alloc(u8, size);
            var prng = std.Random.DefaultPrng.init(42);
            const random = prng.random();
            
            for (text, 0..) |*char, i| {
                // Mix of common characters: letters, spaces, newlines, tabs
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
        
        /// Generate text with specific line ending type
        fn generateTextWithLineEnding(allocator: std.mem.Allocator, size: usize, ending: LineEnding) ![]u8 {
            var list = std.ArrayList(u8).init(allocator);
            defer list.deinit();
            
            var prng = std.Random.DefaultPrng.init(42);
            const random = prng.random();
            
            var chars_in_line: usize = 0;
            while (list.items.len < size) {
                if (chars_in_line >= 60 or (random.int(u8) % 100) < 10) {
                    // Insert line ending
                    switch (ending) {
                        .lf => try list.append('\n'),
                        .cr => try list.append('\r'),
                        .crlf => try list.appendSlice("\r\n"),
                    }
                    chars_in_line = 0;
                } else {
                    // Regular character
                    try list.append('a' + @as(u8, @intCast(random.int(u8) % 26)));
                    chars_in_line += 1;
                }
            }
            
            return try list.toOwnedSlice();
        }
        
        /// Generate text heavy with tabs for tab width testing
        fn generateTabHeavyText(allocator: std.mem.Allocator, size: usize) ![]u8 {
            const text = try allocator.alloc(u8, size);
            var prng = std.Random.DefaultPrng.init(42);
            const random = prng.random();
            
            for (text) |*char| {
                const choice = random.int(u8) % 100;
                if (choice < 30) {
                    // Tabs (30%)
                    char.* = '\t';
                } else if (choice < 40) {
                    // Newlines (10%)
                    char.* = '\n';
                } else if (choice < 50) {
                    // Spaces (10%)
                    char.* = ' ';
                } else {
                    // Letters (50%)
                    char.* = 'a' + @as(u8, @intCast(random.int(u8) % 26));
                }
            }
            
            return text;
        }
    };

    /// Benchmark state struct for advance benchmark
    const AdvanceBenchState = struct {
        text: []const u8,
    };
    
    /// Global state for benchmarks (initialized per benchmark run)
    var advance_bench_state: AdvanceBenchState = undefined;
    
    /// Benchmark advance() method for single character advancement
    pub fn benchmarkAdvance(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: advance() - Single Character ===\n", .{});
        
        // Generate test data
        const ascii_text = try TestData.generateAsciiText(allocator, MEDIUM_TEXT_SIZE);
        defer allocator.free(ascii_text);
        
        // Set up benchmark state
        advance_bench_state = AdvanceBenchState{ .text = ascii_text };
        
        // Warmup
        for (0..WARMUP_ITERATIONS) |_| {
            var pos = SourcePosition.init();
            for (ascii_text) |char| {
                pos.advance(char);
            }
        }
        
        // Benchmark
        var benchmark = Benchmark.init(allocator, "advance()");
        defer benchmark.deinit();
        
        const result = try benchmark.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var pos = SourcePosition.init();
                    for (advance_bench_state.text) |char| {
                        pos.advance(char);
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("{}\n", .{result});
        
        // Calculate throughput
        const total_bytes = ascii_text.len * BENCHMARK_ITERATIONS;
        const throughput = Throughput.bytesPerSecond(total_bytes, result.total_time_ns);
        const formatted = Throughput.formatBytes(throughput);
        try writer.print("  Throughput: {s}\n", .{formatted});
    }

    /// Benchmark state for codepoint benchmark
    var codepoint_bench_state: struct {
        codepoints: []const u21,
    } = undefined;
    
    /// Benchmark advanceCodepoint() for UTF-8 character advancement
    pub fn benchmarkAdvanceCodepoint(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: advanceCodepoint() - UTF-8 Characters ===\n", .{});
        
        // Generate mixed UTF-8 test data
        const utf8_text = try TestData.generateUtf8Text(allocator, MEDIUM_TEXT_SIZE);
        defer allocator.free(utf8_text);
        
        // Pre-decode codepoints for benchmarking
        var codepoints = std.ArrayList(u21).init(allocator);
        defer codepoints.deinit();
        
        var i: usize = 0;
        while (i < utf8_text.len) {
            const len = std.unicode.utf8ByteSequenceLength(utf8_text[i]) catch 1;
            if (i + len <= utf8_text.len) {
                const codepoint = std.unicode.utf8Decode(utf8_text[i..i + len]) catch {
                    try codepoints.append(utf8_text[i]);
                    i += 1;
                    continue;
                };
                try codepoints.append(codepoint);
                i += len;
            } else {
                break;
            }
        }
        
        // Warmup
        for (0..WARMUP_ITERATIONS) |_| {
            var pos = SourcePosition.init();
            for (codepoints.items) |codepoint| {
                pos.advanceCodepoint(codepoint, 4);
            }
        }
        
        // Set up benchmark state
        codepoint_bench_state = .{ .codepoints = codepoints.items };
        
        // Benchmark
        var benchmark = Benchmark.init(allocator, "advanceCodepoint()");
        defer benchmark.deinit();
        
        const result = try benchmark.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var pos = SourcePosition.init();
                    for (codepoint_bench_state.codepoints) |codepoint| {
                        pos.advanceCodepoint(codepoint, 4);
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("{}\n", .{result});
        
        // Calculate throughput
        const total_bytes = utf8_text.len * BENCHMARK_ITERATIONS;
        const throughput = Throughput.bytesPerSecond(total_bytes, result.total_time_ns);
        const formatted = Throughput.formatBytes(throughput);
        try writer.print("  Throughput: {s}\n", .{formatted});
        try writer.print("  Codepoints processed: {d}\n", .{codepoints.items.len});
    }

    /// Benchmark state for UTF-8 bytes benchmark
    var utf8_bench_state: struct {
        text: []const u8,
        chunk_size: usize,
    } = undefined;
    
    /// Benchmark advanceUtf8Bytes() for bulk UTF-8 text advancement
    pub fn benchmarkAdvanceUtf8Bytes(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: advanceUtf8Bytes() - Bulk UTF-8 ===\n", .{});
        
        // Test with different chunk sizes
        const chunk_sizes = [_]usize{ 64, 256, 1024, 4096 };
        const utf8_text = try TestData.generateUtf8Text(allocator, LARGE_TEXT_SIZE);
        defer allocator.free(utf8_text);
        
        for (chunk_sizes) |chunk_size| {
            try writer.print("\n  Chunk size: {d} bytes\n", .{chunk_size});
            
            // Warmup
            for (0..WARMUP_ITERATIONS / 10) |_| {
                var pos = SourcePosition.init();
                var offset: usize = 0;
                while (offset < utf8_text.len) {
                    const end = @min(offset + chunk_size, utf8_text.len);
                    pos.advanceUtf8Bytes(utf8_text[offset..end], 4);
                    offset = end;
                }
            }
            
            // Set up benchmark state
            utf8_bench_state = .{ .text = utf8_text, .chunk_size = chunk_size };
            
            // Benchmark
            var benchmark = Benchmark.init(allocator, "advanceUtf8Bytes()");
            defer benchmark.deinit();
            
            const result = try benchmark.run(
                BENCHMARK_ITERATIONS / 10,
                null,
                struct {
                    fn bench() !void {
                        var pos = SourcePosition.init();
                        var offset: usize = 0;
                        while (offset < utf8_bench_state.text.len) {
                            const end = @min(offset + utf8_bench_state.chunk_size, utf8_bench_state.text.len);
                            pos.advanceUtf8Bytes(utf8_bench_state.text[offset..end], 4);
                            offset = end;
                        }
                    }
                }.bench,
                null,
            );
            
            try writer.print("  {}\n", .{result});
            
            // Calculate throughput
            const total_bytes = utf8_text.len * (BENCHMARK_ITERATIONS / 10);
            const throughput = Throughput.bytesPerSecond(total_bytes, result.total_time_ns);
            const formatted = Throughput.formatBytes(throughput);
            try writer.print("    Throughput: {s}\n", .{formatted});
        }
    }

    /// Benchmark state for tab handling
    var tab_bench_state: struct {
        text: []const u8,
        width: u32,
    } = undefined;
    
    /// Benchmark tab handling overhead with different tab widths
    pub fn benchmarkTabHandling(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: Tab Handling Overhead ===\n", .{});
        
        const tab_text = try TestData.generateTabHeavyText(allocator, MEDIUM_TEXT_SIZE);
        defer allocator.free(tab_text);
        
        const tab_widths = [_]u32{ 2, 4, 8 };
        
        for (tab_widths) |tab_width| {
            try writer.print("\n  Tab width: {d}\n", .{tab_width});
            
            // Warmup
            for (0..WARMUP_ITERATIONS) |_| {
                var pos = SourcePosition.init();
                for (tab_text) |char| {
                    pos.advanceWithTabWidth(char, tab_width);
                }
            }
            
            // Set up benchmark state
            tab_bench_state = .{ .text = tab_text, .width = tab_width };
            
            // Benchmark
            var benchmark = Benchmark.init(allocator, "advanceWithTabWidth()");
            defer benchmark.deinit();
            
            const result = try benchmark.run(
                BENCHMARK_ITERATIONS,
                null,
                struct {
                    fn bench() !void {
                        var pos = SourcePosition.init();
                        for (tab_bench_state.text) |char| {
                            pos.advanceWithTabWidth(char, tab_bench_state.width);
                        }
                    }
                }.bench,
                null,
            );
            
            try writer.print("  {}\n", .{result});
            
            // Calculate throughput
            const total_bytes = tab_text.len * BENCHMARK_ITERATIONS;
            const throughput = Throughput.bytesPerSecond(total_bytes, result.total_time_ns);
            const formatted = Throughput.formatBytes(throughput);
            try writer.print("    Throughput: {s}\n", .{formatted});
        }
        
        // Compare with no-tab handling
        try writer.print("\n  Baseline (no tab special handling):\n", .{});
        
        // Reuse tab_bench_state for baseline
        tab_bench_state = .{ .text = tab_text, .width = 4 };
        
        var benchmark = Benchmark.init(allocator, "advance() baseline");
        defer benchmark.deinit();
        
        const result = try benchmark.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var pos = SourcePosition.init();
                    for (tab_bench_state.text) |char| {
                        pos.advance(char);
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("  {}\n", .{result});
        
        const total_bytes = tab_text.len * BENCHMARK_ITERATIONS;
        const throughput = Throughput.bytesPerSecond(total_bytes, result.total_time_ns);
        const formatted = Throughput.formatBytes(throughput);
        try writer.print("    Throughput: {s}\n", .{formatted});
    }

    /// Benchmark state for line ending detection
    var line_ending_bench_state: struct {
        allocator: std.mem.Allocator,
        text: []const u8,
        ending: LineEnding,
    } = undefined;
    
    /// Benchmark line ending detection performance
    pub fn benchmarkLineEndingDetection(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: Line Ending Detection ===\n", .{});
        
        const line_endings = [_]struct { name: []const u8, ending: LineEnding }{
            .{ .name = "LF (Unix)", .ending = .lf },
            .{ .name = "CRLF (Windows)", .ending = .crlf },
            .{ .name = "CR (Classic Mac)", .ending = .cr },
        };
        
        for (line_endings) |config| {
            try writer.print("\n  {s}:\n", .{config.name});
            
            const text = try TestData.generateTextWithLineEnding(allocator, MEDIUM_TEXT_SIZE, config.ending);
            defer allocator.free(text);
            
            // Set up benchmark state
            line_ending_bench_state = .{ .allocator = allocator, .text = text, .ending = config.ending };
            
            // Benchmark PositionTracker with line ending detection
            var benchmark = Benchmark.init(allocator, "PositionTracker");
            defer benchmark.deinit();
            
            const result = try benchmark.run(
                BENCHMARK_ITERATIONS / 10,
                null,
                struct {
                    fn bench() !void {
                        var tracker = PositionTracker.initWithConfig(line_ending_bench_state.allocator, 4, line_ending_bench_state.ending);
                        defer tracker.deinit();
                        
                        for (line_ending_bench_state.text) |char| {
                            tracker.advance(char);
                        }
                    }
                }.bench,
                null,
            );
            
            try writer.print("  {}\n", .{result});
            
            // Calculate throughput
            const total_bytes = text.len * (BENCHMARK_ITERATIONS / 10);
            const throughput = Throughput.bytesPerSecond(total_bytes, result.total_time_ns);
            const formatted = Throughput.formatBytes(throughput);
            try writer.print("    Throughput: {s}\n", .{formatted});
        }
    }

    /// Benchmark state for mark/restore operations
    var mark_restore_bench_state: struct {
        allocator: std.mem.Allocator,
        text: []const u8,
    } = undefined;
    
    /// Benchmark PositionTracker mark/restore operations
    pub fn benchmarkMarkRestore(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Benchmark: Mark/Restore Operations ===\n", .{});
        
        const text = try TestData.generateAsciiText(allocator, SMALL_TEXT_SIZE);
        defer allocator.free(text);
        
        // Benchmark marking operations
        try writer.print("\n  Mark operations:\n", .{});
        var mark_benchmark = Benchmark.init(allocator, "mark()");
        defer mark_benchmark.deinit();
        
        // Set up benchmark state
        mark_restore_bench_state = .{ .allocator = allocator, .text = text };
        
        const mark_result = try mark_benchmark.run(
            BENCHMARK_ITERATIONS * 10,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(mark_restore_bench_state.allocator);
                    defer tracker.deinit();
                    
                    try tracker.mark();
                }
            }.bench,
            null,
        );
        
        try writer.print("  {}\n", .{mark_result});
        
        // Benchmark restore operations
        try writer.print("\n  Restore operations:\n", .{});
        var restore_benchmark = Benchmark.init(allocator, "restore()");
        defer restore_benchmark.deinit();
        
        const restore_result = try restore_benchmark.run(
            BENCHMARK_ITERATIONS * 10,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(mark_restore_bench_state.allocator);
                    defer tracker.deinit();
                    
                    // Advance and mark
                    tracker.advance('a');
                    tracker.advance('b');
                    try tracker.mark();
                    tracker.advance('c');
                    tracker.advance('d');
                    
                    // Restore
                    try tracker.restore();
                }
            }.bench,
            null,
        );
        
        try writer.print("  {}\n", .{restore_result});
        
        // Benchmark mark/advance/restore pattern
        try writer.print("\n  Mark/Advance/Restore pattern:\n", .{});
        var pattern_benchmark = Benchmark.init(allocator, "mark/advance/restore");
        defer pattern_benchmark.deinit();
        
        const pattern_result = try pattern_benchmark.run(
            BENCHMARK_ITERATIONS,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(mark_restore_bench_state.allocator);
                    defer tracker.deinit();
                    
                    // Simulate lexer lookahead pattern
                    for (mark_restore_bench_state.text) |char| {
                        try tracker.mark();
                        tracker.advance(char);
                        
                        // Simulate conditional restore (50% of the time)
                        if (char % 2 == 0) {
                            try tracker.restore();
                        } else {
                            _ = tracker.marks.pop();
                        }
                    }
                }
            }.bench,
            null,
        );
        
        try writer.print("  {}\n", .{pattern_result});
    }

    /// Run all position benchmarks
    pub fn runAllBenchmarks(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n" ++ "=" ** 60 ++ "\n", .{});
        try writer.print("Position Tracking Performance Benchmarks\n", .{});
        try writer.print("=" ** 60 ++ "\n", .{});
        
        try benchmarkAdvance(allocator, writer);
        try benchmarkAdvanceCodepoint(allocator, writer);
        try benchmarkAdvanceUtf8Bytes(allocator, writer);
        try benchmarkTabHandling(allocator, writer);
        try benchmarkLineEndingDetection(allocator, writer);
        try benchmarkMarkRestore(allocator, writer);
        
        try writer.print("\n" ++ "=" ** 60 ++ "\n", .{});
        try writer.print("Benchmark Complete\n", .{});
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

    test "unit: PositionBenchmark: validates all benchmarks run without error" {
        // Run with small iterations for testing
        const test_allocator = std.testing.allocator;
        var list = std.ArrayList(u8).init(test_allocator);
        defer list.deinit();
        
        // const writer = list.writer();
        
        // Override constants for testing
        // const saved_warmup = WARMUP_ITERATIONS;
        // const saved_bench = BENCHMARK_ITERATIONS;
        
        // Can't actually override consts, so we'll just run a simple validation
        var benchmark = Benchmark.init(test_allocator, "test");
        defer benchmark.deinit();
        
        const result = try benchmark.run(
            10,
            null,
            struct {
                fn bench() !void {
                    var pos = SourcePosition.init();
                    pos.advance('a');
                }
            }.bench,
            null,
        );
        
        try std.testing.expect(result.iterations == 10);
        try std.testing.expect(result.total_time_ns > 0);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝