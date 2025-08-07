// token.zig — Token definitions and types
//
// repo   : https://github.com/emoessner/lexcore  
// docs   : https://emoessner.github.io/lexcore/lib/lexer/token
// author : https://github.com/emoessner
//
// Developed with ❤️ by emoessner.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const position = @import("../position/position.zig");

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
    pub const Token = struct {
        type: TokenType,
        lexeme: []const u8,
        position: position.Position,
        
        /// Optional value for literals
        value: ?TokenValue = null,
        
        /// Create a new token
        pub fn init(
            token_type: TokenType,
            lexeme: []const u8,
            pos: position.Position,
        ) Token {
            return .{
                .type = token_type,
                .lexeme = lexeme,
                .position = pos,
            };
        }
        
        /// Create a token with a value
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
            };
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