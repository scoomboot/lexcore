// token.zig — Token definitions and types
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/token
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const position = @import("../position/position.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Generic token structure generator
    /// 
    /// Creates a token type with the specified token type enum.
    /// This allows for customizable token types per lexer implementation
    /// while maintaining a consistent interface.
    /// 
    /// Memory ownership: Tokens use zero-copy design with slices into the source.
    /// The source buffer must outlive all tokens referencing it.
    /// 
    /// Example:
    /// ```zig
    /// const MyTokenType = enum { Identifier, Number, Operator };
    /// const MyToken = Token(MyTokenType);
    /// ```
    pub fn Token(comptime T: type) type {
        return struct {
            type: T,
            slice: []const u8,              // Zero-copy slice into source
            position: position.SourcePosition,
            
            /// Optional metadata for the token
            metadata: ?TokenMetadata = null,
            
            /// Create a new token
            /// 
            /// Memory ownership: The token does not own the slice memory.
            /// The slice must remain valid for the token's lifetime.
            pub fn init(
                token_type: T,
                source_slice: []const u8,
                pos: position.SourcePosition,
            ) @This() {
                return .{
                    .type = token_type,
                    .slice = source_slice,
                    .position = pos,
                };
            }
            
            /// Create a token with metadata
            pub fn initWithMetadata(
                token_type: T,
                source_slice: []const u8,
                pos: position.SourcePosition,
                metadata: TokenMetadata,
            ) @This() {
                return .{
                    .type = token_type,
                    .slice = source_slice,
                    .position = pos,
                    .metadata = metadata,
                };
            }
            
            /// Get the lexeme/text of the token
            pub fn lexeme(self: @This()) []const u8 {
                return self.slice;
            }
            
            /// Get the length of the token in bytes
            pub fn length(self: @This()) usize {
                return self.slice.len;
            }
            
            /// Check if tokens are equal (type and slice content)
            pub fn eql(self: @This(), other: @This()) bool {
                return self.type == other.type and
                       std.mem.eql(u8, self.slice, other.slice);
            }
            
            /// Check if tokens are identical (including position)
            pub fn identical(self: @This(), other: @This()) bool {
                return self.type == other.type and
                       std.mem.eql(u8, self.slice, other.slice) and
                       self.position.eql(other.position);
            }
            
            /// Format token for display
            pub fn format(
                self: @This(),
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                _ = fmt;
                _ = options;
                
                // Use @tagName if T is an enum, otherwise use @typeName
                const type_name = if (@typeInfo(T) == .@"enum") 
                    @tagName(self.type) 
                else 
                    @typeName(T);
                    
                try writer.print("Token({s}, \"{s}\", {d}:{d})", .{
                    type_name,
                    self.slice,
                    self.position.line,
                    self.position.column,
                });
            }
        };
    }
    
    /// Token metadata for additional information
    pub const TokenMetadata = union(enum) {
        integer_value: i64,
        float_value: f64,
        string_value: []const u8,
        boolean_value: bool,
        character_value: u21,  // Unicode codepoint
        custom: *anyopaque,     // For custom metadata types
        
        /// Get the type of the metadata
        pub fn getType(self: TokenMetadata) []const u8 {
            return switch (self) {
                .integer_value => "integer",
                .float_value => "float",
                .string_value => "string",
                .boolean_value => "boolean",
                .character_value => "character",
                .custom => "custom",
            };
        }
    };
    
    /// Token comparison utilities
    pub const TokenComparison = struct {
        /// Compare two tokens by position
        pub fn compareByPosition(
            comptime T: type,
        ) fn (context: void, a: Token(T), b: Token(T)) bool {
            return struct {
                fn cmp(_: void, a: Token(T), b: Token(T)) bool {
                    return a.position.isBefore(b.position);
                }
            }.cmp;
        }
        
        /// Compare two tokens by type, then position
        pub fn compareByType(
            comptime T: type,
        ) fn (context: void, a: Token(T), b: Token(T)) bool {
            return struct {
                fn cmp(_: void, a: Token(T), b: Token(T)) bool {
                    if (a.type != b.type) {
                        return @intFromEnum(a.type) < @intFromEnum(b.type);
                    }
                    return a.position.isBefore(b.position);
                }
            }.cmp;
        }
        
        /// Check if tokens are adjacent in source
        pub fn areAdjacent(comptime T: type, a: Token(T), b: Token(T)) bool {
            const a_end = a.position.offset + a.slice.len;
            return a_end == b.position.offset;
        }
        
        /// Calculate distance between tokens in bytes
        pub fn distance(comptime T: type, a: Token(T), b: Token(T)) usize {
            const a_end = a.position.offset + a.slice.len;
            if (b.position.offset > a_end) {
                return b.position.offset - a_end;
            }
            return 0;
        }
    };
    
    /// Token traits for categorization
    pub const TokenTraits = struct {
        /// Check if a token type represents whitespace
        pub fn isWhitespace(comptime T: type, token_type: T) bool {
            if (@typeInfo(T) != .@"enum") return false;
            
            // Check for common whitespace token names
            const name = @tagName(token_type);
            return std.mem.eql(u8, name, "Whitespace") or
                   std.mem.eql(u8, name, "Newline") or
                   std.mem.eql(u8, name, "Tab") or
                   std.mem.eql(u8, name, "Space");
        }
        
        /// Check if a token type represents a comment
        pub fn isComment(comptime T: type, token_type: T) bool {
            if (@typeInfo(T) != .@"enum") return false;
            
            const name = @tagName(token_type);
            return std.mem.indexOf(u8, name, "Comment") != null;
        }
        
        /// Check if a token type represents an identifier
        pub fn isIdentifier(comptime T: type, token_type: T) bool {
            if (@typeInfo(T) != .@"enum") return false;
            
            const name = @tagName(token_type);
            return std.mem.eql(u8, name, "Identifier") or
                   std.mem.eql(u8, name, "Ident") or
                   std.mem.eql(u8, name, "Name");
        }
        
        /// Check if a token type represents a literal
        pub fn isLiteral(comptime T: type, token_type: T) bool {
            if (@typeInfo(T) != .@"enum") return false;
            
            const name = @tagName(token_type);
            return std.mem.indexOf(u8, name, "Number") != null or
                   std.mem.indexOf(u8, name, "String") != null or
                   std.mem.indexOf(u8, name, "Char") != null or
                   std.mem.indexOf(u8, name, "Float") != null or
                   std.mem.indexOf(u8, name, "Int") != null or
                   std.mem.indexOf(u8, name, "Literal") != null;
        }
    };

    /// Default token types enumeration (example/reference implementation)
    /// 
    /// This serves as both a default token type set and an example
    /// of how to define custom token types for specific languages.
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
        
        /// Check if token type is whitespace
        pub fn isWhitespace(self: TokenType) bool {
            return switch (self) {
                .Whitespace, .Newline => true,
                else => false,
            };
        }
        
        /// Check if token type is an assignment operator
        pub fn isAssignment(self: TokenType) bool {
            return switch (self) {
                .Assign, .PlusAssign, .MinusAssign,
                .StarAssign, .SlashAssign => true,
                else => false,
            };
        }
        
        /// Get the category of the token type
        pub fn category(self: TokenType) TokenCategory {
            if (self.isLiteral()) return .Literal;
            if (self.isOperator()) return .Operator;
            if (self.isDelimiter()) return .Delimiter;
            if (self.isAssignment()) return .Assignment;
            if (self.isWhitespace()) return .Whitespace;
            
            return switch (self) {
                .Keyword => .Keyword,
                .Comment => .Comment,
                .Eof => .Special,
                .Unknown => .Special,
                else => .Other,
            };
        }
    };
    
    /// Token categories for grouping related token types
    pub const TokenCategory = enum {
        Literal,
        Operator,
        Delimiter,
        Keyword,
        Assignment,
        Whitespace,
        Comment,
        Special,
        Other,
        
        /// Get string representation of category
        pub fn toString(self: TokenCategory) []const u8 {
            return @tagName(self);
        }
    };
    
    /// Default token implementation using the standard TokenType
    /// 
    /// This provides backward compatibility and serves as a reference implementation.
    /// For custom token types, use Token(YourTokenType) instead.
    pub const DefaultToken = Token(TokenType);
    
    
    /// Token struct for backward compatibility
    /// 
    /// This struct maintains the old API for gradual migration.
    /// New code should use Token(TokenType) for the generic implementation.
    pub const LegacyToken = struct {
        type: TokenType,
        lexeme: []const u8,
        position: position.SourcePosition,
        
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
            pos: position.SourcePosition,
        ) LegacyToken {
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
            pos: position.SourcePosition,
        ) LegacyToken {
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
            pos: position.SourcePosition,
            value: TokenValue,
        ) LegacyToken {
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
            pos: position.SourcePosition,
            value: TokenValue,
        ) LegacyToken {
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
        pub fn deinit(self: *LegacyToken) void {
            if (self.owns_lexeme and self.allocator != null) {
                self.allocator.?.free(self.lexeme);
                self.owns_lexeme = false;
                self.allocator = null;
            }
        }
        
        /// Check if tokens are equal (excluding position)
        pub fn eql(self: LegacyToken, other: LegacyToken) bool {
            return self.type == other.type and
                   std.mem.eql(u8, self.lexeme, other.lexeme);
        }
        
        /// Format token for display
        pub fn format(
            self: LegacyToken,
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
    
    /// Token value for literals (legacy, use TokenMetadata for new code)
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
        tokens: []const LegacyToken,
        position: usize,
        
        /// Initialize a new token stream
        pub fn init(tokens: []const LegacyToken) TokenStream {
            return .{
                .tokens = tokens,
                .position = 0,
            };
        }
        
        /// Get current token without advancing
        pub fn peek(self: *const TokenStream) ?LegacyToken {
            if (self.position >= self.tokens.len) return null;
            return self.tokens[self.position];
        }
        
        /// Get current token and advance position
        pub fn next(self: *TokenStream) ?LegacyToken {
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

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // Import test files
    test {
        _ = @import("token.test.zig");
        _ = @import("zero_copy_test.zig");
        _ = @import("memory_test.zig");
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝