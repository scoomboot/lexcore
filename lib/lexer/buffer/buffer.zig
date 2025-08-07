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
    const PositionTracker = @import("../position/position.zig").PositionTracker;

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
        
        /// Initialize an empty buffer
        pub fn init(allocator: std.mem.Allocator) !Buffer {
            return Buffer{
                .allocator = allocator,
                .data = &[_]u8{},
                .position = 0,
                .mark = null,
            };
        }
        
        /// Initialize buffer with content
        pub fn initWithContent(allocator: std.mem.Allocator, content: []const u8) !Buffer {
            return Buffer{
                .allocator = allocator,
                .data = content,
                .position = 0,
                .mark = null,
            };
        }
        
        /// Clean up buffer resources
        pub fn deinit(self: *Buffer) void {
            // Currently no dynamic allocation to clean up
            _ = self;
        }
        
        /// Set buffer content
        pub fn setContent(self: *Buffer, content: []const u8) !void {
            self.data = content;
            self.position = 0;
            self.mark = null;
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
            return char;
        }
        
        /// Get current Unicode codepoint and advance by its byte width
        pub fn nextCodepoint(self: *Buffer) !u21 {
            if (self.position >= self.data.len) {
                return error.EndOfBuffer;
            }
            const result = try unicode.decodeUtf8(self.data[self.position..]);
            self.position += result.bytes_consumed;
            return result.codepoint;
        }
        
        /// Advance position by n bytes
        pub fn advance(self: *Buffer, n: usize) void {
            self.position = @min(self.position + n, self.data.len);
        }
        
        /// Advance position by n Unicode codepoints
        pub fn advanceCodepoints(self: *Buffer, n: usize) !void {
            var count: usize = 0;
            while (count < n and self.position < self.data.len) : (count += 1) {
                const result = try unicode.decodeUtf8(self.data[self.position..]);
                self.position += result.bytes_consumed;
            }
            if (count < n) {
                return error.EndOfBuffer;
            }
        }
        
        /// Move back n positions
        pub fn retreat(self: *Buffer, n: usize) void {
            self.position = if (n > self.position) 0 else self.position - n;
        }
        
        /// Mark current position for later restoration
        pub fn markPosition(self: *Buffer) void {
            self.mark = self.position;
        }
        
        /// Restore previously marked position
        pub fn restoreMark(self: *Buffer) !void {
            if (self.mark) |mark| {
                self.position = mark;
                self.mark = null;
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
        }
        
        /// Skip characters while predicate returns true
        pub fn skipWhile(self: *Buffer, predicate: CharPredicate) !void {
            while (self.position < self.data.len) {
                const result = try unicode.decodeUtf8(self.data[self.position..]);
                if (!predicate(result.codepoint)) {
                    break;
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
            self.position += first_result.bytes_consumed;
            
            // Consume continuing characters
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
        file_size: ?usize,     // Total file size if known
        eof_reached: bool,
        
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
                .file_size = file_size,
                .eof_reached = false,
            };
            
            // Initial fill
            try buffer.fillWindow();
            
            return buffer;
        }
        
        /// Clean up streaming buffer
        pub fn deinit(self: *StreamingBuffer) void {
            self.allocator.free(self.window);
        }
        
        /// Fill the window with data from the file
        fn fillWindow(self: *StreamingBuffer) !void {
            const bytes_read = try self.reader.read(self.window);
            if (bytes_read < self.window.len) {
                self.eof_reached = true;
                // Zero out unused portion
                @memset(self.window[bytes_read..], 0);
            }
        }
        
        /// Slide the window forward when needed
        fn slideWindow(self: *StreamingBuffer) !void {
            if (self.eof_reached) {
                return error.EndOfStream;
            }
            
            // Keep last quarter of window for context
            const keep_size = self.window_size / 4;
            const slide_amount = self.window_size - keep_size;
            
            // Move kept data to beginning
            std.mem.copyForwards(u8, self.window[0..keep_size], self.window[slide_amount..]);
            
            // Read new data
            const bytes_read = try self.reader.read(self.window[keep_size..]);
            if (bytes_read < slide_amount) {
                self.eof_reached = true;
                // Zero out unused portion
                @memset(self.window[keep_size + bytes_read..], 0);
            }
            
            self.window_start += slide_amount;
            self.position = if (self.position >= slide_amount) self.position - slide_amount else 0;
        }
        
        /// Peek at current byte without advancing
        pub fn peek(self: *StreamingBuffer) !u8 {
            if (self.position >= self.window_size) {
                try self.slideWindow();
            }
            
            if (self.eof_reached and self.position >= self.window.len) {
                return error.EndOfStream;
            }
            
            return self.window[self.position];
        }
        
        /// Get current byte and advance
        pub fn next(self: *StreamingBuffer) !u8 {
            const byte = try self.peek();
            self.position += 1;
            return byte;
        }
        
        /// Get absolute position in file
        pub fn getAbsolutePosition(self: *const StreamingBuffer) usize {
            return self.window_start + self.position;
        }
        
        /// Check if at end of stream
        pub fn isAtEnd(self: *const StreamingBuffer) bool {
            return self.eof_reached and self.position >= self.window.len;
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
    
    // Import test files
    test {
        _ = @import("buffer.test.zig");
        _ = @import("streaming_test.zig");
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝