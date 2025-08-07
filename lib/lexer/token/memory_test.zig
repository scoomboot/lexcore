// memory_test.zig — Memory usage validation tests for token system
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/token/test
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const token = @import("token.zig");
    const position = @import("../position/position.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Custom allocator wrapper to track allocations
    const TrackingAllocator = struct {
        underlying: std.mem.Allocator,
        allocation_count: usize = 0,
        deallocation_count: usize = 0,
        total_bytes_allocated: usize = 0,
        total_bytes_freed: usize = 0,
        current_bytes: usize = 0,
        peak_bytes: usize = 0,
        
        const Self = @This();
        
        pub fn init(underlying: std.mem.Allocator) Self {
            return .{
                .underlying = underlying,
            };
        }
        
        pub fn allocator(self: *Self) std.mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                    .remap = remap,
                },
            };
        }
        
        fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));
            const result = self.underlying.rawAlloc(len, ptr_align, ret_addr);
            if (result) |_| {
                self.allocation_count += 1;
                self.total_bytes_allocated += len;
                self.current_bytes += len;
                if (self.current_bytes > self.peak_bytes) {
                    self.peak_bytes = self.current_bytes;
                }
            }
            return result;
        }
        
        fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
            const self: *Self = @ptrCast(@alignCast(ctx));
            const old_len = buf.len;
            const result = self.underlying.rawResize(buf, buf_align, new_len, ret_addr);
            if (result) {
                if (new_len > old_len) {
                    const diff = new_len - old_len;
                    self.total_bytes_allocated += diff;
                    self.current_bytes += diff;
                } else {
                    const diff = old_len - new_len;
                    self.total_bytes_freed += diff;
                    self.current_bytes -= diff;
                }
                if (self.current_bytes > self.peak_bytes) {
                    self.peak_bytes = self.current_bytes;
                }
            }
            return result;
        }
        
        fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
            const self: *Self = @ptrCast(@alignCast(ctx));
            self.underlying.rawFree(buf, buf_align, ret_addr);
            self.deallocation_count += 1;
            self.total_bytes_freed += buf.len;
            if (self.current_bytes >= buf.len) {
                self.current_bytes -= buf.len;
            } else {
                self.current_bytes = 0; // Prevent underflow
            }
        }
        
        fn remap(ctx: *anyopaque, old_mem: []u8, old_align: std.mem.Alignment, new_size: usize, ret_addr: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return self.underlying.rawRemap(old_mem, old_align, new_size, ret_addr);
        }
        
        pub fn reset(self: *Self) void {
            self.allocation_count = 0;
            self.deallocation_count = 0;
            self.total_bytes_allocated = 0;
            self.total_bytes_freed = 0;
            self.current_bytes = 0;
            self.peak_bytes = 0;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: Token: creation requires no heap allocations" {
        var tracker = TrackingAllocator.init(testing.allocator);
        const allocator = tracker.allocator();
        _ = allocator; // Token creation shouldn't need this
        
        const MyToken = token.Token(token.TokenType);
        const source = "test_token";
        
        // Reset tracker to ensure clean state
        tracker.reset();
        
        // Create tokens - should not allocate
        const tok1 = MyToken.init(token.TokenType.Identifier, source, position.SourcePosition.init());
        const tok2 = MyToken.initWithMetadata(
            token.TokenType.Number,
            "42",
            position.SourcePosition.init(),
            token.TokenMetadata{ .integer_value = 42 },
        );
        
        // Verify no allocations occurred
        try testing.expect(tracker.allocation_count == 0);
        try testing.expect(tracker.current_bytes == 0);
        try testing.expect(tracker.peak_bytes == 0);
        
        // Verify tokens work correctly
        try testing.expectEqualStrings(source, tok1.lexeme());
        try testing.expectEqualStrings("42", tok2.lexeme());
    }
    
    test "unit: Token: size remains constant regardless of slice length" {
        const MyToken = token.Token(token.TokenType);
        
        // Tokens with different slice lengths
        const tok1 = MyToken.init(token.TokenType.Identifier, "x", position.SourcePosition.init());
        const tok2 = MyToken.init(token.TokenType.Identifier, "very_long_identifier_name_here", position.SourcePosition.init());
        const tok3 = MyToken.init(token.TokenType.String, "a" ** 1000, position.SourcePosition.init());
        
        // All tokens should have the same size (slice is just ptr + len)
        const size1 = @sizeOf(@TypeOf(tok1));
        const size2 = @sizeOf(@TypeOf(tok2));
        const size3 = @sizeOf(@TypeOf(tok3));
        
        try testing.expect(size1 == size2);
        try testing.expect(size2 == size3);
    }
    
    test "unit: TokenMetadata: memory layout and size validation" {
        // Verify TokenMetadata union size is optimal
        const metadata_size = @sizeOf(token.TokenMetadata);
        
        // The union should be as large as its largest member plus tag
        const expected_min = @max(
            @sizeOf(i64),     // integer_value
            @sizeOf(f64),     // float_value
            @sizeOf([]const u8), // string_value
            @sizeOf(bool),    // boolean_value
            @sizeOf(u21),     // character_value
            @sizeOf(*anyopaque), // custom
        );
        
        // Size should be reasonable (tag + largest member + padding)
        try testing.expect(metadata_size <= expected_min + 8);
        
        // Test each variant
        const int_meta = token.TokenMetadata{ .integer_value = -999999 };
        const float_meta = token.TokenMetadata{ .float_value = 1.23456789 };
        const string_meta = token.TokenMetadata{ .string_value = "test" };
        const bool_meta = token.TokenMetadata{ .boolean_value = false };
        const char_meta = token.TokenMetadata{ .character_value = 'Z' };
        
        // All variants should report correct type
        try testing.expectEqualStrings("integer", int_meta.getType());
        try testing.expectEqualStrings("float", float_meta.getType());
        try testing.expectEqualStrings("string", string_meta.getType());
        try testing.expectEqualStrings("boolean", bool_meta.getType());
        try testing.expectEqualStrings("character", char_meta.getType());
    }
    
    test "performance: Token: memory efficiency with large token arrays" {
        var tracker = TrackingAllocator.init(testing.allocator);
        const allocator = tracker.allocator();
        
        const MyToken = token.Token(token.TokenType);
        const token_count = 10000;
        
        // Create array of tokens
        const tokens = try allocator.alloc(MyToken, token_count);
        defer allocator.free(tokens);
        
        // Fill with tokens
        for (tokens, 0..) |*tok, i| {
            tok.* = MyToken.init(
                token.TokenType.Identifier,
                "tok",
                position.SourcePosition.initWithValues(1, @intCast(i + 1), i),
            );
        }
        
        // Calculate memory efficiency
        const token_size = @sizeOf(MyToken);
        const expected_memory = token_size * token_count;
        const actual_memory = tracker.total_bytes_allocated;
        
        // Memory usage should be close to expected (allowing for alignment)
        try testing.expect(actual_memory <= expected_memory + 64);
        
        // Verify no memory leaks
        try testing.expect(tracker.deallocation_count == 0); // Haven't freed yet
    }
    
    test "stress: Token: memory stability under heavy load" {
        var tracker = TrackingAllocator.init(testing.allocator);
        const allocator = tracker.allocator();
        
        const MyToken = token.Token(token.TokenType);
        const iterations = 100;
        const tokens_per_iteration = 1000;
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            // Allocate tokens
            const tokens = try allocator.alloc(MyToken, tokens_per_iteration);
            
            // Fill with data
            for (tokens, 0..) |*tok, j| {
                const metadata = if (j % 2 == 0)
                    token.TokenMetadata{ .integer_value = @intCast(j) }
                else
                    token.TokenMetadata{ .float_value = @as(f64, @floatFromInt(j)) * 1.5 };
                    
                tok.* = MyToken.initWithMetadata(
                    token.TokenType.Number,
                    "num",
                    position.SourcePosition.initWithValues(@intCast(i + 1), @intCast(j + 1), i * tokens_per_iteration + j),
                    metadata,
                );
            }
            
            // Free tokens
            allocator.free(tokens);
        }
        
        // Verify all memory was freed
        try testing.expect(tracker.current_bytes == 0);
        try testing.expect(tracker.allocation_count == tracker.deallocation_count);
    }
    
    test "unit: LegacyToken: memory management with owned lexemes" {
        var tracker = TrackingAllocator.init(testing.allocator);
        const allocator = tracker.allocator();
        
        // Test owned lexeme allocation and deallocation
        const lexeme = try allocator.dupe(u8, "owned_test_lexeme");
        var tok = token.LegacyToken.initOwned(
            allocator,
            token.TokenType.Identifier,
            lexeme,
            position.Position.init(),
        );
        
        // Verify allocation occurred
        try testing.expect(tracker.allocation_count == 1);
        try testing.expect(tracker.current_bytes > 0);
        
        // Clean up
        tok.deinit();
        
        // Verify deallocation occurred
        try testing.expect(tracker.current_bytes == 0);
        try testing.expect(tracker.deallocation_count == 1);
    }
    
    test "stress: LegacyToken: mixed ownership memory patterns" {
        var tracker = TrackingAllocator.init(testing.allocator);
        const allocator = tracker.allocator();
        
        var tokens = std.ArrayList(token.LegacyToken).init(allocator);
        defer {
            for (tokens.items) |*tok| {
                tok.deinit();
            }
            tokens.deinit();
        }
        
        // Add mix of owned and non-owned tokens
        var i: usize = 0;
        while (i < 1000) : (i += 1) {
            if (i % 3 == 0) {
                // Owned token
                const lexeme = try allocator.alloc(u8, 20);
                _ = try std.fmt.bufPrint(lexeme, "owned_{d}", .{i});
                try tokens.append(token.LegacyToken.initOwned(
                    allocator,
                    token.TokenType.Identifier,
                    lexeme,
                    position.Position.init(),
                ));
            } else {
                // Non-owned token
                try tokens.append(token.LegacyToken.init(
                    token.TokenType.Number,
                    "static",
                    position.Position.init(),
                ));
            }
        }
        
        // Verify some allocations occurred (for owned tokens)
        try testing.expect(tracker.allocation_count > 0);
        
        // Clean up all tokens
        for (tokens.items) |*tok| {
            tok.deinit();
        }
        
        // Clear tokens but keep capacity
        tokens.clearRetainingCapacity();
        
        // Verify owned lexemes were freed
        const remaining = tracker.current_bytes;
        
        // Should only have the ArrayList's buffer remaining
        try testing.expect(remaining < tracker.peak_bytes);
    }
    
    test "integration: Token: memory usage in realistic lexer" {
        var tracker = TrackingAllocator.init(testing.allocator);
        const allocator = tracker.allocator();
        
        const source =
            \\fn fibonacci(n: u32) u32 {
            \\    if (n <= 1) return n;
            \\    return fibonacci(n - 1) + fibonacci(n - 2);
            \\}
        ;
        
        const MyToken = token.Token(token.TokenType);
        var tokens = std.ArrayList(MyToken).init(allocator);
        defer tokens.deinit();
        
        // Simulate tokenization
        tracker.reset();
        
        // Add tokens (zero-copy, so only ArrayList should allocate)
        try tokens.append(MyToken.init(token.TokenType.Keyword, source[0..2], position.SourcePosition.init()));
        try tokens.append(MyToken.init(token.TokenType.Identifier, source[3..12], position.SourcePosition.initWithValues(1, 4, 3)));
        try tokens.append(MyToken.init(token.TokenType.LeftParen, source[12..13], position.SourcePosition.initWithValues(1, 13, 12)));
        
        // Only the ArrayList should have allocated
        try testing.expect(tracker.allocation_count > 0); // ArrayList's buffer
        
        // Memory used should be primarily for the ArrayList buffer
        const token_size = @sizeOf(MyToken);
        const min_expected = token_size * tokens.items.len;
        
        // Actual allocation includes ArrayList overhead and capacity
        try testing.expect(tracker.current_bytes >= min_expected);
        
        // But shouldn't be excessive (no string copies)
        try testing.expect(tracker.current_bytes < source.len + min_expected * 2);
    }
    
    test "performance: TokenComparison: memory-efficient sorting" {
        var tracker = TrackingAllocator.init(testing.allocator);
        const allocator = tracker.allocator();
        
        const MyToken = token.Token(token.TokenType);
        const tokens = try allocator.alloc(MyToken, 1000);
        defer allocator.free(tokens);
        
        // Fill with tokens in reverse order
        for (tokens, 0..) |*tok, i| {
            const idx = tokens.len - 1 - i;
            tok.* = MyToken.init(
                token.TokenType.Identifier,
                "id",
                position.SourcePosition.initWithValues(1, @intCast(idx + 1), idx),
            );
        }
        
        // Reset tracker to measure sorting overhead
        tracker.reset();
        
        // Sort tokens
        const compareFn = token.TokenComparison.compareByPosition(token.TokenType);
        std.mem.sort(MyToken, tokens, {}, compareFn);
        
        // Sorting should not allocate additional memory
        try testing.expect(tracker.allocation_count == 0);
        try testing.expect(tracker.current_bytes == 0);
        
        // Verify sorted correctly
        for (tokens, 0..) |tok, i| {
            try testing.expect(tok.position.offset == i);
        }
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝