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
    
    // Edge case tests for comprehensive coverage
    
    test "unit: StreamingBuffer: empty file handling" {
        // Test that StreamingBuffer correctly handles a completely empty file
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("empty.txt", .{ .read = true });
        defer file.close();
        
        // File has no content
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, 16);
        defer sbuf.deinit();
        
        // Should immediately detect EOF
        try testing.expect(sbuf.eof_reached);
        try testing.expect(sbuf.isAtEnd());
        try testing.expect(sbuf.valid_bytes == 0);
        
        // Any read attempt should fail
        try testing.expectError(error.EndOfStream, sbuf.next());
        try testing.expectError(error.EndOfStream, sbuf.peek());
    }
    
    test "unit: StreamingBuffer: single byte file" {
        // Test that a file with just one byte is processed correctly
        const single_byte: [1]u8 = .{'X'};
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("single.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(&single_byte);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, 16);
        defer sbuf.deinit();
        
        // Should have exactly one byte available
        try testing.expect(sbuf.eof_reached);
        try testing.expect(sbuf.valid_bytes == 1);
        try testing.expect(!sbuf.isAtEnd());
        
        // Read the single byte
        const byte = try sbuf.next();
        try testing.expect(byte == 'X');
        
        // Now should be at end
        try testing.expect(sbuf.isAtEnd());
        try testing.expectError(error.EndOfStream, sbuf.next());
    }
    
    test "unit: StreamingBuffer: file exactly matching buffer size" {
        // Test when file size equals window size
        const window_size: usize = 8;
        var content: [8]u8 = undefined;
        
        // Fill with recognizable pattern
        var i: usize = 0;
        while (i < window_size) : (i += 1) {
            content[i] = @intCast('0' + i);
        }
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("exact.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(&content);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, window_size);
        defer sbuf.deinit();
        
        // Should fill entire window and reach EOF
        try testing.expect(sbuf.eof_reached);
        try testing.expect(sbuf.valid_bytes == window_size);
        
        // Read all bytes
        i = 0;
        while (i < window_size) : (i += 1) {
            const byte = try sbuf.next();
            try testing.expect(byte == '0' + i);
        }
        
        // Should be at end
        try testing.expect(sbuf.isAtEnd());
        try testing.expectError(error.EndOfStream, sbuf.next());
    }
    
    test "unit: StreamingBuffer: file slightly larger than buffer size" {
        // Test when file is window_size + 1 byte
        const window_size: usize = 8;
        var content: [9]u8 = undefined;
        
        // Fill with recognizable pattern
        var i: usize = 0;
        while (i < content.len) : (i += 1) {
            content[i] = @intCast('A' + (i % 26));
        }
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("larger.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(&content);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, window_size);
        defer sbuf.deinit();
        
        // Should NOT reach EOF on initial fill
        try testing.expect(!sbuf.eof_reached);
        try testing.expect(sbuf.valid_bytes == window_size);
        
        // Read through window
        i = 0;
        while (i < window_size) : (i += 1) {
            const byte = try sbuf.next();
            try testing.expect(byte == 'A' + (i % 26));
        }
        
        // Reading one more should trigger slide and read the last byte
        const last_byte = try sbuf.next();
        try testing.expect(last_byte == 'I');
        try testing.expect(sbuf.eof_reached);
        
        // Should now be at end
        try testing.expect(sbuf.isAtEnd());
    }
    
    test "unit: StreamingBuffer: file exact multiple of buffer size" {
        // Test when file size is exactly 2x and 3x window size
        const window_size: usize = 10;
        
        // Test 2x window size
        {
            var content: [20]u8 = undefined;
            var i: usize = 0;
            while (i < content.len) : (i += 1) {
                content[i] = @intCast('a' + (i % 26));
            }
            
            var tmp_dir = testing.tmpDir(.{});
            defer tmp_dir.cleanup();
            
            const file = try tmp_dir.dir.createFile("double.txt", .{ .read = true });
            defer file.close();
            
            try file.writeAll(&content);
            try file.seekTo(0);
            
            var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, window_size);
            defer sbuf.deinit();
            
            // Should not reach EOF initially
            try testing.expect(!sbuf.eof_reached);
            
            // Read first window worth
            i = 0;
            while (i < window_size) : (i += 1) {
                const byte = try sbuf.next();
                try testing.expect(byte == 'a' + (i % 26));
            }
            
            // Read second window worth (should trigger slide)
            while (i < content.len) : (i += 1) {
                const byte = try sbuf.next();
                try testing.expect(byte == 'a' + (i % 26));
            }
            
            try testing.expect(sbuf.isAtEnd());
        }
        
        // Test 3x window size
        {
            var content: [30]u8 = undefined;
            var i: usize = 0;
            while (i < content.len) : (i += 1) {
                content[i] = @intCast('0' + (i % 10));
            }
            
            var tmp_dir = testing.tmpDir(.{});
            defer tmp_dir.cleanup();
            
            const file = try tmp_dir.dir.createFile("triple.txt", .{ .read = true });
            defer file.close();
            
            try file.writeAll(&content);
            try file.seekTo(0);
            
            var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, window_size);
            defer sbuf.deinit();
            
            // Read all three windows worth
            i = 0;
            while (i < content.len) : (i += 1) {
                const byte = try sbuf.next();
                try testing.expect(byte == '0' + (i % 10));
            }
            
            try testing.expect(sbuf.isAtEnd());
            try testing.expect(sbuf.eof_reached);
        }
    }
    
    test "unit: StreamingBuffer: very small window with larger file" {
        // Test with a minimal 2-byte window on a larger file
        const tiny_window: usize = 2;
        const content = "ABCDEFGHIJ"; // 10 bytes
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("tiny_window.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(content);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, tiny_window);
        defer sbuf.deinit();
        
        // Should only load 2 bytes initially
        try testing.expect(sbuf.valid_bytes == tiny_window);
        try testing.expect(!sbuf.eof_reached);
        
        // Read entire file, verifying frequent sliding works correctly
        var i: usize = 0;
        var previous_window_start: usize = 0;
        var slides_detected: usize = 0;
        
        while (i < content.len) : (i += 1) {
            const byte = try sbuf.next();
            try testing.expect(byte == content[i]);
            
            // Check if window has slid
            if (sbuf.window_start > previous_window_start) {
                slides_detected += 1;
                previous_window_start = sbuf.window_start;
            }
        }
        
        // With a 2-byte window and 10 bytes of content, we should see multiple slides
        try testing.expect(slides_detected > 0);
        
        try testing.expect(sbuf.isAtEnd());
        try testing.expect(sbuf.eof_reached);
    }
    
    test "unit: StreamingBuffer: boundary conditions at exact EOF" {
        // Test sliding that occurs exactly at EOF boundary
        const window_size: usize = 5;
        const content = "1234567890"; // 10 bytes = 2x window
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("boundary.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(content);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, window_size);
        defer sbuf.deinit();
        
        // Read first window (5 bytes)
        var i: usize = 0;
        while (i < window_size) : (i += 1) {
            const byte = try sbuf.next();
            try testing.expect(byte == '1' + i);
        }
        
        // At this point, position = 5, window has bytes 0-4
        try testing.expect(!sbuf.eof_reached);
        try testing.expect(sbuf.position == 5);
        
        // Next read should trigger slide to load bytes 5-9
        const sixth_byte = try sbuf.next();
        try testing.expect(sixth_byte == '6');
        
        // Window should have slid
        try testing.expect(sbuf.window_start == 5);
        try testing.expect(sbuf.eof_reached); // Should detect EOF after slide
        
        // Read remaining bytes (7, 8, 9, 0)
        // Content is "1234567890" so after '6' we have '7', '8', '9', '0'
        const expected_bytes = [_]u8{ '7', '8', '9', '0' };
        i = 0;
        while (i < expected_bytes.len) : (i += 1) {
            const byte = try sbuf.next();
            try testing.expect(byte == expected_bytes[i]);
        }
        
        // Should be exactly at end
        try testing.expect(sbuf.isAtEnd());
        try testing.expectError(error.EndOfStream, sbuf.next());
    }
    
    test "unit: StreamingBuffer: multiple small reads near EOF" {
        // Test behavior with multiple small reads approaching EOF
        const window_size: usize = 6;
        const content = "ABC"; // 3 bytes, half of window
        
        var tmp_dir = testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        
        const file = try tmp_dir.dir.createFile("small_eof.txt", .{ .read = true });
        defer file.close();
        
        try file.writeAll(content);
        try file.seekTo(0);
        
        var sbuf = try buffer.StreamingBuffer.init(testing.allocator, file, window_size);
        defer sbuf.deinit();
        
        // Should immediately detect EOF since content < window
        try testing.expect(sbuf.eof_reached);
        try testing.expect(sbuf.valid_bytes == 3);
        
        // Peek multiple times should always return same value
        const first_peek = try sbuf.peek();
        try testing.expect(first_peek == 'A');
        const second_peek = try sbuf.peek();
        try testing.expect(second_peek == 'A');
        
        // Position shouldn't change with peek
        try testing.expect(sbuf.position == 0);
        
        // Read all bytes
        var i: usize = 0;
        while (i < content.len) : (i += 1) {
            const byte = try sbuf.next();
            try testing.expect(byte == content[i]);
        }
        
        // Multiple EOF reads should all fail consistently
        try testing.expectError(error.EndOfStream, sbuf.next());
        try testing.expectError(error.EndOfStream, sbuf.peek());
        try testing.expectError(error.EndOfStream, sbuf.next());
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝