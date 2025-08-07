# Testing Guide for LexCore

## Running Tests

### Run All Tests
The recommended way to run tests is through the build system:

```bash
zig build test
```

This runs all tests in the project including:
- Library module tests
- Executable tests  
- All submodule tests (token, position, buffer, etc.)

### Why Individual File Testing Doesn't Work

Due to Zig's module system, you cannot run tests on individual files directly with `zig test <file>`. This is because:

1. **Module Context Required**: Test files use relative imports like `@import("../position/position.zig")` which only work within the module context
2. **Build System Integration**: The build.zig file sets up the proper module structure that test files depend on
3. **Cross-Module Dependencies**: Many tests depend on types and functions from other modules

### Test Organization

Tests are organized following the Maysara Code Style (MCS):

```
lib/
├── lexer/
│   ├── token/
│   │   ├── token.zig           # Implementation
│   │   ├── token.test.zig      # Main test suite
│   │   ├── zero_copy_test.zig  # Zero-copy verification tests
│   │   └── memory_test.zig     # Memory usage tests
│   ├── position/
│   │   ├── position.zig        # Implementation
│   │   └── position.test.zig   # Test suite
│   └── ...
```

### Test Categories

All tests follow the naming convention:
```zig
test "<category>: <component>: <description>" { }
```

Categories:
- `unit`: Individual function tests
- `integration`: Multi-component interaction tests
- `e2e`: End-to-end workflow tests
- `performance`: Performance validation tests
- `stress`: Extreme condition tests

### Verifying Test Success

When tests pass successfully through `zig build test`, you'll see no output (Unix philosophy - no news is good news). To verify:

```bash
zig build test && echo "All tests passed!"
```

### Test Coverage

The project currently has:
- **56+ tests** in the token module alone
- Comprehensive coverage of all public APIs
- Memory leak detection with `std.testing.allocator`
- Zero-copy verification tests
- Stress tests with 10,000+ tokens

### Adding New Tests

When adding new tests:
1. Place test files adjacent to implementation files
2. Follow MCS guidelines with proper section structure
3. Use appropriate test categories
4. Always use `std.testing.allocator` for memory tests
5. Include both success and error paths

### Continuous Integration

For CI/CD pipelines, use:
```bash
zig build test
```

This ensures all tests run with proper module context and dependencies.