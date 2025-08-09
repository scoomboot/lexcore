// small_file.zig — Small file (<1KB) benchmarks for position tracking
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
    
    const Position = position.Position;
    const SourcePosition = position.SourcePosition;
    const PositionTracker = position.PositionTracker;
    const Timer = perf.Timer;
    const Benchmark = perf.Benchmark;
    const Throughput = perf.Throughput;
    const MemoryTracker = perf.MemoryTracker;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Benchmark configuration for small files
    const Config = struct {
        const warmup_iterations: usize = 100;
        const benchmark_iterations: usize = 10000;
        const max_overhead_percent: f64 = 3.0; // Target < 3% overhead
    };

    /// Token type for simple tokenization
    const TokenType = enum {
        identifier,
        number,
        string,
        keyword,
        operator,
        whitespace,
        comment,
        unknown,
    };

    /// Simple token structure
    const Token = struct {
        type: TokenType,
        start: usize,
        end: usize,
        position: ?SourcePosition = null,
    };

    /// Simple tokenizer for benchmarking
    const SimpleTokenizer = struct {
        buffer: []const u8,
        offset: usize,
        with_positions: bool,
        tracker: ?*PositionTracker,

        fn init(buffer: []const u8, with_positions: bool, tracker: ?*PositionTracker) SimpleTokenizer {
            return .{
                .buffer = buffer,
                .offset = 0,
                .with_positions = with_positions,
                .tracker = tracker,
            };
        }

        fn nextToken(self: *SimpleTokenizer) ?Token {
            if (self.offset >= self.buffer.len) return null;

            const start = self.offset;
            const start_pos = if (self.with_positions and self.tracker != null)
                self.tracker.?.current
            else
                null;

            // Skip whitespace
            while (self.offset < self.buffer.len and std.ascii.isWhitespace(self.buffer[self.offset])) {
                if (self.tracker) |t| {
                    t.advance(self.buffer[self.offset]);
                }
                self.offset += 1;
            }

            if (self.offset >= self.buffer.len) {
                return Token{
                    .type = .whitespace,
                    .start = start,
                    .end = self.offset,
                    .position = start_pos,
                };
            }

            const first_char = self.buffer[self.offset];
            
            // Identify token type and consume
            if (std.ascii.isAlphabetic(first_char) or first_char == '_') {
                // Identifier or keyword
                while (self.offset < self.buffer.len) {
                    const c = self.buffer[self.offset];
                    if (!std.ascii.isAlphanumeric(c) and c != '_') break;
                    if (self.tracker) |t| {
                        t.advance(c);
                    }
                    self.offset += 1;
                }
                
                const text = self.buffer[start..self.offset];
                const token_type = if (isKeyword(text)) TokenType.keyword else TokenType.identifier;
                
                return Token{
                    .type = token_type,
                    .start = start,
                    .end = self.offset,
                    .position = start_pos,
                };
            } else if (std.ascii.isDigit(first_char)) {
                // Number
                while (self.offset < self.buffer.len and std.ascii.isDigit(self.buffer[self.offset])) {
                    if (self.tracker) |t| {
                        t.advance(self.buffer[self.offset]);
                    }
                    self.offset += 1;
                }
                
                return Token{
                    .type = .number,
                    .start = start,
                    .end = self.offset,
                    .position = start_pos,
                };
            } else if (first_char == '"') {
                // String literal
                if (self.tracker) |t| {
                    t.advance(first_char);
                }
                self.offset += 1;
                
                while (self.offset < self.buffer.len) {
                    const c = self.buffer[self.offset];
                    if (self.tracker) |t| {
                        t.advance(c);
                    }
                    self.offset += 1;
                    if (c == '"') break;
                    if (c == '\\' and self.offset < self.buffer.len) {
                        if (self.tracker) |t| {
                            t.advance(self.buffer[self.offset]);
                        }
                        self.offset += 1;
                    }
                }
                
                return Token{
                    .type = .string,
                    .start = start,
                    .end = self.offset,
                    .position = start_pos,
                };
            } else {
                // Single character operator or unknown
                if (self.tracker) |t| {
                    t.advance(first_char);
                }
                self.offset += 1;
                
                const token_type = if (isOperator(first_char)) TokenType.operator else TokenType.unknown;
                
                return Token{
                    .type = token_type,
                    .start = start,
                    .end = self.offset,
                    .position = start_pos,
                };
            }
        }

        fn isKeyword(text: []const u8) bool {
            const keywords = [_][]const u8{
                "const", "var", "fn", "if", "else", "while", "for",
                "return", "try", "catch", "defer", "errdefer", "pub",
                "struct", "enum", "union", "test", "import",
            };
            
            for (keywords) |kw| {
                if (std.mem.eql(u8, text, kw)) return true;
            }
            return false;
        }

        fn isOperator(c: u8) bool {
            return switch (c) {
                '+', '-', '*', '/', '%', '=', '<', '>', '!', '&', '|', '^', '~',
                '(', ')', '[', ']', '{', '}', ',', '.', ';', ':', '?', '@' => true,
                else => false,
            };
        }
    };

    /// Error set for JSON parsing
    const JsonError = error{
        UnexpectedEof,
        UnexpectedChar,
        ExpectedCommaOrBrace,
        ExpectedCommaOrBracket,
        UnterminatedString,
        InvalidNumber,
        InvalidBool,
        InvalidNull,
    };
    
    /// Simple JSON parser for benchmarking
    const JsonParser = struct {
        buffer: []const u8,
        offset: usize,
        with_positions: bool,
        tracker: ?*PositionTracker,
        depth: usize,

        fn init(buffer: []const u8, with_positions: bool, tracker: ?*PositionTracker) JsonParser {
            return .{
                .buffer = buffer,
                .offset = 0,
                .with_positions = with_positions,
                .tracker = tracker,
                .depth = 0,
            };
        }

        fn parse(self: *JsonParser) JsonError!void {
            try self.skipWhitespace();
            try self.parseValue();
        }

        fn parseValue(self: *JsonParser) JsonError!void {
            if (self.offset >= self.buffer.len) return error.UnexpectedEof;

            const c = self.buffer[self.offset];
            switch (c) {
                '{' => try self.parseObject(),
                '[' => try self.parseArray(),
                '"' => try self.parseString(),
                't', 'f' => try self.parseBool(),
                'n' => try self.parseNull(),
                '-', '0'...'9' => try self.parseNumber(),
                else => return error.UnexpectedChar,
            }
        }

        fn parseObject(self: *JsonParser) JsonError!void {
            try self.expect('{');
            self.depth += 1;
            defer self.depth -= 1;

            try self.skipWhitespace();
            if (self.offset < self.buffer.len and self.buffer[self.offset] == '}') {
                try self.advance();
                return;
            }

            while (true) {
                try self.parseString(); // key
                try self.skipWhitespace();
                try self.expect(':');
                try self.skipWhitespace();
                try self.parseValue(); // value
                try self.skipWhitespace();

                if (self.offset >= self.buffer.len) return error.UnexpectedEof;
                
                const next = self.buffer[self.offset];
                if (next == '}') {
                    try self.advance();
                    break;
                } else if (next == ',') {
                    try self.advance();
                    try self.skipWhitespace();
                } else {
                    return error.ExpectedCommaOrBrace;
                }
            }
        }

        fn parseArray(self: *JsonParser) JsonError!void {
            try self.expect('[');
            self.depth += 1;
            defer self.depth -= 1;

            try self.skipWhitespace();
            if (self.offset < self.buffer.len and self.buffer[self.offset] == ']') {
                try self.advance();
                return;
            }

            while (true) {
                try self.parseValue();
                try self.skipWhitespace();

                if (self.offset >= self.buffer.len) return error.UnexpectedEof;
                
                const next = self.buffer[self.offset];
                if (next == ']') {
                    try self.advance();
                    break;
                } else if (next == ',') {
                    try self.advance();
                    try self.skipWhitespace();
                } else {
                    return error.ExpectedCommaOrBracket;
                }
            }
        }

        fn parseString(self: *JsonParser) JsonError!void {
            try self.expect('"');
            
            while (self.offset < self.buffer.len) {
                const c = self.buffer[self.offset];
                try self.advance();
                
                if (c == '"') return;
                if (c == '\\' and self.offset < self.buffer.len) {
                    try self.advance(); // Skip escaped character
                }
            }
            
            return error.UnterminatedString;
        }

        fn parseNumber(self: *JsonParser) JsonError!void {
            if (self.offset < self.buffer.len and self.buffer[self.offset] == '-') {
                try self.advance();
            }

            // Integer part
            if (self.offset >= self.buffer.len) return error.UnexpectedEof;
            if (!std.ascii.isDigit(self.buffer[self.offset])) return error.InvalidNumber;

            while (self.offset < self.buffer.len and std.ascii.isDigit(self.buffer[self.offset])) {
                try self.advance();
            }

            // Fractional part
            if (self.offset < self.buffer.len and self.buffer[self.offset] == '.') {
                try self.advance();
                if (self.offset >= self.buffer.len or !std.ascii.isDigit(self.buffer[self.offset])) {
                    return error.InvalidNumber;
                }
                while (self.offset < self.buffer.len and std.ascii.isDigit(self.buffer[self.offset])) {
                    try self.advance();
                }
            }

            // Exponent part
            if (self.offset < self.buffer.len) {
                const c = self.buffer[self.offset];
                if (c == 'e' or c == 'E') {
                    try self.advance();
                    if (self.offset < self.buffer.len) {
                        const sign = self.buffer[self.offset];
                        if (sign == '+' or sign == '-') {
                            try self.advance();
                        }
                    }
                    if (self.offset >= self.buffer.len or !std.ascii.isDigit(self.buffer[self.offset])) {
                        return error.InvalidNumber;
                    }
                    while (self.offset < self.buffer.len and std.ascii.isDigit(self.buffer[self.offset])) {
                        try self.advance();
                    }
                }
            }
        }

        fn parseBool(self: *JsonParser) JsonError!void {
            const remaining = self.buffer[self.offset..];
            if (std.mem.startsWith(u8, remaining, "true")) {
                for (0..4) |_| try self.advance();
            } else if (std.mem.startsWith(u8, remaining, "false")) {
                for (0..5) |_| try self.advance();
            } else {
                return error.InvalidBool;
            }
        }

        fn parseNull(self: *JsonParser) JsonError!void {
            const remaining = self.buffer[self.offset..];
            if (std.mem.startsWith(u8, remaining, "null")) {
                for (0..4) |_| try self.advance();
            } else {
                return error.InvalidNull;
            }
        }

        fn skipWhitespace(self: *JsonParser) JsonError!void {
            while (self.offset < self.buffer.len) {
                const c = self.buffer[self.offset];
                if (!std.ascii.isWhitespace(c)) break;
                try self.advance();
            }
        }

        fn expect(self: *JsonParser, expected: u8) JsonError!void {
            if (self.offset >= self.buffer.len) return error.UnexpectedEof;
            if (self.buffer[self.offset] != expected) return error.UnexpectedChar;
            try self.advance();
        }

        fn advance(self: *JsonParser) JsonError!void {
            if (self.offset >= self.buffer.len) return;
            
            const c = self.buffer[self.offset];
            if (self.tracker) |t| {
                t.advance(c);
            }
            self.offset += 1;
        }
    };

    /// Benchmark state for tokenization
    var tokenization_state: struct {
        allocator: std.mem.Allocator,
        test_file: []const u8,
    } = undefined;
    
    /// Benchmark tokenization with and without position tracking
    pub fn benchmarkTokenization(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Small File: Tokenization Benchmark ===\n", .{});

        // Load test file
        const test_file = try std.fs.cwd().readFileAlloc(
            allocator,
            "lib/lexer/position/benchmarks/test_data/small_source.zig",
            1024 * 10 // 10KB max
        );
        defer allocator.free(test_file);

        try writer.print("  File size: {d} bytes\n", .{test_file.len});

        // Benchmark without position tracking
        try writer.print("\n  Without position tracking:\n", .{});
        var benchmark_no_pos = Benchmark.init(allocator, "tokenize_no_positions");
        defer benchmark_no_pos.deinit();

        // Set up benchmark state
        tokenization_state = .{ .allocator = allocator, .test_file = test_file };
        
        const result_no_pos = try benchmark_no_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var tokenizer = SimpleTokenizer.init(tokenization_state.test_file, false, null);
                    var token_count: usize = 0;
                    while (tokenizer.nextToken()) |_| {
                        token_count += 1;
                    }
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_no_pos});

        // Benchmark with position tracking
        try writer.print("\n  With position tracking:\n", .{});
        var benchmark_with_pos = Benchmark.init(allocator, "tokenize_with_positions");
        defer benchmark_with_pos.deinit();

        const result_with_pos = try benchmark_with_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(tokenization_state.allocator);
                    defer tracker.deinit();
                    
                    var tokenizer = SimpleTokenizer.init(tokenization_state.test_file, true, &tracker);
                    var token_count: usize = 0;
                    while (tokenizer.nextToken()) |_| {
                        token_count += 1;
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

    /// Benchmark state for JSON parsing
    var json_state: struct {
        allocator: std.mem.Allocator,
        test_file: []const u8,
    } = undefined;
    
    /// Benchmark JSON parsing with and without position tracking
    pub fn benchmarkJsonParsing(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Small File: JSON Parsing Benchmark ===\n", .{});

        // Load test file
        const test_file = try std.fs.cwd().readFileAlloc(
            allocator,
            "lib/lexer/position/benchmarks/test_data/small_data.json",
            1024 * 10 // 10KB max
        );
        defer allocator.free(test_file);

        try writer.print("  File size: {d} bytes\n", .{test_file.len});

        // Benchmark without position tracking
        try writer.print("\n  Without position tracking:\n", .{});
        var benchmark_no_pos = Benchmark.init(allocator, "json_parse_no_positions");
        defer benchmark_no_pos.deinit();

        // Set up benchmark state
        json_state = .{ .allocator = allocator, .test_file = test_file };
        
        const result_no_pos = try benchmark_no_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var parser = JsonParser.init(json_state.test_file, false, null);
                    try parser.parse();
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_no_pos});

        // Benchmark with position tracking
        try writer.print("\n  With position tracking:\n", .{});
        var benchmark_with_pos = Benchmark.init(allocator, "json_parse_with_positions");
        defer benchmark_with_pos.deinit();

        const result_with_pos = try benchmark_with_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(json_state.allocator);
                    defer tracker.deinit();
                    
                    var parser = JsonParser.init(json_state.test_file, true, &tracker);
                    try parser.parse();
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

    /// Benchmark state for CSV parsing
    var csv_state: struct {
        allocator: std.mem.Allocator,
        test_file: []const u8,
    } = undefined;
    
    /// Benchmark CSV parsing with and without position tracking
    pub fn benchmarkCsvParsing(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Small File: CSV Parsing Benchmark ===\n", .{});

        // Load test file
        const test_file = try std.fs.cwd().readFileAlloc(
            allocator,
            "lib/lexer/position/benchmarks/test_data/small_data.csv",
            1024 * 10 // 10KB max
        );
        defer allocator.free(test_file);

        try writer.print("  File size: {d} bytes\n", .{test_file.len});

        // Simple CSV parser closure
        const parseCsv = struct {
            fn parse(buffer: []const u8, tracker: ?*PositionTracker) void {
                var row_count: usize = 0;
                var field_count: usize = 0;
                var in_quotes = false;
                
                for (buffer) |c| {
                    if (tracker) |t| {
                        t.advance(c);
                    }
                    
                    if (c == '"') {
                        in_quotes = !in_quotes;
                    } else if (!in_quotes) {
                        if (c == ',') {
                            field_count += 1;
                        } else if (c == '\n') {
                            row_count += 1;
                            field_count += 1;
                        }
                    }
                }
            }
        }.parse;

        // Benchmark without position tracking
        try writer.print("\n  Without position tracking:\n", .{});
        var benchmark_no_pos = Benchmark.init(allocator, "csv_parse_no_positions");
        defer benchmark_no_pos.deinit();

        // Set up benchmark state
        csv_state = .{ .allocator = allocator, .test_file = test_file };
        
        const result_no_pos = try benchmark_no_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    parseCsv(csv_state.test_file, null);
                }
            }.bench,
            null,
        );

        try writer.print("  {}\n", .{result_no_pos});

        // Benchmark with position tracking
        try writer.print("\n  With position tracking:\n", .{});
        var benchmark_with_pos = Benchmark.init(allocator, "csv_parse_with_positions");
        defer benchmark_with_pos.deinit();

        const result_with_pos = try benchmark_with_pos.run(
            Config.benchmark_iterations,
            null,
            struct {
                fn bench() !void {
                    var tracker = PositionTracker.init(csv_state.allocator);
                    defer tracker.deinit();
                    parseCsv(csv_state.test_file, &tracker);
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

    /// Benchmark memory usage for position tracking
    pub fn benchmarkMemoryUsage(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n=== Small File: Memory Usage Benchmark ===\n", .{});

        // Test with different mark stack depths
        const mark_depths = [_]usize{ 0, 1, 5, 10, 20 };

        for (mark_depths) |depth| {
            try writer.print("\n  Mark stack depth: {d}\n", .{depth});

            var memory_tracker = MemoryTracker.init(allocator);
            
            // Create tracker and perform operations
            var tracker = PositionTracker.init(allocator);
            defer tracker.deinit();
            
            // Track initial allocation
            const initial_size = @sizeOf(PositionTracker);
            memory_tracker.trackAlloc(initial_size);

            // Simulate parser with marks
            for (0..depth) |_| {
                try tracker.mark();
                memory_tracker.trackAlloc(@sizeOf(SourcePosition));
                
                // Advance some
                for (0..10) |_| {
                    tracker.advance('a');
                }
            }

            // Restore all marks
            for (0..depth) |_| {
                try tracker.restore();
                memory_tracker.trackFree(@sizeOf(SourcePosition));
            }

            const stats = memory_tracker.getStats();
            try writer.print("    Allocations: {d}\n", .{stats.allocations});
            try writer.print("    Peak usage: {d} bytes\n", .{stats.peak_usage});
            try writer.print("    Current usage: {d} bytes\n", .{stats.current_usage});
        }
    }

    /// Run all small file benchmarks
    pub fn runAllBenchmarks(allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.print("\n" ++ "=" ** 70 ++ "\n", .{});
        try writer.print("Small File (<1KB) Position Tracking Benchmarks\n", .{});
        try writer.print("=" ** 70 ++ "\n", .{});

        // Ensure test data exists
        var test_data_dir = std.fs.cwd().openDir(
            "lib/lexer/position/benchmarks/test_data",
            .{}
        ) catch |err| blk: {
            if (err == error.FileNotFound) {
                try writer.print("\n⚠️  Test data not found. Generating test files...\n", .{});
                const generate_path = "lib/lexer/position/benchmarks/test_data/generate_test_data.zig";
                const argv = [_][]const u8{ "zig", "run", generate_path };
                var child = std.process.Child.init(&argv, allocator);
                _ = try child.spawnAndWait();
                try writer.print("✓ Test data generated successfully.\n\n", .{});
                // Try to open again after generation
                break :blk try std.fs.cwd().openDir("lib/lexer/position/benchmarks/test_data", .{});
            } else {
                return err;
            }
        };
        defer test_data_dir.close();

        try benchmarkTokenization(allocator, writer);
        try benchmarkJsonParsing(allocator, writer);
        try benchmarkCsvParsing(allocator, writer);
        try benchmarkMemoryUsage(allocator, writer);

        try writer.print("\n" ++ "=" ** 70 ++ "\n", .{});
        try writer.print("Small File Benchmarks Complete\n", .{});
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

    test "unit: SmallFile: validates benchmarks complete without error" {
        const test_allocator = std.testing.allocator;
        
        // Simple validation that components work
        var tracker = PositionTracker.init(test_allocator);
        defer tracker.deinit();

        const test_input = "const x = 42;";
        var tokenizer = SimpleTokenizer.init(test_input, true, &tracker);
        
        var token_count: usize = 0;
        while (tokenizer.nextToken()) |token| {
            token_count += 1;
            try std.testing.expect(token.start < token.end);
        }
        
        try std.testing.expect(token_count > 0);
    }

    test "unit: SmallFile: validates JSON parser handles simple object" {
        const test_allocator = std.testing.allocator;
        
        var tracker = PositionTracker.init(test_allocator);
        defer tracker.deinit();

        const json = 
            \\{"name": "test", "value": 42, "active": true}
        ;
        
        var parser = JsonParser.init(json, true, &tracker);
        try parser.parse();
        
        try std.testing.expect(parser.offset == json.len);
        try std.testing.expect(tracker.position.byte_offset == json.len);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝