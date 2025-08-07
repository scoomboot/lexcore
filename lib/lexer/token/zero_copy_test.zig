// zero_copy_test.zig — Zero-copy verification tests for token system
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

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: Token: verifies zero-copy design with source buffer" {
        // Create a source buffer that will be referenced by multiple tokens
        const source_buffer = "function calculate(x, y) { return x + y * 2; }";
        const MyToken = token.Token(token.TokenType);
        
        // Create tokens that slice into the source buffer
        const tokens = [_]token.Token(token.TokenType){
            MyToken.init(token.TokenType.Keyword, source_buffer[0..8], position.SourcePosition.init()), // "function"
            MyToken.init(token.TokenType.Identifier, source_buffer[9..18], position.SourcePosition.initWithValues(1, 10, 9)), // "calculate"
            MyToken.init(token.TokenType.LeftParen, source_buffer[18..19], position.SourcePosition.initWithValues(1, 19, 18)), // "("
            MyToken.init(token.TokenType.Identifier, source_buffer[19..20], position.SourcePosition.initWithValues(1, 20, 19)), // "x"
            MyToken.init(token.TokenType.Comma, source_buffer[20..21], position.SourcePosition.initWithValues(1, 21, 20)), // ","
            MyToken.init(token.TokenType.Identifier, source_buffer[22..23], position.SourcePosition.initWithValues(1, 23, 22)), // "y"
            MyToken.init(token.TokenType.RightParen, source_buffer[23..24], position.SourcePosition.initWithValues(1, 24, 23)), // ")"
        };
        
        // Verify each token points to the original source buffer
        for (tokens, 0..) |tok, i| {
            const expected_start: usize = switch (i) {
                0 => 0,   // "function"
                1 => 9,   // "calculate"
                2 => 18,  // "("
                3 => 19,  // "x"
                4 => 20,  // ","
                5 => 22,  // "y"
                6 => 23,  // ")"
                else => unreachable,
            };
            
            // Verify the slice pointer points into the source buffer
            try testing.expect(tok.slice.ptr == source_buffer.ptr + expected_start);
            
            // Verify no memory was copied
            try testing.expect(@intFromPtr(tok.slice.ptr) >= @intFromPtr(source_buffer.ptr));
            try testing.expect(@intFromPtr(tok.slice.ptr) < @intFromPtr(source_buffer.ptr + source_buffer.len));
        }
    }
    
    test "unit: Token: maintains zero-copy with metadata" {
        // Verify that adding metadata doesn't affect zero-copy property of the slice
        const source = "42 3.14 true \"hello\"";
        const MyToken = token.Token(token.TokenType);
        
        const tok1 = MyToken.initWithMetadata(
            token.TokenType.Number,
            source[0..2], // "42"
            position.SourcePosition.init(),
            token.TokenMetadata{ .integer_value = 42 },
        );
        
        const tok2 = MyToken.initWithMetadata(
            token.TokenType.Number,
            source[3..7], // "3.14"
            position.SourcePosition.initWithValues(1, 4, 3),
            token.TokenMetadata{ .float_value = 3.14 },
        );
        
        const tok3 = MyToken.initWithMetadata(
            token.TokenType.Keyword,
            source[8..12], // "true"
            position.SourcePosition.initWithValues(1, 9, 8),
            token.TokenMetadata{ .boolean_value = true },
        );
        
        const tok4 = MyToken.initWithMetadata(
            token.TokenType.String,
            source[13..20], // "\"hello\""
            position.SourcePosition.initWithValues(1, 14, 13),
            token.TokenMetadata{ .string_value = "hello" },
        );
        
        // Verify all tokens still point to original source
        try testing.expect(tok1.slice.ptr == source.ptr);
        try testing.expect(tok2.slice.ptr == source.ptr + 3);
        try testing.expect(tok3.slice.ptr == source.ptr + 8);
        try testing.expect(tok4.slice.ptr == source.ptr + 13);
        
        // Verify metadata doesn't affect the slice
        try testing.expectEqualStrings("42", tok1.lexeme());
        try testing.expectEqualStrings("3.14", tok2.lexeme());
        try testing.expectEqualStrings("true", tok3.lexeme());
        try testing.expectEqualStrings("\"hello\"", tok4.lexeme());
    }
    
    test "performance: Token: no allocations during token operations" {
        // Verify that token operations don't allocate memory
        const source = "test_identifier";
        const MyToken = token.Token(token.TokenType);
        
        // These operations should not allocate
        const tok = MyToken.init(token.TokenType.Identifier, source, position.SourcePosition.init());
        
        // Token methods should not allocate
        const lexeme = tok.lexeme();
        const len = tok.length();
        
        // Comparison operations should not allocate
        const tok2 = MyToken.init(token.TokenType.Identifier, source, position.SourcePosition.init());
        const are_equal = tok.eql(tok2);
        const are_identical = tok.identical(tok2);
        
        // Verify results
        try testing.expectEqualStrings(source, lexeme);
        try testing.expect(len == source.len);
        try testing.expect(are_equal);
        try testing.expect(are_identical);
        
        // Verify pointers
        try testing.expect(lexeme.ptr == source.ptr);
        try testing.expect(tok.slice.ptr == source.ptr);
        try testing.expect(tok2.slice.ptr == source.ptr);
    }
    
    test "stress: Token: zero-copy with large source buffers" {
        // Test zero-copy with large source buffers
        const large_source = "a" ** 10000; // 10KB source
        const MyToken = token.Token(token.TokenType);
        
        var tokens = std.ArrayList(MyToken).init(testing.allocator);
        defer tokens.deinit();
        
        // Create tokens at various positions in the large source
        var offset: usize = 0;
        while (offset < large_source.len - 100) : (offset += 100) {
            const tok = MyToken.init(
                token.TokenType.Identifier,
                large_source[offset..offset + 50],
                position.SourcePosition.initWithValues(1, @intCast(offset + 1), offset),
            );
            try tokens.append(tok);
            
            // Verify zero-copy property
            try testing.expect(tok.slice.ptr == large_source.ptr + offset);
        }
        
        // Verify all tokens point into the original buffer
        for (tokens.items, 0..) |tok, i| {
            const expected_offset = i * 100;
            try testing.expect(tok.slice.ptr == large_source.ptr + expected_offset);
            try testing.expect(tok.slice.len == 50);
        }
    }
    
    test "unit: Token: zero-copy preserved across token copying" {
        // Verify that copying a token preserves zero-copy property
        const source = "original_text";
        const MyToken = token.Token(token.TokenType);
        
        const original = MyToken.init(
            token.TokenType.Identifier,
            source,
            position.SourcePosition.init(),
        );
        
        // Copy the token
        const copy = original;
        
        // Both should point to the same source
        try testing.expect(original.slice.ptr == copy.slice.ptr);
        try testing.expect(original.slice.ptr == source.ptr);
        try testing.expect(copy.slice.ptr == source.ptr);
        
        // Modifications to position in copy shouldn't affect original
        var mutable_copy = copy;
        mutable_copy.position.line = 10;
        
        try testing.expect(original.position.line == 1);
        try testing.expect(mutable_copy.position.line == 10);
        
        // But slice still points to same memory
        try testing.expect(mutable_copy.slice.ptr == source.ptr);
    }
    
    test "integration: Token: zero-copy in realistic lexer scenario" {
        // Simulate a realistic lexer that produces tokens from a source file
        const source_code =
            \\const std = @import("std");
            \\
            \\pub fn main() !void {
            \\    const x: i32 = 100;
            \\    const y: i32 = 200;
            \\    std.debug.print("{d}\n", .{x + y});
            \\}
        ;
        
        const MyToken = token.Token(token.TokenType);
        var tokens = std.ArrayList(MyToken).init(testing.allocator);
        defer tokens.deinit();
        
        // Simulate tokenization with zero-copy slices
        // Token: "const"
        try tokens.append(MyToken.init(
            token.TokenType.Keyword,
            source_code[0..5],
            position.SourcePosition.init(),
        ));
        
        // Token: "std"
        try tokens.append(MyToken.init(
            token.TokenType.Identifier,
            source_code[6..9],
            position.SourcePosition.initWithValues(1, 7, 6),
        ));
        
        // Token: "="
        try tokens.append(MyToken.init(
            token.TokenType.Assign,
            source_code[10..11],
            position.SourcePosition.initWithValues(1, 11, 10),
        ));
        
        // Verify all tokens use zero-copy slices
        try testing.expect(tokens.items[0].slice.ptr == source_code.ptr);
        try testing.expect(tokens.items[1].slice.ptr == source_code.ptr + 6);
        try testing.expect(tokens.items[2].slice.ptr == source_code.ptr + 10);
        
        // Verify content integrity
        try testing.expectEqualStrings("const", tokens.items[0].lexeme());
        try testing.expectEqualStrings("std", tokens.items[1].lexeme());
        try testing.expectEqualStrings("=", tokens.items[2].lexeme());
        
        // Calculate total memory used by tokens (excluding the source)
        const token_size = @sizeOf(MyToken);
        const total_token_memory = token_size * tokens.items.len;
        
        // Verify we're not duplicating the source content
        // The total memory should be just the token structures, not the text
        try testing.expect(total_token_memory < source_code.len * 2);
    }
    
    test "e2e: Token: zero-copy verification with position tracking" {
        // End-to-end test verifying zero-copy with accurate position tracking
        const input = "abc def ghi";
        const MyToken = token.Token(token.TokenType);
        
        // Track positions manually to verify accuracy
        var pos = position.SourcePosition.init();
        var tokens = [_]MyToken{undefined} ** 3;
        
        // Token 1: "abc"
        tokens[0] = MyToken.init(token.TokenType.Identifier, input[0..3], pos);
        pos.offset = 4;
        pos.column = 5;
        
        // Token 2: "def"
        tokens[1] = MyToken.init(token.TokenType.Identifier, input[4..7], pos);
        pos.offset = 8;
        pos.column = 9;
        
        // Token 3: "ghi"
        tokens[2] = MyToken.init(token.TokenType.Identifier, input[8..11], pos);
        
        // Verify zero-copy property
        try testing.expect(tokens[0].slice.ptr == input.ptr);
        try testing.expect(tokens[1].slice.ptr == input.ptr + 4);
        try testing.expect(tokens[2].slice.ptr == input.ptr + 8);
        
        // Verify positions
        try testing.expect(tokens[0].position.offset == 0);
        try testing.expect(tokens[1].position.offset == 4);
        try testing.expect(tokens[2].position.offset == 8);
        
        // Verify adjacency using TokenComparison
        try testing.expect(!token.TokenComparison.areAdjacent(token.TokenType, tokens[0], tokens[1]));
        try testing.expect(token.TokenComparison.distance(token.TokenType, tokens[0], tokens[1]) == 1);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝