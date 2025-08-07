// buffer.test.zig — Comprehensive test suite for input buffering and character streaming
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/buffer/test
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const buffer = @import("buffer.zig");
    const Buffer = buffer.Buffer;
    const CircularBuffer = buffer.CircularBuffer;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Helper to create test buffer with UTF-8 content
    fn createUTF8TestBuffer(allocator: std.mem.Allocator, content: []const u8) !Buffer {
        return Buffer.initWithContent(allocator, content);
    }

    /// Helper to measure operation timing (nanoseconds)
    fn measureTime(comptime func: anytype, args: anytype) !u64 {
        const start = std.time.nanoTimestamp();
        _ = try @call(.auto, func, args);
        const end = std.time.nanoTimestamp();
        return @intCast(end - start);
    }

    /// Helper to create large test data
    fn createLargeTestData(allocator: std.mem.Allocator, size: usize) ![]u8 {
        const data = try allocator.alloc(u8, size);
        for (data, 0..) |*byte, i| {
            byte.* = @intCast(i % 256);
        }
        return data;
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: BASIC ══════════════════════════════════════╗

    test "unit: Buffer: initialization with empty buffer" {
        var buf = try Buffer.init(testing.allocator);
        defer buf.deinit();
        
        try testing.expect(buf.position == 0);
        try testing.expect(buf.data.len == 0);
        try testing.expect(buf.mark == null);
        try testing.expect(buf.isAtEnd());
        try testing.expect(buf.remaining() == 0);
    }
    
    test "unit: Buffer: initialization with ASCII content" {
        const content = "test content 123!@#";
        var buf = try Buffer.initWithContent(testing.allocator, content);
        defer buf.deinit();
        
        try testing.expect(buf.position == 0);
        try testing.expectEqualStrings(content, buf.data);
        try testing.expect(!buf.isAtEnd());
        try testing.expect(buf.remaining() == content.len);
    }

    test "unit: Buffer: peek returns correct ASCII character" {
        var buf = try Buffer.initWithContent(testing.allocator, "hello");
        defer buf.deinit();
        
        const char = try buf.peek();
        try testing.expectEqual(@as(u8, 'h'), char);
        try testing.expectEqual(@as(usize, 0), buf.position);
        
        // Multiple peeks should return same character
        const char2 = try buf.peek();
        try testing.expectEqual(char, char2);
    }

    test "unit: Buffer: peekN looks ahead correctly" {
        var buf = try Buffer.initWithContent(testing.allocator, "abcdefghij");
        defer buf.deinit();
        
        try testing.expectEqual(@as(u8, 'a'), try buf.peekN(0));
        try testing.expectEqual(@as(u8, 'b'), try buf.peekN(1));
        try testing.expectEqual(@as(u8, 'e'), try buf.peekN(4));
        try testing.expectEqual(@as(u8, 'j'), try buf.peekN(9));
        
        // Position should not change
        try testing.expectEqual(@as(usize, 0), buf.position);
    }

    test "unit: Buffer: next advances position correctly" {
        var buf = try Buffer.initWithContent(testing.allocator, "abc");
        defer buf.deinit();
        
        try testing.expectEqual(@as(u8, 'a'), try buf.next());
        try testing.expectEqual(@as(usize, 1), buf.position);
        
        try testing.expectEqual(@as(u8, 'b'), try buf.next());
        try testing.expectEqual(@as(usize, 2), buf.position);
        
        try testing.expectEqual(@as(u8, 'c'), try buf.next());
        try testing.expectEqual(@as(usize, 3), buf.position);
        
        // Should error at end
        try testing.expectError(error.EndOfBuffer, buf.next());
    }

    test "unit: Buffer: advance moves position forward" {
        var buf = try Buffer.initWithContent(testing.allocator, "0123456789");
        defer buf.deinit();
        
        buf.advance(0);
        try testing.expectEqual(@as(usize, 0), buf.position);
        
        buf.advance(5);
        try testing.expectEqual(@as(usize, 5), buf.position);
        try testing.expectEqual(@as(u8, '5'), try buf.peek());
        
        // Advance beyond end should clamp
        buf.advance(100);
        try testing.expectEqual(@as(usize, 10), buf.position);
        try testing.expect(buf.isAtEnd());
    }

    test "unit: Buffer: retreat moves position backward" {
        var buf = try Buffer.initWithContent(testing.allocator, "0123456789");
        defer buf.deinit();
        
        buf.advance(7);
        try testing.expectEqual(@as(usize, 7), buf.position);
        
        buf.retreat(3);
        try testing.expectEqual(@as(usize, 4), buf.position);
        try testing.expectEqual(@as(u8, '4'), try buf.peek());
        
        // Retreat beyond start should clamp to 0
        buf.retreat(100);
        try testing.expectEqual(@as(usize, 0), buf.position);
        try testing.expectEqual(@as(u8, '0'), try buf.peek());
    }

    test "unit: Buffer: setContent replaces buffer content" {
        var buf = try Buffer.initWithContent(testing.allocator, "initial");
        defer buf.deinit();
        
        buf.advance(3);
        buf.markPosition();
        
        try buf.setContent("new content");
        try testing.expectEqualStrings("new content", buf.data);
        try testing.expectEqual(@as(usize, 0), buf.position);
        try testing.expect(buf.mark == null);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: MARK ══════════════════════════════════════╗

    test "unit: Buffer: mark and restore single position" {
        var buf = try Buffer.initWithContent(testing.allocator, "hello world");
        defer buf.deinit();
        
        buf.advance(5);
        buf.markPosition();
        try testing.expect(buf.mark.? == 5);
        
        buf.advance(3);
        try testing.expectEqual(@as(usize, 8), buf.position);
        
        try buf.restoreMark();
        try testing.expectEqual(@as(usize, 5), buf.position);
        try testing.expect(buf.mark == null);
    }

    test "unit: Buffer: restore without mark returns error" {
        var buf = try Buffer.initWithContent(testing.allocator, "test");
        defer buf.deinit();
        
        try testing.expectError(error.NoMarkSet, buf.restoreMark());
    }

    test "unit: Buffer: multiple mark operations overwrite previous" {
        var buf = try Buffer.initWithContent(testing.allocator, "0123456789");
        defer buf.deinit();
        
        buf.advance(2);
        buf.markPosition();
        try testing.expect(buf.mark.? == 2);
        
        buf.advance(3);
        buf.markPosition();
        try testing.expect(buf.mark.? == 5);
        
        try buf.restoreMark();
        try testing.expectEqual(@as(usize, 5), buf.position);
    }

    test "unit: Buffer: reset clears position and mark" {
        var buf = try Buffer.initWithContent(testing.allocator, "test data");
        defer buf.deinit();
        
        buf.advance(5);
        buf.markPosition();
        
        buf.reset();
        try testing.expectEqual(@as(usize, 0), buf.position);
        try testing.expect(buf.mark == null);
        try testing.expectEqual(@as(u8, 't'), try buf.peek());
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: SLICE ══════════════════════════════════════╗

    test "unit: Buffer: getSlice returns correct substring" {
        var buf = try Buffer.initWithContent(testing.allocator, "hello world");
        defer buf.deinit();
        
        const slice1 = try buf.getSlice(5);
        try testing.expectEqualStrings("hello", slice1);
        
        buf.advance(6);
        const slice2 = try buf.getSlice(5);
        try testing.expectEqualStrings("world", slice2);
    }

    test "unit: Buffer: getSlice handles partial availability" {
        var buf = try Buffer.initWithContent(testing.allocator, "short");
        defer buf.deinit();
        
        buf.advance(2);
        const slice = try buf.getSlice(10); // Request more than available
        try testing.expectEqualStrings("ort", slice);
    }

    test "unit: Buffer: getSlice at end returns error" {
        var buf = try Buffer.initWithContent(testing.allocator, "test");
        defer buf.deinit();
        
        buf.advance(4);
        try testing.expectError(error.EndOfBuffer, buf.getSlice(1));
    }

    test "unit: Buffer: getRemainingSlice returns tail content" {
        var buf = try Buffer.initWithContent(testing.allocator, "0123456789");
        defer buf.deinit();
        
        const full = buf.getRemainingSlice();
        try testing.expectEqualStrings("0123456789", full);
        
        buf.advance(5);
        const partial = buf.getRemainingSlice();
        try testing.expectEqualStrings("56789", partial);
        
        buf.advance(5);
        const empty = buf.getRemainingSlice();
        try testing.expectEqualStrings("", empty);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: BOUNDARY ══════════════════════════════════════╗

    test "unit: Buffer: operations on empty buffer" {
        var buf = try Buffer.init(testing.allocator);
        defer buf.deinit();
        
        try testing.expect(buf.isAtEnd());
        try testing.expectEqual(@as(usize, 0), buf.remaining());
        try testing.expectError(error.EndOfBuffer, buf.peek());
        try testing.expectError(error.EndOfBuffer, buf.peekN(0));
        try testing.expectError(error.EndOfBuffer, buf.next());
        try testing.expectError(error.EndOfBuffer, buf.getSlice(1));
        
        const empty = buf.getRemainingSlice();
        try testing.expectEqualStrings("", empty);
    }

    test "unit: Buffer: single character buffer operations" {
        var buf = try Buffer.initWithContent(testing.allocator, "X");
        defer buf.deinit();
        
        try testing.expectEqual(@as(u8, 'X'), try buf.peek());
        try testing.expectEqual(@as(usize, 1), buf.remaining());
        try testing.expectError(error.EndOfBuffer, buf.peekN(1));
        
        try testing.expectEqual(@as(u8, 'X'), try buf.next());
        try testing.expect(buf.isAtEnd());
        try testing.expectError(error.EndOfBuffer, buf.peek());
    }

    test "unit: Buffer: operations at buffer boundaries" {
        var buf = try Buffer.initWithContent(testing.allocator, "abc");
        defer buf.deinit();
        
        // At start
        try testing.expectEqual(@as(usize, 0), buf.position);
        buf.retreat(10); // Should stay at 0
        try testing.expectEqual(@as(usize, 0), buf.position);
        
        // At end
        buf.advance(3);
        try testing.expect(buf.isAtEnd());
        buf.advance(10); // Should stay at end
        try testing.expectEqual(@as(usize, 3), buf.position);
        
        // Peek at boundaries
        buf.reset();
        try testing.expectEqual(@as(u8, 'c'), try buf.peekN(2));
        try testing.expectError(error.EndOfBuffer, buf.peekN(3));
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: UTF8 ══════════════════════════════════════╗

    test "unit: Buffer: handles ASCII subset of UTF-8" {
        const ascii = "Hello, World! 123 @#$%";
        var buf = try createUTF8TestBuffer(testing.allocator, ascii);
        defer buf.deinit();
        
        // ASCII is valid UTF-8 subset
        for (ascii) |expected| {
            const actual = try buf.next();
            try testing.expectEqual(expected, actual);
        }
        try testing.expect(buf.isAtEnd());
    }

    test "unit: Buffer: handles 2-byte UTF-8 sequences" {
        // "Café" - é is 2-byte UTF-8 (0xC3 0xA9)
        const text = "Café";
        var buf = try createUTF8TestBuffer(testing.allocator, text);
        defer buf.deinit();
        
        try testing.expectEqual(@as(u8, 'C'), try buf.next());
        try testing.expectEqual(@as(u8, 'a'), try buf.next());
        try testing.expectEqual(@as(u8, 'f'), try buf.next());
        try testing.expectEqual(@as(u8, 0xC3), try buf.next()); // First byte of é
        try testing.expectEqual(@as(u8, 0xA9), try buf.next()); // Second byte of é
    }

    test "unit: Buffer: handles 3-byte UTF-8 sequences" {
        // "€" (Euro sign) is 3-byte UTF-8 (0xE2 0x82 0xAC)
        const text = "Price: €100";
        var buf = try createUTF8TestBuffer(testing.allocator, text);
        defer buf.deinit();
        
        // Skip to Euro sign
        buf.advance(7);
        try testing.expectEqual(@as(u8, 0xE2), try buf.next());
        try testing.expectEqual(@as(u8, 0x82), try buf.next());
        try testing.expectEqual(@as(u8, 0xAC), try buf.next());
        try testing.expectEqual(@as(u8, '1'), try buf.next());
    }

    test "unit: Buffer: handles 4-byte UTF-8 sequences" {
        // "𝄞" (Musical symbol) is 4-byte UTF-8 (0xF0 0x9D 0x84 0x9E)
        const text = "Music: 𝄞";
        var buf = try createUTF8TestBuffer(testing.allocator, text);
        defer buf.deinit();
        
        // Skip to musical symbol
        buf.advance(7);
        try testing.expectEqual(@as(u8, 0xF0), try buf.next());
        try testing.expectEqual(@as(u8, 0x9D), try buf.next());
        try testing.expectEqual(@as(u8, 0x84), try buf.next());
        try testing.expectEqual(@as(u8, 0x9E), try buf.next());
    }

    test "unit: Buffer: mixed ASCII and multi-byte UTF-8" {
        // Mix of 1, 2, 3, and 4-byte sequences
        const text = "Hello café €100 𝄞";
        var buf = try createUTF8TestBuffer(testing.allocator, text);
        defer buf.deinit();
        
        // Verify we can read the entire mixed content byte by byte
        var count: usize = 0;
        while (!buf.isAtEnd()) {
            _ = try buf.next();
            count += 1;
        }
        
        // The string has specific byte count due to multi-byte chars
        // "Hello " = 6, "café" = 5 (é is 2 bytes), " " = 1, 
        // "€" = 3, "100 " = 4, "𝄞" = 4
        try testing.expectEqual(@as(usize, 23), count);
    }

    test "unit: Buffer: peek operations with UTF-8" {
        const text = "a€b"; // 'a' + Euro (3 bytes) + 'b'
        var buf = try createUTF8TestBuffer(testing.allocator, text);
        defer buf.deinit();
        
        try testing.expectEqual(@as(u8, 'a'), try buf.peekN(0));
        try testing.expectEqual(@as(u8, 0xE2), try buf.peekN(1)); // First byte of €
        try testing.expectEqual(@as(u8, 0x82), try buf.peekN(2)); // Second byte of €
        try testing.expectEqual(@as(u8, 0xAC), try buf.peekN(3)); // Third byte of €
        try testing.expectEqual(@as(u8, 'b'), try buf.peekN(4));
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: CIRCULAR ══════════════════════════════════════╗

    test "unit: CircularBuffer: initialization and cleanup" {
        var cbuf = try CircularBuffer.init(testing.allocator, 10);
        defer cbuf.deinit();
        
        try testing.expectEqual(@as(usize, 10), cbuf.capacity);
        try testing.expectEqual(@as(usize, 0), cbuf.count);
        try testing.expectEqual(@as(usize, 0), cbuf.head);
        try testing.expectEqual(@as(usize, 0), cbuf.tail);
        try testing.expect(cbuf.isEmpty());
        try testing.expect(!cbuf.isFull());
        try testing.expectEqual(@as(usize, 10), cbuf.available());
    }

    test "unit: CircularBuffer: write and read single byte" {
        var cbuf = try CircularBuffer.init(testing.allocator, 5);
        defer cbuf.deinit();
        
        try cbuf.write('X');
        try testing.expectEqual(@as(usize, 1), cbuf.count);
        try testing.expect(!cbuf.isEmpty());
        
        const byte = try cbuf.read();
        try testing.expectEqual(@as(u8, 'X'), byte);
        try testing.expectEqual(@as(usize, 0), cbuf.count);
        try testing.expect(cbuf.isEmpty());
    }

    test "unit: CircularBuffer: write and read multiple bytes" {
        var cbuf = try CircularBuffer.init(testing.allocator, 10);
        defer cbuf.deinit();
        
        const data = "hello";
        for (data) |byte| {
            try cbuf.write(byte);
        }
        
        try testing.expectEqual(@as(usize, 5), cbuf.count);
        try testing.expectEqual(@as(usize, 5), cbuf.available());
        
        for (data) |expected| {
            const actual = try cbuf.read();
            try testing.expectEqual(expected, actual);
        }
        
        try testing.expect(cbuf.isEmpty());
    }

    test "unit: CircularBuffer: buffer full condition" {
        var cbuf = try CircularBuffer.init(testing.allocator, 3);
        defer cbuf.deinit();
        
        try cbuf.write('a');
        try cbuf.write('b');
        try cbuf.write('c');
        
        try testing.expect(cbuf.isFull());
        try testing.expectEqual(@as(usize, 0), cbuf.available());
        try testing.expectError(error.BufferFull, cbuf.write('d'));
        
        // After reading one, should have space
        _ = try cbuf.read();
        try testing.expect(!cbuf.isFull());
        try cbuf.write('d'); // Should succeed now
    }

    test "unit: CircularBuffer: buffer empty condition" {
        var cbuf = try CircularBuffer.init(testing.allocator, 5);
        defer cbuf.deinit();
        
        try testing.expect(cbuf.isEmpty());
        try testing.expectError(error.BufferEmpty, cbuf.read());
        
        try cbuf.write('x');
        try testing.expect(!cbuf.isEmpty());
        
        _ = try cbuf.read();
        try testing.expect(cbuf.isEmpty());
        try testing.expectError(error.BufferEmpty, cbuf.read());
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: INTEGRATION ══════════════════════════════════════╗

    test "integration: Buffer: mark and reset with UTF-8 content" {
        const text = "Start café middle €end";
        var buf = try createUTF8TestBuffer(testing.allocator, text);
        defer buf.deinit();
        
        // Advance to 'c' in café
        buf.advance(6);
        buf.markPosition();
        
        // Continue past café
        buf.advance(5); // Now at ' ' after café
        try testing.expectEqual(@as(u8, ' '), try buf.peek());
        
        // Reset to mark
        try buf.restoreMark();
        try testing.expectEqual(@as(u8, 'c'), try buf.peek());
        
        // Verify we can read café correctly from mark
        try testing.expectEqual(@as(u8, 'c'), try buf.next());
        try testing.expectEqual(@as(u8, 'a'), try buf.next());
        try testing.expectEqual(@as(u8, 'f'), try buf.next());
        try testing.expectEqual(@as(u8, 0xC3), try buf.next());
        try testing.expectEqual(@as(u8, 0xA9), try buf.next());
    }

    test "integration: Buffer: complex navigation with mixed content" {
        const text = "123 αβγ 456"; // Greek letters are 2-byte UTF-8
        var buf = try createUTF8TestBuffer(testing.allocator, text);
        defer buf.deinit();
        
        // Skip numbers and space
        buf.advance(4);
        
        // Mark at start of Greek letters
        buf.markPosition();
        
        // Read Greek letters (each is 2 bytes)
        const alpha1 = try buf.next();
        const alpha2 = try buf.next();
        try testing.expectEqual(@as(u8, 0xCE), alpha1); // First byte of α
        try testing.expectEqual(@as(u8, 0xB1), alpha2); // Second byte of α
        
        // Peek ahead at remaining Greek letters
        try testing.expectEqual(@as(u8, 0xCE), try buf.peek()); // First byte of β
        
        // Jump to numbers at end
        buf.advance(5); // Skip remaining Greek letters and space
        try testing.expectEqual(@as(u8, '4'), try buf.peek());
        
        // Reset to Greek letters
        try buf.restoreMark();
        try testing.expectEqual(@as(u8, 0xCE), try buf.peek());
    }

    test "integration: CircularBuffer: wrap around behavior" {
        var cbuf = try CircularBuffer.init(testing.allocator, 4);
        defer cbuf.deinit();
        
        // Fill buffer completely
        try cbuf.write('a');
        try cbuf.write('b');
        try cbuf.write('c');
        try cbuf.write('d');
        
        try testing.expect(cbuf.isFull());
        
        // Read two elements (creates space at beginning)
        try testing.expectEqual(@as(u8, 'a'), try cbuf.read());
        try testing.expectEqual(@as(u8, 'b'), try cbuf.read());
        
        // Write two more (should wrap around)
        try cbuf.write('e');
        try cbuf.write('f');
        
        // Read all remaining in correct order
        try testing.expectEqual(@as(u8, 'c'), try cbuf.read());
        try testing.expectEqual(@as(u8, 'd'), try cbuf.read());
        try testing.expectEqual(@as(u8, 'e'), try cbuf.read());
        try testing.expectEqual(@as(u8, 'f'), try cbuf.read());
        
        try testing.expect(cbuf.isEmpty());
    }

    test "integration: CircularBuffer: continuous read/write pattern" {
        var cbuf = try CircularBuffer.init(testing.allocator, 3);
        defer cbuf.deinit();
        
        // Simulate streaming pattern: write 2, read 1, repeatedly
        var write_value: u8 = 'A';
        var read_count: usize = 0;
        
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            // Write 2 if space available
            if (cbuf.available() >= 2) {
                try cbuf.write(write_value);
                write_value += 1;
                try cbuf.write(write_value);
                write_value += 1;
            }
            
            // Read 1 if available
            if (!cbuf.isEmpty()) {
                _ = try cbuf.read();
                read_count += 1;
            }
        }
        
        // Drain remaining
        while (!cbuf.isEmpty()) {
            _ = try cbuf.read();
            read_count += 1;
        }
        
        try testing.expect(read_count > 0);
        try testing.expect(cbuf.isEmpty());
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: PERFORMANCE ══════════════════════════════════════╗

    test "performance: Buffer: sequential read throughput" {
        const size = 10000;
        const data = try createLargeTestData(testing.allocator, size);
        defer testing.allocator.free(data);
        
        var buf = try Buffer.initWithContent(testing.allocator, data);
        defer buf.deinit();
        
        const start = std.time.nanoTimestamp();
        
        var count: usize = 0;
        while (!buf.isAtEnd()) {
            _ = try buf.next();
            count += 1;
        }
        
        const end = std.time.nanoTimestamp();
        const elapsed_ns = end - start;
        const throughput = (size * 1_000_000_000) / @as(usize, @intCast(elapsed_ns));
        
        try testing.expectEqual(size, count);
        // Performance assertion: should process at least 1MB/sec
        try testing.expect(throughput > 1_000_000);
    }

    test "performance: Buffer: peek operations efficiency" {
        const size = 1000;
        const data = try createLargeTestData(testing.allocator, size);
        defer testing.allocator.free(data);
        
        var buf = try Buffer.initWithContent(testing.allocator, data);
        defer buf.deinit();
        
        const iterations = 10000;
        const start = std.time.nanoTimestamp();
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            _ = try buf.peek();
        }
        
        const end = std.time.nanoTimestamp();
        const elapsed_ns = end - start;
        const ops_per_sec = (iterations * 1_000_000_000) / @as(usize, @intCast(elapsed_ns));
        
        // Performance assertion: should handle at least 1M peeks/sec
        try testing.expect(ops_per_sec > 1_000_000);
    }

    test "performance: CircularBuffer: write/read cycle efficiency" {
        var cbuf = try CircularBuffer.init(testing.allocator, 256);
        defer cbuf.deinit();
        
        const cycles = 1000;
        const start = std.time.nanoTimestamp();
        
        var i: usize = 0;
        while (i < cycles) : (i += 1) {
            // Write batch
            var j: usize = 0;
            while (j < 100 and !cbuf.isFull()) : (j += 1) {
                try cbuf.write(@intCast(j % 256));
            }
            
            // Read batch
            j = 0;
            while (j < 50 and !cbuf.isEmpty()) : (j += 1) {
                _ = try cbuf.read();
            }
        }
        
        const end = std.time.nanoTimestamp();
        const elapsed_ns = end - start;
        const ops_per_sec = (cycles * 150 * 1_000_000_000) / @as(usize, @intCast(elapsed_ns));
        
        // Performance assertion: should handle at least 100K ops/sec
        try testing.expect(ops_per_sec > 100_000);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: STRESS ══════════════════════════════════════╗

    test "stress: Buffer: handles maximum size input" {
        const max_size = 1024 * 1024; // 1MB
        const data = try createLargeTestData(testing.allocator, max_size);
        defer testing.allocator.free(data);
        
        var buf = try Buffer.initWithContent(testing.allocator, data);
        defer buf.deinit();
        
        try testing.expectEqual(max_size, buf.data.len);
        try testing.expectEqual(max_size, buf.remaining());
        
        // Verify we can navigate the entire buffer
        buf.advance(max_size / 2);
        try testing.expectEqual(max_size / 2, buf.position);
        
        buf.markPosition();
        buf.advance(max_size / 4);
        try buf.restoreMark();
        try testing.expectEqual(max_size / 2, buf.position);
        
        // Jump to end
        buf.advance(max_size);
        try testing.expect(buf.isAtEnd());
    }

    test "stress: Buffer: rapid mark/reset operations" {
        const text = "0123456789";
        var buf = try Buffer.initWithContent(testing.allocator, text);
        defer buf.deinit();
        
        const iterations = 1000;
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const pos = i % text.len;
            buf.position = pos;
            buf.markPosition();
            
            buf.advance((i * 3) % text.len);
            try buf.restoreMark();
            
            try testing.expectEqual(pos, buf.position);
        }
    }

    test "stress: CircularBuffer: maximum capacity operations" {
        const max_capacity = 64 * 1024; // 64KB
        var cbuf = try CircularBuffer.init(testing.allocator, max_capacity);
        defer cbuf.deinit();
        
        // Fill to capacity
        var i: usize = 0;
        while (i < max_capacity) : (i += 1) {
            try cbuf.write(@intCast(i % 256));
        }
        
        try testing.expect(cbuf.isFull());
        try testing.expectEqual(@as(usize, 0), cbuf.available());
        
        // Read half
        i = 0;
        while (i < max_capacity / 2) : (i += 1) {
            _ = try cbuf.read();
        }
        
        try testing.expectEqual(max_capacity / 2, cbuf.available());
        
        // Fill again (tests wrap around at large scale)
        i = 0;
        while (i < max_capacity / 2) : (i += 1) {
            try cbuf.write(@intCast(i % 256));
        }
        
        try testing.expect(cbuf.isFull());
    }

    test "stress: CircularBuffer: rapid wrap around" {
        var cbuf = try CircularBuffer.init(testing.allocator, 7); // Prime number size
        defer cbuf.deinit();
        
        const operations = 10000;
        var write_count: usize = 0;
        var read_count: usize = 0;
        
        var i: usize = 0;
        while (i < operations) : (i += 1) {
            // Pseudo-random pattern
            const action = (i * 7 + 3) % 5;
            
            if (action < 3 and !cbuf.isFull()) {
                try cbuf.write(@intCast(write_count % 256));
                write_count += 1;
            } else if (!cbuf.isEmpty()) {
                _ = try cbuf.read();
                read_count += 1;
            }
        }
        
        // Drain remaining
        while (!cbuf.isEmpty()) {
            _ = try cbuf.read();
            read_count += 1;
        }
        
        try testing.expectEqual(write_count, read_count);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST: EDGE ══════════════════════════════════════╗

    test "unit: Buffer: zero-length operations" {
        var buf = try Buffer.initWithContent(testing.allocator, "test");
        defer buf.deinit();
        
        buf.advance(0);
        try testing.expectEqual(@as(usize, 0), buf.position);
        
        buf.retreat(0);
        try testing.expectEqual(@as(usize, 0), buf.position);
        
        const slice = try buf.getSlice(0);
        try testing.expectEqualStrings("", slice);
    }

    test "unit: Buffer: operations after multiple resets" {
        var buf = try Buffer.initWithContent(testing.allocator, "reset test");
        defer buf.deinit();
        
        buf.advance(5);
        buf.markPosition();
        buf.reset();
        
        try testing.expectEqual(@as(usize, 0), buf.position);
        try testing.expect(buf.mark == null);
        
        buf.advance(3);
        buf.reset();
        
        try testing.expectEqual(@as(usize, 0), buf.position);
        try testing.expectEqual(@as(u8, 'r'), try buf.peek());
    }

    test "unit: CircularBuffer: alternating single operations" {
        var cbuf = try CircularBuffer.init(testing.allocator, 2);
        defer cbuf.deinit();
        
        try cbuf.write('a');
        try testing.expectEqual(@as(u8, 'a'), try cbuf.read());
        
        try cbuf.write('b');
        try testing.expectEqual(@as(u8, 'b'), try cbuf.read());
        
        try cbuf.write('c');
        try cbuf.write('d');
        try testing.expect(cbuf.isFull());
        
        try testing.expectEqual(@as(u8, 'c'), try cbuf.read());
        try testing.expectEqual(@as(u8, 'd'), try cbuf.read());
        try testing.expect(cbuf.isEmpty());
    }

    test "integration: Buffer: UTF-8 boundary at buffer end" {
        // Euro sign (3 bytes) with incomplete sequence at end
        const incomplete = [_]u8{ 'a', 'b', 0xE2, 0x82 }; // Missing last byte of €
        var buf = try Buffer.initWithContent(testing.allocator, &incomplete);
        defer buf.deinit();
        
        try testing.expectEqual(@as(u8, 'a'), try buf.next());
        try testing.expectEqual(@as(u8, 'b'), try buf.next());
        try testing.expectEqual(@as(u8, 0xE2), try buf.next());
        try testing.expectEqual(@as(u8, 0x82), try buf.next());
        
        // At end with incomplete UTF-8 sequence
        try testing.expect(buf.isAtEnd());
        try testing.expectError(error.EndOfBuffer, buf.next());
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝