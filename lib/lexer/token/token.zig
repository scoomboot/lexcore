// token.zig — Token definitions and types
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/token
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const lexer = @import("../../lexer.zig");
    const position = lexer.position;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Token types enumeration
    pub const TokenType = enum {
        // Literals
        Identifier,
        Number,
        String,
        Character,
        
        // Keywords
        Keyword,
        
        // Operators
        Plus,
        Minus,
        Star,
        Slash,
        Percent,
        Equal,
        NotEqual,
        Less,
        Greater,
        LessEqual,
        GreaterEqual,
        
        // Logical
        And,
        Or,
        Not,
        
        // Bitwise
        BitwiseAnd,
        BitwiseOr,
        BitwiseXor,
        BitwiseNot,
        LeftShift,
        RightShift,
        
        // Assignment
        Assign,
        PlusAssign,
        MinusAssign,
        StarAssign,
        SlashAssign,
        
        // Delimiters
        LeftParen,
        RightParen,
        LeftBrace,
        RightBrace,
        LeftBracket,
        RightBracket,
        
        // Punctuation
        Semicolon,
        Colon,
        Comma,
        Dot,
        Arrow,
        DoubleColon,
        
        // Special
        Eof,
        Unknown,
        Whitespace,
        Newline,
        Comment,
        
        /// Get string representation of token type
        pub fn toString(self: TokenType) []const u8 {
            return @tagName(self);
        }
        
        /// Check if token type is a literal
        pub fn isLiteral(self: TokenType) bool {
            return switch (self) {
                .Identifier, .Number, .String, .Character => true,
                else => false,
            };
        }
        
        /// Check if token type is an operator
        pub fn isOperator(self: TokenType) bool {
            return switch (self) {
                .Plus, .Minus, .Star, .Slash, .Percent,
                .Equal, .NotEqual, .Less, .Greater,
                .LessEqual, .GreaterEqual => true,
                else => false,
            };
        }
        
        /// Check if token type is a delimiter
        pub fn isDelimiter(self: TokenType) bool {
            return switch (self) {
                .LeftParen, .RightParen, .LeftBrace, .RightBrace,
                .LeftBracket, .RightBracket => true,
                else => false,
            };
        }
    };
    
    /// Token structure representing a lexical unit
    /// 
    /// Memory ownership: Token owns its lexeme if it was dynamically allocated.
    /// The token is responsible for freeing the lexeme memory through deinit().
    pub const Token = struct {
        type: TokenType,
        lexeme: []const u8,
        position: position.Position,
        
        /// Optional value for literals
        value: ?TokenValue = null,
        
        /// Whether the lexeme was allocated and needs to be freed
        owns_lexeme: bool = false,
        
        /// Allocator used for lexeme (if owned)
        allocator: ?std.mem.Allocator = null,
        
        /// Create a new token
        /// 
        /// Memory ownership: The caller retains ownership of the lexeme.
        /// The token will not free this memory on deinit.
        pub fn init(
            token_type: TokenType,
            lexeme: []const u8,
            pos: position.Position,
        ) Token {
            return .{
                .type = token_type,
                .lexeme = lexeme,
                .position = pos,
                .owns_lexeme = false,
            };
        }
        
        /// Create a new token with owned lexeme
        /// 
        /// Memory ownership: The token takes ownership of the lexeme.
        /// The lexeme will be freed when deinit() is called.
        pub fn initOwned(
            allocator: std.mem.Allocator,
            token_type: TokenType,
            lexeme: []const u8,
            pos: position.Position,
        ) Token {
            return .{
                .type = token_type,
                .lexeme = lexeme,
                .position = pos,
                .owns_lexeme = true,
                .allocator = allocator,
            };
        }
        
        /// Create a token with a value
        /// 
        /// Memory ownership: The caller retains ownership of the lexeme.
        /// The token will not free this memory on deinit.
        pub fn initWithValue(
            token_type: TokenType,
            lexeme: []const u8,
            pos: position.Position,
            value: TokenValue,
        ) Token {
            return .{
                .type = token_type,
                .lexeme = lexeme,
                .position = pos,
                .value = value,
                .owns_lexeme = false,
            };
        }
        
        /// Create a token with owned lexeme and value
        /// 
        /// Memory ownership: The token takes ownership of the lexeme.
        /// The lexeme will be freed when deinit() is called.
        pub fn initOwnedWithValue(
            allocator: std.mem.Allocator,
            token_type: TokenType,
            lexeme: []const u8,
            pos: position.Position,
            value: TokenValue,
        ) Token {
            return .{
                .type = token_type,
                .lexeme = lexeme,
                .position = pos,
                .value = value,
                .owns_lexeme = true,
                .allocator = allocator,
            };
        }
        
        /// Clean up token resources
        /// 
        /// Memory ownership: Frees the lexeme if it was allocated and owned by this token.
        /// After calling deinit, the token should not be used.
        pub fn deinit(self: *Token) void {
            if (self.owns_lexeme and self.allocator != null) {
                self.allocator.?.free(self.lexeme);
                self.owns_lexeme = false;
                self.allocator = null;
            }
        }
        
        /// Check if tokens are equal (excluding position)
        pub fn eql(self: Token, other: Token) bool {
            return self.type == other.type and
                   std.mem.eql(u8, self.lexeme, other.lexeme);
        }
        
        /// Format token for display
        pub fn format(
            self: Token,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try writer.print("Token({s}, \"{s}\", {d}:{d})", .{
                self.type.toString(),
                self.lexeme,
                self.position.line,
                self.position.column,
            });
        }
    };
    
    /// Token value for literals
    pub const TokenValue = union(enum) {
        integer: i64,
        float: f64,
        string: []const u8,
        boolean: bool,
        character: u8,
        
        /// Get the type of the value
        pub fn getType(self: TokenValue) []const u8 {
            return switch (self) {
                .integer => "integer",
                .float => "float",
                .string => "string",
                .boolean => "boolean",
                .character => "character",
            };
        }
    };
    
    /// Token stream for managing sequences of tokens
    pub const TokenStream = struct {
        tokens: []const Token,
        position: usize,
        
        /// Initialize a new token stream
        pub fn init(tokens: []const Token) TokenStream {
            return .{
                .tokens = tokens,
                .position = 0,
            };
        }
        
        /// Get current token without advancing
        pub fn peek(self: *const TokenStream) ?Token {
            if (self.position >= self.tokens.len) return null;
            return self.tokens[self.position];
        }
        
        /// Get current token and advance position
        pub fn next(self: *TokenStream) ?Token {
            const token = self.peek();
            if (token != null) self.position += 1;
            return token;
        }
        
        /// Check if at end of stream
        pub fn isAtEnd(self: *const TokenStream) bool {
            return self.position >= self.tokens.len;
        }
        
        /// Reset stream to beginning
        pub fn reset(self: *TokenStream) void {
            self.position = 0;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝