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

// ╚══════════════════════════════════════════════════════════════════════════════════════╝