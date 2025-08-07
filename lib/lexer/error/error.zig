// error.zig — Error handling and reporting for lexer
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/error
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const lexer = @import("../../lexer.zig");
    const position = lexer.position;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Error types that can occur during lexing
    pub const LexerErrorType = enum {
        UnexpectedCharacter,
        UnterminatedString,
        UnterminatedComment,
        InvalidEscapeSequence,
        InvalidNumber,
        InvalidIdentifier,
        BufferOverflow,
        EncodingError,
        UnexpectedEndOfFile,
        InvalidToken,
        NestingTooDeep,
        TokenTooLong,
        
        /// Get human-readable error message
        pub fn getMessage(self: LexerErrorType) []const u8 {
            return switch (self) {
                .UnexpectedCharacter => "Unexpected character encountered",
                .UnterminatedString => "String literal is not terminated",
                .UnterminatedComment => "Comment is not terminated",
                .InvalidEscapeSequence => "Invalid escape sequence in string",
                .InvalidNumber => "Invalid number format",
                .InvalidIdentifier => "Invalid identifier format",
                .BufferOverflow => "Input buffer overflow",
                .EncodingError => "Character encoding error",
                .UnexpectedEndOfFile => "Unexpected end of file",
                .InvalidToken => "Invalid token",
                .NestingTooDeep => "Nesting level too deep",
                .TokenTooLong => "Token exceeds maximum length",
            };
        }
    };
    
    /// Severity levels for errors
    pub const ErrorSeverity = enum {
        Warning,
        Error,
        Fatal,
        
        /// Get severity as string
        pub fn toString(self: ErrorSeverity) []const u8 {
            return switch (self) {
                .Warning => "warning",
                .Error => "error",
                .Fatal => "fatal",
            };
        }
        
        /// Check if error should halt processing
        pub fn shouldHalt(self: ErrorSeverity) bool {
            return self == .Fatal;
        }
    };
    
    /// Lexer error structure
    pub const LexerError = struct {
        type: LexerErrorType,
        severity: ErrorSeverity,
        message: []const u8,
        position: position.Position,
        context: ?[]const u8,
        suggestion: ?[]const u8,
        
        /// Create a new lexer error
        pub fn init(
            error_type: LexerErrorType,
            pos: position.Position,
        ) LexerError {
            return .{
                .type = error_type,
                .severity = .Error,
                .message = error_type.getMessage(),
                .position = pos,
                .context = null,
                .suggestion = null,
            };
        }
        
        /// Create error with custom message
        pub fn initWithMessage(
            error_type: LexerErrorType,
            pos: position.Position,
            message: []const u8,
        ) LexerError {
            return .{
                .type = error_type,
                .severity = .Error,
                .message = message,
                .position = pos,
                .context = null,
                .suggestion = null,
            };
        }
        
        /// Create error with full details
        pub fn initFull(
            error_type: LexerErrorType,
            severity: ErrorSeverity,
            pos: position.Position,
            message: []const u8,
            context: ?[]const u8,
            suggestion: ?[]const u8,
        ) LexerError {
            return .{
                .type = error_type,
                .severity = severity,
                .message = message,
                .position = pos,
                .context = context,
                .suggestion = suggestion,
            };
        }
        
        /// Format error for display
        pub fn format(
            self: LexerError,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            
            try writer.print("{s}: {s} at {d}:{d}", .{
                self.severity.toString(),
                self.message,
                self.position.line,
                self.position.column,
            });
            
            if (self.context) |ctx| {
                try writer.print("\n  Context: {s}", .{ctx});
            }
            
            if (self.suggestion) |sug| {
                try writer.print("\n  Suggestion: {s}", .{sug});
            }
        }
    };
    
    /// Error collector for accumulating errors during lexing
    pub const ErrorCollector = struct {
        allocator: std.mem.Allocator,
        errors: std.ArrayList(LexerError),
        max_errors: usize,
        error_count: usize,
        warning_count: usize,
        fatal_count: usize,
        
        /// Initialize error collector
        pub fn init(allocator: std.mem.Allocator) ErrorCollector {
            return .{
                .allocator = allocator,
                .errors = std.ArrayList(LexerError).init(allocator),
                .max_errors = 100,
                .error_count = 0,
                .warning_count = 0,
                .fatal_count = 0,
            };
        }
        
        /// Clean up error collector
        pub fn deinit(self: *ErrorCollector) void {
            self.errors.deinit();
        }
        
        /// Add an error to the collector
        pub fn addError(self: *ErrorCollector, err: LexerError) !void {
            if (self.errors.items.len >= self.max_errors) {
                return error.TooManyErrors;
            }
            
            try self.errors.append(err);
            
            switch (err.severity) {
                .Warning => self.warning_count += 1,
                .Error => self.error_count += 1,
                .Fatal => self.fatal_count += 1,
            }
        }
        
        /// Check if there are any errors
        pub fn hasErrors(self: *const ErrorCollector) bool {
            return self.error_count > 0 or self.fatal_count > 0;
        }
        
        /// Check if there are any fatal errors
        pub fn hasFatalErrors(self: *const ErrorCollector) bool {
            return self.fatal_count > 0;
        }
        
        /// Get all errors
        pub fn getErrors(self: *const ErrorCollector) []const LexerError {
            return self.errors.items;
        }
        
        /// Clear all errors
        pub fn clear(self: *ErrorCollector) void {
            self.errors.clearRetainingCapacity();
            self.error_count = 0;
            self.warning_count = 0;
            self.fatal_count = 0;
        }
        
        /// Get error statistics
        pub fn getStats(self: *const ErrorCollector) ErrorStats {
            return .{
                .total = self.errors.items.len,
                .warnings = self.warning_count,
                .errors = self.error_count,
                .fatals = self.fatal_count,
            };
        }
    };
    
    /// Error statistics
    pub const ErrorStats = struct {
        total: usize,
        warnings: usize,
        errors: usize,
        fatals: usize,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝