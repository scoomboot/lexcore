// buffer.zig — Input buffering and stream management
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/buffer
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Buffer for managing input source data
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
        
        /// Get current character without advancing
        pub fn peek(self: *const Buffer) !u8 {
            if (self.position >= self.data.len) {
                return error.EndOfBuffer;
            }
            return self.data[self.position];
        }
        
        /// Look ahead n characters without advancing
        pub fn peekN(self: *const Buffer, n: usize) !u8 {
            const pos = self.position + n;
            if (pos >= self.data.len) {
                return error.EndOfBuffer;
            }
            return self.data[pos];
        }
        
        /// Get current character and advance position
        pub fn next(self: *Buffer) !u8 {
            const char = try self.peek();
            self.position += 1;
            return char;
        }
        
        /// Advance position by n characters
        pub fn advance(self: *Buffer, n: usize) void {
            self.position = @min(self.position + n, self.data.len);
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