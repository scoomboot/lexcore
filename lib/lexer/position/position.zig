// position.zig — Source position tracking and location management
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/position
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const unicode = std.unicode;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Line ending types supported by the position tracker
    pub const LineEnding = enum {
        lf,     // \n (Unix/Linux/macOS)
        cr,     // \r (Classic Mac)
        crlf,   // \r\n (Windows)
        
        /// Detect line ending from a buffer
        pub fn detect(buffer: []const u8) LineEnding {
            // Look for first line ending in the buffer
            for (buffer, 0..) |char, i| {
                if (char == '\r') {
                    // Check if followed by \n
                    if (i + 1 < buffer.len and buffer[i + 1] == '\n') {
                        return .crlf;
                    }
                    return .cr;
                } else if (char == '\n') {
                    return .lf;
                }
            }
            // Default to LF if no line endings found
            return .lf;
        }
        
        /// Get the byte length of this line ending
        pub fn length(self: LineEnding) usize {
            return switch (self) {
                .lf, .cr => 1,
                .crlf => 2,
            };
        }
    };

    /// Source position within text
    /// 
    /// Represents a specific location in source code with line, column, and byte offset.
    /// Lines and columns are 1-indexed for human readability, while offset is 0-indexed.
    pub const SourcePosition = struct {
        line: u32,
        column: u32,
        offset: usize,
        
        /// Create initial position (1:1:0)
        pub fn init() SourcePosition {
            return .{
                .line = 1,
                .column = 1,
                .offset = 0,
            };
        }
        
        /// Create position with specific values
        pub fn initWithValues(line: u32, column: u32, offset: usize) SourcePosition {
            return .{
                .line = line,
                .column = column,
                .offset = offset,
            };
        }
        
        /// Advance position by one character with tab width support
        pub fn advanceWithTabWidth(self: *SourcePosition, char: u8, tab_width: u32) void {
            self.offset += 1;
            if (char == '\n') {
                self.line += 1;
                self.column = 1;
            } else if (char == '\r') {
                // CR is handled separately, might be part of CRLF
                // Don't advance column for CR
            } else if (char == '\t') {
                // Advance to next tab stop
                const spaces_to_tab = tab_width - ((self.column - 1) % tab_width);
                self.column += spaces_to_tab;
            } else {
                self.column += 1;
            }
        }
        
        /// Advance position by one character (uses default tab width of 4)
        pub fn advance(self: *SourcePosition, char: u8) void {
            self.advanceWithTabWidth(char, 4);
        }
        
        /// Advance position by multiple characters with tab width support
        pub fn advanceStringWithTabWidth(self: *SourcePosition, text: []const u8, tab_width: u32) void {
            for (text) |char| {
                self.advanceWithTabWidth(char, tab_width);
            }
        }
        
        /// Advance position by multiple characters (uses default tab width of 4)
        pub fn advanceString(self: *SourcePosition, text: []const u8) void {
            self.advanceStringWithTabWidth(text, 4);
        }
        
        /// Advance position by a UTF-8 codepoint
        pub fn advanceCodepoint(self: *SourcePosition, codepoint: u21, tab_width: u32) void {
            // Special handling for control characters
            if (codepoint == '\n') {
                self.offset += 1;
                self.line += 1;
                self.column = 1;
            } else if (codepoint == '\r') {
                self.offset += 1;
                // Don't advance column for CR
            } else if (codepoint == '\t') {
                self.offset += 1;
                const spaces_to_tab = tab_width - ((self.column - 1) % tab_width);
                self.column += spaces_to_tab;
            } else {
                // Calculate byte length of the codepoint
                const len = unicode.utf8CodepointSequenceLength(codepoint) catch 1;
                self.offset += len;
                // Most codepoints advance column by 1
                // Note: This doesn't handle wide characters or combining marks
                self.column += 1;
            }
        }
        
        /// Advance position by UTF-8 bytes
        pub fn advanceUtf8Bytes(self: *SourcePosition, bytes: []const u8, tab_width: u32) void {
            var i: usize = 0;
            while (i < bytes.len) {
                const len = unicode.utf8ByteSequenceLength(bytes[i]) catch 1;
                if (i + len > bytes.len) break;
                
                const codepoint = unicode.utf8Decode(bytes[i..i + len]) catch {
                    // Invalid UTF-8, treat as single byte
                    self.advanceWithTabWidth(bytes[i], tab_width);
                    i += 1;
                    continue;
                };
                
                self.advanceCodepoint(codepoint, tab_width);
                i += len;
            }
        }
        
        /// Move to next line
        pub fn nextLine(self: *SourcePosition) void {
            self.line += 1;
            self.column = 1;
            self.offset += 1;
        }
        
        /// Move to next column
        pub fn nextColumn(self: *SourcePosition) void {
            self.column += 1;
            self.offset += 1;
        }
        
        /// Compare positions
        pub fn eql(self: SourcePosition, other: SourcePosition) bool {
            return self.line == other.line and
                   self.column == other.column and
                   self.offset == other.offset;
        }
        
        /// Check if this position comes before another
        pub fn isBefore(self: SourcePosition, other: SourcePosition) bool {
            return self.offset < other.offset;
        }
        
        /// Check if this position comes after another
        pub fn isAfter(self: SourcePosition, other: SourcePosition) bool {
            return self.offset > other.offset;
        }
        
        /// Format position for display
        pub fn format(
            self: SourcePosition,
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
        start: SourcePosition,
        end: SourcePosition,
        
        /// Create a new range
        pub fn init(start: SourcePosition, end: SourcePosition) Range {
            return .{
                .start = start,
                .end = end,
            };
        }
        
        /// Create a range from a single position
        pub fn fromPosition(pos: SourcePosition) Range {
            return .{
                .start = pos,
                .end = pos,
            };
        }
        
        /// Check if range contains a position
        pub fn contains(self: Range, pos: SourcePosition) bool {
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
        tab_width: u32,
        line_ending: LineEnding,
        
        /// Initialize position tracker with default settings
        pub fn init(allocator: std.mem.Allocator) PositionTracker {
            return .{
                .current = Position.init(),
                .marks = std.ArrayList(Position).init(allocator),
                .tab_width = 4,
                .line_ending = .lf,
            };
        }
        
        /// Initialize position tracker with custom settings
        pub fn initWithConfig(allocator: std.mem.Allocator, tab_width: u32, line_ending: LineEnding) PositionTracker {
            return .{
                .current = Position.init(),
                .marks = std.ArrayList(Position).init(allocator),
                .tab_width = tab_width,
                .line_ending = line_ending,
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
        
        /// Set tab width
        pub fn setTabWidth(self: *PositionTracker, width: u32) void {
            self.tab_width = width;
        }
        
        /// Set line ending type
        pub fn setLineEnding(self: *PositionTracker, ending: LineEnding) void {
            self.line_ending = ending;
        }
        
        /// Detect and set line ending from buffer
        pub fn detectLineEnding(self: *PositionTracker, buffer: []const u8) void {
            self.line_ending = LineEnding.detect(buffer);
        }
        
        /// Advance by character using configured tab width
        pub fn advance(self: *PositionTracker, char: u8) void {
            // Handle different line endings
            if (char == '\r') {
                self.current.offset += 1;
                // Don't update line/column yet, might be CRLF
            } else if (char == '\n') {
                // Check if this completes a CRLF
                if (self.line_ending == .crlf and self.current.offset > 0) {
                    // We're expecting CRLF and already saw CR
                    self.current.offset += 1;
                }
                self.current.line += 1;
                self.current.column = 1;
                if (self.line_ending != .crlf) {
                    self.current.offset += 1;
                }
            } else {
                self.current.advanceWithTabWidth(char, self.tab_width);
            }
        }
        
        /// Advance by string using configured tab width
        pub fn advanceString(self: *PositionTracker, text: []const u8) void {
            for (text) |char| {
                self.advance(char);
            }
        }
        
        /// Advance by a UTF-8 codepoint
        pub fn advanceCodepoint(self: *PositionTracker, codepoint: u21) void {
            self.current.advanceCodepoint(codepoint, self.tab_width);
        }
        
        /// Advance by UTF-8 bytes with proper multi-byte handling
        pub fn advanceUtf8Bytes(self: *PositionTracker, bytes: []const u8) void {
            self.current.advanceUtf8Bytes(bytes, self.tab_width);
        }
        
        /// Mark current position
        pub fn mark(self: *PositionTracker) !void {
            try self.marks.append(self.current);
        }
        
        /// Restore last marked position
        pub fn restore(self: *PositionTracker) !void {
            if (self.marks.items.len > 0) {
                self.current = self.marks.pop().?;
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
        
        /// Pop the last mark and create a range from it to current position
        /// This is useful for creating token ranges after lexing
        pub fn popMarkToRange(self: *PositionTracker) !Range {
            if (self.marks.items.len == 0) {
                return error.NoMarkSet;
            }
            const mark_pos = self.marks.pop().?;
            return Range.init(mark_pos, self.current);
        }
        
        /// Get the distance between two positions
        /// Returns difference in lines, columns, and bytes
        pub fn getPositionDifference(start: Position, end: Position) PositionDifference {
            const line_diff = if (end.line >= start.line) 
                end.line - start.line 
            else 
                0;
            
            const column_diff = if (end.line == start.line) 
                if (end.column >= start.column) end.column - start.column else 0
            else 
                end.column - 1; // End column from start of its line
            
            const byte_diff = if (end.offset >= start.offset) 
                end.offset - start.offset 
            else 
                0;
            
            return .{
                .lines = line_diff,
                .columns = column_diff,
                .bytes = byte_diff,
            };
        }
        
        /// Convert a byte offset to a Position by scanning from the start
        /// Requires the original buffer to accurately track line/column positions
        pub fn offsetToPosition(self: *const PositionTracker, buffer: []const u8, target_offset: usize) !Position {
            if (target_offset > buffer.len) {
                return error.OffsetOutOfBounds;
            }
            
            var pos = Position.init();
            var i: usize = 0;
            
            while (i < target_offset and i < buffer.len) {
                const char = buffer[i];
                
                // Handle different line endings
                if (char == '\r') {
                    // Check for CRLF
                    if (i + 1 < buffer.len and buffer[i + 1] == '\n') {
                        pos.offset = i + 2;
                        pos.line += 1;
                        pos.column = 1;
                        i += 2;
                        if (i > target_offset) {
                            // Target was the CR in CRLF
                            pos.offset = target_offset;
                            break;
                        }
                    } else {
                        // Just CR
                        pos.offset = i + 1;
                        pos.line += 1;
                        pos.column = 1;
                        i += 1;
                    }
                } else if (char == '\n') {
                    pos.offset = i + 1;
                    pos.line += 1;
                    pos.column = 1;
                    i += 1;
                } else if (char == '\t') {
                    pos.offset = i + 1;
                    const spaces_to_tab = self.tab_width - ((pos.column - 1) % self.tab_width);
                    pos.column += spaces_to_tab;
                    i += 1;
                } else {
                    pos.offset = i + 1;
                    pos.column += 1;
                    i += 1;
                }
            }
            
            // Adjust if we overshot due to multi-byte sequences
            if (pos.offset > target_offset) {
                pos.offset = target_offset;
            }
            
            return pos;
        }
        
        /// Check if current position is at the start of a line
        pub fn isAtLineStart(self: *const PositionTracker) bool {
            return self.current.column == 1;
        }
        
        /// Check if current position is at the end of a line
        /// Requires lookahead into the buffer to determine
        pub fn isAtLineEnd(self: *const PositionTracker, buffer: []const u8) bool {
            if (self.current.offset >= buffer.len) {
                return true; // At end of buffer
            }
            
            const next_char = buffer[self.current.offset];
            
            // Check for line ending characters
            if (next_char == '\n' or next_char == '\r') {
                return true;
            }
            
            return false;
        }
        
        /// Check if current position is at the start of the buffer
        pub fn isAtStart(self: *const PositionTracker) bool {
            return self.current.offset == 0;
        }
        
        /// Check if current position is at the end of the buffer
        pub fn isAtEnd(self: *const PositionTracker, buffer: []const u8) bool {
            return self.current.offset >= buffer.len;
        }
        
        /// Get column position considering tab stops
        /// This returns the visual column position accounting for tab expansion
        pub fn getVisualColumn(self: *const PositionTracker) u32 {
            return self.current.column;
        }
        
        /// Skip whitespace from current position
        /// Returns the number of bytes skipped
        pub fn skipWhitespace(self: *PositionTracker, buffer: []const u8) usize {
            const start_offset = self.current.offset;
            
            while (self.current.offset < buffer.len) {
                const char = buffer[self.current.offset];
                switch (char) {
                    ' ', '\t' => self.advance(char),
                    else => break,
                }
            }
            
            return self.current.offset - start_offset;
        }
        
        /// Skip to end of current line
        /// Positions cursor at the line ending character(s)
        pub fn skipToLineEnd(self: *PositionTracker, buffer: []const u8) void {
            while (self.current.offset < buffer.len) {
                const char = buffer[self.current.offset];
                if (char == '\n' or char == '\r') {
                    break;
                }
                self.advance(char);
            }
        }
        
        /// Skip to start of next line
        /// Positions cursor at the first character of the next line
        pub fn skipToNextLine(self: *PositionTracker, buffer: []const u8) void {
            // First skip to line end
            self.skipToLineEnd(buffer);
            
            // Then skip the line ending
            if (self.current.offset < buffer.len) {
                const char = buffer[self.current.offset];
                if (char == '\r') {
                    self.advance(char);
                    // Check for CRLF
                    if (self.current.offset < buffer.len and buffer[self.current.offset] == '\n') {
                        self.advance('\n');
                    }
                } else if (char == '\n') {
                    self.advance(char);
                }
            }
        }
        
        /// Get a snapshot of the current position
        pub fn snapshot(self: *const PositionTracker) Position {
            return self.current;
        }
        
        /// Restore position from a snapshot
        pub fn restoreSnapshot(self: *PositionTracker, pos: Position) void {
            self.current = pos;
        }
    };
    
    /// Structure representing the difference between two positions
    pub const PositionDifference = struct {
        lines: u32,    // Number of lines between positions
        columns: u32,  // Column difference (only meaningful on same line)
        bytes: usize,  // Byte offset difference
        
        /// Check if positions are on the same line
        pub fn isSameLine(self: PositionDifference) bool {
            return self.lines == 0;
        }
        
        /// Get total distance as a simple metric
        pub fn totalDistance(self: PositionDifference) usize {
            return self.bytes;
        }
    };
    
    // Legacy alias for backward compatibility during transition
    pub const Position = SourcePosition;
    
    // Import test files
    test {
        _ = @import("position.test.zig");
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
