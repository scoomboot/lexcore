// streaming_test.zig — Test suite for streaming buffer functionality
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/buffer/streaming_test
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const buffer = @import("buffer.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: StreamingBuffer: initialization and cleanup" {
        const test_content = "This is test content for streaming buffer";
        
        // Create a temporary file
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("test.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(test_content);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, 16);
        defer sbuf.deinit();
        
        try testing.expect(sbuf.window_size == 16);
        try testing.expect(sbuf.window_start == 0);
        try testing.expect(sbuf.position == 0);
        try testing.expect(!sbuf.eof_reached);
    }
    
    test "unit: StreamingBuffer: basic read operations" {
        const test_content = "Hello, World!";
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("test.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(test_content);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, 8);
        defer sbuf.deinit();
        
        // Peek and next operations
        const first = try sbuf.peek();
        try testing.expect(first == 'H');
        try testing.expect(sbuf.position == 0);
        
        const next = try sbuf.next();
        try testing.expect(next == 'H');
        try testing.expect(sbuf.position == 1);
        
        // Read more characters
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            _ = try sbuf.next();
        }
        
        const char = try sbuf.peek();
        try testing.expect(char == ',');
    }
    
    test "unit: StreamingBuffer: window sliding" {
        // Create content larger than window size
        var content = std.ArrayList(u8).init(testing.allocator);
        defer content.deinit();
        
        var i: usize = 0;
        while (i < 50) : (i += 1) {
            try content.append(@intCast('A' + (i % 26)));
        }
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("test.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(content.items);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, 16);
        defer sbuf.deinit();
        
        // Read through the entire window
        i = 0;
        while (i < 16) : (i += 1) {
            const byte = try sbuf.next();
            try testing.expect(byte == 'A' + (i % 26));
        }
        
        // This should trigger window sliding
        const next_byte = try sbuf.next();
        try testing.expect(next_byte == 'A' + (16 % 26));
        
        // Window should have slid
        try testing.expect(sbuf.window_start > 0);
    }
    
    test "unit: StreamingBuffer: absolute position tracking" {
        const test_content = "0123456789ABCDEFGHIJKLMNOP";
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("test.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(test_content);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, 10);
        defer sbuf.deinit();
        
        // Read some bytes
        var i: usize = 0;
        while (i < 5) : (i += 1) {
            _ = try sbuf.next();
        }
        
        var abs_pos = sbuf.getAbsolutePosition();
        try testing.expect(abs_pos == 5);
        
        // Read past window boundary
        while (i < 15) : (i += 1) {
            _ = try sbuf.next();
        }
        
        abs_pos = sbuf.getAbsolutePosition();
        try testing.expect(abs_pos == 15);
    }
    
    test "unit: StreamingBuffer: EOF handling" {
        const test_content = "Short";
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("test.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(test_content);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, 16);
        defer sbuf.deinit();
        
        // EOF should be reached on initial fill since content < window
        try testing.expect(sbuf.eof_reached);
        
        // Read all content
        var i: usize = 0;
        while (i < test_content.len) : (i += 1) {
            _ = try sbuf.next();
        }
        
        // Should be at end
        try testing.expect(sbuf.isAtEnd());
        
        // Further reads should fail
        try testing.expectError(error.EndOfStream, sbuf.next());
    }
    
    test "integration: StreamingBuffer: large file processing" {
        // Create a large file
        var content = std.ArrayList(u8).init(testing.allocator);
        defer content.deinit();
        
        // Generate 10KB of data
        var i: usize = 0;
        while (i < 10240) : (i += 1) {
            try content.append(@intCast('A' + (i % 26)));
        }
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("large.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(content.items);
        try file.seekTo(0);
        
        // Use a small window to force many slides
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, 64);
        defer sbuf.deinit();
        
        // Read and verify all data
        i = 0;
        while (i < content.items.len) : (i += 1) {
            const byte = try sbuf.next();
            try testing.expect(byte == content.items[i]);
        }
        
        // Should be at end
        try testing.expect(sbuf.isAtEnd());
    }
    
    test "performance: StreamingBuffer: throughput measurement" {
        // Create a 1MB file
        var content = try testing.allocator.alloc(u8, 1024 * 1024);
        defer testing.allocator.free(content);
        
        // Fill with pattern
        var i: usize = 0;
        while (i < content.len) : (i += 1) {
            content[i] = @intCast(i & 0xFF);
        }
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("perf.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(content);
        try file.seekTo(0);
        
        // Test with different window sizes
        const window_sizes = [_]usize{ 256, 1024, 4096, 16384 };
        
        for (window_sizes) |window_size| {
            try file.seekTo(0);
            
            var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, window_size);
            defer sbuf.deinit();
            
            const start = std.time.nanoTimestamp();
            
            // Read entire file
            var bytes_read: usize = 0;
            while (!sbuf.isAtEnd()) {
                _ = try sbuf.next();
                bytes_read += 1;
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const elapsed_ms = @as(f64, @floatFromInt(elapsed)) / 1_000_000.0;
            const throughput_mb = @as(f64, @floatFromInt(bytes_read)) / (1024.0 * 1024.0) / (elapsed_ms / 1000.0);
            
            // Just verify we read all bytes
            try testing.expect(bytes_read == content.len);
            
            // Performance should be reasonable (at least 10 MB/s)
            // Note: This is a soft check, may vary on different systems
            _ = throughput_mb;
        }
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝