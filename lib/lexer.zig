// lexer.zig — Module entry point for lexer subsystem
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

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
    
    /// Factory function for creating lexers.
    ///
    /// Memory ownership: Creates a new Lexer on the heap.
    /// The caller must call destroyLexer() to properly clean up.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator for the lexer instance
    ///
    /// __Return__
    ///
    /// - Pointer to new Lexer instance or error if allocation fails
    pub fn createLexer(allocator: std.mem.Allocator) !*Lexer {
        return lexer_impl.create(allocator);
    }
    
    /// Cleanup function for factory-created lexers.
    ///
    /// Memory ownership: Properly cleans up a lexer created with createLexer().
    /// This function calls deinit() on the lexer's internal resources
    /// and then frees the lexer instance itself.
    ///
    /// __Parameters__
    ///
    /// - `lexer`: Pointer to lexer instance to destroy
    ///
    /// __Return__
    ///
    /// - None
    pub fn destroyLexer(lexer: *Lexer) void {
        lexer_impl.destroy(lexer);
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
        
        // Test factory function with proper cleanup
        const lexer = try createLexer(testing.allocator);
        defer destroyLexer(lexer);
        
        // Verify the lexer was created successfully
        try testing.expect(@intFromPtr(lexer) != 0);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝