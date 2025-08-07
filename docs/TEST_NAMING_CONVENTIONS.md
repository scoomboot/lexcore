# Test Naming Conventions

This document outlines the test naming conventions for the LexCore project. These conventions are enforced by our automated testing analyzer.

## Format

All tests must follow this naming pattern:

```zig
test "<category>: <component>: <description>" {
    // Test implementation
}
```

## Categories

Tests must be prefixed with one of the following categories:

- **`unit`**: Tests for individual functions, methods, or small components in isolation
- **`integration`**: Tests that verify interactions between multiple components or modules
- **`e2e`**: End-to-end tests that validate complete workflows or user scenarios
- **`performance`**: Tests that measure and validate performance characteristics
- **`stress`**: Tests that verify behavior under extreme conditions or heavy load

## Examples

### Unit Tests
```zig
test "unit: Parser: handles empty input gracefully" {
    // Test implementation
}

test "unit: Lexer: tokenizes basic identifiers" {
    // Test implementation
}

test "unit: ASTNode: correctly initializes default values" {
    // Test implementation
}
```

### Integration Tests
```zig
test "integration: Parser: processes complete valid program" {
    // Test implementation
}

test "integration: CoreParser: handles complex nested structures" {
    // Test implementation
}
```

### End-to-End Tests
```zig
test "e2e: full parsing pipeline: transforms source to AST" {
    // Test implementation
}
```

### Performance Tests
```zig
test "performance: Parser: handles large files efficiently" {
    // Test implementation
}
```

### Stress Tests
```zig
test "stress: Parser: handles deeply nested structures" {
    // Test implementation
}
```

## Best Practices

1. **Be Specific**: Use descriptive names that clearly indicate what the test validates
2. **Component Names**: Include the component or module being tested after the category
3. **Action-Oriented**: Describe what the test does or what behavior it verifies
4. **Consistent Format**: Always use lowercase for categories, PascalCase for component names
5. **Memory Safety**: Tests involving allocations should use `std.testing.allocator` and proper cleanup with `defer`

## Memory Safety in Tests

Tests that allocate memory should follow these patterns:

```zig
test "unit: MyComponent: allocates and frees resources correctly" {
    const allocator = std.testing.allocator;
    const component = try MyComponent.init(allocator);
    defer component.deinit();
    
    // Test implementation
}
```

## Test File Organization

- Unit tests can be included inline in source files
- Integration and e2e tests should be in separate test files
- Test files should use the suffix `_test.zig` (e.g., `parser_test.zig`)