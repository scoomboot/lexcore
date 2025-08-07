// core.zig — Generic lexer traits and interfaces
//
// repo   : https://github.com/emoessner/lexcore  
// docs   : https://emoessner.github.io/lexcore/lib/lexer/core
// author : https://github.com/emoessner
//
// Developed with ❤️ by emoessner.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const token = @import("../token/token.zig");
    const position = @import("../position/position.zig");
    const @"error" = @import("../error/error.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Core lexer interface defining common behavior for all lexer implementations
    pub const LexerCore = struct {
        /// Function pointer types for lexer operations
        pub const NextTokenFn = *const fn (self: *anyopaque) anyerror!?token.Token;
        pub const SetInputFn = *const fn (self: *anyopaque, input: []const u8) anyerror!void;
        pub const ResetFn = *const fn (self: *anyopaque) void;
        pub const GetPositionFn = *const fn (self: *const anyopaque) position.Position;
        
        /// Virtual function table for polymorphic lexer behavior
        pub const VTable = struct {
            nextToken: NextTokenFn,
            setInput: SetInputFn,
            reset: ResetFn,
            getPosition: GetPositionFn,
        };
        
        impl: *anyopaque,
        vtable: *const VTable,
        
        /// Get next token from the lexer
        pub fn nextToken(self: LexerCore) !?token.Token {
            return self.vtable.nextToken(self.impl);
        }
        
        /// Set input source
        pub fn setInput(self: LexerCore, input: []const u8) !void {
            return self.vtable.setInput(self.impl, input);
        }
        
        /// Reset lexer state
        pub fn reset(self: LexerCore) void {
            self.vtable.reset(self.impl);
        }
        
        /// Get current position in source
        pub fn getPosition(self: LexerCore) position.Position {
            return self.vtable.getPosition(self.impl);
        }
    };
    
    /// Lexer state enumeration
    pub const LexerState = enum {
        Initial,
        InProgress,
        Complete,
        Error,
    };
    
    /// Configuration options for lexer behavior
    pub const LexerConfig = struct {
        /// Skip whitespace automatically
        skip_whitespace: bool = true,
        
        /// Skip comments automatically
        skip_comments: bool = true,
        
        /// Track line numbers
        track_lines: bool = true,
        
        /// Maximum token length (0 = unlimited)
        max_token_length: usize = 0,
        
        /// Maximum nesting depth for nested constructs
        max_nesting_depth: usize = 1000,
        
        /// Buffer size for input reading
        buffer_size: usize = 4096,
        
        /// Enable Unicode support
        unicode_enabled: bool = true,
        
        /// Default configuration
        pub fn default() LexerConfig {
            return .{};
        }
    };
    
    /// Lexer capabilities flags
    pub const LexerCapabilities = packed struct {
        supports_unicode: bool = false,
        supports_lookahead: bool = false,
        supports_backtracking: bool = false,
        supports_incremental: bool = false,
        supports_error_recovery: bool = false,
        supports_context_sensitive: bool = false,
        _padding: u2 = 0,
    };
    
    /// Lexer statistics for performance monitoring
    pub const LexerStats = struct {
        tokens_produced: usize = 0,
        bytes_processed: usize = 0,
        errors_encountered: usize = 0,
        lines_processed: usize = 0,
        peak_memory_usage: usize = 0,
        lexing_time_ns: u64 = 0,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝