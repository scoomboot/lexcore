# Zig Lexer Library Development Plan

## Executive Summary

This document outlines the development plan for a general-purpose lexer library in Zig, designed to be the foundation for parser development in the Zig ecosystem. The library will prioritize ergonomics, performance, and compile-time optimization using Zig's unique features.

## Project Vision

Create a reusable, efficient, and ergonomic lexer library that:
- Leverages Zig's comptime features for zero-cost abstractions
- Provides both streaming and batch tokenization
- Supports multiple parsing strategies (LL, LR, PEG)
- Becomes the standard lexer infrastructure for Zig projects

## Architecture Design

### Module Structure
```
src/
├── lexer/
│   ├── core.zig          // Generic lexer traits and interfaces
│   ├── token.zig         // Token type definitions
│   ├── buffer.zig        // Input buffering strategies
│   ├── error.zig         // Error handling and recovery
│   ├── position.zig      // Source position tracking
│   └── implementations/
│       ├── json.zig      // JSON lexer (first implementation)
│       ├── toml.zig      // TOML lexer (second implementation)
│       └── zig.zig       // Zig language lexer (future)
├── parser/
│   └── json.zig          // Proof-of-concept parser
├── utils/
│   ├── unicode.zig       // UTF-8/Unicode utilities
│   └── perf.zig          // Performance measurement
└── root.zig              // Public API surface
```

### Core Abstractions

#### Token Definition
```zig
pub fn Token(comptime T: type) type {
    return struct {
        type: T,
        slice: []const u8,    // Zero-copy slice into source
        position: SourcePosition,
        
        pub const SourcePosition = struct {
            line: u32,
            column: u32,
            offset: usize,
        };
    };
}
```

#### Lexer Interface
```zig
pub fn Lexer(comptime TokenType: type) type {
    return struct {
        source: []const u8,
        position: usize,
        allocator: Allocator,
        
        pub fn next(self: *@This()) !?Token(TokenType);
        pub fn peek(self: *@This()) !?Token(TokenType);
        pub fn reset(self: *@This()) void;
    };
}
```

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1-2)
**Goal**: Establish foundation and basic tokenization

- [ ] Set up project structure following MCS guidelines → [Issue #001](../issues/001_issue.md)
- [ ] Implement core token types and interfaces → [Issue #002](../issues/002_issue.md)
- [ ] Build basic character stream handling → [Issue #003](../issues/003_issue.md)
- [ ] Add source position tracking → [Issue #004](../issues/004_issue.md)
- [ ] Create error handling framework → [Issue #005](../issues/005_issue.md)
- [ ] Write unit tests for core components → [Issue #006](../issues/006_issue.md)

**Deliverable**: Working lexer that can tokenize simple text

### Phase 2: JSON Lexer (Week 3-4)
**Goal**: First complete lexer implementation

- [ ] Implement JSON token types (string, number, bool, null, brackets) → [Issue #007](../issues/007_issue.md)
- [ ] Add string escape sequence handling → [Issue #008](../issues/008_issue.md)
- [ ] Implement number parsing (integers, floats, scientific notation) → [Issue #009](../issues/009_issue.md)
- [ ] Add comprehensive error messages → [Issue #010](../issues/010_issue.md)
- [ ] Create JSON-specific test suite → [Issue #011](../issues/011_issue.md)
- [ ] Benchmark against existing JSON parsers → [Issue #012](../issues/012_issue.md)

**Deliverable**: Production-ready JSON lexer

### Phase 3: Parser Integration (Week 5-6)
**Goal**: Validate design through real usage

- [ ] Build JSON parser using the lexer → [Issue #013](../issues/013_issue.md)
- [ ] Implement lookahead and backtracking → [Issue #014](../issues/014_issue.md)
- [ ] Add parser error recovery → [Issue #015](../issues/015_issue.md)
- [ ] Create end-to-end tests → [Issue #016](../issues/016_issue.md)
- [ ] Write documentation and examples → [Issue #017](../issues/017_issue.md)
- [ ] Performance optimization based on profiling → [Issue #018](../issues/018_issue.md)

**Deliverable**: Complete JSON parser demonstrating lexer capabilities

## Design Principles

### 1. Zero-Copy by Default
- Tokens reference slices of original input
- Allocation only when transformation needed
- Support for both borrowed and owned tokens

### 2. Comptime Configuration
```zig
const MyLexer = Lexer(.{
    .token_type = MyTokens,
    .buffer_size = 4096,
    .enable_unicode = true,
    .track_positions = true,
});
```

### 3. Error Recovery
- Continue lexing after errors
- Provide context for error messages
- Support error recovery strategies

### 4. Streaming Interface
- Process arbitrarily large inputs
- Support incremental parsing
- Enable parallel tokenization

### 5. Performance First
- SIMD optimizations where applicable
- Lookup tables for character classification
- Minimal allocations
- Cache-friendly data structures

## API Examples

### Basic Usage
```zig
const std = @import("std");
const lexer = @import("lexer");

pub fn main() !void {
    const input = "{ \"name\": \"John\", \"age\": 30 }";
    
    var lex = lexer.json.Lexer.init(input, std.heap.page_allocator);
    defer lex.deinit();
    
    while (try lex.next()) |token| {
        std.debug.print("{s}: {s}\n", .{@tagName(token.type), token.slice});
    }
}
```

### Custom Lexer Definition
```zig
const MyTokens = enum {
    identifier,
    number,
    string,
    operator,
    keyword,
    eof,
};

const MyLexer = lexer.Lexer(MyTokens);

pub fn createLexer(input: []const u8) MyLexer {
    return MyLexer.init(input, .{
        .keywords = &.{"if", "else", "while", "return"},
        .operators = &.{"+", "-", "*", "/", "==", "!="},
    });
}
```

### Error Handling
```zig
const result = lex.next() catch |err| {
    const context = lex.getErrorContext();
    std.debug.print("Lexical error at {}:{}: {}\n", .{
        context.line,
        context.column,
        @errorName(err),
    });
    std.debug.print("{s}\n", .{context.line_text});
    std.debug.print("{s}^\n", .{" " ** context.column});
    return err;
};
```

## Success Metrics

### Version 1.0 Criteria
- [ ] Complete JSON lexer with 100% spec compliance → [Issue #019](../issues/019_issue.md)
- [ ] Performance within 2x of fastest Zig JSON parser → [Issue #020](../issues/020_issue.md)
- [ ] Zero memory leaks in all test scenarios → [Issue #021](../issues/021_issue.md)
- [ ] Documentation for all public APIs → [Issue #022](../issues/022_issue.md)
- [ ] Example programs demonstrating usage → [Issue #023](../issues/023_issue.md)
- [ ] Published to Zig package registry → [Issue #024](../issues/024_issue.md)

### Quality Metrics
- Test coverage > 90% → [Issue #025](../issues/025_issue.md)
- Benchmark suite with regression detection → [Issue #026](../issues/026_issue.md)
- Fuzz testing for 24 hours without crashes → [Issue #027](../issues/027_issue.md)
- Clean compilation with all Zig safety checks → [Issue #028](../issues/028_issue.md)

## Technical Decisions

### Memory Management
- Use provided allocator for all allocations
- Arena allocator option for batch processing
- Support for custom allocator strategies

### Unicode Support
- UTF-8 as primary encoding
- Configurable Unicode normalization
- Efficient codepoint iteration

### Threading Model
- Thread-safe lexer creation
- Immutable token streams
- Optional parallel tokenization

## Future Roadmap (Post-v1.0)

### Phase 4: TOML Lexer (Week 7-8)
- More complex than JSON
- Tests multi-line strings, comments
- Validates lexer flexibility

### Phase 5: Language Support (Week 9-12)
- Zig lexer for self-hosting
- C lexer for interop
- Python/JavaScript for scripting

### Phase 6: Advanced Features (Ongoing)
- Incremental re-lexing
- Syntax highlighting support
- Language server protocol integration
- Lexer generator from grammar

### Phase 7: Optimization (Ongoing)
- SIMD character classification
- Parallel tokenization
- Memory pooling
- JIT compilation for hot paths

## Risk Mitigation

### Technical Risks
1. **Performance not meeting expectations**
   - Mitigation: Early benchmarking, profiling tools
   
2. **API design flaws**
   - Mitigation: Multiple implementation validation
   
3. **Memory management complexity**
   - Mitigation: Strict ownership rules, extensive testing

### Schedule Risks
1. **Scope creep**
   - Mitigation: Fixed 6-week timeline for v1.0
   
2. **Zig language changes**
   - Mitigation: Target stable Zig version

## Dependencies

### Build Dependencies
- Zig 0.13.0 or later
- No external C libraries

### Development Dependencies
- zig-bench (benchmarking)
- zig-fuzzer (fuzz testing)
- std.testing (unit tests)

## Testing Strategy

### Unit Tests
- Every public function
- Edge cases and error conditions
- Memory leak detection

### Integration Tests
- Complete lexer workflows
- Parser integration
- Real-world file processing

### Performance Tests
- Benchmark suite
- Memory usage profiling
- Comparison with alternatives

### Fuzz Testing
- Random input generation
- Malformed input handling
- Memory safety validation

## Documentation Plan

### API Documentation
- Doc comments for all public APIs
- Usage examples in comments
- Generated HTML documentation

### Tutorials
1. Getting Started Guide
2. Building a Custom Lexer
3. Performance Optimization Tips
4. Error Handling Best Practices

### Reference
- Complete API reference
- Architecture overview
- Design rationale document

## Conclusion

This lexer library will provide essential infrastructure for the Zig ecosystem while showcasing the language's strengths in systems programming. The phased approach ensures steady progress with regular deliverables, while the focus on JSON as the first implementation provides immediate practical value.

The 6-week timeline is aggressive but achievable, with clear milestones and success criteria. Post-v1.0 development will expand capabilities based on community feedback and real-world usage patterns.

---

## Issue Tracking

All implementation tasks are tracked as individual issues in the [issues directory](../issues/). See the [Issue Index](../issues/000_index.md) for a complete overview of all tasks, their dependencies, and implementation order.

---

*Document Version*: 1.1  
*Last Updated*: 2025-01-07  
*Author*: Development Team  
*Status*: Active Planning