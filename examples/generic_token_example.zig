// generic_token_example.zig — Example of using the generic Token system
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/examples
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const lexcore = @import("lexcore");
    const token_mod = lexcore.token;
    const position_mod = lexcore.position;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Custom token type for a simple expression language
    pub const ExprTokenType = enum {
        // Literals
        Integer,
        Float,
        Identifier,
        
        // Operators
        Plus,
        Minus,
        Multiply,
        Divide,
        
        // Parentheses
        LeftParen,
        RightParen,
        
        // Control
        Eof,
        Unknown,
    };
    
    /// Create our custom token type using the generic Token function
    pub const ExprToken = token_mod.Token(ExprTokenType);
    
    /// Example lexer using the custom token type
    pub fn lexExpression(source: []const u8) ![]ExprToken {
        var tokens = std.ArrayList(ExprToken).init(std.heap.page_allocator);
        defer tokens.deinit();
        
        var pos = position_mod.SourcePosition.init();
        var i: usize = 0;
        
        while (i < source.len) {
            const start = i;
            const start_pos = pos;
            
            switch (source[i]) {
                '+' => {
                    try tokens.append(ExprToken.init(
                        .Plus,
                        source[start..i+1],
                        start_pos,
                    ));
                    pos.advance('+');
                    i += 1;
                },
                '-' => {
                    try tokens.append(ExprToken.init(
                        .Minus,
                        source[start..i+1],
                        start_pos,
                    ));
                    pos.advance('-');
                    i += 1;
                },
                '*' => {
                    try tokens.append(ExprToken.init(
                        .Multiply,
                        source[start..i+1],
                        start_pos,
                    ));
                    pos.advance('*');
                    i += 1;
                },
                '/' => {
                    try tokens.append(ExprToken.init(
                        .Divide,
                        source[start..i+1],
                        start_pos,
                    ));
                    pos.advance('/');
                    i += 1;
                },
                '(' => {
                    try tokens.append(ExprToken.init(
                        .LeftParen,
                        source[start..i+1],
                        start_pos,
                    ));
                    pos.advance('(');
                    i += 1;
                },
                ')' => {
                    try tokens.append(ExprToken.init(
                        .RightParen,
                        source[start..i+1],
                        start_pos,
                    ));
                    pos.advance(')');
                    i += 1;
                },
                '0'...'9' => {
                    // Scan number
                    var is_float = false;
                    while (i < source.len and (std.ascii.isDigit(source[i]) or source[i] == '.')) {
                        if (source[i] == '.') is_float = true;
                        pos.advance(source[i]);
                        i += 1;
                    }
                    
                    const token_type = if (is_float) ExprTokenType.Float else ExprTokenType.Integer;
                    const slice = source[start..i];
                    
                    // Create token with metadata for the numeric value
                    var tok = ExprToken.init(token_type, slice, start_pos);
                    if (!is_float) {
                        const value = try std.fmt.parseInt(i64, slice, 10);
                        tok.metadata = token_mod.TokenMetadata{ .integer_value = value };
                    } else {
                        const value = try std.fmt.parseFloat(f64, slice);
                        tok.metadata = token_mod.TokenMetadata{ .float_value = value };
                    }
                    try tokens.append(tok);
                },
                'a'...'z', 'A'...'Z', '_' => {
                    // Scan identifier
                    while (i < source.len and (std.ascii.isAlphanumeric(source[i]) or source[i] == '_')) {
                        pos.advance(source[i]);
                        i += 1;
                    }
                    try tokens.append(ExprToken.init(
                        .Identifier,
                        source[start..i],
                        start_pos,
                    ));
                },
                ' ', '\t', '\n', '\r' => {
                    // Skip whitespace
                    pos.advance(source[i]);
                    i += 1;
                },
                else => {
                    // Unknown character
                    try tokens.append(ExprToken.init(
                        .Unknown,
                        source[start..i+1],
                        start_pos,
                    ));
                    pos.advance(source[i]);
                    i += 1;
                },
            }
        }
        
        // Add EOF token
        try tokens.append(ExprToken.init(
            .Eof,
            "",
            pos,
        ));
        
        return try tokens.toOwnedSlice();
    }
    
    pub fn main() !void {
        const expression = "x + 42 * (y - 3.14)";
        
        std.debug.print("Lexing expression: {s}\n\n", .{expression});
        
        const tokens = try lexExpression(expression);
        defer std.heap.page_allocator.free(tokens);
        
        std.debug.print("Tokens:\n", .{});
        for (tokens) |tok| {
            std.debug.print("  {s:12} '{s}'", .{ @tagName(tok.type), tok.slice });
            
            if (tok.metadata) |metadata| {
                switch (metadata) {
                    .integer_value => |v| std.debug.print(" (value: {})", .{v}),
                    .float_value => |v| std.debug.print(" (value: {d:.2})", .{v}),
                    else => {},
                }
            }
            
            std.debug.print(" at {}:{}\n", .{ tok.position.line, tok.position.column });
        }
        
        // Demonstrate token comparison utilities
        if (tokens.len >= 2) {
            const adjacent = token_mod.TokenComparison.areAdjacent(ExprTokenType, tokens[0], tokens[1]);
            std.debug.print("\nFirst two tokens are adjacent: {}\n", .{adjacent});
        }
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝