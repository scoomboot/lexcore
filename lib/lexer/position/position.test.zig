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

    test "unit: Position: initialization" {
        const pos = position.Position.init();
        try testing.expect(pos.line == 1);
        try testing.expect(pos.column == 1);
        try testing.expect(pos.offset == 0);
        
        const pos2 = position.Position.initWithValues(5, 10, 50);
        try testing.expect(pos2.line == 5);
        try testing.expect(pos2.column == 10);
        try testing.expect(pos2.offset == 50);
    }
    
    test "unit: Position: advance with regular character" {
        var pos = position.Position.init();
        pos.advance('a');
        
        try testing.expect(pos.line == 1);
        try testing.expect(pos.column == 2);
        try testing.expect(pos.offset == 1);
        
        pos.advance('b');
        try testing.expect(pos.column == 3);
        try testing.expect(pos.offset == 2);
    }
    
    test "unit: Position: advance with newline" {
        var pos = position.Position.init();
        pos.advance('a');
        pos.advance('\n');
        
        try testing.expect(pos.line == 2);
        try testing.expect(pos.column == 1);
        try testing.expect(pos.offset == 2);
    }
    
    test "unit: Position: advance string" {
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
    
    test "unit: Position: nextLine and nextColumn" {
        var pos = position.Position.init();
        
        pos.nextColumn();
        try testing.expect(pos.column == 2);
        try testing.expect(pos.offset == 1);
        
        pos.nextLine();
        try testing.expect(pos.line == 2);
        try testing.expect(pos.column == 1);
        try testing.expect(pos.offset == 2);
    }
    
    test "unit: Position: comparison operations" {
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

// ╚══════════════════════════════════════════════════════════════════════════════════════╝