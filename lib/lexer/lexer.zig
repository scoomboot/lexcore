// lexer.zig — Core lexer implementation
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/lexer
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const core = @import("core/core.zig");
    const token = @import("token/token.zig");
    const buffer = @import("buffer/buffer.zig");
    const position = @import("position/position.zig");
    const @"error" = @import("error/error.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Main lexer structure implementing the core lexer interface
    /// 
    /// Memory ownership: The lexer owns all tokens in its token list and is
    /// responsible for cleaning them up on deinit.
    pub const Lexer = struct {
        allocator: std.mem.Allocator,
        input_buffer: buffer.Buffer,
        current_position: position.Position,
        tokens: std.ArrayList(token.Token),
        errors: std.ArrayList(@"error".LexerError),
        
        /// Initialize a new lexer instance.
        /// 
        /// Memory ownership: The lexer takes ownership of its internal structures.
        /// Call deinit() to clean up all resources.
        pub fn init(allocator: std.mem.Allocator) !Lexer {
            return Lexer{
                .allocator = allocator,
                .input_buffer = try buffer.Buffer.init(allocator),
                .current_position = position.Position.init(),
                .tokens = std.ArrayList(token.Token).init(allocator),
                .errors = std.ArrayList(@"error".LexerError).init(allocator),
            };
        }
        
        /// Clean up lexer resources.
        ///
        /// Memory ownership: Frees all token lexemes that were allocated,
        /// then cleans up all internal structures.
        ///
        /// __Parameters__
        ///
        /// - `self`: Lexer instance to clean up
        ///
        /// __Return__
        ///
        /// - None
        pub fn deinit(self: *Lexer) void {
            // Free all token lexemes before clearing the list
            for (self.tokens.items) |*tok| {
                tok.deinit();
            }
            self.input_buffer.deinit();
            self.tokens.deinit();
            self.errors.deinit();
        }
        
        /// Set input source for lexing.
        ///
        /// Memory ownership: The lexer does not take ownership of the input slice.
        /// The input must remain valid for the lifetime of lexing operations.
        ///
        /// __Parameters__
        ///
        /// - `self`: Lexer instance
        /// - `input`: Source text to tokenize
        ///
        /// __Return__
        ///
        /// - None or error if buffer operations fail
        pub fn setInput(self: *Lexer, input: []const u8) !void {
            try self.input_buffer.setContent(input);
            self.current_position = position.Position.init();
        }
        
        /// Get next token from input.
        ///
        /// Memory ownership: The returned token owns its lexeme and must be
        /// cleaned up by calling deinit() when no longer needed.
        ///
        /// __Parameters__
        ///
        /// - `self`: Lexer instance
        ///
        /// __Return__
        ///
        /// - Next Token or null if end of input, error if processing fails
        pub fn nextToken(self: *Lexer) !?token.Token {
            // Placeholder implementation
            if (self.input_buffer.isAtEnd()) {
                return null;
            }
            
            const start_pos = self.current_position;
            
            // Simple placeholder: create identifier token
            var lexeme = std.ArrayList(u8).init(self.allocator);
            defer lexeme.deinit();
            
            while (!self.input_buffer.isAtEnd()) {
                const c = try self.input_buffer.next();
                if (c == ' ' or c == '\n' or c == '\t') break;
                try lexeme.append(c);
                self.current_position.advance(c);
            }
            
            if (lexeme.items.len > 0) {
                // Create token with owned lexeme
                const duped_lexeme = try self.allocator.dupe(u8, lexeme.items);
                return token.Token.initOwned(
                    self.allocator,
                    token.TokenType.Identifier,
                    duped_lexeme,
                    start_pos,
                );
            }
            
            return null;
        }
        
        /// Reset the lexer to initial state.
        ///
        /// Clears all tokens and errors, resets position tracking.
        /// The input buffer remains unchanged.
        ///
        /// __Parameters__
        ///
        /// - `self`: Lexer instance to reset
        ///
        /// __Return__
        ///
        /// - None
        pub fn reset(self: *Lexer) void {
            // Clear tokens, freeing lexemes
            for (self.tokens.items) |*tok| {
                tok.deinit(self.allocator);
            }
            self.tokens.clearRetainingCapacity();
            
            // Clear errors and reset position
            self.errors.clearRetainingCapacity();
            self.current_position = position.Position.init();
        }
        
        /// Tokenize entire input.
        ///
        /// Memory ownership: The lexer retains ownership of all tokens.
        /// The tokens will be freed when the lexer is deinitialized.
        /// Callers should not free the returned tokens.
        ///
        /// __Parameters__
        ///
        /// - `self`: Lexer instance
        ///
        /// __Return__
        ///
        /// - Slice of all tokens or error if tokenization fails
        pub fn tokenize(self: *Lexer) ![]token.Token {
            // Clear existing tokens, freeing their lexemes
            for (self.tokens.items) |*tok| {
                tok.deinit();
            }
            self.tokens.clearRetainingCapacity();
            
            while (try self.nextToken()) |tok| {
                try self.tokens.append(tok);
            }
            
            return self.tokens.items;
        }
    };
    
    /// Factory function for creating lexer instances.
    ///
    /// Memory ownership: Allocates a new Lexer on the heap.
    /// The caller must call destroy() to clean up both the lexer
    /// and its internal resources.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator for the lexer instance
    ///
    /// __Return__
    ///
    /// - Pointer to new Lexer instance or error if allocation fails
    pub fn create(allocator: std.mem.Allocator) !*Lexer {
        const lexer = try allocator.create(Lexer);
        lexer.* = try Lexer.init(allocator);
        return lexer;
    }
    
    /// Destroy a factory-created lexer.
    ///
    /// Memory ownership: Cleans up all internal resources via deinit(),
    /// then frees the lexer instance itself. After calling this function,
    /// the lexer pointer is invalid and must not be used.
    ///
    /// __Parameters__
    ///
    /// - `lexer`: Pointer to lexer instance to destroy
    ///
    /// __Return__
    ///
    /// - None
    pub fn destroy(lexer: *Lexer) void {
        const allocator = lexer.allocator;
        lexer.deinit();
        allocator.destroy(lexer);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝