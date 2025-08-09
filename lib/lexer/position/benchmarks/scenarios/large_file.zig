// large_file.zig — Large file (100KB-10MB) benchmarks for position tracking
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

    /// Benchmark state for large log processing
    var log_state: struct {
        allocator: std.mem.Allocator,
        test_file: []const u8,
    } = undefined;
    
    /// Benchmark state for incremental JSON parsing
    var json_state: struct {
        allocator: std.mem.Allocator,
        test_file: []const u8,
    } = undefined;

    /// Benchmark configuration for large files
    const Config = struct {
        const warmup_iterations: usize = 5;
        const benchmark_iterations: usize = 100;
        const max_overhead_percent: f64 = 3.0; // Target < 3% overhead
        const chunk_size: usize = 16384; // Process in 16KB chunks
        const sample_interval: usize = 1000; // Sample every N items for statistics
    };

    /// Large file processor with statistics
    const LargeFileProcessor = struct {
        allocator: std.mem.Allocator,
        with_positions: bool,
        tracker: ?*PositionTracker,
        stats: FileStats,
        sample_positions: std.ArrayList(SourcePosition),

        const FileStats = struct {
            total_bytes: usize = 0,
            total_lines: usize = 0,
            total_tokens: usize = 0,
            max_line_length: usize = 0,
            chunks_processed: usize = 0,
            processing_time_ns: u64 = 0,
        };

        fn init(allocator: std.mem.Allocator, with_positions: bool, tracker: ?*PositionTracker) !LargeFileProcessor {
            return .{
                .allocator = allocator,
                .with_positions = with_positions,
                .tracker = tracker,
                .stats = .{},
                .sample_positions = std.ArrayList(SourcePosition).init(allocator),
            };
        }

        fn deinit(self: *LargeFileProcessor) void {
            self.sample_positions.deinit();
        }

        fn processFile(self: *LargeFileProcessor, content: []const u8) !void {
            const timer = Timer.start();
            defer {
                self.stats.processing_time_ns = timer.elapsedNanos();
            }

            var offset: usize = 0;
            while (offset < content.len) {
                const chunk_end = @min(offset + Config.chunk_size, content.len);
                try self.processChunk(content[offset..chunk_end]);
                offset = chunk_end;
                self.stats.chunks_processed += 1;
            }
        }

        fn processChunk(self: *LargeFileProcessor, chunk: []const u8) !void {
            var current_line_length: usize = 0;
            
            for (chunk) |c| {
                self.stats.total_bytes += 1;
                
                if (self.tracker) |t| {
                    t.advance(c);
                    
                    // Sample positions at intervals
                    if (self.with_positions and 
                        self.stats.total_bytes % Config.sample_interval == 0) {
                        try self.sample_positions.append(t.current);
                    }
                }

                current_line_length += 1;

                // Track line statistics
                if (c == '\n') {
                    self.stats.total_lines += 1;
                    if (current_line_length > self.stats.max_line_length) {
                        self.stats.max_line_length = current_line_length;
                    }
                    current_line_length = 0;
                }

                // Simple token counting (whitespace-separated)
                if (std.ascii.isWhitespace(c)) {
                    self.stats.total_tokens += 1;
                }
            }
        }

        fn getAverageLineLength(self: *const LargeFileProcessor) usize {
            if (self.stats.total_lines == 0) return 0;
            return self.stats.total_bytes / self.stats.total_lines;
        }

        fn getThroughput(self: *const LargeFileProcessor) f64 {
            return Throughput.bytesPerSecond(self.stats.total_bytes, self.stats.processing_time_ns);
        }
    };

    /// Incremental parser for large JSON arrays
    const IncrementalJsonParser = struct {
        allocator: std.mem.Allocator,
        with_positions: bool,
        tracker: ?*PositionTracker,
        state: ParserState,
        depth: usize,
        object_count: usize,
        array_count: usize,
        string_count: usize,
        number_count: usize,
        error_positions: std.ArrayList(SourcePosition),

        const ParserState = enum {
            initial,
            in_object,
            in_array,
            in_string,
            in_number,
            in_value,
            expecting_comma,
            complete,
        };

        fn init(allocator: std.mem.Allocator, with_positions: bool, tracker: ?*PositionTracker) !IncrementalJsonParser {
            return .{
                .allocator = allocator,
                .with_positions = with_positions,
                .tracker = tracker,
                .state = .initial,
                .depth = 0,
                .object_count = 0,
                .array_count = 0,
                .string_count = 0,
                .number_count = 0,
                .error_positions = std.ArrayList(SourcePosition).init(allocator),
            };
        }

        fn deinit(self: *IncrementalJsonParser) void {
            self.error_positions.deinit();
        }

        fn parseIncremental(self: *IncrementalJsonParser, content: []const u8) !void {
            var in_string = false;
            var escape_next = false;

            for (content) |c| {
                if (self.tracker) |t| {
                    t.advance(c);
                }

                // Handle string content
                if (in_string) {
                    if (escape_next) {
                        escape_next = false;
                        continue;
                    }
                    if (c == '\\') {
                        escape_next = true;
                        continue;
                    }
                    if (c == '"') {
                        in_string = false;
                        self.string_count += 1;
                    }
                    continue;
                }

                // Handle structural characters
                switch (c) {
                    '{' => {
                        self.depth += 1;
                        self.object_count += 1;
                        if (self.with_positions and self.tracker != null) {
                            try self.tracker.?.mark();
                            _ = self.tracker.?.marks.pop(); // Just for overhead measurement
                        }
                    },
                    '}' => {
                        if (self.depth == 0) {
                            if (self.with_positions and self.tracker != null) {
                                try self.error_positions.append(self.tracker.?.current);
                            }
                        } else {
                            self.depth -= 1;
                        }
                    },
                    '[' => {
                        self.depth += 1;
                        self.array_count += 1;
                    },
                    ']' => {
                        if (self.depth > 0) {
                            self.depth -= 1;
                        }
                    },
                    '"' => {
                        in_string = true;
                    },
                    '0'...'9', '-' => {
                        self.number_count += 1;
                    },
                    else => {},
                }
            }
        }

        fn getStatsSummary(self: *const IncrementalJsonParser) void {
            std.debug.print("    Objects: {d}, Arrays: {d}, Strings: {d}, Numbers: {d}\n", 
                .{ self.object_count, self.array_count, self.string_count, self.number_count });
            if (self.error_positions.items.len > 0) {
                std.debug.print("    Potential errors detected: {d}\n", .{self.error_positions.items.len});
            }
        }
    };

    /// Parallel chunk processor for stress testing
    const ParallelProcessor = struct {
        allocator: std.mem.Allocator,
        with_positions: bool,
        thread_count: usize,
        chunks_per_thread: []usize,
        
        const ThreadContext = struct {
            id: usize,
            content: []const u8,
            with_positions: bool,
            result: ProcessResult,
        };

        const ProcessResult = struct {
            bytes_processed: usize = 0,
            lines_counted: usize = 0,
            time_ns: u64 = 0,
        };

        fn init(allocator: std.mem.Allocator, with_positions: bool, thread_count: usize) !ParallelProcessor {
            return .{
                .allocator = allocator,
                .with_positions = with_positions,
                .thread_count = thread_count,
                .chunks_per_thread = try allocator.alloc(usize, thread_count),
            };
        }

        fn deinit(self: *ParallelProcessor) void {
            self.allocator.free(self.chunks_per_thread);
        }

        fn processParallel(self: *ParallelProcessor, content: []const u8) !ProcessResult {
            const chunk_size = content.len / self.thread_count;
            var contexts = try self.allocator.alloc(ThreadContext, self.thread_count);
            defer self.allocator.free(contexts);

            var threads = try self.allocator.alloc(std.Thread, self.thread_count);
            defer self.allocator.free(threads);

            // Create thread contexts
            for (0..self.thread_count) |i| {
                const start = i * chunk_size;
                const end = if (i == self.thread_count - 1) content.len else (i + 1) * chunk_size;
                
                contexts[i] = .{
                    .id = i,
                    .content = content[start..end],
                    .with_positions = self.with_positions,
                    .result = .{},
                };
            }

            // Spawn threads
            for (0..self.thread_count) |i| {
                threads[i] = try std.Thread.spawn(.{}, processChunk, .{&contexts[i]});
            }

            // Wait for completion
            for (threads) |thread| {
                thread.join();
            }

            // Aggregate results
            var total_result = ProcessResult{};
            for (contexts) |ctx| {
                total_result.bytes_processed += ctx.result.bytes_processed;
                total_result.lines_counted += ctx.result.lines_counted;
                total_result.time_ns = @max(total_result.time_ns, ctx.result.time_ns);
            }

            return total_result;
        }

        fn processChunk(ctx: *ThreadContext) void {
            const timer = Timer.start();
            defer {
                ctx.result.time_ns = timer.elapsedNanos();
            }

            var tracker: ?PositionTracker = if (ctx.with_positions) 
                PositionTracker.init(std.heap.page_allocator) 
            else 
                null;
            defer if (tracker) |*t| t.deinit();

            for (ctx.content) |c| {
                ctx.result.bytes_processed += 1;
                
                if (tracker) |*t| {
                    t.advance(c);
                }
                
                if (c == '\n') {
                    ctx.result.lines_counted += 1;
                }
            }
        }
    };

    /// Benchmark large log file processing
    pub fn benchmarkLargeLogProcessing(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Large File: Log Processing Benchmark ===\n", .{});

        // Try to load actual large log file, or generate one
        const test_file = blk: {
            const file_content = std.fs.cwd().readFileAlloc(
                allocator,
                "lib/lexer/position/benchmarks/test_data/large_log.txt",
                1024 * 1024 * 15 // 15MB max
            ) catch |err| {
                if (err == error.FileNotFound) {
                    try writer.print("  ⚠️  Large log file not found, generating synthetic data...\n", .{});
                    
                    // Generate synthetic log
                    const log_data = try allocator.alloc(u8, 1024 * 1024); // 1MB
                    
                    var prng = std.Random.DefaultPrng.init(42);
                    const random = prng.random();
                    
                    for (log_data) |*byte| {
                        const choice = random.int(u8) % 100;
                        if (choice < 70) {
                            byte.* = 'a' + @as(u8, @intCast(random.int(u8) % 26));
                        } else if (choice < 85) {
                            byte.* = ' ';
                        } else {
                            byte.* = '\n';
                        }
                    }
                    
                    break :blk log_data;
                }
                return err;
            };
            break :blk file_content;
        };
        defer allocator.free(test_file);

        try writer.print("  File size: {d:.2} MB\n", .{@as(f64, @floatFromInt(test_file.len)) / (1024.0 * 1024.0)});

        // Set up benchmark state
        log_state = .{ .allocator = allocator, .test_file = test_file };

        // Benchmark without position tracking
        try writer.print("\n  Without position tracking:\n", .{});
        var benchmark_no_pos = Benchmark.init(allocator, "large_log_no_positions");
        defer benchmark_no_pos.deinit();

        const result_no_pos = try benchmark_no_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var processor = try LargeFileProcessor.init(log_state.allocator, false, null);
                    defer processor.deinit();
                    try processor.processFile(log_state.test_file);
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_no_pos});

        // Benchmark with position tracking
        try writer.print("\n  With position tracking:\n", .{});
        var benchmark_with_pos = Benchmark.init(allocator, "large_log_with_positions");
        defer benchmark_with_pos.deinit();

        const result_with_pos = try benchmark_with_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(log_state.allocator);
                    defer tracker.deinit();
                    
                    var processor = try LargeFileProcessor.init(log_state.allocator, true, &tracker);
                    defer processor.deinit();
                    try processor.processFile(log_state.test_file);
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_with_pos});

        // Calculate overhead
        const overhead_ns = result_with_pos.mean_time_ns - result_no_pos.mean_time_ns;
        const overhead_percent = (@as(f64, @floatFromInt(overhead_ns)) / @as(f64, @floatFromInt(result_no_pos.mean_time_ns))) * 100.0;
        
        try writer.print("\n  Position tracking overhead:\n", .{});
        try writer.print("    Absolute: {d:.3} ms\n", .{@as(f64, @floatFromInt(overhead_ns)) / 1_000_000.0});
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

        // Show file statistics
        var stats_processor = try LargeFileProcessor.init(allocator, true, null);
        defer stats_processor.deinit();
        try stats_processor.processFile(test_file);
        
        try writer.print("\n  File statistics:\n", .{});
        try writer.print("    Total lines: {d}\n", .{stats_processor.stats.total_lines});
        try writer.print("    Avg line length: {d} bytes\n", .{stats_processor.getAverageLineLength()});
        try writer.print("    Max line length: {d} bytes\n", .{stats_processor.stats.max_line_length});
        try writer.print("    Chunks processed: {d}\n", .{stats_processor.stats.chunks_processed});
    }

    /// Benchmark incremental JSON parsing
    pub fn benchmarkIncrementalJsonParsing(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Large File: Incremental JSON Parsing ===\n", .{});

        // Try to load large JSON file
        const test_file = std.fs.cwd().readFileAlloc(
            allocator,
            "lib/lexer/position/benchmarks/test_data/large_data.json",
            1024 * 1024 * 10 // 10MB max
        ) catch |err| {
            if (err == error.FileNotFound) {
                try writer.print("  ⚠️  Large JSON file not found, skipping...\n", .{});
                return;
            }
            return err;
        };
        defer allocator.free(test_file);

        try writer.print("  File size: {d:.2} MB\n", .{@as(f64, @floatFromInt(test_file.len)) / (1024.0 * 1024.0)});

        // Set up benchmark state
        json_state = .{ .allocator = allocator, .test_file = test_file };

        // Benchmark without position tracking
        try writer.print("\n  Without position tracking:\n", .{});
        var benchmark_no_pos = Benchmark.init(allocator, "json_incremental_no_positions");
        defer benchmark_no_pos.deinit();

        const result_no_pos = try benchmark_no_pos.run(
            Config.benchmark_iterations / 10, // Fewer iterations for large files
            null,
            struct {
                fn bench() !void {
                    var parser = try IncrementalJsonParser.init(json_state.allocator, false, null);
                    defer parser.deinit();
                    
                    var offset: usize = 0;
                    while (offset < json_state.test_file.len) {
                        const chunk_end = @min(offset + Config.chunk_size, json_state.test_file.len);
                        try parser.parseIncremental(json_state.test_file[offset..chunk_end]);
                        offset = chunk_end;
                    }
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_no_pos});

        // Benchmark with position tracking
        try writer.print("\n  With position tracking:\n", .{});
        var benchmark_with_pos = Benchmark.init(allocator, "json_incremental_with_positions");
        defer benchmark_with_pos.deinit();

        const result_with_pos = try benchmark_with_pos.run(
            Config.benchmark_iterations / 10,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(json_state.allocator);
                    defer tracker.deinit();
                    
                    var parser = try IncrementalJsonParser.init(json_state.allocator, true, &tracker);
                    defer parser.deinit();
                    
                    var offset: usize = 0;
                    while (offset < json_state.test_file.len) {
                        const chunk_end = @min(offset + Config.chunk_size, json_state.test_file.len);
                        try parser.parseIncremental(json_state.test_file[offset..chunk_end]);
                        offset = chunk_end;
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
        try writer.print("    Absolute: {d:.3} ms\n", .{@as(f64, @floatFromInt(overhead_ns)) / 1_000_000.0});
        try writer.print("    Relative: {d:.2}%\n", .{overhead_percent});
        
        if (overhead_percent < Config.max_overhead_percent) {
            try writer.print("    ✓ Within target (<{d}% overhead)\n", .{Config.max_overhead_percent});
        } else {
            try writer.print("    ✗ Exceeds target ({d}% max overhead)\n", .{Config.max_overhead_percent});
        }
    }

    /// Benchmark parallel processing (stress test)
    pub fn benchmarkParallelProcessing(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Large File: Parallel Processing Stress Test ===\n", .{});

        // Generate large synthetic data for stress testing
        const data_size = 1024 * 1024 * 2; // 2MB for parallel test
        const test_data = try allocator.alloc(u8, data_size);
        defer allocator.free(test_data);

        // Fill with realistic content
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();
        
        for (test_data) |*byte| {
            const choice = random.int(u8) % 100;
            if (choice < 60) {
                byte.* = 'a' + @as(u8, @intCast(random.int(u8) % 26));
            } else if (choice < 75) {
                byte.* = ' ';
            } else if (choice < 85) {
                byte.* = '\n';
            } else if (choice < 90) {
                byte.* = '\t';
            } else {
                const punct = ".,;:!?()[]{}\"'";
                byte.* = punct[random.int(usize) % punct.len];
            }
        }

        try writer.print("  Data size: {d:.2} MB\n", .{@as(f64, @floatFromInt(data_size)) / (1024.0 * 1024.0)});

        const thread_counts = [_]usize{ 1, 2, 4 };

        for (thread_counts) |thread_count| {
            try writer.print("\n  Threads: {d}\n", .{thread_count});

            // Without position tracking
            var processor_no_pos = try ParallelProcessor.init(allocator, false, thread_count);
            defer processor_no_pos.deinit();

            // Manually time the operations since we can't use closures in benchmark.run
            var total_time_no_pos: u64 = 0;
            const iterations = Config.benchmark_iterations / 10;
            
            for (0..iterations) |_| {
                const timer = Timer.start();
                _ = try processor_no_pos.processParallel(test_data);
                total_time_no_pos += timer.elapsedNanos();
            }
            
            const avg_time_no_pos = total_time_no_pos / iterations;
            try writer.print("    Without positions: {d:.3} µs\n", .{@as(f64, @floatFromInt(avg_time_no_pos)) / 1000.0});

            // With position tracking
            var processor_with_pos = try ParallelProcessor.init(allocator, true, thread_count);
            defer processor_with_pos.deinit();

            var total_time_with_pos: u64 = 0;
            
            for (0..iterations) |_| {
                const timer = Timer.start();
                _ = try processor_with_pos.processParallel(test_data);
                total_time_with_pos += timer.elapsedNanos();
            }
            
            const avg_time_with_pos = total_time_with_pos / iterations;

            try writer.print("    With positions:    {d:.3} µs\n", .{@as(f64, @floatFromInt(avg_time_with_pos)) / 1000.0});

            // Calculate overhead
            const overhead_ns = @as(i64, @intCast(avg_time_with_pos)) - @as(i64, @intCast(avg_time_no_pos));
            const overhead_percent = if (avg_time_no_pos > 0) 
                (@as(f64, @floatFromInt(overhead_ns)) / @as(f64, @floatFromInt(avg_time_no_pos))) * 100.0
            else 
                0.0;
            
            try writer.print("    Overhead: {d:.2}%\n", .{overhead_percent});
            
            if (overhead_percent < Config.max_overhead_percent) {
                try writer.print("    ✓ Within target\n", .{});
            } else {
                try writer.print("    ✗ Exceeds target\n", .{});
            }
        }
    }

    /// Benchmark memory usage at scale
    pub fn benchmarkMemoryAtScale(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Large File: Memory Usage at Scale ===\n", .{});

        const file_sizes = [_]usize{
            100 * 1024,      // 100KB
            500 * 1024,      // 500KB
            1024 * 1024,     // 1MB
            2 * 1024 * 1024, // 2MB
        };

        for (file_sizes) |size| {
            try writer.print("\n  File size: {d} KB\n", .{size / 1024});

            // Generate test data
            const test_data = try allocator.alloc(u8, size);
            defer allocator.free(test_data);
            
            for (test_data, 0..) |*byte, i| {
                if (i % 80 == 79) {
                    byte.* = '\n';
                } else {
                    byte.* = 'a' + @as(u8, @intCast(i % 26));
                }
            }

            // Track memory usage
            var memory_tracker = MemoryTracker.init(allocator);
            
            // Process with position tracking
            var tracker = PositionTracker.init(allocator);
            defer tracker.deinit();
            
            memory_tracker.trackAlloc(@sizeOf(PositionTracker));
            
            var processor = try LargeFileProcessor.init(allocator, true, &tracker);
            defer processor.deinit();
            
            memory_tracker.trackAlloc(@sizeOf(LargeFileProcessor));
            
            // Process and track sample positions
            try processor.processFile(test_data);
            
            const sample_memory = processor.sample_positions.items.len * @sizeOf(SourcePosition);
            memory_tracker.trackAlloc(sample_memory);
            
            const stats = memory_tracker.getStats();
            
            try writer.print("    Lines processed: {d}\n", .{processor.stats.total_lines});
            try writer.print("    Position samples: {d}\n", .{processor.sample_positions.items.len});
            try writer.print("    Memory overhead: {d} bytes\n", .{stats.peak_usage});
            try writer.print("    Overhead per KB: {d:.2} bytes\n", .{@as(f64, @floatFromInt(stats.peak_usage)) / (@as(f64, @floatFromInt(size)) / 1024.0)});
        }
    }

    /// Run all large file benchmarks
    pub fn runAllBenchmarks(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n" ++ "=" ** 70 ++ "\n", .{});
        try writer.print("Large File (100KB-10MB) Position Tracking Benchmarks\n", .{});
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

        try benchmarkLargeLogProcessing(allocator, writer);
        try benchmarkIncrementalJsonParsing(allocator, writer);
        try benchmarkParallelProcessing(allocator, writer);
        try benchmarkMemoryAtScale(allocator, writer);

        try writer.print("\n" ++ "=" ** 70 ++ "\n", .{});
        try writer.print("Large File Benchmarks Complete\n", .{});
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

    test "unit: LargeFile: validates processor handles large chunks" {
        const test_allocator = std.testing.allocator;
        
        var tracker = PositionTracker.init(test_allocator);
        defer tracker.deinit();

        var processor = try LargeFileProcessor.init(test_allocator, true, &tracker);
        defer processor.deinit();
        
        const test_data = "a" ** 1000 ++ "\n" ++ "b" ** 1000 ++ "\n";
        try processor.processFile(test_data);
        
        try std.testing.expectEqual(@as(usize, 2002), processor.stats.total_bytes);
        try std.testing.expectEqual(@as(usize, 2), processor.stats.total_lines);
        try std.testing.expectEqual(@as(usize, 1001), processor.stats.max_line_length);
    }

    test "unit: LargeFile: validates incremental JSON parser tracks structure" {
        const test_allocator = std.testing.allocator;
        
        var tracker = PositionTracker.init(test_allocator);
        defer tracker.deinit();

        var parser = try IncrementalJsonParser.init(test_allocator, true, &tracker);
        defer parser.deinit();
        
        const json_chunk1 = "[{\"id\":1,\"name\":\"test\"},";
        const json_chunk2 = "{\"id\":2,\"data\":[1,2,3]}]";
        
        try parser.parseIncremental(json_chunk1);
        try parser.parseIncremental(json_chunk2);
        
        try std.testing.expectEqual(@as(usize, 2), parser.object_count);
        try std.testing.expectEqual(@as(usize, 2), parser.array_count); // Main array + nested array
        try std.testing.expect(parser.string_count > 0);
        try std.testing.expect(parser.number_count > 0);
    }

    test "unit: LargeFile: validates parallel processor divides work correctly" {
        const test_allocator = std.testing.allocator;
        
        var processor = try ParallelProcessor.init(test_allocator, false, 2);
        defer processor.deinit();
        
        const test_data = "line1\nline2\nline3\nline4\n";
        const result = try processor.processParallel(test_data);
        
        try std.testing.expectEqual(@as(usize, 24), result.bytes_processed);
        try std.testing.expectEqual(@as(usize, 4), result.lines_counted);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝