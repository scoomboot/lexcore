// unicode.test.zig — Test suite for Unicode utilities
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/utils/unicode/test
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const unicode = @import("unicode.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: decodeUtf8: ASCII characters" {
        const text = "A";
        const result = try unicode.decodeUtf8(text);
        
        try testing.expect(result.codepoint == 'A');
        try testing.expect(result.bytes_consumed == 1);
    }
    
    test "unit: decodeUtf8: 2-byte UTF-8 sequence" {
        const text = "ñ"; // U+00F1
        const result = try unicode.decodeUtf8(text);
        
        try testing.expect(result.codepoint == 0x00F1);
        try testing.expect(result.bytes_consumed == 2);
    }
    
    test "unit: decodeUtf8: 3-byte UTF-8 sequence" {
        const text = "€"; // U+20AC
        const result = try unicode.decodeUtf8(text);
        
        try testing.expect(result.codepoint == 0x20AC);
        try testing.expect(result.bytes_consumed == 3);
    }
    
    test "unit: decodeUtf8: 4-byte UTF-8 sequence" {
        const text = "𝄞"; // U+1D11E (musical symbol)
        const result = try unicode.decodeUtf8(text);
        
        try testing.expect(result.codepoint == 0x1D11E);
        try testing.expect(result.bytes_consumed == 4);
    }
    
    test "unit: decodeUtf8: invalid UTF-8" {
        const invalid = [_]u8{0xFF, 0xFF};
        try testing.expectError(error.InvalidUtf8, unicode.decodeUtf8(&invalid));
    }
    
    test "unit: decodeUtf8: incomplete UTF-8" {
        const incomplete = [_]u8{0xC3}; // Start of 2-byte sequence but missing continuation
        try testing.expectError(error.IncompleteUtf8, unicode.decodeUtf8(&incomplete));
    }
    
    test "unit: encodeUtf8: ASCII character" {
        var buffer: [4]u8 = undefined;
        const len = try unicode.encodeUtf8('A', &buffer);
        
        try testing.expect(len == 1);
        try testing.expect(buffer[0] == 'A');
    }
    
    test "unit: encodeUtf8: 2-byte character" {
        var buffer: [4]u8 = undefined;
        const len = try unicode.encodeUtf8(0x00F1, &buffer); // ñ
        
        try testing.expect(len == 2);
        try testing.expect(buffer[0] == 0xC3);
        try testing.expect(buffer[1] == 0xB1);
    }
    
    test "unit: encodeUtf8: 3-byte character" {
        var buffer: [4]u8 = undefined;
        const len = try unicode.encodeUtf8(0x20AC, &buffer); // €
        
        try testing.expect(len == 3);
        try testing.expect(buffer[0] == 0xE2);
        try testing.expect(buffer[1] == 0x82);
        try testing.expect(buffer[2] == 0xAC);
    }
    
    test "unit: encodeUtf8: 4-byte character" {
        var buffer: [4]u8 = undefined;
        const len = try unicode.encodeUtf8(0x1D11E, &buffer); // 𝄞
        
        try testing.expect(len == 4);
        try testing.expect(buffer[0] == 0xF0);
        try testing.expect(buffer[1] == 0x9D);
        try testing.expect(buffer[2] == 0x84);
        try testing.expect(buffer[3] == 0x9E);
    }
    
    test "unit: encodeUtf8: buffer too small" {
        var buffer: [1]u8 = undefined;
        try testing.expectError(error.BufferTooSmall, unicode.encodeUtf8(0x20AC, &buffer));
    }
    
    test "unit: isValidCodepoint: valid ranges" {
        try testing.expect(unicode.isValidCodepoint(0x0000));
        try testing.expect(unicode.isValidCodepoint(0x007F)); // ASCII max
        try testing.expect(unicode.isValidCodepoint(0x10FFFF)); // Unicode max
        
        // Invalid surrogates
        try testing.expect(!unicode.isValidCodepoint(0xD800));
        try testing.expect(!unicode.isValidCodepoint(0xDFFF));
        
        // Beyond Unicode
        try testing.expect(!unicode.isValidCodepoint(0x110000));
    }
    
    test "unit: isWhitespace: common whitespace characters" {
        try testing.expect(unicode.isWhitespace(' '));
        try testing.expect(unicode.isWhitespace('\t'));
        try testing.expect(unicode.isWhitespace('\n'));
        try testing.expect(unicode.isWhitespace('\r'));
        try testing.expect(unicode.isWhitespace(0x00A0)); // No-break space
        
        try testing.expect(!unicode.isWhitespace('A'));
        try testing.expect(!unicode.isWhitespace('0'));
    }
    
    test "unit: isLetter: basic Latin letters" {
        try testing.expect(unicode.isLetter('A'));
        try testing.expect(unicode.isLetter('Z'));
        try testing.expect(unicode.isLetter('a'));
        try testing.expect(unicode.isLetter('z'));
        try testing.expect(unicode.isLetter(0x00E9)); // é
        
        try testing.expect(!unicode.isLetter('0'));
        try testing.expect(!unicode.isLetter(' '));
        try testing.expect(!unicode.isLetter('_'));
    }
    
    test "unit: isDigit: decimal digits" {
        try testing.expect(unicode.isDigit('0'));
        try testing.expect(unicode.isDigit('5'));
        try testing.expect(unicode.isDigit('9'));
        
        try testing.expect(!unicode.isDigit('A'));
        try testing.expect(!unicode.isDigit(' '));
    }
    
    test "unit: isAlphanumeric: letters and digits" {
        try testing.expect(unicode.isAlphanumeric('A'));
        try testing.expect(unicode.isAlphanumeric('z'));
        try testing.expect(unicode.isAlphanumeric('5'));
        
        try testing.expect(!unicode.isAlphanumeric(' '));
        try testing.expect(!unicode.isAlphanumeric('_'));
        try testing.expect(!unicode.isAlphanumeric('!'));
    }
    
    test "unit: isIdentifierStart: valid identifier starts" {
        try testing.expect(unicode.isIdentifierStart('A'));
        try testing.expect(unicode.isIdentifierStart('z'));
        try testing.expect(unicode.isIdentifierStart('_'));
        try testing.expect(unicode.isIdentifierStart('$'));
        
        try testing.expect(!unicode.isIdentifierStart('0'));
        try testing.expect(!unicode.isIdentifierStart(' '));
    }
    
    test "unit: isIdentifierContinue: valid identifier continuations" {
        try testing.expect(unicode.isIdentifierContinue('A'));
        try testing.expect(unicode.isIdentifierContinue('_'));
        try testing.expect(unicode.isIdentifierContinue('0'));
        try testing.expect(unicode.isIdentifierContinue('9'));
        
        try testing.expect(!unicode.isIdentifierContinue(' '));
        try testing.expect(!unicode.isIdentifierContinue('.'));
    }
    
    test "unit: displayWidth: character widths" {
        try testing.expect(unicode.displayWidth('A') == 1);
        try testing.expect(unicode.displayWidth(' ') == 1);
        try testing.expect(unicode.displayWidth(0x00) == 0); // Control char
        try testing.expect(unicode.displayWidth(0x4E00) == 2); // CJK
    }
    
    test "unit: validateUtf8: valid UTF-8 strings" {
        try testing.expect(unicode.validateUtf8("Hello"));
        try testing.expect(unicode.validateUtf8("Héllo €"));
        try testing.expect(unicode.validateUtf8("你好"));
        try testing.expect(unicode.validateUtf8(""));
        
        const invalid = [_]u8{ 0xFF, 0xFE };
        try testing.expect(!unicode.validateUtf8(&invalid));
    }
    
    test "unit: countCodepoints: counting characters" {
        try testing.expect(try unicode.countCodepoints("Hello") == 5);
        try testing.expect(try unicode.countCodepoints("€") == 1);
        try testing.expect(try unicode.countCodepoints("你好") == 2);
        try testing.expect(try unicode.countCodepoints("") == 0);
    }
    
    test "integration: decodeUtf8 and encodeUtf8: round trip" {
        const original = "Hello, 世界! 🌍";
        var i: usize = 0;
        
        while (i < original.len) {
            const decode_result = try unicode.decodeUtf8(original[i..]);
            
            var buffer: [4]u8 = undefined;
            const encode_len = try unicode.encodeUtf8(decode_result.codepoint, &buffer);
            
            try testing.expect(encode_len == decode_result.bytes_consumed);
            try testing.expectEqualSlices(
                u8,
                original[i..i + decode_result.bytes_consumed],
                buffer[0..encode_len],
            );
            
            i += decode_result.bytes_consumed;
        }
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝