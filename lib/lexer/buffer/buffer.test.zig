// buffer.test.zig — Test suite for input buffering
//
// repo   : https://github.com/emoessner/lexcore  
// docs   : https://emoessner.github.io/lexcore/lib/lexer/buffer/test
// author : https://github.com/emoessner
//
// Developed with ❤️ by emoessner.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const buffer = @import("buffer.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: Buffer: initialization and cleanup" {
        var buf = try buffer.Buffer.init(testing.allocator);
        defer buf.deinit();
        
        try testing.expect(buf.position == 0);
        try testing.expect(buf.data.len == 0);
        try testing.expect(buf.mark == null);
    }
    
    test "unit: Buffer: initialization with content" {
        const content = "test content";
        var buf = try buffer.Buffer.initWithContent(testing.allocator, content);
        defer buf.deinit();
        
        try testing.expect(buf.position == 0);
        try testing.expectEqualStrings(content, buf.data);
    }
    
    test "unit: Buffer: peek operations" {
        var buf = try buffer.Buffer.initWithContent(testing.allocator, "hello");
        defer buf.deinit();
        
        const char = try buf.peek();
        try testing.expect(char == 'h');
        try testing.expect(buf.position == 0); // Position unchanged
        
        const char2 = try buf.peekN(2);
        try testing.expect(char2 == 'l');
        try testing.expect(buf.position == 0); // Position still unchanged
    }
    
    test "unit: Buffer: next and advance operations" {
        var buf = try buffer.Buffer.initWithContent(testing.allocator, "hello");
        defer buf.deinit();
        
        const char = try buf.next();
        try testing.expect(char == 'h');
        try testing.expect(buf.position == 1);
        
        buf.advance(2);
        try testing.expect(buf.position == 3);
        
        const char2 = try buf.peek();
        try testing.expect(char2 == 'l');
    }
    
    test "unit: Buffer: retreat operation" {
        var buf = try buffer.Buffer.initWithContent(testing.allocator, "hello");
        defer buf.deinit();
        
        buf.advance(3);
        try testing.expect(buf.position == 3);
        
        buf.retreat(2);
        try testing.expect(buf.position == 1);
        
        buf.retreat(5); // Should clamp to 0
        try testing.expect(buf.position == 0);
    }
    
    test "unit: Buffer: mark and restore position" {
        var buf = try buffer.Buffer.initWithContent(testing.allocator, "hello world");
        defer buf.deinit();
        
        buf.advance(5);
        buf.markPosition();
        try testing.expect(buf.mark.? == 5);
        
        buf.advance(3);
        try testing.expect(buf.position == 8);
        
        try buf.restoreMark();
        try testing.expect(buf.position == 5);
        try testing.expect(buf.mark == null);
    }
    
    test "unit: Buffer: end of buffer checks" {
        var buf = try buffer.Buffer.initWithContent(testing.allocator, "hi");
        defer buf.deinit();
        
        try testing.expect(!buf.isAtEnd());
        try testing.expect(buf.remaining() == 2);
        
        buf.advance(2);
        try testing.expect(buf.isAtEnd());
        try testing.expect(buf.remaining() == 0);
        
        // Should return error at end
        try testing.expectError(error.EndOfBuffer, buf.peek());
    }
    
    test "unit: Buffer: get slice operations" {
        var buf = try buffer.Buffer.initWithContent(testing.allocator, "hello world");
        defer buf.deinit();
        
        const slice = try buf.getSlice(5);
        try testing.expectEqualStrings("hello", slice);
        
        buf.advance(6);
        const remaining = buf.getRemainingSlice();
        try testing.expectEqualStrings("world", remaining);
    }
    
    test "unit: CircularBuffer: initialization and cleanup" {
        var cbuf = try buffer.CircularBuffer.init(testing.allocator, 10);
        defer cbuf.deinit();
        
        try testing.expect(cbuf.capacity == 10);
        try testing.expect(cbuf.isEmpty());
        try testing.expect(!cbuf.isFull());
        try testing.expect(cbuf.available() == 10);
    }
    
    test "unit: CircularBuffer: write and read operations" {
        var cbuf = try buffer.CircularBuffer.init(testing.allocator, 5);
        defer cbuf.deinit();
        
        try cbuf.write('a');
        try cbuf.write('b');
        try cbuf.write('c');
        
        try testing.expect(cbuf.count == 3);
        try testing.expect(cbuf.available() == 2);
        
        const char1 = try cbuf.read();
        try testing.expect(char1 == 'a');
        
        const char2 = try cbuf.read();
        try testing.expect(char2 == 'b');
        
        try testing.expect(cbuf.count == 1);
    }
    
    test "unit: CircularBuffer: buffer full error" {
        var cbuf = try buffer.CircularBuffer.init(testing.allocator, 2);
        defer cbuf.deinit();
        
        try cbuf.write('a');
        try cbuf.write('b');
        
        try testing.expect(cbuf.isFull());
        try testing.expectError(error.BufferFull, cbuf.write('c'));
    }
    
    test "unit: CircularBuffer: buffer empty error" {
        var cbuf = try buffer.CircularBuffer.init(testing.allocator, 5);
        defer cbuf.deinit();
        
        try testing.expect(cbuf.isEmpty());
        try testing.expectError(error.BufferEmpty, cbuf.read());
    }
    
    test "integration: CircularBuffer: wrap around behavior" {
        var cbuf = try buffer.CircularBuffer.init(testing.allocator, 3);
        defer cbuf.deinit();
        
        // Fill buffer
        try cbuf.write('a');
        try cbuf.write('b');
        try cbuf.write('c');
        
        // Read one to make space
        _ = try cbuf.read();
        
        // Write should wrap around
        try cbuf.write('d');
        
        // Read remaining
        try testing.expect(try cbuf.read() == 'b');
        try testing.expect(try cbuf.read() == 'c');
        try testing.expect(try cbuf.read() == 'd');
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝