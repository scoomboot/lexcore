// error.test.zig — Test suite for error handling
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/error/test
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const err_mod = @import("error.zig");
    const lexer = @import("../../lexer.zig");
    const position = lexer.position;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: LexerErrorType: getMessage returns appropriate messages" {
        const err_type = err_mod.LexerErrorType.UnexpectedCharacter;
        try testing.expectEqualStrings("Unexpected character encountered", err_type.getMessage());
        
        const err_type2 = err_mod.LexerErrorType.UnterminatedString;
        try testing.expectEqualStrings("String literal is not terminated", err_type2.getMessage());
    }
    
    test "unit: ErrorSeverity: toString and shouldHalt" {
        const warning = err_mod.ErrorSeverity.Warning;
        try testing.expectEqualStrings("warning", warning.toString());
        try testing.expect(!warning.shouldHalt());
        
        const fatal = err_mod.ErrorSeverity.Fatal;
        try testing.expectEqualStrings("fatal", fatal.toString());
        try testing.expect(fatal.shouldHalt());
    }
    
    test "unit: LexerError: basic initialization" {
        const pos = position.Position.init();
        const err = err_mod.LexerError.init(
            err_mod.LexerErrorType.InvalidNumber,
            pos,
        );
        
        try testing.expect(err.type == err_mod.LexerErrorType.InvalidNumber);
        try testing.expect(err.severity == err_mod.ErrorSeverity.Error);
        try testing.expectEqualStrings("Invalid number format", err.message);
        try testing.expect(err.context == null);
        try testing.expect(err.suggestion == null);
    }
    
    test "unit: LexerError: initialization with custom message" {
        const pos = position.Position{ .line = 5, .column = 10, .offset = 50 };
        const err = err_mod.LexerError.initWithMessage(
            err_mod.LexerErrorType.InvalidToken,
            pos,
            "Custom error message",
        );
        
        try testing.expectEqualStrings("Custom error message", err.message);
        try testing.expect(err.position.line == 5);
        try testing.expect(err.position.column == 10);
    }
    
    test "unit: LexerError: full initialization" {
        const pos = position.Position.init();
        const err = err_mod.LexerError.initFull(
            err_mod.LexerErrorType.InvalidEscapeSequence,
            err_mod.ErrorSeverity.Warning,
            pos,
            "Invalid escape \\q",
            "\\q is not a valid escape",
            "Use \\n for newline",
        );
        
        try testing.expect(err.severity == err_mod.ErrorSeverity.Warning);
        try testing.expectEqualStrings("Invalid escape \\q", err.message);
        try testing.expect(err.context != null);
        try testing.expect(err.suggestion != null);
    }
    
    test "unit: ErrorCollector: initialization and cleanup" {
        var collector = err_mod.ErrorCollector.init(testing.allocator);
        defer collector.deinit();
        
        try testing.expect(collector.error_count == 0);
        try testing.expect(collector.warning_count == 0);
        try testing.expect(collector.fatal_count == 0);
        try testing.expect(!collector.hasErrors());
    }
    
    test "unit: ErrorCollector: adding errors" {
        var collector = err_mod.ErrorCollector.init(testing.allocator);
        defer collector.deinit();
        
        const pos = position.Position.init();
        
        const warning = err_mod.LexerError.initFull(
            err_mod.LexerErrorType.InvalidIdentifier,
            err_mod.ErrorSeverity.Warning,
            pos,
            "Warning message",
            null,
            null,
        );
        try collector.addError(warning);
        
        const err = err_mod.LexerError.init(
            err_mod.LexerErrorType.UnexpectedCharacter,
            pos,
        );
        try collector.addError(err);
        
        try testing.expect(collector.warning_count == 1);
        try testing.expect(collector.error_count == 1);
        try testing.expect(collector.hasErrors());
        try testing.expect(!collector.hasFatalErrors());
    }
    
    test "unit: ErrorCollector: fatal error handling" {
        var collector = err_mod.ErrorCollector.init(testing.allocator);
        defer collector.deinit();
        
        const pos = position.Position.init();
        const fatal = err_mod.LexerError.initFull(
            err_mod.LexerErrorType.BufferOverflow,
            err_mod.ErrorSeverity.Fatal,
            pos,
            "Fatal buffer overflow",
            null,
            null,
        );
        
        try collector.addError(fatal);
        
        try testing.expect(collector.fatal_count == 1);
        try testing.expect(collector.hasFatalErrors());
        try testing.expect(collector.hasErrors());
    }
    
    test "unit: ErrorCollector: get errors and stats" {
        var collector = err_mod.ErrorCollector.init(testing.allocator);
        defer collector.deinit();
        
        const pos = position.Position.init();
        
        // Add various errors
        for (0..3) |_| {
            const err = err_mod.LexerError.init(
                err_mod.LexerErrorType.InvalidToken,
                pos,
            );
            try collector.addError(err);
        }
        
        const errors = collector.getErrors();
        try testing.expect(errors.len == 3);
        
        const stats = collector.getStats();
        try testing.expect(stats.total == 3);
        try testing.expect(stats.errors == 3);
        try testing.expect(stats.warnings == 0);
        try testing.expect(stats.fatals == 0);
    }
    
    test "unit: ErrorCollector: clear errors" {
        var collector = err_mod.ErrorCollector.init(testing.allocator);
        defer collector.deinit();
        
        const pos = position.Position.init();
        const err = err_mod.LexerError.init(
            err_mod.LexerErrorType.InvalidNumber,
            pos,
        );
        try collector.addError(err);
        
        try testing.expect(collector.hasErrors());
        
        collector.clear();
        
        try testing.expect(!collector.hasErrors());
        try testing.expect(collector.error_count == 0);
        try testing.expect(collector.errors.items.len == 0);
    }
    
    test "integration: ErrorCollector: max errors limit" {
        var collector = err_mod.ErrorCollector.init(testing.allocator);
        defer collector.deinit();
        
        collector.max_errors = 5;
        
        const pos = position.Position.init();
        
        // Add errors up to limit
        for (0..5) |_| {
            const err = err_mod.LexerError.init(
                err_mod.LexerErrorType.InvalidToken,
                pos,
            );
            try collector.addError(err);
        }
        
        // This should fail
        const extra_err = err_mod.LexerError.init(
            err_mod.LexerErrorType.InvalidToken,
            pos,
        );
        try testing.expectError(error.TooManyErrors, collector.addError(extra_err));
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝