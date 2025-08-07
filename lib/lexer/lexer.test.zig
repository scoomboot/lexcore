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
        
        // Tokens are owned by the lexer and will be freed in deinit
        // No manual cleanup needed here
    }
    
    test "unit: Lexer: factory function creates valid instance" {
        const lexer = try lexer_mod.create(testing.allocator);
        defer lexer_mod.destroy(lexer);
        
        // Verify the lexer was created successfully
        try testing.expect(@intFromPtr(lexer) != 0);
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
        while (try lexer.nextToken()) |tok| {
            // Must manually clean up tokens from nextToken since they're not
            // stored in the lexer's internal list
            var token = tok;
            defer token.deinit();
            count += 1;
        }
        
        try testing.expect(count == 3);
    }
    
    test "stress: Lexer: memory leak validation" {
        // Test that multiple tokenize operations don't leak memory
        var lexer = try lexer_mod.Lexer.init(testing.allocator);
        defer lexer.deinit();
        
        const input = "token1 token2 token3 token4 token5";
        
        // Tokenize multiple times to ensure proper cleanup
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            try lexer.setInput(input);
            _ = try lexer.tokenize();
        }
        
        // All tokens should be properly cleaned up by deinit
    }
    
    test "stress: Lexer: factory cleanup validation" {
        // Test factory create/destroy pattern for memory leaks
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            const lexer = try lexer_mod.create(testing.allocator);
            
            // Do some work with the lexer
            try lexer.setInput("test input");
            _ = try lexer.tokenize();
            
            // Properly destroy the lexer
            lexer_mod.destroy(lexer);
        }
        
        // All memory should be freed
    }
    
    test "stress: Lexer: error path memory management" {
        // Test that memory is properly cleaned up even in error conditions
        var lexer = try lexer_mod.Lexer.init(testing.allocator);
        defer lexer.deinit();
        
        // Set input with various content
        try lexer.setInput("token1 token2 error_token token3");
        
        // Tokenize and ensure proper cleanup even if errors occur
        _ = try lexer.tokenize();
        
        // Reset and try again
        lexer.reset();
        try lexer.setInput("another test with multiple tokens");
        _ = try lexer.tokenize();
        
        // All tokens should be properly managed
    }
    
    test "stress: Lexer: large input memory management" {
        // Test memory management with large inputs
        var lexer = try lexer_mod.Lexer.init(testing.allocator);
        defer lexer.deinit();
        
        // Create a large input string
        var large_input = std.ArrayList(u8).init(testing.allocator);
        defer large_input.deinit();
        
        // Generate 10KB of text
        var j: usize = 0;
        while (j < 1000) : (j += 1) {
            try large_input.appendSlice("token_");
            try large_input.append(@intCast('0' + (j % 10)));
            try large_input.append(' ');
        }
        
        try lexer.setInput(large_input.items);
        _ = try lexer.tokenize();
        
        // Verify memory is properly managed
    }
    
    test "integration: Lexer: mixed token ownership patterns" {
        // Test that lexer properly handles tokens with different ownership patterns
        var lexer = try lexer_mod.Lexer.init(testing.allocator);
        defer lexer.deinit();
        
        // First batch with one pattern
        try lexer.setInput("simple tokens here");
        _ = try lexer.tokenize();
        
        // Second batch with different pattern
        lexer.reset();
        try lexer.setInput("more complex \"string literal\" tokens");
        _ = try lexer.tokenize();
        
        // Third batch
        lexer.reset();
        try lexer.setInput("final batch 123 456.789");
        _ = try lexer.tokenize();
        
        // All memory should be properly managed through deinit
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝