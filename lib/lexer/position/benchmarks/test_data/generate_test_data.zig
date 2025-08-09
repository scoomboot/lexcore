// generate_test_data.zig — Test data generator for position tracking benchmarks
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/position/benchmarks/test_data
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Test data categories
    pub const DataCategory = enum {
        small_files,    // < 1KB
        medium_files,   // 1KB - 100KB
        large_files,    // 100KB - 10MB
        encoding_tests, // Various encodings
        line_endings,   // Different line ending types
        mixed_content,  // Mixed ASCII/UTF-8/emoji
    };

    /// File type configurations
    pub const FileType = enum {
        zig_source,
        json_data,
        csv_data,
        xml_data,
        markdown,
        plain_text,
        binary_like,
    };

    /// Generate all test data files
    pub fn generateAllTestData(allocator: std.mem.Allocator) !void {
        const cwd = std.fs.cwd();
        var test_data_dir = try cwd.makeOpenPath("lib/lexer/position/benchmarks/test_data", .{});
        defer test_data_dir.close();

        std.debug.print("Generating test data files...\n", .{});

        // Small files (< 1KB)
        try generateSmallFiles(allocator, test_data_dir);
        
        // Medium files (1KB - 100KB)
        try generateMediumFiles(allocator, test_data_dir);
        
        // Large files (100KB - 10MB)
        try generateLargeFiles(allocator, test_data_dir);
        
        // Encoding test files
        try generateEncodingTests(allocator, test_data_dir);
        
        // Line ending test files
        try generateLineEndingTests(allocator, test_data_dir);
        
        // Mixed content files
        try generateMixedContent(allocator, test_data_dir);

        std.debug.print("Test data generation complete!\n", .{});
    }

    /// Generate small test files (< 1KB)
    fn generateSmallFiles(allocator: std.mem.Allocator, dir: std.fs.Dir) !void {
        _ = allocator; // Mark as used
        std.debug.print("  Generating small files...\n", .{});

        // Small Zig source
        const small_zig = 
            \\// Small Zig source file for benchmarking
            \\const std = @import("std");
            \\
            \\pub fn main() !void {
            \\    const stdout = std.io.getStdOut().writer();
            \\    try stdout.print("Hello, World!\n", .{});
            \\}
            \\
            \\test "simple test" {
            \\    const x = 42;
            \\    try std.testing.expectEqual(@as(i32, 42), x);
            \\}
        ;
        try dir.writeFile(.{ .sub_path = "small_source.zig", .data = small_zig });

        // Small JSON
        const small_json = 
            \\{
            \\  "name": "LexCore",
            \\  "version": "0.1.0",
            \\  "description": "High-performance lexer library",
            \\  "author": "scoomboot",
            \\  "dependencies": {
            \\    "std": "0.13.0"
            \\  },
            \\  "tags": ["lexer", "parser", "performance", "zig"],
            \\  "metrics": {
            \\    "lines": 1234,
            \\    "coverage": 95.7,
            \\    "benchmarks": true
            \\  }
            \\}
        ;
        try dir.writeFile(.{ .sub_path = "small_data.json", .data = small_json });

        // Small CSV
        const small_csv = 
            \\id,name,age,city,country,occupation,salary
            \\1,"Alice Smith",28,"New York","USA","Software Engineer",95000
            \\2,"Bob Johnson",35,"London","UK","Data Scientist",85000
            \\3,"Charlie Lee",42,"Tokyo","Japan","Product Manager",110000
            \\4,"Diana Garcia",31,"Barcelona","Spain","UX Designer",75000
            \\5,"Eve Wilson",29,"Sydney","Australia","DevOps Engineer",90000
            \\6,"Frank Chen",38,"Shanghai","China","Technical Lead",105000
            \\7,"Grace Kim",26,"Seoul","South Korea","Frontend Developer",70000
            \\8,"Henry Brown",45,"Toronto","Canada","CTO",150000
            \\9,"Iris Martinez",33,"Mexico City","Mexico","Backend Developer",80000
            \\10,"Jack Taylor",27,"Berlin","Germany","QA Engineer",65000
        ;
        try dir.writeFile(.{ .sub_path = "small_data.csv", .data = small_csv });
    }

    /// Generate medium test files (1KB - 100KB)
    fn generateMediumFiles(allocator: std.mem.Allocator, dir: std.fs.Dir) !void {
        std.debug.print("  Generating medium files...\n", .{});

        // Medium Zig source (typical module)
        var zig_content = std.ArrayList(u8).init(allocator);
        defer zig_content.deinit();

        try zig_content.appendSlice(
            \\// Medium Zig source file - typical module
            \\const std = @import("std");
            \\const testing = std.testing;
            \\
            \\pub const Parser = struct {
            \\    allocator: std.mem.Allocator,
            \\    buffer: []const u8,
            \\    position: usize,
            \\
        );

        // Generate multiple functions
        for (0..50) |i| {
            try zig_content.writer().print(
                \\    pub fn function_{d}(self: *Parser) !void {{
                \\        // Function implementation
                \\        const start = self.position;
                \\        while (self.position < self.buffer.len) : (self.position += 1) {{
                \\            const char = self.buffer[self.position];
                \\            if (char == '\n') break;
                \\        }}
                \\        return self.buffer[start..self.position];
                \\    }}
                \\
            , .{i});
        }

        try zig_content.appendSlice("};\n\n");

        // Add tests
        for (0..30) |i| {
            try zig_content.writer().print(
                \\test "unit: Parser: test case {d}" {{
                \\    const parser = Parser.init(testing.allocator);
                \\    defer parser.deinit();
                \\    try testing.expectEqual(@as(usize, {d}), parser.position);
                \\}}
                \\
            , .{ i, i * 10 });
        }

        try dir.writeFile(.{ .sub_path = "medium_source.zig", .data = zig_content.items });

        // Medium JSON (API response simulation)
        var json_content = std.ArrayList(u8).init(allocator);
        defer json_content.deinit();

        try json_content.appendSlice("{\n  \"users\": [\n");
        for (0..500) |i| {
            try json_content.writer().print(
                \\    {{
                \\      "id": {d},
                \\      "username": "user_{d}",
                \\      "email": "user{d}@example.com",
                \\      "created_at": "2024-01-{d:0>2}T10:30:00Z",
                \\      "profile": {{
                \\        "bio": "Software developer passionate about open source",
                \\        "location": "City {d}",
                \\        "website": "https://user{d}.dev"
                \\      }}
                \\    }}
            , .{ i, i, i, (i % 28) + 1, i, i });
            
            if (i < 499) try json_content.appendSlice(",");
            try json_content.appendSlice("\n");
        }
        try json_content.appendSlice("  ]\n}\n");

        try dir.writeFile(.{ .sub_path = "medium_data.json", .data = json_content.items });

        // Medium CSV (data table)
        var csv_content = std.ArrayList(u8).init(allocator);
        defer csv_content.deinit();

        try csv_content.appendSlice("timestamp,temperature,humidity,pressure,wind_speed,wind_direction,precipitation,visibility,uv_index,air_quality\n");
        
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();
        
        for (0..2000) |i| {
            const hour = i % 24;
            const day = (i / 24) + 1;
            const temp = 15.0 + @as(f32, @floatFromInt(random.int(u8) % 20));
            const humidity = 40.0 + @as(f32, @floatFromInt(random.int(u8) % 40));
            const pressure = 1000.0 + @as(f32, @floatFromInt(random.int(u8) % 50));
            
            try csv_content.writer().print(
                "2024-01-{d:0>2}T{d:0>2}:00:00Z,{d:.1},{d:.1},{d:.1},{d},{d},{d:.2},{d},{d},{d}\n",
                .{ day, hour, temp, humidity, pressure, 
                   random.int(u8) % 30, random.int(u16) % 360,
                   @as(f32, @floatFromInt(random.int(u8) % 10)) / 10.0,
                   5 + (random.int(u8) % 15), random.int(u8) % 11,
                   50 + (random.int(u8) % 100) }
            );
        }

        try dir.writeFile(.{ .sub_path = "medium_data.csv", .data = csv_content.items });
    }

    /// Generate large test files (100KB - 10MB)
    fn generateLargeFiles(allocator: std.mem.Allocator, dir: std.fs.Dir) !void {
        std.debug.print("  Generating large files...\n", .{});

        // Large log file (1MB)
        var log_content = std.ArrayList(u8).init(allocator);
        defer log_content.deinit();

        const log_levels = [_][]const u8{ "DEBUG", "INFO", "WARN", "ERROR", "FATAL" };
        const components = [_][]const u8{ "parser", "lexer", "buffer", "position", "tracker" };
        
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();

        for (0..10000) |i| {
            const level = log_levels[random.int(usize) % log_levels.len];
            const component = components[random.int(usize) % components.len];
            const timestamp = 1704067200 + i * 100; // Unix timestamp
            
            try log_content.writer().print(
                "[{d}] [{s}] [{s}] Processing item {d} - ",
                .{ timestamp, level, component, i }
            );

            // Add variable length log message
            const msg_len = 50 + (random.int(usize) % 200);
            for (0..msg_len) |_| {
                const char = 'a' + @as(u8, @intCast(random.int(u8) % 26));
                try log_content.append(char);
                if (random.int(u8) % 20 == 0) try log_content.append(' ');
            }
            try log_content.append('\n');
        }

        try dir.writeFile(.{ .sub_path = "large_log.txt", .data = log_content.items });

        // Large JSON array (5MB)
        var large_json = std.ArrayList(u8).init(allocator);
        defer large_json.deinit();

        try large_json.appendSlice("[\n");
        for (0..50000) |i| {
            try large_json.writer().print(
                \\  {{
                \\    "id": "{x}",
                \\    "index": {d},
                \\    "isActive": {s},
                \\    "balance": {d:.2},
                \\    "tags": [
            , .{ 
                random.int(u64), 
                i, 
                if (i % 2 == 0) "true" else "false",
                @as(f64, @floatFromInt(random.int(u32) % 100000)) / 100.0
            });

            // Add random tags
            const num_tags = 3 + (random.int(u8) % 5);
            for (0..num_tags) |j| {
                try large_json.writer().print("\"tag_{d}\"", .{random.int(u16)});
                if (j < num_tags - 1) try large_json.appendSlice(", ");
            }

            try large_json.appendSlice("],\n");
            try large_json.writer().print(
                \\    "registered": "2024-01-{d:0>2}T{d:0>2}:{d:0>2}:00Z"
                \\  }}
            , .{ (i % 28) + 1, i % 24, i % 60 });

            if (i < 49999) try large_json.appendSlice(",");
            try large_json.append('\n');
        }
        try large_json.appendSlice("]\n");

        try dir.writeFile(.{ .sub_path = "large_data.json", .data = large_json.items });
    }

    /// Generate encoding test files
    fn generateEncodingTests(allocator: std.mem.Allocator, dir: std.fs.Dir) !void {
        std.debug.print("  Generating encoding test files...\n", .{});

        // Pure ASCII
        const ascii_content = 
            \\ASCII Test File
            \\===============
            \\This file contains only ASCII characters (0-127).
            \\Numbers: 0123456789
            \\Uppercase: ABCDEFGHIJKLMNOPQRSTUVWXYZ
            \\Lowercase: abcdefghijklmnopqrstuvwxyz
            \\Symbols: !@#$%^&*()_+-=[]{}|;':",./<>?`~
            \\Control chars: tab and newline
            \\are also ASCII.
        ;
        try dir.writeFile(.{ .sub_path = "encoding_ascii.txt", .data = ascii_content });

        // UTF-8 with BOM
        var utf8_bom = std.ArrayList(u8).init(allocator);
        defer utf8_bom.deinit();
        
        // UTF-8 BOM
        try utf8_bom.appendSlice(&[_]u8{ 0xEF, 0xBB, 0xBF });
        try utf8_bom.appendSlice(
            \\UTF-8 with BOM Test
            \\===================
            \\Latin: café, naïve, résumé
            \\Greek: Α α, Β β, Γ γ, Δ δ, Ε ε
            \\Cyrillic: А а, Б б, В в, Г г, Д д
            \\Chinese: 你好世界 (Hello World)
            \\Japanese: こんにちは世界 (Konnichiwa sekai)
            \\Korean: 안녕하세요 세계 (Annyeonghaseyo segye)
            \\Arabic: مرحبا بالعالم (Marhaban bil'alam)
            \\Hebrew: שלום עולם (Shalom olam)
            \\Emoji: 😀 😃 😄 😁 🎉 🚀 ❤️ ✨
        );
        try dir.writeFile(.{ .sub_path = "encoding_utf8_bom.txt", .data = utf8_bom.items });

        // Mixed ASCII and UTF-8
        const mixed_encoding = 
            \\Mixed Encoding Test
            \\===================
            \\Line 1: Pure ASCII text
            \\Line 2: Café résumé naïve (Latin extended)
            \\Line 3: Mathematical: ∑ ∏ ∫ ∂ ∇ ∞ ≈ ≠ ≤ ≥
            \\Line 4: Emoji party: 🎉 🎊 🎈 🎁 🎂 🍰
            \\Line 5: Box drawing: ┌─┬─┐ │ │ │ ├─┼─┤ │ │ │ └─┴─┘
            \\Line 6: Currency: $ € £ ¥ ₹ ₽ ¢
            \\Line 7: Back to ASCII
        ;
        try dir.writeFile(.{ .sub_path = "encoding_mixed.txt", .data = mixed_encoding });
    }

    /// Generate line ending test files
    fn generateLineEndingTests(allocator: std.mem.Allocator, dir: std.fs.Dir) !void {
        _ = allocator; // Mark as used
        std.debug.print("  Generating line ending test files...\n", .{});

        // LF (Unix) line endings
        const lf_content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\n";
        try dir.writeFile(.{ .sub_path = "line_ending_lf.txt", .data = lf_content });

        // CRLF (Windows) line endings
        const crlf_content = "Line 1\r\nLine 2\r\nLine 3\r\nLine 4\r\nLine 5\r\n";
        try dir.writeFile(.{ .sub_path = "line_ending_crlf.txt", .data = crlf_content });

        // CR (Classic Mac) line endings
        const cr_content = "Line 1\rLine 2\rLine 3\rLine 4\rLine 5\r";
        try dir.writeFile(.{ .sub_path = "line_ending_cr.txt", .data = cr_content });

        // Mixed line endings (problematic but real-world)
        const mixed_endings = "Line 1\nLine 2\r\nLine 3\rLine 4\n\rLine 5\r\nLine 6\n";
        try dir.writeFile(.{ .sub_path = "line_ending_mixed.txt", .data = mixed_endings });
    }

    /// Generate mixed content files
    fn generateMixedContent(allocator: std.mem.Allocator, dir: std.fs.Dir) !void {
        _ = allocator; // Mark as used
        std.debug.print("  Generating mixed content files...\n", .{});

        // Code with comments and strings containing special characters
        const code_mixed = 
            \\// Complex source file with mixed content
            \\const message = "Hello, 世界! 🌍"; // UTF-8 string
            \\const regex = /[\u0000-\u001F]/g; // Control chars
            \\
            \\/* Multi-line comment
            \\ * with special chars: © ® ™
            \\ * and emoji: 🔥 💯 ✅
            \\ */
            \\
            \\function calculate(α, β, γ) {
            \\    const π = 3.14159;
            \\    const result = α * Math.sin(β) + γ;
            \\    console.log(`Result: ${result}°`);
            \\    return result;
            \\}
            \\
            \\// Test data with tabs and spaces mixed
            \\const data = {
            \\    name: "Test",  // Tab replaced with spaces
            \\    value: 42,     // Space indented
            \\    emoji: "🚀"    // Tab replaced with spaces
            \\};
        ;
        try dir.writeFile(.{ .sub_path = "mixed_code.js", .data = code_mixed });

        // Markdown with code blocks and tables
        const markdown_mixed = 
            \\# Mixed Content Markdown
            \\
            \\## Introduction
            \\
            \\This document contains **mixed content** including:
            \\- ASCII text
            \\- UTF-8 characters: café, naïve
            \\- Emoji: 🎯 🎨 🎭
            \\- Code blocks
            \\
            \\## Code Example
            \\
            \\```zig
            \\const std = @import("std");
            \\
            \\pub fn main() !void {
            \\    std.debug.print("Hello, 世界!\n", .{});
            \\}
            \\```
            \\
            \\## Data Table
            \\
            \\| Column 1 | Column 2 | Column 3 |
            \\|----------|----------|----------|
            \\| α        | β        | γ        |
            \\| 😀       | 😎       | 🤔       |
            \\| 100%     | 50°C     | €99.99   |
            \\
            \\## Special Characters
            \\
            \\- Copyright: ©
            \\- Registered: ®
            \\- Trademark: ™
            \\- Math: ∑ ∏ ∫ ∞
            \\- Arrows: ← → ↑ ↓ ↔ ⇒
        ;
        try dir.writeFile(.{ .sub_path = "mixed_content.md", .data = markdown_mixed });
    }

    /// Main entry point for standalone test data generation
    pub fn main() !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        try generateAllTestData(allocator);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝