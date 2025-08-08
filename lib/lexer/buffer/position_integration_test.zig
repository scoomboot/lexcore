// position_integration_test.zig — Position tracking integration tests
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/buffer
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Buffer = @import("buffer.zig").Buffer;
    const position_module = @import("../position/position.zig");
    const PositionTracker = position_module.PositionTracker;
    const Position = position_module.Position;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: Buffer: position tracking disabled by default" {
        var buffer = try Buffer.init(testing.allocator);
        defer buffer.deinit();
        
        try buffer.setContent("Hello World");
        
        // Position tracking should be null by default
        try testing.expect(buffer.position_tracker == null);
        try testing.expect(buffer.getCurrentPosition() == null);
        
        // Operations should work without position tracking
        const char = try buffer.next();
        try testing.expectEqual(@as(u8, 'H'), char);
        try testing.expect(buffer.getCurrentPosition() == null);
    }
    
    test "unit: Buffer: enable and disable position tracking" {
        var buffer = try Buffer.init(testing.allocator);
        defer buffer.deinit();
        
        try buffer.setContent("Hello\nWorld");
        
        // Enable position tracking
        try buffer.enablePositionTracking();
        try testing.expect(buffer.position_tracker != null);
        
        // Should start at 1:1:0
        const pos1 = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos1.line);
        try testing.expectEqual(@as(u32, 1), pos1.column);
        try testing.expectEqual(@as(usize, 0), pos1.offset);
        
        // Disable position tracking
        buffer.disablePositionTracking();
        try testing.expect(buffer.position_tracker == null);
        try testing.expect(buffer.getCurrentPosition() == null);
    }
    
    test "unit: Buffer: position tracking with next()" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "Hello\nWorld");
        defer buffer.deinit();
        
        // Consume "Hello"
        _ = try buffer.next(); // H: 1:1 -> 1:2
        _ = try buffer.next(); // e: 1:2 -> 1:3
        _ = try buffer.next(); // l: 1:3 -> 1:4
        _ = try buffer.next(); // l: 1:4 -> 1:5
        _ = try buffer.next(); // o: 1:5 -> 1:6
        
        var pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 6), pos.column);
        try testing.expectEqual(@as(usize, 5), pos.offset);
        
        // Consume newline
        _ = try buffer.next(); // \n: 1:6 -> 2:1
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        try testing.expectEqual(@as(usize, 6), pos.offset);
    }
    
    test "unit: Buffer: position tracking with UTF-8 nextCodepoint()" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "Hi 😊\nTest");
        defer buffer.deinit();
        
        // Consume "Hi "
        _ = try buffer.nextCodepoint(); // H
        _ = try buffer.nextCodepoint(); // i
        _ = try buffer.nextCodepoint(); // space
        
        var pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 4), pos.column);
        try testing.expectEqual(@as(usize, 3), pos.offset);
        
        // Consume emoji (4 bytes)
        const emoji = try buffer.nextCodepoint();
        try testing.expectEqual(@as(u21, 0x1F60A), emoji); // 😊
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 5), pos.column); // Column advances by 1 for emoji
        try testing.expectEqual(@as(usize, 7), pos.offset); // Offset advances by 4
        
        // Consume newline
        _ = try buffer.nextCodepoint();
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        try testing.expectEqual(@as(usize, 8), pos.offset);
    }
    
    test "unit: Buffer: position tracking with advance()" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "Line1\nLine2\nLine3");
        defer buffer.deinit();
        
        // Advance by 5 bytes (to just before newline)
        buffer.advance(5);
        
        var pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 6), pos.column);
        try testing.expectEqual(@as(usize, 5), pos.offset);
        
        // Advance by 1 byte (newline)
        buffer.advance(1);
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        try testing.expectEqual(@as(usize, 6), pos.offset);
    }
    
    test "unit: Buffer: position tracking with advanceCodepoints()" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "Hi 😊 Test");
        defer buffer.deinit();
        
        // Advance by 4 codepoints (H, i, space, emoji)
        try buffer.advanceCodepoints(4);
        
        const pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 5), pos.column);
        try testing.expectEqual(@as(usize, 7), pos.offset); // 3 ASCII + 4 bytes for emoji
    }
    
    test "unit: Buffer: position tracking with mark and restore" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "Line1\nLine2\nLine3");
        defer buffer.deinit();
        
        // Advance to "Line2"
        buffer.advance(6);
        
        // Mark position at start of Line2
        buffer.markPosition();
        
        var pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        
        // Advance to Line3
        buffer.advance(6);
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 3), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        
        // Restore mark
        try buffer.restoreMark();
        
        // Should be back at Line2
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        try testing.expectEqual(@as(usize, 6), pos.offset);
    }
    
    test "unit: Buffer: position tracking with retreat" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "Line1\nLine2");
        defer buffer.deinit();
        
        // Advance to middle of Line2
        buffer.advance(9); // "Line1\nLin"
        
        var pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 4), pos.column);
        
        // Retreat back 3 positions
        buffer.retreat(3); // "Line1\n"
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        try testing.expectEqual(@as(usize, 6), pos.offset);
        
        // Retreat past newline
        buffer.retreat(2); // "Line"
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 5), pos.column);
        try testing.expectEqual(@as(usize, 4), pos.offset);
    }
    
    test "unit: Buffer: position tracking with consumeWhile" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "   Hello   World");
        defer buffer.deinit();
        
        // Consume whitespace
        const ws = try buffer.consumeWhitespace();
        try testing.expectEqual(@as(usize, 3), ws.len);
        
        var pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 4), pos.column);
        try testing.expectEqual(@as(usize, 3), pos.offset);
        
        // Consume identifier
        const id = try buffer.consumeIdentifier();
        try testing.expectEqualStrings("Hello", id);
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 9), pos.column);
        try testing.expectEqual(@as(usize, 8), pos.offset);
    }
    
    test "unit: Buffer: position tracking with tabs" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "A\tB\tC");
        defer buffer.deinit();
        
        _ = try buffer.next(); // A: column 1->2
        
        var pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.column);
        
        _ = try buffer.next(); // Tab: column 2->5 (next tab stop with width 4)
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 5), pos.column);
        
        _ = try buffer.next(); // B: column 5->6
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 6), pos.column);
        
        _ = try buffer.next(); // Tab: column 6->9 (next tab stop)
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 9), pos.column);
    }
    
    test "unit: Buffer: position tracking with reset" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "Line1\nLine2");
        defer buffer.deinit();
        
        // Advance to Line2
        buffer.advance(7);
        
        var pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 2), pos.column);
        
        // Reset buffer
        buffer.reset();
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        try testing.expectEqual(@as(usize, 0), pos.offset);
    }
    
    test "unit: Buffer: position tracking with setContent" {
        var buffer = try Buffer.initWithPositionTracking(testing.allocator, "Old Content");
        defer buffer.deinit();
        
        // Advance a bit
        buffer.advance(4);
        
        // Set new content
        try buffer.setContent("New\nContent");
        
        // Position should be reset
        const pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 1), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        try testing.expectEqual(@as(usize, 0), pos.offset);
    }
    
    test "unit: Buffer: enable position tracking mid-stream" {
        var buffer = try Buffer.init(testing.allocator);
        defer buffer.deinit();
        
        try buffer.setContent("Line1\nLine2\nLine3");
        
        // Advance without tracking
        buffer.advance(6); // Move to start of Line2
        
        // Enable tracking
        try buffer.enablePositionTracking();
        
        // Position should reflect current location
        var pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 1), pos.column);
        try testing.expectEqual(@as(usize, 6), pos.offset);
        
        // Continue advancing with tracking
        _ = try buffer.next(); // 'L'
        
        pos = buffer.getCurrentPosition().?;
        try testing.expectEqual(@as(u32, 2), pos.line);
        try testing.expectEqual(@as(u32, 2), pos.column);
        try testing.expectEqual(@as(usize, 7), pos.offset);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝