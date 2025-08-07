// position.zig — Source position tracking and location management
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/position
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Position within source text
    pub const Position = struct {
        line: usize,
        column: usize,
        offset: usize,
        
        /// Create initial position (1:1:0)
        pub fn init() Position {
            return .{
                .line = 1,
                .column = 1,
                .offset = 0,
            };
        }
        
        /// Create position with specific values
        pub fn initWithValues(line: usize, column: usize, offset: usize) Position {
            return .{
                .line = line,
                .column = column,
                .offset = offset,
            };
        }
        
        /// Advance position by one character
        pub fn advance(self: *Position, char: u8) void {
            self.offset += 1;
            if (char == '\n') {
                self.line += 1;
                self.column = 1;
            } else {
                self.column += 1;
            }
        }
        
        /// Advance position by multiple characters
        pub fn advanceString(self: *Position, text: []const u8) void {
            for (text) |char| {
                self.advance(char);
            }
        }
        
        /// Move to next line
        pub fn nextLine(self: *Position) void {
            self.line += 1;
            self.column = 1;
            self.offset += 1;
        }
        
        /// Move to next column
        pub fn nextColumn(self: *Position) void {
            self.column += 1;
            self.offset += 1;
        }
        
        /// Compare positions
        pub fn eql(self: Position, other: Position) bool {
            return self.line == other.line and
                   self.column == other.column and
                   self.offset == other.offset;
        }
        
        /// Check if this position comes before another
        pub fn isBefore(self: Position, other: Position) bool {
            return self.offset < other.offset;
        }
        
        /// Check if this position comes after another
        pub fn isAfter(self: Position, other: Position) bool {
            return self.offset > other.offset;
        }
        
        /// Format position for display
        pub fn format(
            self: Position,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try writer.print("{d}:{d}", .{ self.line, self.column });
        }
    };
    
    /// Range between two positions
    pub const Range = struct {
        start: Position,
        end: Position,
        
        /// Create a new range
        pub fn init(start: Position, end: Position) Range {
            return .{
                .start = start,
                .end = end,
            };
        }
        
        /// Create a range from a single position
        pub fn fromPosition(pos: Position) Range {
            return .{
                .start = pos,
                .end = pos,
            };
        }
        
        /// Check if range contains a position
        pub fn contains(self: Range, pos: Position) bool {
            return !pos.isBefore(self.start) and !pos.isAfter(self.end);
        }
        
        /// Check if ranges overlap
        pub fn overlaps(self: Range, other: Range) bool {
            return !self.end.isBefore(other.start) and !other.end.isBefore(self.start);
        }
        
        /// Merge two ranges into one
        pub fn merge(self: Range, other: Range) Range {
            return .{
                .start = if (self.start.isBefore(other.start)) self.start else other.start,
                .end = if (self.end.isAfter(other.end)) self.end else other.end,
            };
        }
        
        /// Get the length of the range in bytes
        pub fn length(self: Range) usize {
            if (self.end.offset >= self.start.offset) {
                return self.end.offset - self.start.offset;
            }
            return 0;
        }
        
        /// Check if range is empty
        pub fn isEmpty(self: Range) bool {
            return self.start.eql(self.end);
        }
    };
    
    /// Source location with file information
    pub const SourceLocation = struct {
        file_path: ?[]const u8,
        position: Position,
        range: ?Range,
        
        /// Create source location with position only
        pub fn init(pos: Position) SourceLocation {
            return .{
                .file_path = null,
                .position = pos,
                .range = null,
            };
        }
        
        /// Create source location with file path
        pub fn initWithFile(file_path: []const u8, pos: Position) SourceLocation {
            return .{
                .file_path = file_path,
                .position = pos,
                .range = null,
            };
        }
        
        /// Create source location with range
        pub fn initWithRange(pos: Position, range: Range) SourceLocation {
            return .{
                .file_path = null,
                .position = pos,
                .range = range,
            };
        }
        
        /// Create full source location
        pub fn initFull(file_path: []const u8, pos: Position, range: Range) SourceLocation {
            return .{
                .file_path = file_path,
                .position = pos,
                .range = range,
            };
        }
        
        /// Format location for display
        pub fn format(
            self: SourceLocation,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            
            if (self.file_path) |path| {
                try writer.print("{s}:", .{path});
            }
            try writer.print("{}", .{self.position});
        }
    };
    
    /// Position tracker for maintaining current position during lexing
    pub const PositionTracker = struct {
        current: Position,
        marks: std.ArrayList(Position),
        
        /// Initialize position tracker
        pub fn init(allocator: std.mem.Allocator) PositionTracker {
            return .{
                .current = Position.init(),
                .marks = std.ArrayList(Position).init(allocator),
            };
        }
        
        /// Clean up position tracker
        pub fn deinit(self: *PositionTracker) void {
            self.marks.deinit();
        }
        
        /// Reset to initial position
        pub fn reset(self: *PositionTracker) void {
            self.current = Position.init();
            self.marks.clearRetainingCapacity();
        }
        
        /// Advance by character
        pub fn advance(self: *PositionTracker, char: u8) void {
            self.current.advance(char);
        }
        
        /// Advance by string
        pub fn advanceString(self: *PositionTracker, text: []const u8) void {
            self.current.advanceString(text);
        }
        
        /// Mark current position
        pub fn mark(self: *PositionTracker) !void {
            try self.marks.append(self.current);
        }
        
        /// Restore last marked position
        pub fn restore(self: *PositionTracker) !void {
            if (self.marks.popOrNull()) |pos| {
                self.current = pos;
            } else {
                return error.NoMarkToRestore;
            }
        }
        
        /// Get range from last mark to current
        pub fn getRangeFromMark(self: *const PositionTracker) !Range {
            if (self.marks.items.len == 0) {
                return error.NoMarkSet;
            }
            const mark_pos = self.marks.items[self.marks.items.len - 1];
            return Range.init(mark_pos, self.current);
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝