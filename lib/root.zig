// root.zig — Public API surface for lexcore library
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    pub const lexer = @import("lexer.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // Re-export lexer module components for public API
    pub const Lexer = lexer.Lexer;
    pub const Token = lexer.Token;
    pub const TokenType = lexer.TokenType;
    pub const Position = lexer.Position;
    pub const LexerError = lexer.LexerError;
    pub const Buffer = lexer.Buffer;

    // Version information
    pub const version = std.SemanticVersion{
        .major = 0,
        .minor = 1,
        .patch = 0,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: root: exports lexer module" {
        const testing = std.testing;
        
        // Verify that types are accessible
        _ = Lexer;
        _ = Token;
        _ = TokenType;
        _ = Position;
        _ = LexerError;
        _ = Buffer;
        
        try testing.expect(version.major == 0);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝