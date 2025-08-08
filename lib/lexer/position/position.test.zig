// position.test.zig — Test suite for source position tracking
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/position/test
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const position = @import("position.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: SourcePosition: initialization" {
        const pos = position.Position.init();
        try testing.expect(pos.line == 1);
        try testing.expect(pos.column == 1);
        try testing.expect(pos.offset == 0);
        
        const pos2 = position.Position.initWithValues(5, 10, 50);
        try testing.expect(pos2.line == 5);
        try testing.expect(pos2.column == 10);
        try testing.expect(pos2.offset == 50);
    }
    
    test "unit: SourcePosition: advance with regular character" {
        var pos = position.Position.init();
        pos.advance('a');
        
        try testing.expect(pos.line == 1);
        try testing.expect(pos.column == 2);
        try testing.expect(pos.offset == 1);
        
        pos.advance('b');
        try testing.expect(pos.column == 3);
        try testing.expect(pos.offset == 2);
    }
    
    test "unit: SourcePosition: advance with newline" {
        var pos = position.Position.init();
        pos.advance('a');
        pos.advance('\n');
        
        try testing.expect(pos.line == 2);
        try testing.expect(pos.column == 1);
        try testing.expect(pos.offset == 2);
    }
    
    test "unit: SourcePosition: advance string" {
        var pos = position.Position.init();
        pos.advanceString("hello");
        
        try testing.expect(pos.line == 1);
        try testing.expect(pos.column == 6);
        try testing.expect(pos.offset == 5);
        
        pos.advanceString("\nworld");
        try testing.expect(pos.line == 2);
        try testing.expect(pos.column == 6);
        try testing.expect(pos.offset == 11);
    }
    
    test "unit: SourcePosition: nextLine and nextColumn" {
        var pos = position.Position.init();
        
        pos.nextColumn();
        try testing.expect(pos.column == 2);
        try testing.expect(pos.offset == 1);
        
        pos.nextLine();
        try testing.expect(pos.line == 2);
        try testing.expect(pos.column == 1);
        try testing.expect(pos.offset == 2);
    }
    
    test "unit: SourcePosition: comparison operations" {
        const pos1 = position.Position.initWithValues(1, 1, 0);
        const pos2 = position.Position.initWithValues(1, 1, 0);
        const pos3 = position.Position.initWithValues(2, 1, 10);
        
        try testing.expect(pos1.eql(pos2));
        try testing.expect(!pos1.eql(pos3));
        
        try testing.expect(pos1.isBefore(pos3));
        try testing.expect(!pos3.isBefore(pos1));
        
        try testing.expect(pos3.isAfter(pos1));
        try testing.expect(!pos1.isAfter(pos3));
    }
    
    test "unit: Range: initialization and basic operations" {
        const start = position.Position.init();
        const end = position.Position.initWithValues(1, 5, 4);
        
        const range = position.Range.init(start, end);
        try testing.expect(range.start.eql(start));
        try testing.expect(range.end.eql(end));
        
        const single_range = position.Range.fromPosition(start);
        try testing.expect(single_range.start.eql(start));
        try testing.expect(single_range.end.eql(start));
        try testing.expect(single_range.isEmpty());
    }
    
    test "unit: Range: contains position" {
        const start = position.Position.initWithValues(1, 1, 0);
        const end = position.Position.initWithValues(1, 10, 9);
        const range = position.Range.init(start, end);
        
        const inside = position.Position.initWithValues(1, 5, 4);
        const before = position.Position.initWithValues(1, 1, 0); // At start
        const after = position.Position.initWithValues(2, 1, 15);
        
        try testing.expect(range.contains(inside));
        try testing.expect(range.contains(before)); // Start is inclusive
        try testing.expect(!range.contains(after));
    }
    
    test "unit: Range: overlaps" {
        const range1 = position.Range.init(
            position.Position.initWithValues(1, 1, 0),
            position.Position.initWithValues(1, 10, 9),
        );
        
        const range2 = position.Range.init(
            position.Position.initWithValues(1, 5, 4),
            position.Position.initWithValues(1, 15, 14),
        );
        
        const range3 = position.Range.init(
            position.Position.initWithValues(2, 1, 20),
            position.Position.initWithValues(2, 10, 29),
        );
        
        try testing.expect(range1.overlaps(range2));
        try testing.expect(range2.overlaps(range1));
        try testing.expect(!range1.overlaps(range3));
    }
    
    test "unit: Range: merge ranges" {
        const range1 = position.Range.init(
            position.Position.initWithValues(1, 1, 0),
            position.Position.initWithValues(1, 5, 4),
        );
        
        const range2 = position.Range.init(
            position.Position.initWithValues(1, 3, 2),
            position.Position.initWithValues(1, 8, 7),
        );
        
        const merged = range1.merge(range2);
        try testing.expect(merged.start.offset == 0);
        try testing.expect(merged.end.offset == 7);
    }
    
    test "unit: Range: length calculation" {
        const range = position.Range.init(
            position.Position.initWithValues(1, 1, 10),
            position.Position.initWithValues(1, 6, 15),
        );
        
        try testing.expect(range.length() == 5);
        
        const empty = position.Range.fromPosition(position.Position.init());
        try testing.expect(empty.length() == 0);
    }
    
    test "unit: SourceLocation: initialization variations" {
        const pos = position.Position.init();
        
        const loc1 = position.SourceLocation.init(pos);
        try testing.expect(loc1.file_path == null);
        try testing.expect(loc1.range == null);
        
        const loc2 = position.SourceLocation.initWithFile("test.zig", pos);
        try testing.expectEqualStrings("test.zig", loc2.file_path.?);
        
        const range = position.Range.fromPosition(pos);
        const loc3 = position.SourceLocation.initWithRange(pos, range);
        try testing.expect(loc3.range != null);
        
        const loc4 = position.SourceLocation.initFull("test.zig", pos, range);
        try testing.expect(loc4.file_path != null);
        try testing.expect(loc4.range != null);
    }
    
    test "unit: PositionTracker: initialization and cleanup" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        try testing.expect(tracker.current.line == 1);
        try testing.expect(tracker.current.column == 1);
        try testing.expect(tracker.marks.items.len == 0);
    }
    
    test "unit: PositionTracker: advance operations" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        tracker.advance('a');
        try testing.expect(tracker.current.column == 2);
        
        tracker.advanceString("bc\n");
        try testing.expect(tracker.current.line == 2);
        try testing.expect(tracker.current.column == 1);
    }
    
    test "unit: PositionTracker: mark and restore" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        tracker.advanceString("hello");
        try tracker.mark();
        
        tracker.advanceString(" world");
        try testing.expect(tracker.current.column == 12);
        
        try tracker.restore();
        try testing.expect(tracker.current.column == 6);
    }
    
    test "unit: PositionTracker: range from mark" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        try tracker.mark();
        tracker.advanceString("token");
        
        const range = try tracker.getRangeFromMark();
        try testing.expect(range.length() == 5);
        try testing.expect(range.start.column == 1);
        try testing.expect(range.end.column == 6);
    }
    
    test "unit: PositionTracker: reset functionality" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        tracker.advanceString("test");
        try tracker.mark();
        
        tracker.reset();
        try testing.expect(tracker.current.line == 1);
        try testing.expect(tracker.current.column == 1);
        try testing.expect(tracker.marks.items.len == 0);
    }
    
    test "unit: LineEnding: detect line endings" {
        const lf_text = "Hello\nWorld";
        const cr_text = "Hello\rWorld";
        const crlf_text = "Hello\r\nWorld";
        const no_ending = "Hello World";
        
        try testing.expect(position.LineEnding.detect(lf_text) == .lf);
        try testing.expect(position.LineEnding.detect(cr_text) == .cr);
        try testing.expect(position.LineEnding.detect(crlf_text) == .crlf);
        try testing.expect(position.LineEnding.detect(no_ending) == .lf); // Default
    }
    
    test "unit: LineEnding: length calculation" {
        try testing.expect(position.LineEnding.lf.length() == 1);
        try testing.expect(position.LineEnding.cr.length() == 1);
        try testing.expect(position.LineEnding.crlf.length() == 2);
    }
    
    test "unit: Position: tab handling" {
        var pos = position.Position.init();
        
        // Tab at column 1 should advance to column 5 (with tab width 4)
        pos.advanceWithTabWidth('\t', 4);
        try testing.expect(pos.column == 5);
        try testing.expect(pos.offset == 1);
        
        // Tab at column 5 should advance to column 9
        pos.advanceWithTabWidth('\t', 4);
        try testing.expect(pos.column == 9);
        try testing.expect(pos.offset == 2);
        
        // Regular char advances by 1
        pos.advanceWithTabWidth('a', 4);
        try testing.expect(pos.column == 10);
        
        // Tab at column 10 should advance to column 13 (next tab stop is 12, but we're past it)
        pos.advanceWithTabWidth('\t', 4);
        try testing.expect(pos.column == 13);
    }
    
    test "unit: Position: custom tab width" {
        var pos = position.Position.init();
        
        // Tab with width 8
        pos.advanceWithTabWidth('\t', 8);
        try testing.expect(pos.column == 9);
        
        // Reset for width 2
        pos = position.Position.init();
        pos.advanceWithTabWidth('\t', 2);
        try testing.expect(pos.column == 3);
    }
    
    test "unit: Position: UTF-8 codepoint handling" {
        var pos = position.Position.init();
        
        // ASCII character
        pos.advanceCodepoint('A', 4);
        try testing.expect(pos.column == 2);
        try testing.expect(pos.offset == 1);
        
        // Multi-byte UTF-8 character (€ is 3 bytes)
        pos.advanceCodepoint(0x20AC, 4); // Euro sign
        try testing.expect(pos.column == 3); // Column advances by 1
        try testing.expect(pos.offset == 4); // Offset advances by 3
        
        // Emoji (4 bytes)
        pos.advanceCodepoint(0x1F600, 4); // Grinning face
        try testing.expect(pos.column == 4);
        try testing.expect(pos.offset == 8); // 1 + 3 + 4
    }
    
    test "unit: Position: UTF-8 bytes handling" {
        var pos = position.Position.init();
        
        // Mixed ASCII and UTF-8
        const text = "Hello 世界"; // "Hello " is 6 bytes, "世界" is 6 bytes (3 each)
        pos.advanceUtf8Bytes(text, 4);
        
        // Should have advanced through all characters
        try testing.expect(pos.column == 9); // 6 ASCII + 2 Chinese chars + initial 1
        try testing.expect(pos.offset == 12); // Total bytes
    }
    
    test "unit: PositionTracker: tab width configuration" {
        var tracker = position.PositionTracker.initWithConfig(testing.allocator, 8, .lf);
        defer tracker.deinit();
        
        try testing.expect(tracker.tab_width == 8);
        
        tracker.advance('\t');
        try testing.expect(tracker.current.column == 9);
        
        // Change tab width
        tracker.setTabWidth(2);
        tracker.advance('\t');
        try testing.expect(tracker.current.column == 11); // 9 + 2
    }
    
    test "unit: PositionTracker: line ending handling" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        // Test LF
        tracker.setLineEnding(.lf);
        tracker.advance('\n');
        try testing.expect(tracker.current.line == 2);
        try testing.expect(tracker.current.column == 1);
        
        // Reset and test CRLF
        tracker.reset();
        tracker.setLineEnding(.crlf);
        tracker.advance('\r');
        tracker.advance('\n');
        try testing.expect(tracker.current.line == 2);
        try testing.expect(tracker.current.column == 1);
        
        // Reset and test CR
        tracker.reset();
        tracker.setLineEnding(.cr);
        tracker.advance('\r');
        // CR alone doesn't advance line in our implementation
        try testing.expect(tracker.current.line == 1);
    }
    
    test "unit: PositionTracker: detect line ending" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const windows_text = "Line1\r\nLine2";
        tracker.detectLineEnding(windows_text);
        try testing.expect(tracker.line_ending == .crlf);
        
        const unix_text = "Line1\nLine2";
        tracker.detectLineEnding(unix_text);
        try testing.expect(tracker.line_ending == .lf);
    }
    
    test "unit: PositionTracker: UTF-8 methods" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        // Test advanceCodepoint
        tracker.advanceCodepoint('€'); // Euro sign
        try testing.expect(tracker.current.column == 2);
        
        // Test advanceUtf8Bytes
        const text = "Hello 🌍"; // Earth globe emoji
        tracker.reset();
        tracker.advanceUtf8Bytes(text);
        try testing.expect(tracker.current.column == 8); // "Hello " = 6 chars, emoji = 1 char
    }
    
    test "integration: PositionTracker: mixed content with tabs and newlines" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const code = "func\tmain() {\n\tprintln(\"Hello\")\n}";
        tracker.advanceString(code);
        
        // After processing should be at line 3, column 2
        try testing.expect(tracker.current.line == 3);
        try testing.expect(tracker.current.column == 2);
    }
    
    test "integration: PositionTracker: Windows line endings" {
        var tracker = position.PositionTracker.initWithConfig(testing.allocator, 4, .crlf);
        defer tracker.deinit();
        
        const windows_code = "Line1\r\nLine2\r\nLine3";
        tracker.advanceString(windows_code);
        
        try testing.expect(tracker.current.line == 3);
        try testing.expect(tracker.current.column == 6); // "Line3" is 5 chars
    }
    
    // Tests for new position query methods
    
    test "unit: PositionTracker: popMarkToRange" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        try tracker.mark();
        tracker.advanceString("hello");
        const range = try tracker.popMarkToRange();
        
        try testing.expect(range.length() == 5);
        try testing.expect(range.start.column == 1);
        try testing.expect(range.end.column == 6);
        
        // Mark should be popped
        try testing.expect(tracker.marks.items.len == 0);
        
        // Test error when no marks
        try testing.expectError(error.NoMarkSet, tracker.popMarkToRange());
    }
    
    test "unit: PositionTracker: getPositionDifference" {
        const start = position.Position.initWithValues(1, 5, 10);
        const end = position.Position.initWithValues(3, 8, 50);
        
        const diff = position.PositionTracker.getPositionDifference(start, end);
        
        try testing.expect(diff.lines == 2);
        try testing.expect(diff.columns == 7); // End column from start of its line
        try testing.expect(diff.bytes == 40);
        try testing.expect(!diff.isSameLine());
        try testing.expect(diff.totalDistance() == 40);
        
        // Same line test
        const start2 = position.Position.initWithValues(1, 5, 10);
        const end2 = position.Position.initWithValues(1, 10, 15);
        
        const diff2 = position.PositionTracker.getPositionDifference(start2, end2);
        try testing.expect(diff2.lines == 0);
        try testing.expect(diff2.columns == 5);
        try testing.expect(diff2.bytes == 5);
        try testing.expect(diff2.isSameLine());
    }
    
    test "unit: PositionTracker: offsetToPosition" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const buffer = "Hello\nWorld\n\tTabbed";
        
        // Test various offsets
        const pos0 = try tracker.offsetToPosition(buffer, 0);
        try testing.expect(pos0.line == 1);
        try testing.expect(pos0.column == 1);
        try testing.expect(pos0.offset == 0);
        
        const pos5 = try tracker.offsetToPosition(buffer, 5);
        try testing.expect(pos5.line == 1);
        try testing.expect(pos5.column == 6);
        try testing.expect(pos5.offset == 5);
        
        const pos6 = try tracker.offsetToPosition(buffer, 6); // After newline
        try testing.expect(pos6.line == 2);
        try testing.expect(pos6.column == 1);
        try testing.expect(pos6.offset == 6);
        
        const pos12 = try tracker.offsetToPosition(buffer, 12); // After second newline
        try testing.expect(pos12.line == 3);
        try testing.expect(pos12.column == 1);
        try testing.expect(pos12.offset == 12);
        
        const pos13 = try tracker.offsetToPosition(buffer, 13); // After tab
        try testing.expect(pos13.line == 3);
        try testing.expect(pos13.column == 5); // Tab expands to 4 spaces
        try testing.expect(pos13.offset == 13);
        
        // Test out of bounds
        try testing.expectError(error.OffsetOutOfBounds, tracker.offsetToPosition(buffer, 1000));
    }
    
    test "unit: PositionTracker: offsetToPosition with CRLF" {
        var tracker = position.PositionTracker.initWithConfig(testing.allocator, 4, .crlf);
        defer tracker.deinit();
        
        const buffer = "Hello\r\nWorld";
        
        const pos5 = try tracker.offsetToPosition(buffer, 5); // Before CR
        try testing.expect(pos5.line == 1);
        try testing.expect(pos5.column == 6);
        
        const pos7 = try tracker.offsetToPosition(buffer, 7); // After CRLF
        try testing.expect(pos7.line == 2);
        try testing.expect(pos7.column == 1);
    }
    
    test "unit: PositionTracker: isAtLineStart" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        try testing.expect(tracker.isAtLineStart());
        
        tracker.advance('a');
        try testing.expect(!tracker.isAtLineStart());
        
        tracker.advance('\n');
        try testing.expect(tracker.isAtLineStart());
        
        tracker.advanceString("  hello");
        try testing.expect(!tracker.isAtLineStart());
    }
    
    test "unit: PositionTracker: isAtLineEnd" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const buffer = "Hello\nWorld";
        
        // At start, not at line end
        try testing.expect(!tracker.isAtLineEnd(buffer));
        
        // Move to position before newline
        tracker.advanceString("Hello");
        try testing.expect(tracker.isAtLineEnd(buffer));
        
        // Move past newline
        tracker.advance('\n');
        try testing.expect(!tracker.isAtLineEnd(buffer));
        
        // Move to end of buffer
        tracker.advanceString("World");
        try testing.expect(tracker.isAtLineEnd(buffer));
    }
    
    test "unit: PositionTracker: isAtStart and isAtEnd" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const buffer = "Hello";
        
        try testing.expect(tracker.isAtStart());
        try testing.expect(!tracker.isAtEnd(buffer));
        
        tracker.advance('H');
        try testing.expect(!tracker.isAtStart());
        try testing.expect(!tracker.isAtEnd(buffer));
        
        tracker.advanceString("ello");
        try testing.expect(!tracker.isAtStart());
        try testing.expect(tracker.isAtEnd(buffer));
    }
    
    test "unit: PositionTracker: skipWhitespace" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const buffer = "  \t  Hello World";
        
        const skipped = tracker.skipWhitespace(buffer);
        try testing.expect(skipped == 5); // 2 spaces, 1 tab, 2 spaces
        try testing.expect(tracker.current.column == 7); // 2 spaces (col 3), tab to col 5, 2 spaces (col 7)
        
        // Should not skip non-whitespace
        const skipped2 = tracker.skipWhitespace(buffer);
        try testing.expect(skipped2 == 0);
    }
    
    test "unit: PositionTracker: skipToLineEnd" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const buffer = "Hello World\nNext Line";
        
        tracker.skipToLineEnd(buffer);
        try testing.expect(tracker.current.offset == 11); // At the newline
        try testing.expect(tracker.current.column == 12);
        
        // Already at line end
        tracker.skipToLineEnd(buffer);
        try testing.expect(tracker.current.offset == 11); // Still at newline
    }
    
    test "unit: PositionTracker: skipToNextLine" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const buffer = "Line 1\nLine 2\nLine 3";
        
        tracker.skipToNextLine(buffer);
        try testing.expect(tracker.current.line == 2);
        try testing.expect(tracker.current.column == 1);
        try testing.expect(tracker.current.offset == 7);
        
        // Advance partway through line 2
        tracker.advanceString("Li");
        tracker.skipToNextLine(buffer);
        try testing.expect(tracker.current.line == 3);
        try testing.expect(tracker.current.column == 1);
    }
    
    test "unit: PositionTracker: skipToNextLine with CRLF" {
        var tracker = position.PositionTracker.initWithConfig(testing.allocator, 4, .crlf);
        defer tracker.deinit();
        
        const buffer = "Line 1\r\nLine 2\r\nLine 3";
        
        tracker.skipToNextLine(buffer);
        try testing.expect(tracker.current.line == 2);
        try testing.expect(tracker.current.column == 1);
    }
    
    test "unit: PositionTracker: snapshot and restore" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        tracker.advanceString("Hello");
        const snapshot = tracker.snapshot();
        
        tracker.advanceString(" World");
        try testing.expect(tracker.current.column == 12);
        
        tracker.restoreSnapshot(snapshot);
        try testing.expect(tracker.current.column == 6);
        try testing.expect(tracker.current.offset == 5);
    }
    
    test "unit: PositionTracker: getVisualColumn" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        tracker.advance('\t');
        try testing.expect(tracker.getVisualColumn() == 5); // Tab to column 5
        
        tracker.advanceString("ab");
        try testing.expect(tracker.getVisualColumn() == 7);
        
        tracker.advance('\t');
        try testing.expect(tracker.getVisualColumn() == 9); // Next tab stop
    }
    
    test "integration: PositionTracker: complex navigation" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const code =
            \\function main() {
            \\    // Comment
            \\    if (true) {
            \\        return 0;
            \\    }
            \\}
        ;
        
        // Mark start of function
        try tracker.mark();
        tracker.advanceString("function");
        const func_range = try tracker.popMarkToRange();
        try testing.expect(func_range.length() == 8);
        
        // Skip to comment
        tracker.skipToNextLine(code);
        _ = tracker.skipWhitespace(code);
        try testing.expect(tracker.current.line == 2);
        
        // Check we're at comment start
        try testing.expect(code[tracker.current.offset] == '/');
        
        // Skip to end of comment line
        tracker.skipToLineEnd(code);
        
        // Move to next line
        tracker.skipToNextLine(code);
        try testing.expect(tracker.current.line == 3);
    }
    
    test "integration: PositionTracker: offset conversion roundtrip" {
        var tracker = position.PositionTracker.init(testing.allocator);
        defer tracker.deinit();
        
        const buffer = "Line 1\nLine 2\n\tLine 3";
        
        // Advance through buffer
        tracker.advanceString(buffer);
        _ = tracker.snapshot(); // We don't need to save this, just advance through the buffer
        
        // Convert various offsets back to positions
        var test_tracker = position.PositionTracker.init(testing.allocator);
        defer test_tracker.deinit();
        
        const pos_at_7 = try test_tracker.offsetToPosition(buffer, 7);
        try testing.expect(pos_at_7.line == 2);
        try testing.expect(pos_at_7.column == 1);
        
        const pos_at_14 = try test_tracker.offsetToPosition(buffer, 14);
        try testing.expect(pos_at_14.line == 3);
        try testing.expect(pos_at_14.column == 1);
        
        const pos_at_15 = try test_tracker.offsetToPosition(buffer, 15);
        try testing.expect(pos_at_15.line == 3);
        try testing.expect(pos_at_15.column == 5); // After tab
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝