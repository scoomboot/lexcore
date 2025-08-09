// mark_restore_test.zig — Tests for mark/restore functionality
//
// repo   : https://github.com/scoomboot/lexcore
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/buffer
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Buffer = @import("buffer.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: StreamingBuffer: mark/restore within same window" {
        const allocator = testing.allocator;
        
        // Create a test file
        var test_dir = testing.tmpDir(.{});
        defer test_dir.cleanup();
        
        const content = "Hello, World! This is a test file.";
        try test_dir.dir.writeFile(.{ .sub_path = "test.txt", .data = content });
        
        const file = try test_dir.dir.openFile("test.txt", .{});
        defer file.close();
        
        var buffer = try Buffer.StreamingBuffer.init(allocator, file, 128);
        defer buffer.deinit();
        
        // Read a few bytes
        _ = try buffer.next();
        _ = try buffer.next();
        _ = try buffer.next();
        _ = try buffer.next();
        _ = try buffer.next(); // Position at index 5
        
        // Mark the position
        buffer.markPosition();
        
        // Continue reading
        _ = try buffer.next();
        _ = try buffer.next();
        _ = try buffer.next(); // Position at index 8
        
        // Restore to marked position
        try buffer.restoreMark();
        
        // Verify we're back at position 5
        const byte = try buffer.next();
        try testing.expectEqual(@as(u8, ','), byte);
    }
    
    test "unit: StreamingBuffer: mark/restore across window boundaries backward" {
        const allocator = testing.allocator;
        
        // Create a test file with more content
        var test_dir = testing.tmpDir(.{});
        defer test_dir.cleanup();
        
        // Create content larger than window size
        var content: [256]u8 = undefined;
        for (&content, 0..) |*c, i| {
            c.* = @as(u8, @intCast((i % 26) + 'a'));
        }
        try test_dir.dir.writeFile(.{ .sub_path = "test.txt", .data = &content });
        
        const file = try test_dir.dir.openFile("test.txt", .{});
        defer file.close();
        
        // Use small window size to force window sliding
        var buffer = try Buffer.StreamingBuffer.init(allocator, file, 32);
        defer buffer.deinit();
        
        // Read first few bytes and mark
        _ = try buffer.next();
        _ = try buffer.next();
        _ = try buffer.next();
        _ = try buffer.next();
        _ = try buffer.next(); // Position at index 5 ('f')
        
        buffer.markPosition();
        const marked_pos = buffer.getAbsolutePosition();
        
        // Read enough to trigger window sliding
        var i: usize = 0;
        while (i < 40) : (i += 1) {
            _ = try buffer.next();
        }
        
        // Now we should be in a different window
        try testing.expect(buffer.window_start > 0);
        
        // Restore to marked position (should seek back)
        try buffer.restoreMark();
        
        // Verify position and content
        try testing.expectEqual(marked_pos, buffer.getAbsolutePosition());
        const byte = try buffer.next();
        try testing.expectEqual(@as(u8, 'f'), byte); // We're back at 'f'
    }
    
    test "unit: StreamingBuffer: mark/restore across window boundaries forward" {
        const allocator = testing.allocator;
        
        var test_dir = testing.tmpDir(.{});
        defer test_dir.cleanup();
        
        // Create content larger than window size
        var content: [256]u8 = undefined;
        for (&content, 0..) |*c, i| {
            c.* = @as(u8, @intCast((i % 10) + '0'));
        }
        try test_dir.dir.writeFile(.{ .sub_path = "test.txt", .data = &content });
        
        const file = try test_dir.dir.openFile("test.txt", .{});
        defer file.close();
        
        var buffer = try Buffer.StreamingBuffer.init(allocator, file, 32);
        defer buffer.deinit();
        
        // Read to middle of file
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            _ = try buffer.next();
        }
        
        // Mark position at index 100
        buffer.markPosition();
        
        // Continue reading forward
        i = 0;
        while (i < 50) : (i += 1) {
            _ = try buffer.next();
        }
        
        // Now at position 150, restore back to 100
        try buffer.restoreMark();
        
        // Verify we're at position 100
        try testing.expectEqual(@as(usize, 100), buffer.getAbsolutePosition());
        const byte = try buffer.next();
        try testing.expectEqual(@as(u8, '0'), byte); // 100 % 10 = 0, so '0'
    }
    
    test "unit: StreamingBuffer: multiple mark/restore operations" {
        const allocator = testing.allocator;
        
        var test_dir = testing.tmpDir(.{});
        defer test_dir.cleanup();
        
        const content = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        try test_dir.dir.writeFile(.{ .sub_path = "test.txt", .data = content });
        
        const file = try test_dir.dir.openFile("test.txt", .{});
        defer file.close();
        
        var buffer = try Buffer.StreamingBuffer.init(allocator, file, 16);
        defer buffer.deinit();
        
        // First mark at position 5
        var i: usize = 0;
        while (i < 5) : (i += 1) {
            _ = try buffer.next();
        }
        buffer.markPosition();
        
        // Read forward
        i = 0;
        while (i < 10) : (i += 1) {
            _ = try buffer.next();
        }
        
        // Restore to first mark
        try buffer.restoreMark();
        try testing.expectEqual(@as(usize, 5), buffer.getAbsolutePosition());
        
        // Mark again at different position
        i = 0;
        while (i < 20) : (i += 1) {
            _ = try buffer.next();
        }
        buffer.markPosition();
        try testing.expectEqual(@as(usize, 25), buffer.getAbsolutePosition());
        
        // Read more
        i = 0;
        while (i < 5) : (i += 1) {
            _ = try buffer.next();
        }
        
        // Restore to second mark
        try buffer.restoreMark();
        try testing.expectEqual(@as(usize, 25), buffer.getAbsolutePosition());
        const byte = try buffer.next();
        try testing.expectEqual(@as(u8, 'Z'), byte);
    }
    
    test "unit: StreamingBuffer: mark/restore at EOF" {
        const allocator = testing.allocator;
        
        var test_dir = testing.tmpDir(.{});
        defer test_dir.cleanup();
        
        const content = "Short file";
        try test_dir.dir.writeFile(.{ .sub_path = "test.txt", .data = content });
        
        const file = try test_dir.dir.openFile("test.txt", .{});
        defer file.close();
        
        var buffer = try Buffer.StreamingBuffer.init(allocator, file, 32);
        defer buffer.deinit();
        
        // Read to EOF
        while (buffer.next()) |_| {} else |_| {}
        
        // Mark at EOF
        buffer.markPosition();
        const eof_pos = buffer.getAbsolutePosition();
        
        // This should work but position should be at EOF
        try buffer.restoreMark();
        try testing.expectEqual(eof_pos, buffer.getAbsolutePosition());
        
        // Next read should fail with EOF
        try testing.expectError(error.EndOfStream, buffer.next());
    }
    
    test "unit: StreamingBuffer: mark/restore with position tracking" {
        const allocator = testing.allocator;
        
        var test_dir = testing.tmpDir(.{});
        defer test_dir.cleanup();
        
        const content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5";
        try test_dir.dir.writeFile(.{ .sub_path = "test.txt", .data = content });
        
        const file = try test_dir.dir.openFile("test.txt", .{});
        defer file.close();
        
        var buffer = try Buffer.StreamingBuffer.init(allocator, file, 16);
        defer buffer.deinit();
        
        // Enable position tracking
        try buffer.enablePositionTracking();
        
        // Read to second line
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            _ = try buffer.next();
        }
        
        // Mark position (should be at start of "Line 2")
        buffer.markPosition();
        const marked_src_pos = buffer.getCurrentPosition();
        try testing.expect(marked_src_pos != null);
        
        // Read more
        i = 0;
        while (i < 14) : (i += 1) {
            _ = try buffer.next();
        }
        
        // Restore position
        try buffer.restoreMark();
        
        // Check that source position was restored
        const restored_pos = buffer.getCurrentPosition();
        try testing.expect(restored_pos != null);
        try testing.expectEqual(marked_src_pos.?.line, restored_pos.?.line);
        try testing.expectEqual(marked_src_pos.?.column, restored_pos.?.column);
    }
    
    test "unit: StreamingBuffer: restore without mark should error" {
        const allocator = testing.allocator;
        
        var test_dir = testing.tmpDir(.{});
        defer test_dir.cleanup();
        
        const content = "Test content";
        try test_dir.dir.writeFile(.{ .sub_path = "test.txt", .data = content });
        
        const file = try test_dir.dir.openFile("test.txt", .{});
        defer file.close();
        
        var buffer = try Buffer.StreamingBuffer.init(allocator, file, 32);
        defer buffer.deinit();
        
        // Try to restore without marking
        try testing.expectError(error.NoMarkSet, buffer.restoreMark());
    }
    
    test "stress: StreamingBuffer: rapid mark/restore cycles" {
        const allocator = testing.allocator;
        
        var test_dir = testing.tmpDir(.{});
        defer test_dir.cleanup();
        
        // Create larger content
        var content: [1024]u8 = undefined;
        for (&content, 0..) |*c, i| {
            c.* = @as(u8, @intCast((i % 256)));
        }
        try test_dir.dir.writeFile(.{ .sub_path = "test.txt", .data = &content });
        
        const file = try test_dir.dir.openFile("test.txt", .{});
        defer file.close();
        
        var buffer = try Buffer.StreamingBuffer.init(allocator, file, 64);
        defer buffer.deinit();
        
        // Perform rapid mark/restore cycles
        var cycle: usize = 0;
        while (cycle < 10) : (cycle += 1) {
            // Read forward
            var i: usize = 0;
            while (i < 50) : (i += 1) {
                _ = try buffer.next();
            }
            
            // Mark
            buffer.markPosition();
            const marked = buffer.getAbsolutePosition();
            
            // Read more
            i = 0;
            while (i < 30) : (i += 1) {
                _ = try buffer.next();
            }
            
            // Restore
            try buffer.restoreMark();
            try testing.expectEqual(marked, buffer.getAbsolutePosition());
        }
    }
    
    test "integration: StreamingBuffer: compare with regular Buffer mark/restore" {
        const allocator = testing.allocator;
        
        const content = "This is a test string for comparing buffer behaviors.";
        
        // Test with regular Buffer
        var regular = try Buffer.Buffer.initWithContent(allocator, content);
        defer regular.deinit();
        
        // Read some bytes
        _ = try regular.next();
        _ = try regular.next();
        _ = try regular.next();
        _ = try regular.next();
        _ = try regular.next();
        
        regular.markPosition();
        const regular_marked = regular.position;
        
        // Read more
        _ = try regular.next();
        _ = try regular.next();
        _ = try regular.next();
        
        try regular.restoreMark();
        try testing.expectEqual(regular_marked, regular.position);
        
        // Test with StreamingBuffer
        var test_dir = testing.tmpDir(.{});
        defer test_dir.cleanup();
        
        try test_dir.dir.writeFile(.{ .sub_path = "test.txt", .data = content });
        
        const file = try test_dir.dir.openFile("test.txt", .{});
        defer file.close();
        
        var streaming = try Buffer.StreamingBuffer.init(allocator, file, 32);
        defer streaming.deinit();
        
        // Read same number of bytes
        _ = try streaming.next();
        _ = try streaming.next();
        _ = try streaming.next();
        _ = try streaming.next();
        _ = try streaming.next();
        
        streaming.markPosition();
        const streaming_marked = streaming.getAbsolutePosition();
        
        // Read more
        _ = try streaming.next();
        _ = try streaming.next();
        _ = try streaming.next();
        
        try streaming.restoreMark();
        try testing.expectEqual(streaming_marked, streaming.getAbsolutePosition());
        
        // Both should have marked at the same position
        try testing.expectEqual(regular_marked, streaming_marked);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝