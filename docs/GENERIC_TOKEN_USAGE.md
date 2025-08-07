# Generic Token System Usage Guide

## Overview

LexCore provides a flexible generic token system that allows you to define custom token types for your specific lexer implementation while maintaining a consistent interface.

## Basic Usage

### Defining Custom Token Types

```zig
// Define your custom token type enum
pub const MyTokenType = enum {
    Identifier,
    Number,
    String,
    Operator,
    Keyword,
    // ... your specific token types
};

// Create your token type using the generic Token function
pub const MyToken = token.Token(MyTokenType);
```

### Creating Tokens

```zig
const pos = position.SourcePosition.init();

// Basic token creation (zero-copy)
const tok = MyToken.init(
    MyTokenType.Identifier,
    source_slice,  // Slice into source buffer
    pos,
);

// Token with metadata
const metadata = token.TokenMetadata{ .integer_value = 42 };
const tok_with_value = MyToken.initWithMetadata(
    MyTokenType.Number,
    "42",
    pos,
    metadata,
);
```

## Token Metadata

Tokens can carry additional metadata using the `TokenMetadata` union:

```zig
pub const TokenMetadata = union(enum) {
    integer_value: i64,
    float_value: f64,
    string_value: []const u8,
    boolean_value: bool,
    character_value: u21,  // Unicode codepoint
    custom: *anyopaque,     // For custom metadata types
};
```

## Token Operations

### Comparison

```zig
// Check if tokens are equal (type and content)
if (tok1.eql(tok2)) {
    // Tokens have same type and lexeme
}

// Check if tokens are identical (including position)
if (tok1.identical(tok2)) {
    // Tokens are exactly the same
}
```

### Token Properties

```zig
// Get token text
const text = tok.lexeme();  // or tok.slice

// Get token length
const len = tok.length();

// Access position
const line = tok.position.line;
const column = tok.position.column;
```

## Advanced Features

### Token Comparison Utilities

```zig
// Check if tokens are adjacent in source
const adjacent = TokenComparison.areAdjacent(MyTokenType, tok1, tok2);

// Calculate distance between tokens
const distance = TokenComparison.distance(MyTokenType, tok1, tok2);

// Sort tokens by position
std.sort.sort(MyToken, tokens, {}, TokenComparison.compareByPosition(MyTokenType));
```

### Token Categorization

For the default `TokenType`, categories are provided:

```zig
const category = token.TokenType.Identifier.category();
// Returns TokenCategory.Literal

if (token.TokenType.Plus.isOperator()) {
    // Handle operator token
}
```

### Token Traits

Generic trait detection for any token type:

```zig
// Check if a token type represents whitespace
if (TokenTraits.isWhitespace(MyTokenType, tok.type)) {
    // Skip whitespace
}

// Check for other common traits
const is_comment = TokenTraits.isComment(MyTokenType, tok.type);
const is_identifier = TokenTraits.isIdentifier(MyTokenType, tok.type);
const is_literal = TokenTraits.isLiteral(MyTokenType, tok.type);
```

## Migration from Legacy API

If you're using the old Token API, you can gradually migrate:

```zig
// Old API (still supported via LegacyToken)
const tok = token.LegacyToken.init(
    token.TokenType.Identifier,
    "name",
    pos,
);

// New API
const MyToken = token.Token(token.TokenType);
const tok = MyToken.init(
    token.TokenType.Identifier,
    "name",
    pos,
);
```

## Memory Management

The generic token system uses zero-copy design:

- Tokens hold slices into the source buffer
- The source buffer must outlive all tokens
- No manual memory management needed for tokens
- Metadata is stored by value in the token

## Example: Custom Expression Lexer

See `examples/generic_token_example.zig` for a complete example of implementing a custom expression lexer using the generic token system.

## Best Practices

1. **Define domain-specific token types**: Create enums that match your language's needs
2. **Use zero-copy slices**: Avoid copying source text when possible
3. **Leverage metadata**: Store parsed values in token metadata for later use
4. **Use comparison utilities**: Take advantage of built-in sorting and comparison functions
5. **Consider trait detection**: Use TokenTraits for generic token categorization