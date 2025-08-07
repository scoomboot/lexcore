// lexer.zig — Module entry point for lexer subsystem
//
// repo   : https://github.com/emoessner/lexcore  
// docs   : https://emoessner.github.io/lexcore/lib/lexer
// author : https://github.com/emoessner
//
// Developed with ❤️ by emoessner.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    
    // Import submodules
    pub const core = @import("lexer/core/core.zig");
    pub const token = @import("lexer/token/token.zig");
    pub const buffer = @import("lexer/buffer/buffer.zig");
    pub const position = @import("lexer/position/position.zig");
    pub const @"error" = @import("lexer/error/error.zig");
    pub const unicode = @import("lexer/utils/unicode/unicode.zig");
    pub const perf = @import("lexer/utils/perf/perf.zig");
    
    // Main lexer implementation
    const lexer_impl = @import("lexer/lexer.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // Re-export primary types for convenience
    pub const Lexer = lexer_impl.Lexer;
    pub const Token = token.Token;
    pub const TokenType = token.TokenType;
    pub const Position = position.Position;
    pub const SourceLocation = position.SourceLocation;
    pub const LexerError = @"error".LexerError;
    pub const Buffer = buffer.Buffer;
    pub const LexerCore = core.LexerCore;
    
    // Factory function for creating lexers
    pub fn createLexer(allocator: std.mem.Allocator) !*Lexer {
        return lexer_impl.create(allocator);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: lexer: module exports are accessible" {
        const testing = std.testing;
        
        // Verify all exports are accessible
        _ = Lexer;
        _ = Token;
        _ = TokenType;
        _ = Position;
        _ = SourceLocation;
        _ = LexerError;
        _ = Buffer;
        _ = LexerCore;
        
        // Test factory function
        const lexer = try createLexer(testing.allocator);
        defer lexer.deinit();
        
        try testing.expect(lexer != undefined);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝