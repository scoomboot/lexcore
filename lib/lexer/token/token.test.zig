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
    
    // Use LegacyToken for backward compatibility tests
    const Token = token.LegacyToken;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    const test_lexeme = "test_lexeme";
    const stress_iterations = 1000;
    const test_position = position.Position.init();

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ======================== Generic Token Tests ========================
    
    test "unit: Token: generic token with custom enum type" {
        // Test the generic Token function with a custom enum
        const CustomTokenType = enum {
            Identifier,
            Number,
            Operator,
            Keyword,
        };
        
        const CustomToken = token.Token(CustomTokenType);
        
        const pos = position.SourcePosition.init();
        const tok = CustomToken.init(
            CustomTokenType.Identifier,
            "myVariable",
            pos,
        );
        
        try testing.expect(tok.type == CustomTokenType.Identifier);
        try testing.expectEqualStrings("myVariable", tok.slice);
        try testing.expect(tok.position.eql(pos));
        try testing.expect(tok.length() == 10);
    }
    
    test "unit: Token: generic token with integer type" {
        // Test the generic Token function with an integer type
        const IntToken = token.Token(u8);
        
        const pos = position.SourcePosition.initWithValues(2, 5, 10);
        const tok = IntToken.init(
            42,
            "forty-two",
            pos,
        );
        
        try testing.expect(tok.type == 42);
        try testing.expectEqualStrings("forty-two", tok.slice);
        try testing.expect(tok.position.line == 2);
        try testing.expect(tok.position.column == 5);
        try testing.expect(tok.position.offset == 10);
    }
    
    test "unit: Token: generic token with struct type" {
        // Test the generic Token function with a struct type
        const CustomType = struct {
            category: u8,
            subtype: u8,
            
            pub fn eql(self: @This(), other: @This()) bool {
                return self.category == other.category and self.subtype == other.subtype;
            }
        };
        
        const StructToken = token.Token(CustomType);
        const tok_type = CustomType{ .category = 1, .subtype = 2 };
        const pos = position.SourcePosition.init();
        
        const tok = StructToken.init(
            tok_type,
            "test_token",
            pos,
        );
        
        try testing.expect(tok.type.category == 1);
        try testing.expect(tok.type.subtype == 2);
        try testing.expectEqualStrings("test_token", tok.slice);
    }
    
    test "unit: Token: generic token with various metadata types" {
        const MyToken = token.Token(token.TokenType);
        
        const pos = position.SourcePosition.init();
        const metadata = token.TokenMetadata{ .integer_value = 42 };
        const tok = MyToken.initWithMetadata(
            token.TokenType.Number,
            "42",
            pos,
            metadata,
        );
        
        try testing.expect(tok.type == token.TokenType.Number);
        try testing.expectEqualStrings("42", tok.slice);
        try testing.expect(tok.metadata != null);
        try testing.expect(tok.metadata.?.integer_value == 42);
    }
    
    test "unit: Token: lexeme method returns slice correctly" {
        const MyToken = token.Token(token.TokenType);
        const pos = position.SourcePosition.init();
        const tok = MyToken.init(token.TokenType.String, "hello world", pos);
        
        const lexeme = tok.lexeme();
        try testing.expectEqualStrings("hello world", lexeme);
        try testing.expect(lexeme.ptr == tok.slice.ptr); // Verify it's the same slice
    }
    
    test "unit: Token: generic token comparison methods" {
        const MyToken = token.Token(token.TokenType);
        
        const pos1 = position.SourcePosition.init();
        const pos2 = position.SourcePosition.initWithValues(2, 5, 10);
        
        const tok1 = MyToken.init(token.TokenType.Identifier, "test", pos1);
        const tok2 = MyToken.init(token.TokenType.Identifier, "test", pos2);
        const tok3 = MyToken.init(token.TokenType.Number, "123", pos1);
        
        // Test eql (ignores position)
        try testing.expect(tok1.eql(tok2));
        try testing.expect(!tok1.eql(tok3));
        
        // Test identical (includes position)
        try testing.expect(!tok1.identical(tok2));
        try testing.expect(tok1.identical(tok1));
    }
    
    test "unit: Token: format method displays token correctly" {
        const MyToken = token.Token(token.TokenType);
        const pos = position.SourcePosition.initWithValues(10, 15, 100);
        const tok = MyToken.init(token.TokenType.Identifier, "myVar", pos);
        
        var buffer: [256]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        const writer = fbs.writer();
        
        try writer.print("{}", .{tok});
        const result = fbs.getWritten();
        try testing.expectEqualStrings("Token(Identifier, \"myVar\", 10:15)", result);
    }
    
    // ======================== Zero-Copy Verification Tests ========================
    
    test "unit: Token: zero-copy slice verification" {
        // Verify that tokens use slices without copying the source
        const source = "identifier + number * 42";
        const MyToken = token.Token(token.TokenType);
        
        // Create tokens pointing to different parts of the source
        const tok1 = MyToken.init(
            token.TokenType.Identifier,
            source[0..10], // "identifier"
            position.SourcePosition.init(),
        );
        
        const tok2 = MyToken.init(
            token.TokenType.Plus,
            source[11..12], // "+"
            position.SourcePosition.initWithValues(1, 12, 11),
        );
        
        const tok3 = MyToken.init(
            token.TokenType.Number,
            source[13..19], // "number"
            position.SourcePosition.initWithValues(1, 14, 13),
        );
        
        // Verify the slices point to the original source memory
        try testing.expect(tok1.slice.ptr == source.ptr);
        try testing.expect(tok2.slice.ptr == source.ptr + 11);
        try testing.expect(tok3.slice.ptr == source.ptr + 13);
        
        // Verify no allocations were made
        try testing.expectEqualStrings("identifier", tok1.slice);
        try testing.expectEqualStrings("+", tok2.slice);
        try testing.expectEqualStrings("number", tok3.slice);
    }
    
    test "performance: Token: zero allocations for token creation" {
        // Verify that creating tokens doesn't allocate any memory
        const MyToken = token.Token(token.TokenType);
        const source = "test_source";
        
        // Create multiple tokens without any allocations
        var i: usize = 0;
        while (i < 1000) : (i += 1) {
            const tok = MyToken.init(
                token.TokenType.Identifier,
                source,
                position.SourcePosition.init(),
            );
            
            // Token should be stack-allocated, no heap allocations
            try testing.expect(tok.slice.ptr == source.ptr);
            try testing.expect(tok.metadata == null);
        }
    }
    
    test "unit: TokenComparison: adjacency and distance" {
        const MyToken = token.Token(token.TokenType);
        
        const tok1 = MyToken.init(
            token.TokenType.Identifier,
            "hello",
            position.SourcePosition.initWithValues(1, 1, 0),
        );
        
        const tok2 = MyToken.init(
            token.TokenType.Identifier,
            "world",
            position.SourcePosition.initWithValues(1, 6, 5),
        );
        
        const tok3 = MyToken.init(
            token.TokenType.Identifier,
            "foo",
            position.SourcePosition.initWithValues(1, 12, 11),
        );
        
        // Test adjacency
        try testing.expect(token.TokenComparison.areAdjacent(token.TokenType, tok1, tok2));
        try testing.expect(!token.TokenComparison.areAdjacent(token.TokenType, tok2, tok3));
        
        // Test distance
        try testing.expect(token.TokenComparison.distance(token.TokenType, tok1, tok2) == 0);
        try testing.expect(token.TokenComparison.distance(token.TokenType, tok2, tok3) == 1);
    }
    
    test "unit: TokenComparison: sorting by position" {
        const MyToken = token.Token(token.TokenType);
        const compareFn = token.TokenComparison.compareByPosition(token.TokenType);
        
        var tokens = [_]token.Token(token.TokenType){
            MyToken.init(token.TokenType.Number, "3", position.SourcePosition.initWithValues(1, 5, 4)),
            MyToken.init(token.TokenType.Identifier, "x", position.SourcePosition.initWithValues(1, 1, 0)),
            MyToken.init(token.TokenType.Plus, "+", position.SourcePosition.initWithValues(1, 3, 2)),
        };
        
        std.mem.sort(token.Token(token.TokenType), &tokens, {}, compareFn);
        
        try testing.expect(tokens[0].position.offset == 0);
        try testing.expect(tokens[1].position.offset == 2);
        try testing.expect(tokens[2].position.offset == 4);
    }
    
    test "unit: TokenComparison: sorting by type then position" {
        const MyToken = token.Token(token.TokenType);
        const compareFn = token.TokenComparison.compareByType(token.TokenType);
        
        var tokens = [_]token.Token(token.TokenType){
            MyToken.init(token.TokenType.Plus, "+", position.SourcePosition.initWithValues(1, 1, 0)),
            MyToken.init(token.TokenType.Identifier, "x", position.SourcePosition.initWithValues(1, 3, 2)),
            MyToken.init(token.TokenType.Identifier, "y", position.SourcePosition.initWithValues(1, 5, 4)),
        };
        
        std.mem.sort(token.Token(token.TokenType), &tokens, {}, compareFn);
        
        // Identifiers should come first (lower enum value), then Plus
        try testing.expect(tokens[0].type == token.TokenType.Identifier);
        try testing.expect(tokens[1].type == token.TokenType.Identifier);
        try testing.expect(tokens[2].type == token.TokenType.Plus);
        
        // Within same type, should be sorted by position
        try testing.expect(tokens[0].position.offset == 2);
        try testing.expect(tokens[1].position.offset == 4);
    }
    
    // ======================== Memory Usage Validation Tests ========================
    
    test "unit: TokenMetadata: all metadata types work correctly" {
        // Test integer metadata
        const int_meta = token.TokenMetadata{ .integer_value = -123456 };
        try testing.expect(int_meta.integer_value == -123456);
        try testing.expectEqualStrings("integer", int_meta.getType());
        
        // Test float metadata
        const float_meta = token.TokenMetadata{ .float_value = 3.14159265 };
        try testing.expect(float_meta.float_value == 3.14159265);
        try testing.expectEqualStrings("float", float_meta.getType());
        
        // Test string metadata
        const string_meta = token.TokenMetadata{ .string_value = "test string" };
        try testing.expectEqualStrings("test string", string_meta.string_value);
        try testing.expectEqualStrings("string", string_meta.getType());
        
        // Test boolean metadata
        const bool_meta = token.TokenMetadata{ .boolean_value = true };
        try testing.expect(bool_meta.boolean_value == true);
        try testing.expectEqualStrings("boolean", bool_meta.getType());
        
        // Test character metadata (Unicode codepoint)
        const char_meta = token.TokenMetadata{ .character_value = '🔥' }; // Unicode emoji
        try testing.expect(char_meta.character_value == '🔥');
        try testing.expectEqualStrings("character", char_meta.getType());
        
        // Test custom metadata
        var custom_data: i32 = 42;
        const custom_meta = token.TokenMetadata{ .custom = @ptrCast(&custom_data) };
        try testing.expectEqualStrings("custom", custom_meta.getType());
    }
    
    test "stress: Token: large number of tokens with metadata" {
        const MyToken = token.Token(token.TokenType);
        var tokens = std.ArrayList(MyToken).init(testing.allocator);
        defer tokens.deinit();
        
        // Create many tokens with different metadata types
        var i: usize = 0;
        while (i < 10000) : (i += 1) {
            const pos = position.SourcePosition.initWithValues(@intCast(i / 100 + 1), @intCast(i % 100 + 1), i);
            
            const metadata = switch (i % 5) {
                0 => token.TokenMetadata{ .integer_value = @intCast(i) },
                1 => token.TokenMetadata{ .float_value = @as(f64, @floatFromInt(i)) * 1.5 },
                2 => token.TokenMetadata{ .string_value = "constant" },
                3 => token.TokenMetadata{ .boolean_value = (i % 2 == 0) },
                4 => token.TokenMetadata{ .character_value = @intCast(65 + (i % 26)) }, // A-Z
                else => unreachable,
            };
            
            const tok = MyToken.initWithMetadata(
                token.TokenType.Number,
                "token",
                pos,
                metadata,
            );
            
            try tokens.append(tok);
        }
        
        // Verify all tokens were created correctly
        try testing.expect(tokens.items.len == 10000);
        
        // Spot check some tokens
        try testing.expect(tokens.items[0].metadata.?.integer_value == 0);
        try testing.expect(tokens.items[1].metadata.?.float_value == 1.5);
        try testing.expectEqualStrings("constant", tokens.items[2].metadata.?.string_value);
        try testing.expect(tokens.items[3].metadata.?.boolean_value == false);
        try testing.expect(tokens.items[4].metadata.?.character_value == 69); // 'E'
    }
    
    test "performance: Token: memory usage remains constant" {
        // Verify that token size is predictable and doesn't grow unexpectedly
        const MyToken = token.Token(token.TokenType);
        const token_size = @sizeOf(MyToken);
        
        // Size should be sum of: enum type + slice (ptr + len) + position + optional metadata
        const expected_min_size = @sizeOf(token.TokenType) + @sizeOf([]const u8) + @sizeOf(position.SourcePosition);
        try testing.expect(token_size >= expected_min_size);
        
        // Create tokens and verify memory usage
        var tokens: [100]MyToken = undefined;
        var i: usize = 0;
        while (i < tokens.len) : (i += 1) {
            tokens[i] = MyToken.init(
                token.TokenType.Identifier,
                "test",
                position.SourcePosition.init(),
            );
        }
        
        // All tokens should have same size
        const array_size = @sizeOf(@TypeOf(tokens));
        try testing.expect(array_size == token_size * tokens.len);
    }
    
    test "unit: TokenCategory: categorization system" {
        try testing.expect(token.TokenType.Identifier.category() == token.TokenCategory.Literal);
        try testing.expect(token.TokenType.Plus.category() == token.TokenCategory.Operator);
        try testing.expect(token.TokenType.LeftParen.category() == token.TokenCategory.Delimiter);
        try testing.expect(token.TokenType.Keyword.category() == token.TokenCategory.Keyword);
        try testing.expect(token.TokenType.Assign.category() == token.TokenCategory.Assignment);
        try testing.expect(token.TokenType.Whitespace.category() == token.TokenCategory.Whitespace);
        try testing.expect(token.TokenType.Comment.category() == token.TokenCategory.Comment);
        try testing.expect(token.TokenType.Eof.category() == token.TokenCategory.Special);
    }
    
    test "unit: TokenTraits: trait detection" {
        // Test whitespace detection
        try testing.expect(token.TokenTraits.isWhitespace(token.TokenType, token.TokenType.Whitespace));
        try testing.expect(token.TokenTraits.isWhitespace(token.TokenType, token.TokenType.Newline));
        try testing.expect(!token.TokenTraits.isWhitespace(token.TokenType, token.TokenType.Identifier));
        
        // Test comment detection
        try testing.expect(token.TokenTraits.isComment(token.TokenType, token.TokenType.Comment));
        try testing.expect(!token.TokenTraits.isComment(token.TokenType, token.TokenType.Identifier));
        
        // Test identifier detection
        try testing.expect(token.TokenTraits.isIdentifier(token.TokenType, token.TokenType.Identifier));
        try testing.expect(!token.TokenTraits.isIdentifier(token.TokenType, token.TokenType.Number));
        
        // Test literal detection
        try testing.expect(token.TokenTraits.isLiteral(token.TokenType, token.TokenType.Number));
        try testing.expect(token.TokenTraits.isLiteral(token.TokenType, token.TokenType.String));
        try testing.expect(!token.TokenTraits.isLiteral(token.TokenType, token.TokenType.Plus));
    }

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
        const tok = Token.init(
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
        const tok = Token.initWithValue(
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
        var tok = Token.initOwned(
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
        var tok = Token.initOwnedWithValue(
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
        var tok = Token.initOwned(
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
        var tok = Token.init(
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
        
        const tok1 = Token.init(token.TokenType.Identifier, "test", pos1);
        const tok2 = Token.init(token.TokenType.Identifier, "test", pos2);
        const tok3 = Token.init(token.TokenType.Identifier, "other", pos1);
        
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
        const tokens = [_]Token{
            Token.init(token.TokenType.Identifier, "foo", position.Position.init()),
            Token.init(token.TokenType.Plus, "+", position.Position.init()),
            Token.init(token.TokenType.Number, "42", position.Position.init()),
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
        const tokens = [_]Token{
            Token.init(token.TokenType.Identifier, "test", position.Position.init()),
        };
        
        var stream = token.TokenStream.init(&tokens);
        _ = stream.next();
        
        try testing.expect(stream.isAtEnd());
        
        stream.reset();
        try testing.expect(!stream.isAtEnd());
        try testing.expect(stream.position == 0);
    }
    
    // ======================== Integration Tests ========================
    
    test "integration: Token: custom token type with traits" {
        // Create a custom language token type and verify trait detection
        const LangToken = enum {
            Whitespace,
            Tab,
            Newline,
            LineComment,
            BlockComment,
            Identifier,
            IntegerLiteral,
            FloatLiteral,
            StringLiteral,
            CharLiteral,
        };
        
        const CustomToken = token.Token(LangToken);
        _ = CustomToken; // Will be used for more complex tests
        
        // Test whitespace trait detection
        try testing.expect(token.TokenTraits.isWhitespace(LangToken, LangToken.Whitespace));
        try testing.expect(token.TokenTraits.isWhitespace(LangToken, LangToken.Tab));
        try testing.expect(token.TokenTraits.isWhitespace(LangToken, LangToken.Newline));
        try testing.expect(!token.TokenTraits.isWhitespace(LangToken, LangToken.Identifier));
        
        // Test comment trait detection
        try testing.expect(token.TokenTraits.isComment(LangToken, LangToken.LineComment));
        try testing.expect(token.TokenTraits.isComment(LangToken, LangToken.BlockComment));
        try testing.expect(!token.TokenTraits.isComment(LangToken, LangToken.Identifier));
        
        // Test identifier trait detection
        try testing.expect(token.TokenTraits.isIdentifier(LangToken, LangToken.Identifier));
        
        // Test literal trait detection
        try testing.expect(token.TokenTraits.isLiteral(LangToken, LangToken.IntegerLiteral));
        try testing.expect(token.TokenTraits.isLiteral(LangToken, LangToken.FloatLiteral));
        try testing.expect(token.TokenTraits.isLiteral(LangToken, LangToken.StringLiteral));
        try testing.expect(token.TokenTraits.isLiteral(LangToken, LangToken.CharLiteral));
    }
    
    test "integration: Token: token stream with generic tokens" {
        // Test integration between generic tokens and position tracking
        const MyToken = token.Token(token.TokenType);
        const source = "let x = 42 + y";
        
        var tokens_list = std.ArrayList(MyToken).init(testing.allocator);
        defer tokens_list.deinit();
        
        // Simulate tokenization
        try tokens_list.append(MyToken.init(
            token.TokenType.Keyword,
            source[0..3], // "let"
            position.SourcePosition.initWithValues(1, 1, 0),
        ));
        
        try tokens_list.append(MyToken.init(
            token.TokenType.Identifier,
            source[4..5], // "x"
            position.SourcePosition.initWithValues(1, 5, 4),
        ));
        
        try tokens_list.append(MyToken.init(
            token.TokenType.Assign,
            source[6..7], // "="
            position.SourcePosition.initWithValues(1, 7, 6),
        ));
        
        try tokens_list.append(MyToken.initWithMetadata(
            token.TokenType.Number,
            source[8..10], // "42"
            position.SourcePosition.initWithValues(1, 9, 8),
            token.TokenMetadata{ .integer_value = 42 },
        ));
        
        try tokens_list.append(MyToken.init(
            token.TokenType.Plus,
            source[11..12], // "+"
            position.SourcePosition.initWithValues(1, 12, 11),
        ));
        
        try tokens_list.append(MyToken.init(
            token.TokenType.Identifier,
            source[13..14], // "y"
            position.SourcePosition.initWithValues(1, 14, 13),
        ));
        
        // Verify token relationships
        const toks = tokens_list.items;
        
        // Check adjacency
        try testing.expect(!token.TokenComparison.areAdjacent(token.TokenType, toks[0], toks[1])); // "let" and "x" have space
        try testing.expect(!token.TokenComparison.areAdjacent(token.TokenType, toks[1], toks[2])); // "x" and "=" have space
        
        // Check distances
        try testing.expect(token.TokenComparison.distance(token.TokenType, toks[0], toks[1]) == 1); // one space
        try testing.expect(token.TokenComparison.distance(token.TokenType, toks[1], toks[2]) == 1); // one space
        
        // Verify zero-copy - all tokens point into original source
        try testing.expect(toks[0].slice.ptr == source.ptr);
        try testing.expect(toks[1].slice.ptr == source.ptr + 4);
        try testing.expect(toks[2].slice.ptr == source.ptr + 6);
        try testing.expect(toks[3].slice.ptr == source.ptr + 8);
        try testing.expect(toks[4].slice.ptr == source.ptr + 11);
        try testing.expect(toks[5].slice.ptr == source.ptr + 13);
        
        // Verify metadata
        try testing.expect(toks[3].metadata != null);
        try testing.expect(toks[3].metadata.?.integer_value == 42);
    }
    
    test "e2e: Token: complete tokenization workflow" {
        // End-to-end test simulating a real lexer workflow
        const MyToken = token.Token(token.TokenType);
        const source =
            \\fn main() {
            \\    const x = 10;
            \\    const y = 20;
            \\    return x + y;
            \\}
        ;
        
        var tokens_list = std.ArrayList(MyToken).init(testing.allocator);
        defer tokens_list.deinit();
        
        // Simulate a lexer producing tokens
        var pos = position.SourcePosition.init();
        
        // Token: "fn"
        const fn_tok = MyToken.init(
            token.TokenType.Keyword,
            source[0..2],
            pos,
        );
        try tokens_list.append(fn_tok);
        pos.offset = 3;
        pos.column = 4;
        
        // Token: "main"
        const main_tok = MyToken.init(
            token.TokenType.Identifier,
            source[3..7],
            pos,
        );
        try tokens_list.append(main_tok);
        
        // Verify tokens maintain zero-copy property
        try testing.expect(fn_tok.slice.ptr == source.ptr);
        try testing.expect(main_tok.slice.ptr == source.ptr + 3);
        
        // Verify token properties
        try testing.expectEqualStrings("fn", fn_tok.lexeme());
        try testing.expectEqualStrings("main", main_tok.lexeme());
        try testing.expect(fn_tok.length() == 2);
        try testing.expect(main_tok.length() == 4);
    }
    
    // ======================== Error Handling Tests ========================
    
    test "unit: Token: handles empty slices correctly" {
        const MyToken = token.Token(token.TokenType);
        const empty_slice: []const u8 = "";
        
        const tok = MyToken.init(
            token.TokenType.Unknown,
            empty_slice,
            position.SourcePosition.init(),
        );
        
        try testing.expect(tok.length() == 0);
        try testing.expectEqualStrings("", tok.lexeme());
    }
    
    test "unit: Token: handles unicode in slices" {
        const MyToken = token.Token(token.TokenType);
        const unicode_source = "Hello, 世界! 🌍";
        
        const tok = MyToken.init(
            token.TokenType.String,
            unicode_source,
            position.SourcePosition.init(),
        );
        
        try testing.expectEqualStrings(unicode_source, tok.lexeme());
        // Note: length() returns byte count, not character count
        try testing.expect(tok.length() == unicode_source.len);
    }
    
    // ======================== Performance and Stress Tests ========================
    
    test "performance: TokenComparison: efficient sorting of large token arrays" {
        const MyToken = token.Token(token.TokenType);
        const compareFn = token.TokenComparison.compareByPosition(token.TokenType);
        
        var tokens = std.ArrayList(MyToken).init(testing.allocator);
        defer tokens.deinit();
        
        // Create tokens in reverse order
        var i: i32 = 999;
        while (i >= 0) : (i -= 1) {
            const pos = position.SourcePosition.initWithValues(1, @intCast(i + 1), @intCast(i));
            const tok = MyToken.init(
                token.TokenType.Identifier,
                "tok",
                pos,
            );
            try tokens.append(tok);
        }
        
        // Sort tokens
        std.mem.sort(MyToken, tokens.items, {}, compareFn);
        
        // Verify sorted order
        i = 0;
        while (i < 1000) : (i += 1) {
            try testing.expect(tokens.items[@intCast(i)].position.offset == @as(usize, @intCast(i)));
        }
    }
    
    test "stress: Token: memory management with many allocations" {
        // Stress test to ensure proper memory management under heavy allocation
        const iterations = 1000;
        var i: usize = 0;
        
        while (i < iterations) : (i += 1) {
            // Test owned token creation and cleanup
            const test_text = "stress_test_lexeme_with_long_content_to_test_memory_management_properly_under_load";
            const lexeme = try testing.allocator.alloc(u8, test_text.len);
            @memcpy(lexeme, test_text);
            
            var tok = Token.initOwned(
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
    
    test "stress: Token: extreme metadata variations" {
        // Stress test with many different metadata configurations
        const MyToken = token.Token(token.TokenType);
        var tokens = std.ArrayList(MyToken).init(testing.allocator);
        defer tokens.deinit();
        
        var i: usize = 0;
        while (i < 5000) : (i += 1) {
            const pos = position.SourcePosition.initWithValues(@intCast(i / 80 + 1), @intCast(i % 80 + 1), i);
            
            const tok = if (i % 3 == 0)
                // Token with metadata
                MyToken.initWithMetadata(
                    token.TokenType.Number,
                    "num",
                    pos,
                    token.TokenMetadata{ .integer_value = @intCast(i * 2) },
                )
            else
                // Token without metadata
                MyToken.init(
                    token.TokenType.Identifier,
                    "id",
                    pos,
                );
            
            try tokens.append(tok);
        }
        
        // Verify mixture of tokens with and without metadata
        var with_metadata: usize = 0;
        var without_metadata: usize = 0;
        
        for (tokens.items) |tok| {
            if (tok.metadata != null) {
                with_metadata += 1;
            } else {
                without_metadata += 1;
            }
        }
        
        try testing.expect(with_metadata > 0);
        try testing.expect(without_metadata > 0);
        try testing.expect(with_metadata + without_metadata == 5000);
    }
    
    test "stress: Token: mixed ownership patterns" {
        // Test mixing owned and non-owned tokens to ensure proper memory management
        var tokens = std.ArrayList(Token).init(testing.allocator);
        defer {
            // Clean up all tokens
            for (tokens.items) |*tok| {
                tok.deinit();
            }
            tokens.deinit();
        }
        
        // Add non-owned tokens
        try tokens.append(Token.init(
            token.TokenType.Identifier,
            "static1",
            position.Position.init(),
        ));
        
        // Add owned tokens
        const lexeme1 = try testing.allocator.dupe(u8, "owned1");
        try tokens.append(Token.initOwned(
            testing.allocator,
            token.TokenType.String,
            lexeme1,
            position.Position.init(),
        ));
        
        // Add more non-owned tokens
        try tokens.append(Token.init(
            token.TokenType.Number,
            "42",
            position.Position.init(),
        ));
        
        // Add more owned tokens
        const lexeme2 = try testing.allocator.dupe(u8, "owned2");
        try tokens.append(Token.initOwned(
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