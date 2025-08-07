// token.test.zig — Test suite for token definitions
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

    const test_lexeme = "test_lexeme";
    const stress_iterations = 1000;
    const test_position = position.Position.init();

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: TokenType: toString returns tag name" {
        const tt = token.TokenType.Identifier;
        try testing.expectEqualStrings("Identifier", tt.toString());
        
        const tt2 = token.TokenType.Plus;
        try testing.expectEqualStrings("Plus", tt2.toString());
    }
    
    test "unit: TokenType: isLiteral correctly identifies literals" {
        try testing.expect(token.TokenType.Identifier.isLiteral());
        try testing.expect(token.TokenType.Number.isLiteral());
        try testing.expect(token.TokenType.String.isLiteral());
        try testing.expect(token.TokenType.Character.isLiteral());
        
        try testing.expect(!token.TokenType.Plus.isLiteral());
        try testing.expect(!token.TokenType.LeftParen.isLiteral());
    }
    
    test "unit: TokenType: isOperator correctly identifies operators" {
        try testing.expect(token.TokenType.Plus.isOperator());
        try testing.expect(token.TokenType.Minus.isOperator());
        try testing.expect(token.TokenType.Equal.isOperator());
        
        try testing.expect(!token.TokenType.Identifier.isOperator());
        try testing.expect(!token.TokenType.LeftParen.isOperator());
    }
    
    test "unit: TokenType: isDelimiter correctly identifies delimiters" {
        try testing.expect(token.TokenType.LeftParen.isDelimiter());
        try testing.expect(token.TokenType.RightBrace.isDelimiter());
        try testing.expect(token.TokenType.LeftBracket.isDelimiter());
        
        try testing.expect(!token.TokenType.Plus.isDelimiter());
        try testing.expect(!token.TokenType.Identifier.isDelimiter());
    }
    
    test "unit: Token: initialization without value" {
        const pos = position.Position.init();
        const tok = token.Token.init(
            token.TokenType.Identifier,
            "test",
            pos,
        );
        
        try testing.expect(tok.type == token.TokenType.Identifier);
        try testing.expectEqualStrings("test", tok.lexeme);
        try testing.expect(tok.value == null);
        try testing.expect(!tok.owns_lexeme);
    }
    
    test "unit: Token: initialization with value" {
        const pos = position.Position.init();
        const value = token.TokenValue{ .integer = 42 };
        const tok = token.Token.initWithValue(
            token.TokenType.Number,
            "42",
            pos,
            value,
        );
        
        try testing.expect(tok.type == token.TokenType.Number);
        try testing.expectEqualStrings("42", tok.lexeme);
        try testing.expect(tok.value != null);
        try testing.expect(tok.value.?.integer == 42);
        try testing.expect(!tok.owns_lexeme);
    }
    
    test "unit: Token: initialization with owned lexeme" {
        const pos = position.Position.init();
        const lexeme = try testing.allocator.dupe(u8, "owned_test");
        var tok = token.Token.initOwned(
            testing.allocator,
            token.TokenType.Identifier,
            lexeme,
            pos,
        );
        defer tok.deinit();
        
        try testing.expect(tok.type == token.TokenType.Identifier);
        try testing.expectEqualStrings("owned_test", tok.lexeme);
        try testing.expect(tok.owns_lexeme);
        try testing.expect(tok.allocator != null);
    }
    
    test "unit: Token: initialization with owned lexeme and value" {
        const pos = position.Position.init();
        const lexeme = try testing.allocator.dupe(u8, "3.14");
        const value = token.TokenValue{ .float = 3.14 };
        var tok = token.Token.initOwnedWithValue(
            testing.allocator,
            token.TokenType.Number,
            lexeme,
            pos,
            value,
        );
        defer tok.deinit();
        
        try testing.expect(tok.type == token.TokenType.Number);
        try testing.expectEqualStrings("3.14", tok.lexeme);
        try testing.expect(tok.value != null);
        try testing.expect(tok.value.?.float == 3.14);
        try testing.expect(tok.owns_lexeme);
        try testing.expect(tok.allocator != null);
    }
    
    test "unit: Token: deinit properly frees owned memory" {
        // Test that deinit() correctly frees owned lexeme
        const pos = position.Position.init();
        const lexeme = try testing.allocator.dupe(u8, "test_deinit");
        var tok = token.Token.initOwned(
            testing.allocator,
            token.TokenType.Identifier,
            lexeme,
            pos,
        );
        
        try testing.expect(tok.owns_lexeme);
        tok.deinit();
        try testing.expect(!tok.owns_lexeme);
        try testing.expect(tok.allocator == null);
    }
    
    test "unit: Token: deinit is safe on non-owned tokens" {
        // Test that deinit() is safe to call on tokens that don't own their lexeme
        const pos = position.Position.init();
        var tok = token.Token.init(
            token.TokenType.Identifier,
            "static_lexeme",
            pos,
        );
        
        try testing.expect(!tok.owns_lexeme);
        tok.deinit(); // Should not crash or cause issues
        try testing.expect(!tok.owns_lexeme);
    }
    
    test "unit: Token: equality comparison" {
        const pos1 = position.Position.init();
        const pos2 = position.Position{ .line = 2, .column = 5, .offset = 10 };
        
        const tok1 = token.Token.init(token.TokenType.Identifier, "test", pos1);
        const tok2 = token.Token.init(token.TokenType.Identifier, "test", pos2);
        const tok3 = token.Token.init(token.TokenType.Identifier, "other", pos1);
        
        try testing.expect(tok1.eql(tok2)); // Different positions, same content
        try testing.expect(!tok1.eql(tok3)); // Different lexemes
    }
    
    test "unit: TokenValue: getType returns correct type name" {
        const val1 = token.TokenValue{ .integer = 42 };
        try testing.expectEqualStrings("integer", val1.getType());
        
        const val2 = token.TokenValue{ .float = 3.14 };
        try testing.expectEqualStrings("float", val2.getType());
        
        const val3 = token.TokenValue{ .string = "hello" };
        try testing.expectEqualStrings("string", val3.getType());
    }
    
    test "unit: TokenStream: initialization and basic operations" {
        const tokens = [_]token.Token{
            token.Token.init(token.TokenType.Identifier, "foo", position.Position.init()),
            token.Token.init(token.TokenType.Plus, "+", position.Position.init()),
            token.Token.init(token.TokenType.Number, "42", position.Position.init()),
        };
        
        var stream = token.TokenStream.init(&tokens);
        
        try testing.expect(!stream.isAtEnd());
        try testing.expect(stream.position == 0);
        
        const tok1 = stream.peek();
        try testing.expect(tok1 != null);
        try testing.expect(tok1.?.type == token.TokenType.Identifier);
        try testing.expect(stream.position == 0); // Peek doesn't advance
        
        const tok2 = stream.next();
        try testing.expect(tok2 != null);
        try testing.expect(tok2.?.type == token.TokenType.Identifier);
        try testing.expect(stream.position == 1); // Next advances
    }
    
    test "unit: TokenStream: reset functionality" {
        const tokens = [_]token.Token{
            token.Token.init(token.TokenType.Identifier, "test", position.Position.init()),
        };
        
        var stream = token.TokenStream.init(&tokens);
        _ = stream.next();
        
        try testing.expect(stream.isAtEnd());
        
        stream.reset();
        try testing.expect(!stream.isAtEnd());
        try testing.expect(stream.position == 0);
    }
    
    test "stress: Token: memory management with many allocations" {
        // Stress test to ensure proper memory management under heavy allocation
        const iterations = 1000;
        var i: usize = 0;
        
        while (i < iterations) : (i += 1) {
            // Test owned token creation and cleanup
            const lexeme = try testing.allocator.alloc(u8, 100);
            @memcpy(lexeme, "stress_test_lexeme_with_long_content_to_test_memory_management_properly_under_load"[0..82]);
            
            var tok = token.Token.initOwned(
                testing.allocator,
                token.TokenType.String,
                lexeme,
                position.Position.init(),
            );
            
            try testing.expect(tok.owns_lexeme);
            try testing.expect(tok.allocator != null);
            
            // Clean up
            tok.deinit();
            try testing.expect(!tok.owns_lexeme);
            try testing.expect(tok.allocator == null);
        }
        
        // Test should complete without memory leaks
    }
    
    test "stress: Token: mixed ownership patterns" {
        // Test mixing owned and non-owned tokens to ensure proper memory management
        var tokens = std.ArrayList(token.Token).init(testing.allocator);
        defer {
            // Clean up all tokens
            for (tokens.items) |*tok| {
                tok.deinit();
            }
            tokens.deinit();
        }
        
        // Add non-owned tokens
        try tokens.append(token.Token.init(
            token.TokenType.Identifier,
            "static1",
            position.Position.init(),
        ));
        
        // Add owned tokens
        const lexeme1 = try testing.allocator.dupe(u8, "owned1");
        try tokens.append(token.Token.initOwned(
            testing.allocator,
            token.TokenType.String,
            lexeme1,
            position.Position.init(),
        ));
        
        // Add more non-owned tokens
        try tokens.append(token.Token.init(
            token.TokenType.Number,
            "42",
            position.Position.init(),
        ));
        
        // Add more owned tokens
        const lexeme2 = try testing.allocator.dupe(u8, "owned2");
        try tokens.append(token.Token.initOwned(
            testing.allocator,
            token.TokenType.Identifier,
            lexeme2,
            position.Position.init(),
        ));
        
        // Verify ownership status
        try testing.expect(!tokens.items[0].owns_lexeme); // static1
        try testing.expect(tokens.items[1].owns_lexeme);  // owned1
        try testing.expect(!tokens.items[2].owns_lexeme); // 42
        try testing.expect(tokens.items[3].owns_lexeme);  // owned2
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝