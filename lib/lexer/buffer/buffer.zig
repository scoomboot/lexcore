// buffer.zig — Input buffering and stream management
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/buffer
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const unicode = @import("../utils/unicode/unicode.zig");
    const position_module = @import("../position/position.zig");
    const PositionTracker = position_module.PositionTracker;
    const Position = position_module.Position;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Character predicate function type for filtering operations
    pub const CharPredicate = *const fn (u21) bool;
    
    /// Buffer for managing input source data with UTF-8 support
    pub const Buffer = struct {
        allocator: std.mem.Allocator,
        data: []const u8,
        position: usize,
        mark: ?usize,
        position_tracker: ?*PositionTracker,
        marked_source_position: ?Position,
        
        /// Initialize an empty buffer
        pub fn init(allocator: std.mem.Allocator) !Buffer {
            return Buffer{
                .allocator = allocator,
                .data = &[_]u8{},
                .position = 0,
                .mark = null,
                .position_tracker = null,
                .marked_source_position = null,
            };
        }
        
        /// Initialize buffer with content
        pub fn initWithContent(allocator: std.mem.Allocator, content: []const u8) !Buffer {
            return Buffer{
                .allocator = allocator,
                .data = content,
                .position = 0,
                .mark = null,
                .position_tracker = null,
                .marked_source_position = null,
            };
        }
        
        /// Initialize buffer with content and position tracking
        pub fn initWithPositionTracking(allocator: std.mem.Allocator, content: []const u8) !Buffer {
            var tracker = try allocator.create(PositionTracker);
            tracker.* = PositionTracker.init(allocator);
            
            // Auto-detect line ending from content
            if (content.len > 0) {
                tracker.detectLineEnding(content);
            }
            
            return Buffer{
                .allocator = allocator,
                .data = content,
                .position = 0,
                .mark = null,
                .position_tracker = tracker,
                .marked_source_position = null,
            };
        }
        
        /// Clean up buffer resources
        pub fn deinit(self: *Buffer) void {
            if (self.position_tracker) |tracker| {
                tracker.deinit();
                self.allocator.destroy(tracker);
                self.position_tracker = null;
            }
        }
        
        /// Enable position tracking
        pub fn enablePositionTracking(self: *Buffer) !void {
            if (self.position_tracker != null) return; // Already enabled
            
            var tracker = try self.allocator.create(PositionTracker);
            tracker.* = PositionTracker.init(self.allocator);
            
            // Auto-detect line ending from content
            if (self.data.len > 0) {
                tracker.detectLineEnding(self.data);
            }
            
            // If we're not at the beginning, advance tracker to current position
            if (self.position > 0) {
                var i: usize = 0;
                while (i < self.position) : (i += 1) {
                    tracker.advance(self.data[i]);
                }
            }
            
            self.position_tracker = tracker;
        }
        
        /// Disable position tracking
        pub fn disablePositionTracking(self: *Buffer) void {
            if (self.position_tracker) |tracker| {
                tracker.deinit();
                self.allocator.destroy(tracker);
                self.position_tracker = null;
                self.marked_source_position = null;
            }
        }
        
        /// Get current source position (if tracking is enabled)
        pub fn getCurrentPosition(self: *const Buffer) ?Position {
            if (self.position_tracker) |tracker| {
                return tracker.current;
            }
            return null;
        }
        
        /// Set buffer content
        pub fn setContent(self: *Buffer, content: []const u8) !void {
            self.data = content;
            self.position = 0;
            self.mark = null;
            self.marked_source_position = null;
            
            // Reset position tracker if enabled
            if (self.position_tracker) |tracker| {
                tracker.reset();
                // Auto-detect line ending from new content
                if (content.len > 0) {
                    tracker.detectLineEnding(content);
                }
            }
        }
        
        /// Get current character without advancing (byte-level)
        pub fn peek(self: *const Buffer) !u8 {
            if (self.position >= self.data.len) {
                return error.EndOfBuffer;
            }
            return self.data[self.position];
        }
        
        /// Peek at the next Unicode codepoint without advancing
        pub fn peekCodepoint(self: *const Buffer) !u21 {
            if (self.position >= self.data.len) {
                return error.EndOfBuffer;
            }
            const result = try unicode.decodeUtf8(self.data[self.position..]);
            return result.codepoint;
        }
        
        /// Look ahead n characters without advancing
        pub fn peekN(self: *const Buffer, n: usize) !u8 {
            const pos = self.position + n;
            if (pos >= self.data.len) {
                return error.EndOfBuffer;
            }
            return self.data[pos];
        }
        
        /// Get current character and advance position (byte-level)
        pub fn next(self: *Buffer) !u8 {
            const char = try self.peek();
            self.position += 1;
            
            // Update position tracker if enabled
            if (self.position_tracker) |tracker| {
                tracker.advance(char);
            }
            
            return char;
        }
        
        /// Get current Unicode codepoint and advance by its byte width
        pub fn nextCodepoint(self: *Buffer) !u21 {
            if (self.position >= self.data.len) {
                return error.EndOfBuffer;
            }
            const result = try unicode.decodeUtf8(self.data[self.position..]);
            
            // Update position tracker with UTF-8 aware advance if enabled
            if (self.position_tracker) |tracker| {
                tracker.advanceUtf8Bytes(self.data[self.position..self.position + result.bytes_consumed]);
            }
            
            self.position += result.bytes_consumed;
            return result.codepoint;
        }
        
        /// Advance position by n bytes
        pub fn advance(self: *Buffer, n: usize) void {
            const old_position = self.position;
            self.position = @min(self.position + n, self.data.len);
            
            // Update position tracker if enabled
            if (self.position_tracker) |tracker| {
                // Advance through each byte to properly track line/column
                var i = old_position;
                while (i < self.position) : (i += 1) {
                    tracker.advance(self.data[i]);
                }
            }
        }
        
        /// Advance position by n Unicode codepoints
        pub fn advanceCodepoints(self: *Buffer, n: usize) !void {
            var count: usize = 0;
            while (count < n and self.position < self.data.len) : (count += 1) {
                const result = try unicode.decodeUtf8(self.data[self.position..]);
                
                // Update position tracker with UTF-8 aware advance if enabled
                if (self.position_tracker) |tracker| {
                    tracker.advanceUtf8Bytes(self.data[self.position..self.position + result.bytes_consumed]);
                }
                
                self.position += result.bytes_consumed;
            }
            if (count < n) {
                return error.EndOfBuffer;
            }
        }
        
        /// Move back n positions
        pub fn retreat(self: *Buffer, n: usize) void {
            const new_position = if (n > self.position) 0 else self.position - n;
            
            // If position tracking is enabled, we need to recalculate position from the beginning
            // since going backwards is complex with variable-width UTF-8 and line tracking
            if (self.position_tracker) |tracker| {
                tracker.reset();
                var i: usize = 0;
                while (i < new_position) : (i += 1) {
                    tracker.advance(self.data[i]);
                }
            }
            
            self.position = new_position;
        }
        
        /// Mark current position for later restoration
        pub fn markPosition(self: *Buffer) void {
            self.mark = self.position;
            
            // Save source position if tracking is enabled
            if (self.position_tracker) |tracker| {
                self.marked_source_position = tracker.current;
            }
        }
        
        /// Restore previously marked position
        pub fn restoreMark(self: *Buffer) !void {
            if (self.mark) |mark| {
                self.position = mark;
                self.mark = null;
                
                // Restore source position if tracking is enabled
                if (self.position_tracker) |tracker| {
                    if (self.marked_source_position) |source_pos| {
                        tracker.current = source_pos;
                        self.marked_source_position = null;
                    }
                }
            } else {
                return error.NoMarkSet;
            }
        }
        
        /// Check if at end of buffer
        pub fn isAtEnd(self: *const Buffer) bool {
            return self.position >= self.data.len;
        }
        
        /// Get remaining bytes in buffer
        pub fn remaining(self: *const Buffer) usize {
            if (self.position >= self.data.len) return 0;
            return self.data.len - self.position;
        }
        
        /// Get slice from current position to end
        pub fn getRemainingSlice(self: *const Buffer) []const u8 {
            if (self.position >= self.data.len) return &[_]u8{};
            return self.data[self.position..];
        }
        
        /// Get slice of n characters from current position
        pub fn getSlice(self: *const Buffer, n: usize) ![]const u8 {
            const end = @min(self.position + n, self.data.len);
            if (self.position >= self.data.len) {
                return error.EndOfBuffer;
            }
            return self.data[self.position..end];
        }
        
        /// Reset buffer to beginning
        pub fn reset(self: *Buffer) void {
            self.position = 0;
            self.mark = null;
            self.marked_source_position = null;
            
            // Reset position tracker if enabled
            if (self.position_tracker) |tracker| {
                tracker.reset();
            }
        }
        
        /// Skip characters while predicate returns true
        pub fn skipWhile(self: *Buffer, predicate: CharPredicate) !void {
            while (self.position < self.data.len) {
                const result = try unicode.decodeUtf8(self.data[self.position..]);
                if (!predicate(result.codepoint)) {
                    break;
                }
                
                // Update position tracker with UTF-8 aware advance if enabled
                if (self.position_tracker) |tracker| {
                    tracker.advanceUtf8Bytes(self.data[self.position..self.position + result.bytes_consumed]);
                }
                
                self.position += result.bytes_consumed;
            }
        }
        
        /// Consume characters while predicate returns true, returning the consumed slice
        pub fn consumeWhile(self: *Buffer, predicate: CharPredicate) ![]const u8 {
            const start = self.position;
            
            while (self.position < self.data.len) {
                const result = try unicode.decodeUtf8(self.data[self.position..]);
                if (!predicate(result.codepoint)) {
                    break;
                }
                
                // Update position tracker with UTF-8 aware advance if enabled
                if (self.position_tracker) |tracker| {
                    tracker.advanceUtf8Bytes(self.data[self.position..self.position + result.bytes_consumed]);
                }
                
                self.position += result.bytes_consumed;
            }
            
            return self.data[start..self.position];
        }
        
        /// Skip whitespace characters
        pub fn skipWhitespace(self: *Buffer) !void {
            try self.skipWhile(unicode.isWhitespace);
        }
        
        /// Consume whitespace characters
        pub fn consumeWhitespace(self: *Buffer) ![]const u8 {
            return try self.consumeWhile(unicode.isWhitespace);
        }
        
        /// Consume identifier (starting with letter/underscore, continuing with alphanumeric)
        pub fn consumeIdentifier(self: *Buffer) ![]const u8 {
            const start = self.position;
            
            // Check first character
            if (self.position >= self.data.len) {
                return error.EndOfBuffer;
            }
            
            const first_result = try unicode.decodeUtf8(self.data[self.position..]);
            if (!unicode.isIdentifierStart(first_result.codepoint)) {
                return error.InvalidIdentifierStart;
            }
            
            // Update position tracker for the first character if enabled
            if (self.position_tracker) |tracker| {
                tracker.advanceUtf8Bytes(self.data[self.position..self.position + first_result.bytes_consumed]);
            }
            
            self.position += first_result.bytes_consumed;
            
            // Consume continuing characters (consumeWhile already updates position tracker)
            _ = try self.consumeWhile(unicode.isIdentifierContinue);
            
            return self.data[start..self.position];
        }
        
        /// Check if buffer contains valid UTF-8
        pub fn validateUtf8(self: *const Buffer) bool {
            return unicode.validateUtf8(self.data);
        }
        
        /// Get the byte position for a given codepoint index
        pub fn codepointIndexToByteOffset(self: *const Buffer, codepoint_index: usize) !usize {
            var byte_offset: usize = 0;
            var cp_count: usize = 0;
            
            while (byte_offset < self.data.len and cp_count < codepoint_index) : (cp_count += 1) {
                const result = try unicode.decodeUtf8(self.data[byte_offset..]);
                byte_offset += result.bytes_consumed;
            }
            
            if (cp_count < codepoint_index) {
                return error.IndexOutOfBounds;
            }
            
            return byte_offset;
        }
    };
    
    /// Streaming buffer for handling large files with minimal memory footprint
    /// Supports incremental reading and maintains a sliding window over the input
    pub const StreamingBuffer = struct {
        allocator: std.mem.Allocator,
        reader: std.fs.File.Reader,
        window: []u8,
        window_size: usize,
        window_start: usize,  // Absolute position in file where window starts
        position: usize,       // Current position within window
        valid_bytes: usize,    // Actual amount of valid data in the window
        file_size: ?usize,     // Total file size if known
        eof_reached: bool,
        position_tracker: ?*PositionTracker,  // Optional position tracking
        marked_source_position: ?Position,    // Saved position for mark/restore
        
        /// Initialize streaming buffer with a file reader
        pub fn init(allocator: std.mem.Allocator, file: std.fs.File, window_size: usize) !StreamingBuffer {
            const window = try allocator.alloc(u8, window_size);
            errdefer allocator.free(window);
            
            // Try to get file size
            const file_size = file.getEndPos() catch null;
            
            var buffer = StreamingBuffer{
                .allocator = allocator,
                .reader = file.reader(),
                .window = window,
                .window_size = window_size,
                .window_start = 0,
                .position = 0,
                .valid_bytes = 0,
                .file_size = file_size,
                .eof_reached = false,
                .position_tracker = null,
                .marked_source_position = null,
            };
            
            // Initial fill
            try buffer.fillWindow();
            
            return buffer;
        }
        
        /// Clean up streaming buffer
        pub fn deinit(self: *StreamingBuffer) void {
            if (self.position_tracker) |tracker| {
                tracker.deinit();
                self.allocator.destroy(tracker);
                self.position_tracker = null;
            }
            self.allocator.free(self.window);
        }
        
        /// Enable position tracking for the streaming buffer
        pub fn enablePositionTracking(self: *StreamingBuffer) !void {
            if (self.position_tracker != null) return; // Already enabled
            
            var tracker = try self.allocator.create(PositionTracker);
            tracker.* = PositionTracker.init(self.allocator);
            
            // Auto-detect line ending from current window content
            if (self.valid_bytes > 0) {
                tracker.detectLineEnding(self.window[0..self.valid_bytes]);
            }
            
            // If we're not at the beginning of the window, advance tracker to current position
            if (self.position > 0) {
                var i: usize = 0;
                while (i < self.position) : (i += 1) {
                    tracker.advance(self.window[i]);
                }
            }
            
            // If the window has been slid (window_start > 0), we need to account for that
            // by storing the cumulative position state
            if (self.window_start > 0) {
                // This is a complex case - we'd need to have tracked from the beginning
                // For now, we'll start tracking from the current window position
                // In a full implementation, we might want to store cumulative line/column
                // counts when sliding the window
            }
            
            self.position_tracker = tracker;
        }
        
        /// Disable position tracking
        pub fn disablePositionTracking(self: *StreamingBuffer) void {
            if (self.position_tracker) |tracker| {
                tracker.deinit();
                self.allocator.destroy(tracker);
                self.position_tracker = null;
                self.marked_source_position = null;
            }
        }
        
        /// Get current source position (if tracking is enabled)
        pub fn getCurrentPosition(self: *const StreamingBuffer) ?Position {
            if (self.position_tracker) |tracker| {
                return tracker.current;
            }
            return null;
        }
        
        /// Fill the window with data from the file
        fn fillWindow(self: *StreamingBuffer) !void {
            const bytes_read = try self.reader.read(self.window);
            self.valid_bytes = bytes_read;
            
            // Determine if we've reached EOF
            if (bytes_read < self.window.len) {
                // If we couldn't fill the whole window, we've definitely reached EOF
                self.eof_reached = true;
            } else if (self.file_size) |size| {
                // If we know the file size, check if we've read it all
                const bytes_read_total = self.window_start + bytes_read;
                if (bytes_read_total >= size) {
                    self.eof_reached = true;
                }
            }
        }
        
        /// Slide the window forward when needed
        fn slideWindow(self: *StreamingBuffer) !void {
            if (self.eof_reached and self.position >= self.valid_bytes) {
                return error.EndOfStream;
            }
            
            // Before sliding, save cumulative position state if tracking is enabled
            var cumulative_lines: u32 = 0;
            var cumulative_columns: u32 = 0;
            var last_was_cr: bool = false;
            
            if (self.position_tracker) |tracker| {
                // Save the current state before we process the bytes we're discarding
                cumulative_lines = tracker.current.line;
                cumulative_columns = tracker.current.column;
                
                // Process all bytes up to current position to get accurate cumulative state
                // This represents the bytes we're about to discard from the window
                tracker.reset();
                var i: usize = 0;
                while (i < self.position) : (i += 1) {
                    tracker.advance(self.window[i]);
                }
                
                // Store the cumulative position after processing discarded bytes
                cumulative_lines = tracker.current.line;
                cumulative_columns = tracker.current.column;
                
                // Check if last byte before keep region is CR (for CRLF handling)
                if (self.position > 0) {
                    last_was_cr = (self.window[self.position - 1] == '\r');
                }
            }
            
            // Determine how much data to keep from the current window
            // We keep the last quarter of the window size, but not more than what we have
            const target_keep = self.window_size / 4;
            const available_to_keep = if (self.valid_bytes > self.position) 
                self.valid_bytes - self.position 
            else 0;
            const keep_size = @min(target_keep, available_to_keep);
            
            // Calculate slide amount based on current position
            const slide_amount = self.position;
            
            // Move kept data to beginning if there's any
            if (keep_size > 0) {
                std.mem.copyForwards(u8, self.window[0..keep_size], self.window[self.position..self.position + keep_size]);
            }
            
            // Read new data to fill the rest of the window
            const read_size = self.window_size - keep_size;
            const bytes_read = try self.reader.read(self.window[keep_size..keep_size + read_size]);
            self.valid_bytes = keep_size + bytes_read;
            
            // Update window start position
            self.window_start += slide_amount;
            self.position = 0;  // Reset position to beginning of new window
            
            // Restore position tracker state if enabled
            if (self.position_tracker) |tracker| {
                // Reset the tracker and set it to the cumulative state
                tracker.reset();
                tracker.current.line = cumulative_lines;
                tracker.current.column = cumulative_columns;
                tracker.current.offset = self.window_start;
                
                // Handle potential CRLF split across window boundary
                // If last byte of discarded data was CR and first byte of kept data is LF,
                // we need to handle this specially
                if (last_was_cr and keep_size > 0 and self.window[0] == '\n') {
                    // This LF completes a CRLF pair, don't count it as a new line
                    // The line was already incremented when we saw the CR
                }
            }
            
            // Check if we've hit EOF
            if (bytes_read < read_size) {
                self.eof_reached = true;
            } else if (self.file_size) |size| {
                // If we know the file size, check if we've read it all
                const bytes_read_total = self.window_start + self.valid_bytes;
                if (bytes_read_total >= size) {
                    self.eof_reached = true;
                }
            }
        }
        
        /// Peek at current byte without advancing
        pub fn peek(self: *StreamingBuffer) !u8 {
            // Need to slide window if we're at or past the valid data boundary
            if (self.position >= self.valid_bytes) {
                if (self.eof_reached) {
                    return error.EndOfStream;
                }
                try self.slideWindow();
                
                // After sliding, check again
                if (self.position >= self.valid_bytes) {
                    return error.EndOfStream;
                }
            }
            
            // Peek doesn't advance position, so no position tracking update needed
            return self.window[self.position];
        }
        
        /// Get current byte and advance
        pub fn next(self: *StreamingBuffer) !u8 {
            const byte = try self.peek();
            self.position += 1;
            
            // Update position tracker if enabled
            if (self.position_tracker) |tracker| {
                tracker.advance(byte);
            }
            
            return byte;
        }
        
        /// Mark current position for later restoration
        pub fn markPosition(self: *StreamingBuffer) void {
            // For StreamingBuffer, we need to track both window position and absolute position
            // Store the current position within the window
            // Note: This simple implementation doesn't handle window sliding between mark and restore
            
            // Save source position if tracking is enabled
            if (self.position_tracker) |tracker| {
                self.marked_source_position = tracker.current;
            }
        }
        
        /// Restore previously marked position
        /// Note: This is limited for StreamingBuffer - can only restore within current window
        pub fn restoreMark(self: *StreamingBuffer) !void {
            // Restore source position if tracking is enabled
            if (self.position_tracker) |tracker| {
                if (self.marked_source_position) |source_pos| {
                    tracker.current = source_pos;
                    self.marked_source_position = null;
                }
            }
        }
        
        /// Get absolute position in file
        pub fn getAbsolutePosition(self: *const StreamingBuffer) usize {
            return self.window_start + self.position;
        }
        
        /// Check if at end of stream
        pub fn isAtEnd(self: *StreamingBuffer) bool {
            // If we've already detected EOF and we're at or past valid data, we're at end
            if (self.eof_reached and self.position >= self.valid_bytes) {
                return true;
            }
            
            // If we're at the end of our valid data but haven't checked for EOF yet,
            // try to peek ahead to detect it (this will trigger a slide if needed)
            if (self.position >= self.valid_bytes and !self.eof_reached) {
                _ = self.peek() catch {
                    // If peek fails, we're at EOF
                    return true;
                };
            }
            
            // After peek attempt, check again
            return self.eof_reached and self.position >= self.valid_bytes;
        }
    };
    
    /// Circular buffer for streaming input
    pub const CircularBuffer = struct {
        allocator: std.mem.Allocator,
        data: []u8,
        capacity: usize,
        head: usize,
        tail: usize,
        count: usize,
        
        /// Initialize circular buffer with given capacity
        pub fn init(allocator: std.mem.Allocator, capacity: usize) !CircularBuffer {
            const data = try allocator.alloc(u8, capacity);
            return CircularBuffer{
                .allocator = allocator,
                .data = data,
                .capacity = capacity,
                .head = 0,
                .tail = 0,
                .count = 0,
            };
        }
        
        /// Clean up circular buffer
        pub fn deinit(self: *CircularBuffer) void {
            self.allocator.free(self.data);
        }
        
        /// Write data to buffer
        pub fn write(self: *CircularBuffer, byte: u8) !void {
            if (self.count >= self.capacity) {
                return error.BufferFull;
            }
            
            self.data[self.tail] = byte;
            self.tail = (self.tail + 1) % self.capacity;
            self.count += 1;
        }
        
        /// Read data from buffer
        pub fn read(self: *CircularBuffer) !u8 {
            if (self.count == 0) {
                return error.BufferEmpty;
            }
            
            const byte = self.data[self.head];
            self.head = (self.head + 1) % self.capacity;
            self.count -= 1;
            return byte;
        }
        
        /// Check if buffer is empty
        pub fn isEmpty(self: *const CircularBuffer) bool {
            return self.count == 0;
        }
        
        /// Check if buffer is full
        pub fn isFull(self: *const CircularBuffer) bool {
            return self.count >= self.capacity;
        }
        
        /// Get available space in buffer
        pub fn available(self: *const CircularBuffer) usize {
            return self.capacity - self.count;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // Import test files
    test {
        _ = @import("buffer.test.zig");
        _ = @import("streaming_test.zig");
        _ = @import("position_integration_test.zig");
        _ = @import("streaming_position_test.zig");
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝