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
    pub const Lexer = struct {
        allocator: std.mem.Allocator,
        input_buffer: buffer.Buffer,
        current_position: position.Position,
        tokens: std.ArrayList(token.Token),
        errors: std.ArrayList(@"error".LexerError),
        
        /// Initialize a new lexer instance
        pub fn init(allocator: std.mem.Allocator) !Lexer {
            return Lexer{
                .allocator = allocator,
                .input_buffer = try buffer.Buffer.init(allocator),
                .current_position = position.Position.init(),
                .tokens = std.ArrayList(token.Token).init(allocator),
                .errors = std.ArrayList(@"error".LexerError).init(allocator),
            };
        }
        
        /// Clean up lexer resources
        pub fn deinit(self: *Lexer) void {
            self.input_buffer.deinit();
            self.tokens.deinit();
            self.errors.deinit();
        }
        
        /// Set input source for lexing
        pub fn setInput(self: *Lexer, input: []const u8) !void {
            try self.input_buffer.setContent(input);
            self.current_position = position.Position.init();
        }
        
        /// Get next token from input
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
                return token.Token{
                    .type = token.TokenType.Identifier,
                    .lexeme = try self.allocator.dupe(u8, lexeme.items),
                    .position = start_pos,
                };
            }
            
            return null;
        }
        
        /// Tokenize entire input
        pub fn tokenize(self: *Lexer) ![]token.Token {
            self.tokens.clearRetainingCapacity();
            
            while (try self.nextToken()) |tok| {
                try self.tokens.append(tok);
            }
            
            return self.tokens.items;
        }
    };
    
    /// Factory function for creating lexer instances
    pub fn create(allocator: std.mem.Allocator) !*Lexer {
        const lexer = try allocator.create(Lexer);
        lexer.* = try Lexer.init(allocator);
        return lexer;
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝