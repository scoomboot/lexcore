// lexer.test.zig — Test suite for core lexer implementation
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/lexer.test
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const lexer_mod = @import("lexer.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: Lexer: initialization and cleanup" {
        var lexer = try lexer_mod.Lexer.init(testing.allocator);
        defer lexer.deinit();
        
        try testing.expect(lexer.tokens.items.len == 0);
        try testing.expect(lexer.errors.items.len == 0);
    }
    
    test "unit: Lexer: set input source" {
        var lexer = try lexer_mod.Lexer.init(testing.allocator);
        defer lexer.deinit();
        
        const input = "test input";
        try lexer.setInput(input);
        
        try testing.expect(!lexer.input_buffer.isAtEnd());
    }
    
    test "unit: Lexer: tokenize simple input" {
        var lexer = try lexer_mod.Lexer.init(testing.allocator);
        defer lexer.deinit();
        
        const input = "hello world";
        try lexer.setInput(input);
        
        const tokens = try lexer.tokenize();
        try testing.expect(tokens.len > 0);
        
        // Clean up allocated token lexemes
        for (tokens) |token| {
            testing.allocator.free(token.lexeme);
        }
    }
    
    test "unit: Lexer: factory function creates valid instance" {
        const lexer = try lexer_mod.create(testing.allocator);
        defer {
            lexer.deinit();
            testing.allocator.destroy(lexer);
        }
        
        try testing.expect(lexer != undefined);
    }
    
    test "integration: Lexer: handles empty input" {
        var lexer = try lexer_mod.Lexer.init(testing.allocator);
        defer lexer.deinit();
        
        try lexer.setInput("");
        const tokens = try lexer.tokenize();
        
        try testing.expect(tokens.len == 0);
    }
    
    test "integration: Lexer: processes multiple tokens" {
        var lexer = try lexer_mod.Lexer.init(testing.allocator);
        defer lexer.deinit();
        
        const input = "one two three";
        try lexer.setInput(input);
        
        var count: usize = 0;
        while (try lexer.nextToken()) |token| {
            defer testing.allocator.free(token.lexeme);
            count += 1;
        }
        
        try testing.expect(count == 3);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝