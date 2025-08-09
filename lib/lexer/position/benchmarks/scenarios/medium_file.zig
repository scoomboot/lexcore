// medium_file.zig — Medium file (1KB-100KB) benchmarks for position tracking
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/position/benchmarks/scenarios
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
    const Timer = perf.Timer;
    const Benchmark = perf.Benchmark;
    const Throughput = perf.Throughput;
    const MemoryTracker = perf.MemoryTracker;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// State variables for benchmarks (declared at module level to avoid capture issues)
    var log_state: struct {
        allocator: std.mem.Allocator,
        test_file: []const u8,
    } = undefined;
    
    var utf8_state: struct {
        allocator: std.mem.Allocator,
        test_file: []const u8,
    } = undefined;

    /// Benchmark configuration for medium files
    const Config = struct {
        const warmup_iterations: usize = 50;
        const benchmark_iterations: usize = 1000;
        const max_overhead_percent: f64 = 3.0; // Target < 3% overhead
        const chunk_size: usize = 4096; // Process in 4KB chunks
    };

    /// Streaming processor interface for benchmarking
    const StreamProcessor = struct {
        allocator: std.mem.Allocator,
        with_positions: bool,
        tracker: ?*PositionTracker,
        stats: ProcessingStats,

        const ProcessingStats = struct {
            lines_processed: usize = 0,
            tokens_processed: usize = 0,
            bytes_processed: usize = 0,
            max_line_length: usize = 0,
            avg_line_length: usize = 0,
        };

        fn init(allocator: std.mem.Allocator, with_positions: bool, tracker: ?*PositionTracker) StreamProcessor {
            return .{
                .allocator = allocator,
                .with_positions = with_positions,
                .tracker = tracker,
                .stats = .{},
            };
        }

        fn processChunk(self: *StreamProcessor, chunk: []const u8) !void {
            var line_start: usize = 0;
            var current_line_length: usize = 0;

            for (chunk, 0..) |c, i| {
                if (self.tracker) |t| {
                    t.advance(c);
                }

                current_line_length += 1;
                self.stats.bytes_processed += 1;

                if (c == '\n') {
                    self.stats.lines_processed += 1;
                    if (current_line_length > self.stats.max_line_length) {
                        self.stats.max_line_length = current_line_length;
                    }
                    
                    // Process the line
                    const line = chunk[line_start..i];
                    self.stats.tokens_processed += try self.countTokensInLine(line);
                    
                    line_start = i + 1;
                    current_line_length = 0;
                }
            }

            // Handle partial line at end of chunk
            if (line_start < chunk.len) {
                const line = chunk[line_start..];
                self.stats.tokens_processed += try self.countTokensInLine(line);
            }

            if (self.stats.lines_processed > 0) {
                self.stats.avg_line_length = self.stats.bytes_processed / self.stats.lines_processed;
            }
        }

        fn countTokensInLine(self: *StreamProcessor, line: []const u8) !usize {
            _ = self;
            var tokens: usize = 0;
            var in_token = false;

            for (line) |c| {
                const is_separator = std.ascii.isWhitespace(c) or 
                                    c == ',' or c == ';' or c == ':' or
                                    c == '(' or c == ')' or c == '[' or c == ']' or
                                    c == '{' or c == '}' or c == '"' or c == '\'';
                
                if (!is_separator and !in_token) {
                    tokens += 1;
                    in_token = true;
                } else if (is_separator) {
                    in_token = false;
                    if (c == '"' or c == '\'' or c == ',' or c == ';') {
                        tokens += 1; // Count separators as tokens too
                    }
                }
            }

            return tokens;
        }
    };

    /// Log file processor for benchmarking
    const LogProcessor = struct {
        allocator: std.mem.Allocator,
        with_positions: bool,
        tracker: ?*PositionTracker,
        log_entries: usize,
        error_count: usize,
        warn_count: usize,

        fn init(allocator: std.mem.Allocator, with_positions: bool, tracker: ?*PositionTracker) LogProcessor {
            return .{
                .allocator = allocator,
                .with_positions = with_positions,
                .tracker = tracker,
                .log_entries = 0,
                .error_count = 0,
                .warn_count = 0,
            };
        }

        fn processLog(self: *LogProcessor, content: []const u8) !void {
            var line_start: usize = 0;
            
            for (content, 0..) |c, i| {
                if (self.tracker) |t| {
                    t.advance(c);
                }

                if (c == '\n') {
                    const line = content[line_start..i];
                    try self.processLogLine(line);
                    line_start = i + 1;
                }
            }

            // Process last line if no trailing newline
            if (line_start < content.len) {
                const line = content[line_start..];
                try self.processLogLine(line);
            }
        }

        fn processLogLine(self: *LogProcessor, line: []const u8) !void {
            self.log_entries += 1;

            // Parse log level
            if (std.mem.indexOf(u8, line, "[ERROR]")) |_| {
                self.error_count += 1;
                if (self.with_positions and self.tracker != null) {
                    // Mark error position for potential reporting
                    try self.tracker.?.mark();
                    _ = self.tracker.?.marks.pop(); // Just marking for overhead measurement
                }
            } else if (std.mem.indexOf(u8, line, "[WARN]")) |_| {
                self.warn_count += 1;
            }

            // Simulate parsing timestamp, component, message
            var field_count: usize = 0;
            var in_brackets = false;
            
            for (line) |c| {
                if (c == '[') {
                    in_brackets = true;
                    field_count += 1;
                } else if (c == ']') {
                    in_brackets = false;
                }
            }
        }
    };

    /// Source code analyzer for benchmarking
    const CodeAnalyzer = struct {
        allocator: std.mem.Allocator,
        with_positions: bool,
        tracker: ?*PositionTracker,
        function_count: usize,
        test_count: usize,
        import_count: usize,
        comment_lines: usize,
        code_lines: usize,
        complexity_score: usize,

        fn init(allocator: std.mem.Allocator, with_positions: bool, tracker: ?*PositionTracker) CodeAnalyzer {
            return .{
                .allocator = allocator,
                .with_positions = with_positions,
                .tracker = tracker,
                .function_count = 0,
                .test_count = 0,
                .import_count = 0,
                .comment_lines = 0,
                .code_lines = 0,
                .complexity_score = 0,
            };
        }

        fn analyze(self: *CodeAnalyzer, source: []const u8) !void {
            var in_comment = false;
            var in_string = false;
            var line_start: usize = 0;
            var brace_depth: usize = 0;

            for (source, 0..) |c, i| {
                if (self.tracker) |t| {
                    t.advance(c);
                }

                // Track string literals
                if (!in_comment and c == '"' and (i == 0 or source[i - 1] != '\\')) {
                    in_string = !in_string;
                }

                // Track comments
                if (!in_string and i + 1 < source.len) {
                    if (c == '/' and source[i + 1] == '/') {
                        in_comment = true;
                    }
                }

                // Track brace depth for complexity
                if (!in_comment and !in_string) {
                    if (c == '{') {
                        brace_depth += 1;
                        if (brace_depth > 3) {
                            self.complexity_score += 1;
                        }
                    } else if (c == '}') {
                        brace_depth -|= 1;
                    }
                }

                // Process line endings
                if (c == '\n') {
                    const line = source[line_start..i];
                    try self.analyzeLine(line);
                    
                    if (in_comment) {
                        self.comment_lines += 1;
                        in_comment = false;
                    } else if (line.len > 0) {
                        self.code_lines += 1;
                    }
                    
                    line_start = i + 1;
                }
            }

            // Process last line
            if (line_start < source.len) {
                const line = source[line_start..];
                try self.analyzeLine(line);
            }
        }

        fn analyzeLine(self: *CodeAnalyzer, line: []const u8) !void {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            
            // Count specific patterns
            if (std.mem.startsWith(u8, trimmed, "pub fn ") or 
                std.mem.startsWith(u8, trimmed, "fn ")) {
                self.function_count += 1;
                if (self.with_positions and self.tracker != null) {
                    // Mark function start position
                    try self.tracker.?.mark();
                    _ = self.tracker.?.marks.pop();
                }
            } else if (std.mem.startsWith(u8, trimmed, "test \"")) {
                self.test_count += 1;
            } else if (std.mem.startsWith(u8, trimmed, "const ") and 
                       std.mem.indexOf(u8, trimmed, "@import") != null) {
                self.import_count += 1;
            }

            // Calculate complexity based on control flow keywords
            const control_flow = [_][]const u8{
                "if ", "else", "while", "for", "switch", "catch", "try"
            };
            
            for (control_flow) |keyword| {
                if (std.mem.indexOf(u8, trimmed, keyword)) |_| {
                    self.complexity_score += 1;
                }
            }
        }
    };

    /// Benchmark state for stream processing
    var stream_state: struct {
        allocator: std.mem.Allocator,
        test_file: []const u8,
    } = undefined;
    
    /// Benchmark streaming file processing
    pub fn benchmarkStreamProcessing(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Medium File: Stream Processing Benchmark ===\n", .{});

        // Load test file
        const test_file = try std.fs.cwd().readFileAlloc(
            allocator,
            "lib/lexer/position/benchmarks/test_data/medium_data.csv",
            1024 * 200 // 200KB max
        );
        defer allocator.free(test_file);

        try writer.print("  File size: {d} KB\n", .{test_file.len / 1024});

        // Set up benchmark state
        stream_state = .{ .allocator = allocator, .test_file = test_file };

        // Benchmark without position tracking
        try writer.print("\n  Without position tracking:\n", .{});
        var benchmark_no_pos = Benchmark.init(allocator, "stream_process_no_positions");
        defer benchmark_no_pos.deinit();

        const result_no_pos = try benchmark_no_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var processor = StreamProcessor.init(stream_state.allocator, false, null);
                    
                    var offset: usize = 0;
                    while (offset < stream_state.test_file.len) {
                        const end = @min(offset + Config.chunk_size, stream_state.test_file.len);
                        try processor.processChunk(stream_state.test_file[offset..end]);
                        offset = end;
                    }
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_no_pos});

        // Benchmark with position tracking
        try writer.print("\n  With position tracking:\n", .{});
        var benchmark_with_pos = Benchmark.init(allocator, "stream_process_with_positions");
        defer benchmark_with_pos.deinit();

        const result_with_pos = try benchmark_with_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(stream_state.allocator);
                    defer tracker.deinit();
                    
                    var processor = StreamProcessor.init(stream_state.allocator, true, &tracker);
                    
                    var offset: usize = 0;
                    while (offset < stream_state.test_file.len) {
                        const end = @min(offset + Config.chunk_size, stream_state.test_file.len);
                        try processor.processChunk(stream_state.test_file[offset..end]);
                        offset = end;
                    }
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_with_pos});

        // Calculate overhead
        const overhead_ns = result_with_pos.mean_time_ns - result_no_pos.mean_time_ns;
        const overhead_percent = (@as(f64, @floatFromInt(overhead_ns)) / @as(f64, @floatFromInt(result_no_pos.mean_time_ns))) * 100.0;
        
        try writer.print("\n  Position tracking overhead:\n", .{});
        try writer.print("    Absolute: {d:.3} µs\n", .{@as(f64, @floatFromInt(overhead_ns)) / 1000.0});
        try writer.print("    Relative: {d:.2}%\n", .{overhead_percent});
        
        if (overhead_percent < Config.max_overhead_percent) {
            try writer.print("    ✓ Within target (<{d}% overhead)\n", .{Config.max_overhead_percent});
        } else {
            try writer.print("    ✗ Exceeds target ({d}% max overhead)\n", .{Config.max_overhead_percent});
        }

        // Calculate throughput
        const bytes_per_iter = test_file.len;
        const throughput_no_pos = Throughput.bytesPerSecond(
            bytes_per_iter * Config.benchmark_iterations,
            result_no_pos.total_time_ns
        );
        const throughput_with_pos = Throughput.bytesPerSecond(
            bytes_per_iter * Config.benchmark_iterations,
            result_with_pos.total_time_ns
        );

        try writer.print("\n  Throughput:\n", .{});
        try writer.print("    Without positions: {s}\n", .{Throughput.formatBytes(throughput_no_pos)});
        try writer.print("    With positions:    {s}\n", .{Throughput.formatBytes(throughput_with_pos)});
    }

    /// Benchmark log file processing
    pub fn benchmarkLogProcessing(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Medium File: Log Processing Benchmark ===\n", .{});

        // Generate or load log file
        var log_content = std.ArrayList(u8).init(allocator);
        defer log_content.deinit();

        // Generate synthetic log data
        const log_levels = [_][]const u8{ "DEBUG", "INFO", "WARN", "ERROR" };
        const components = [_][]const u8{ "parser", "lexer", "buffer", "position" };
        
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();

        for (0..2000) |i| {
            const level = log_levels[random.int(usize) % log_levels.len];
            const component = components[random.int(usize) % components.len];
            
            try log_content.writer().print(
                "[2024-01-15T{d:0>2}:{d:0>2}:{d:0>2}] [{s}] [{s}] Message {d}: ",
                .{ i % 24, i % 60, i % 60, level, component, i }
            );

            // Add variable length message
            const msg_len = 50 + (random.int(usize) % 100);
            for (0..msg_len) |_| {
                const c = 'a' + @as(u8, @intCast(random.int(u8) % 26));
                try log_content.append(c);
                if (random.int(u8) % 10 == 0) try log_content.append(' ');
            }
            try log_content.append('\n');
        }

        const test_file = log_content.items;
        try writer.print("  File size: {d} KB\n", .{test_file.len / 1024});

        // Set up benchmark state
        log_state = .{ .allocator = allocator, .test_file = test_file };

        // Benchmark without position tracking
        try writer.print("\n  Without position tracking:\n", .{});
        var benchmark_no_pos = Benchmark.init(allocator, "log_process_no_positions");
        defer benchmark_no_pos.deinit();

        const result_no_pos = try benchmark_no_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var processor = LogProcessor.init(log_state.allocator, false, null);
                    try processor.processLog(log_state.test_file);
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_no_pos});

        // Benchmark with position tracking
        try writer.print("\n  With position tracking:\n", .{});
        var benchmark_with_pos = Benchmark.init(allocator, "log_process_with_positions");
        defer benchmark_with_pos.deinit();

        const result_with_pos = try benchmark_with_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(log_state.allocator);
                    defer tracker.deinit();
                    
                    var processor = LogProcessor.init(log_state.allocator, true, &tracker);
                    try processor.processLog(log_state.test_file);
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_with_pos});

        // Calculate overhead
        const overhead_ns = result_with_pos.mean_time_ns - result_no_pos.mean_time_ns;
        const overhead_percent = (@as(f64, @floatFromInt(overhead_ns)) / @as(f64, @floatFromInt(result_no_pos.mean_time_ns))) * 100.0;
        
        try writer.print("\n  Position tracking overhead:\n", .{});
        try writer.print("    Absolute: {d:.3} µs\n", .{@as(f64, @floatFromInt(overhead_ns)) / 1000.0});
        try writer.print("    Relative: {d:.2}%\n", .{overhead_percent});
        
        if (overhead_percent < Config.max_overhead_percent) {
            try writer.print("    ✓ Within target (<{d}% overhead)\n", .{Config.max_overhead_percent});
        } else {
            try writer.print("    ✗ Exceeds target ({d}% max overhead)\n", .{Config.max_overhead_percent});
        }
    }

    /// Benchmark state for code analysis
    var code_state: struct {
        allocator: std.mem.Allocator,
        test_file: []const u8,
    } = undefined;
    
    /// Benchmark source code analysis
    pub fn benchmarkCodeAnalysis(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Medium File: Code Analysis Benchmark ===\n", .{});

        // Load test file
        const test_file = try std.fs.cwd().readFileAlloc(
            allocator,
            "lib/lexer/position/benchmarks/test_data/medium_source.zig",
            1024 * 200 // 200KB max
        );
        defer allocator.free(test_file);

        try writer.print("  File size: {d} KB\n", .{test_file.len / 1024});

        // Set up benchmark state
        code_state = .{ .allocator = allocator, .test_file = test_file };

        // Benchmark without position tracking
        try writer.print("\n  Without position tracking:\n", .{});
        var benchmark_no_pos = Benchmark.init(allocator, "code_analyze_no_positions");
        defer benchmark_no_pos.deinit();

        const result_no_pos = try benchmark_no_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var analyzer = CodeAnalyzer.init(code_state.allocator, false, null);
                    try analyzer.analyze(code_state.test_file);
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_no_pos});

        // Benchmark with position tracking
        try writer.print("\n  With position tracking:\n", .{});
        var benchmark_with_pos = Benchmark.init(allocator, "code_analyze_with_positions");
        defer benchmark_with_pos.deinit();

        const result_with_pos = try benchmark_with_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(code_state.allocator);
                    defer tracker.deinit();
                    
                    var analyzer = CodeAnalyzer.init(code_state.allocator, true, &tracker);
                    try analyzer.analyze(code_state.test_file);
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_with_pos});

        // Calculate overhead
        const overhead_ns = result_with_pos.mean_time_ns - result_no_pos.mean_time_ns;
        const overhead_percent = (@as(f64, @floatFromInt(overhead_ns)) / @as(f64, @floatFromInt(result_no_pos.mean_time_ns))) * 100.0;
        
        try writer.print("\n  Position tracking overhead:\n", .{});
        try writer.print("    Absolute: {d:.3} µs\n", .{@as(f64, @floatFromInt(overhead_ns)) / 1000.0});
        try writer.print("    Relative: {d:.2}%\n", .{overhead_percent});
        
        if (overhead_percent < Config.max_overhead_percent) {
            try writer.print("    ✓ Within target (<{d}% overhead)\n", .{Config.max_overhead_percent});
        } else {
            try writer.print("    ✗ Exceeds target ({d}% max overhead)\n", .{Config.max_overhead_percent});
        }

        // Run one analysis to show statistics
        var analyzer = CodeAnalyzer.init(allocator, true, null);
        try analyzer.analyze(test_file);
        
        try writer.print("\n  Code statistics:\n", .{});
        try writer.print("    Functions: {d}\n", .{analyzer.function_count});
        try writer.print("    Tests: {d}\n", .{analyzer.test_count});
        try writer.print("    Imports: {d}\n", .{analyzer.import_count});
        try writer.print("    Code lines: {d}\n", .{analyzer.code_lines});
        try writer.print("    Comment lines: {d}\n", .{analyzer.comment_lines});
        try writer.print("    Complexity score: {d}\n", .{analyzer.complexity_score});
    }

    /// Benchmark UTF-8 content processing
    pub fn benchmarkUtf8Processing(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Medium File: UTF-8 Processing Benchmark ===\n", .{});

        // Load UTF-8 test file
        const test_file = std.fs.cwd().readFileAlloc(
            allocator,
            "lib/lexer/position/benchmarks/test_data/encoding_mixed.txt",
            1024 * 100 // 100KB max
        ) catch |err| {
            if (err == error.FileNotFound) {
                try writer.print("  ⚠️  UTF-8 test file not found, skipping...\n", .{});
                return;
            }
            return err;
        };
        defer allocator.free(test_file);

        try writer.print("  File size: {d} bytes\n", .{test_file.len});

        // Count actual codepoints for accurate stats
        var codepoint_count: usize = 0;
        var iter = std.unicode.Utf8Iterator{ .bytes = test_file, .i = 0 };
        while (iter.nextCodepoint()) |_| {
            codepoint_count += 1;
        }
        try writer.print("  Codepoints: {d}\n", .{codepoint_count});

        // Set up benchmark state
        utf8_state = .{ .allocator = allocator, .test_file = test_file };

        // Benchmark without position tracking
        try writer.print("\n  Without position tracking:\n", .{});
        var benchmark_no_pos = Benchmark.init(allocator, "utf8_process_no_positions");
        defer benchmark_no_pos.deinit();

        const result_no_pos = try benchmark_no_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var utf8_iter = std.unicode.Utf8Iterator{ .bytes = utf8_state.test_file, .i = 0 };
                    var count: usize = 0;
                    while (utf8_iter.nextCodepoint()) |cp| {
                        // Simulate processing
                        if (cp > 127) count += 1;
                    }
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_no_pos});

        // Benchmark with position tracking
        try writer.print("\n  With position tracking:\n", .{});
        var benchmark_with_pos = Benchmark.init(allocator, "utf8_process_with_positions");
        defer benchmark_with_pos.deinit();

        const result_with_pos = try benchmark_with_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(utf8_state.allocator);
                    defer tracker.deinit();
                    
                    var utf8_iter = std.unicode.Utf8Iterator{ .bytes = utf8_state.test_file, .i = 0 };
                    while (utf8_iter.nextCodepoint()) |cp| {
                        tracker.advanceCodepoint(cp);
                    }
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_with_pos});

        // Calculate overhead
        const overhead_ns = result_with_pos.mean_time_ns - result_no_pos.mean_time_ns;
        const overhead_percent = (@as(f64, @floatFromInt(overhead_ns)) / @as(f64, @floatFromInt(result_no_pos.mean_time_ns))) * 100.0;
        
        try writer.print("\n  Position tracking overhead:\n", .{});
        try writer.print("    Absolute: {d:.3} µs\n", .{@as(f64, @floatFromInt(overhead_ns)) / 1000.0});
        try writer.print("    Relative: {d:.2}%\n", .{overhead_percent});
        
        if (overhead_percent < Config.max_overhead_percent) {
            try writer.print("    ✓ Within target (<{d}% overhead)\n", .{Config.max_overhead_percent});
        } else {
            try writer.print("    ✗ Exceeds target ({d}% max overhead)\n", .{Config.max_overhead_percent});
        }
    }

    /// Run all medium file benchmarks
    pub fn runAllBenchmarks(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n" ++ "=" ** 70 ++ "\n", .{});
        try writer.print("Medium File (1KB-100KB) Position Tracking Benchmarks\n", .{});
        try writer.print("=" ** 70 ++ "\n", .{});

        // Ensure test data exists
        var test_data_dir = std.fs.cwd().openDir(
            "lib/lexer/position/benchmarks/test_data",
            .{}
        ) catch |err| {
            if (err == error.FileNotFound) {
                try writer.print("\n⚠️  Test data not found. Please run generate_test_data.zig first.\n", .{});
                return;
            }
            return err;
        };
        defer test_data_dir.close();

        try benchmarkStreamProcessing(allocator, writer);
        try benchmarkLogProcessing(allocator, writer);
        try benchmarkCodeAnalysis(allocator, writer);
        try benchmarkUtf8Processing(allocator, writer);

        try writer.print("\n" ++ "=" ** 70 ++ "\n", .{});
        try writer.print("Medium File Benchmarks Complete\n", .{});
        try writer.print("=" ** 70 ++ "\n\n", .{});
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

    test "unit: MediumFile: validates stream processor handles chunks correctly" {
        const test_allocator = std.testing.allocator;
        
        var tracker = PositionTracker.init(test_allocator);
        defer tracker.deinit();

        var processor = StreamProcessor.init(test_allocator, true, &tracker);
        
        const test_data = "line1\nline2\nline3\n";
        try processor.processChunk(test_data);
        
        try std.testing.expectEqual(@as(usize, 3), processor.stats.lines_processed);
        try std.testing.expectEqual(@as(usize, 18), processor.stats.bytes_processed);
    }

    test "unit: MediumFile: validates log processor counts levels correctly" {
        const test_allocator = std.testing.allocator;
        
        var tracker = PositionTracker.init(test_allocator);
        defer tracker.deinit();

        var processor = LogProcessor.init(test_allocator, true, &tracker);
        
        const test_log = 
            \\[2024-01-15T10:00:00] [INFO] [parser] Starting parse
            \\[2024-01-15T10:00:01] [ERROR] [lexer] Unexpected token
            \\[2024-01-15T10:00:02] [WARN] [buffer] Buffer nearly full
            \\[2024-01-15T10:00:03] [ERROR] [parser] Parse failed
            \\
        ;
        
        try processor.processLog(test_log);
        
        try std.testing.expectEqual(@as(usize, 4), processor.log_entries);
        try std.testing.expectEqual(@as(usize, 2), processor.error_count);
        try std.testing.expectEqual(@as(usize, 1), processor.warn_count);
    }

    test "unit: MediumFile: validates code analyzer detects patterns" {
        const test_allocator = std.testing.allocator;
        
        var analyzer = CodeAnalyzer.init(test_allocator, false, null);
        
        const test_code = 
            \\const std = @import("std");
            \\
            \\pub fn main() !void {
            \\    // Comment line
            \\    if (true) {
            \\        while (false) {}
            \\    }
            \\}
            \\
            \\test "example test" {
            \\    try std.testing.expect(true);
            \\}
            \\
        ;
        
        try analyzer.analyze(test_code);
        
        try std.testing.expectEqual(@as(usize, 1), analyzer.function_count);
        try std.testing.expectEqual(@as(usize, 1), analyzer.test_count);
        try std.testing.expectEqual(@as(usize, 1), analyzer.import_count);
        try std.testing.expect(analyzer.complexity_score > 0);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝