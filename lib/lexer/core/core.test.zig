// core.test.zig — Test suite for generic lexer traits
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/core/test
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const core = @import("core.zig");
    const token = @import("../token/token.zig");
    const position = @import("../position/position.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: LexerConfig: default configuration values" {
        const config = core.LexerConfig.default();
        
        try testing.expect(config.skip_whitespace == true);
        try testing.expect(config.skip_comments == true);
        try testing.expect(config.track_lines == true);
        try testing.expect(config.max_token_length == 0);
        try testing.expect(config.max_nesting_depth == 1000);
        try testing.expect(config.buffer_size == 4096);
        try testing.expect(config.unicode_enabled == true);
    }
    
    test "unit: LexerConfig: custom configuration" {
        const config = core.LexerConfig{
            .skip_whitespace = false,
            .skip_comments = false,
            .max_token_length = 256,
        };
        
        try testing.expect(config.skip_whitespace == false);
        try testing.expect(config.skip_comments == false);
        try testing.expect(config.max_token_length == 256);
    }
    
    test "unit: LexerState: enum values" {
        const state = core.LexerState.Initial;
        try testing.expect(state == .Initial);
        
        const states = [_]core.LexerState{
            .Initial,
            .InProgress,
            .Complete,
            .Error,
        };
        
        try testing.expect(states.len == 4);
    }
    
    test "unit: LexerCapabilities: packed struct size" {
        const caps = core.LexerCapabilities{};
        
        // Verify packed struct is 1 byte
        try testing.expect(@sizeOf(core.LexerCapabilities) == 1);
        try testing.expect(caps.supports_unicode == false);
        try testing.expect(caps.supports_lookahead == false);
    }
    
    test "unit: LexerCapabilities: setting flags" {
        var caps = core.LexerCapabilities{
            .supports_unicode = true,
            .supports_lookahead = true,
            .supports_error_recovery = true,
        };
        
        try testing.expect(caps.supports_unicode == true);
        try testing.expect(caps.supports_lookahead == true);
        try testing.expect(caps.supports_error_recovery == true);
        try testing.expect(caps.supports_backtracking == false);
    }
    
    test "unit: LexerStats: initial values" {
        const stats = core.LexerStats{};
        
        try testing.expect(stats.tokens_produced == 0);
        try testing.expect(stats.bytes_processed == 0);
        try testing.expect(stats.errors_encountered == 0);
        try testing.expect(stats.lines_processed == 0);
        try testing.expect(stats.peak_memory_usage == 0);
        try testing.expect(stats.lexing_time_ns == 0);
    }
    
    test "unit: LexerStats: updating statistics" {
        var stats = core.LexerStats{};
        
        stats.tokens_produced += 10;
        stats.bytes_processed += 100;
        stats.lines_processed += 5;
        
        try testing.expect(stats.tokens_produced == 10);
        try testing.expect(stats.bytes_processed == 100);
        try testing.expect(stats.lines_processed == 5);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝