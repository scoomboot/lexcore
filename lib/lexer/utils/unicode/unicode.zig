// unicode.zig — Unicode handling utilities for lexer
//
// repo   : https://github.com/emoessner/lexcore  
// docs   : https://emoessner.github.io/lexcore/lib/lexer/utils/unicode
// author : https://github.com/emoessner
//
// Developed with ❤️ by emoessner.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// UTF-8 decoding result
    pub const DecodeResult = struct {
        codepoint: u21,
        bytes_consumed: u8,
    };
    
    /// Decode UTF-8 sequence from bytes
    pub fn decodeUtf8(bytes: []const u8) !DecodeResult {
        if (bytes.len == 0) {
            return error.EmptyInput;
        }
        
        const first = bytes[0];
        
        // ASCII fast path
        if (first < 0x80) {
            return DecodeResult{
                .codepoint = first,
                .bytes_consumed = 1,
            };
        }
        
        // Multi-byte sequences
        var len: u8 = undefined;
        var codepoint: u21 = undefined;
        
        if ((first & 0xE0) == 0xC0) {
            // 2-byte sequence
            len = 2;
            codepoint = @as(u21, first & 0x1F);
        } else if ((first & 0xF0) == 0xE0) {
            // 3-byte sequence
            len = 3;
            codepoint = @as(u21, first & 0x0F);
        } else if ((first & 0xF8) == 0xF0) {
            // 4-byte sequence
            len = 4;
            codepoint = @as(u21, first & 0x07);
        } else {
            return error.InvalidUtf8;
        }
        
        if (bytes.len < len) {
            return error.IncompleteUtf8;
        }
        
        // Decode continuation bytes
        var i: u8 = 1;
        while (i < len) : (i += 1) {
            const byte = bytes[i];
            if ((byte & 0xC0) != 0x80) {
                return error.InvalidUtf8Continuation;
            }
            codepoint = (codepoint << 6) | @as(u21, byte & 0x3F);
        }
        
        return DecodeResult{
            .codepoint = codepoint,
            .bytes_consumed = len,
        };
    }
    
    /// Encode Unicode codepoint to UTF-8
    pub fn encodeUtf8(codepoint: u21, buffer: []u8) !u8 {
        if (codepoint < 0x80) {
            // ASCII
            if (buffer.len < 1) return error.BufferTooSmall;
            buffer[0] = @intCast(codepoint);
            return 1;
        } else if (codepoint < 0x800) {
            // 2-byte sequence
            if (buffer.len < 2) return error.BufferTooSmall;
            buffer[0] = @intCast(0xC0 | (codepoint >> 6));
            buffer[1] = @intCast(0x80 | (codepoint & 0x3F));
            return 2;
        } else if (codepoint < 0x10000) {
            // 3-byte sequence
            if (buffer.len < 3) return error.BufferTooSmall;
            buffer[0] = @intCast(0xE0 | (codepoint >> 12));
            buffer[1] = @intCast(0x80 | ((codepoint >> 6) & 0x3F));
            buffer[2] = @intCast(0x80 | (codepoint & 0x3F));
            return 3;
        } else if (codepoint < 0x110000) {
            // 4-byte sequence
            if (buffer.len < 4) return error.BufferTooSmall;
            buffer[0] = @intCast(0xF0 | (codepoint >> 18));
            buffer[1] = @intCast(0x80 | ((codepoint >> 12) & 0x3F));
            buffer[2] = @intCast(0x80 | ((codepoint >> 6) & 0x3F));
            buffer[3] = @intCast(0x80 | (codepoint & 0x3F));
            return 4;
        } else {
            return error.InvalidCodepoint;
        }
    }
    
    /// Check if codepoint is valid Unicode
    pub fn isValidCodepoint(codepoint: u21) bool {
        // Valid Unicode range is 0x0000 to 0x10FFFF
        // Excluding surrogates 0xD800 to 0xDFFF
        if (codepoint > 0x10FFFF) return false;
        if (codepoint >= 0xD800 and codepoint <= 0xDFFF) return false;
        return true;
    }
    
    /// Check if codepoint is whitespace
    pub fn isWhitespace(codepoint: u21) bool {
        return switch (codepoint) {
            0x0009, // Tab
            0x000A, // Line Feed
            0x000B, // Vertical Tab
            0x000C, // Form Feed
            0x000D, // Carriage Return
            0x0020, // Space
            0x0085, // Next Line
            0x00A0, // No-Break Space
            0x1680, // Ogham Space Mark
            0x2000...0x200A, // Various spaces
            0x2028, // Line Separator
            0x2029, // Paragraph Separator
            0x202F, // Narrow No-Break Space
            0x205F, // Medium Mathematical Space
            0x3000, // Ideographic Space
            => true,
            else => false,
        };
    }
    
    /// Check if codepoint is a letter
    pub fn isLetter(codepoint: u21) bool {
        // Simplified check for common Latin letters
        return (codepoint >= 'A' and codepoint <= 'Z') or
               (codepoint >= 'a' and codepoint <= 'z') or
               (codepoint >= 0x00C0 and codepoint <= 0x00FF) or // Latin Extended
               (codepoint >= 0x0100 and codepoint <= 0x017F);   // Latin Extended-A
    }
    
    /// Check if codepoint is a digit
    pub fn isDigit(codepoint: u21) bool {
        return codepoint >= '0' and codepoint <= '9';
    }
    
    /// Check if codepoint is alphanumeric
    pub fn isAlphanumeric(codepoint: u21) bool {
        return isLetter(codepoint) or isDigit(codepoint);
    }
    
    /// Check if codepoint can start an identifier
    pub fn isIdentifierStart(codepoint: u21) bool {
        return isLetter(codepoint) or codepoint == '_' or codepoint == '$';
    }
    
    /// Check if codepoint can continue an identifier
    pub fn isIdentifierContinue(codepoint: u21) bool {
        return isIdentifierStart(codepoint) or isDigit(codepoint);
    }
    
    /// Get display width of a codepoint (simplified)
    pub fn displayWidth(codepoint: u21) u8 {
        // Simplified width calculation
        if (codepoint < 0x20) return 0; // Control characters
        if (codepoint < 0x7F) return 1; // ASCII
        if (codepoint >= 0x1100 and codepoint <= 0x115F) return 2; // Hangul Jamo
        if (codepoint >= 0x2E80 and codepoint <= 0x9FFF) return 2; // CJK
        if (codepoint >= 0xAC00 and codepoint <= 0xD7AF) return 2; // Hangul Syllables
        if (codepoint >= 0xF900 and codepoint <= 0xFAFF) return 2; // CJK Compatibility
        return 1; // Default
    }
    
    /// UTF-8 validator for entire strings
    pub fn validateUtf8(text: []const u8) bool {
        var i: usize = 0;
        while (i < text.len) {
            const result = decodeUtf8(text[i..]) catch {
                return false;
            };
            i += result.bytes_consumed;
        }
        return true;
    }
    
    /// Count UTF-8 codepoints in a string
    pub fn countCodepoints(text: []const u8) !usize {
        var count: usize = 0;
        var i: usize = 0;
        
        while (i < text.len) {
            const result = try decodeUtf8(text[i..]);
            i += result.bytes_consumed;
            count += 1;
        }
        
        return count;
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝