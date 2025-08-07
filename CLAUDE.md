# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Zig library and executable project called `lexcore`. The project follows the Maysara Code Style (MCS) which emphasizes code as art with structured organization and comprehensive testing.

## Build Commands

```bash
# Build the project
zig build

# Run the executable
zig build run

# Run all tests (both module and executable tests)
zig build test

# Run tests with fuzzing
zig build test -- --fuzz

# Build in release mode
zig build -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=ReleaseSmall
```

## Architecture

### Module Structure
- **Library Module** (`lexcore`): Exposed as a reusable module via `lib/root.zig`
- **Executable**: Entry point at `src/main.zig`, imports the library module
- Both the library and executable have separate test suites

### Key Files
- `lib/root.zig`: Library entry point, exposes public API
- `src/main.zig`: Executable entry point with CLI functionality
- `build.zig`: Build configuration defining module structure and build steps
- `build.zig.zon`: Package manifest with dependencies and metadata

## Code Style Requirements

This project strictly follows the Maysara Code Style (MCS). Key requirements:

### File Structure
Every source file must have:
1. Standard header with repo/docs/author info
2. Section demarcation using decorative borders
3. 4-space indentation within sections

### Section Borders
```zig
// ╔══════════════════════════════════════ SECTION ══════════════════════════════════════╗
    // Code indented by 4 spaces
// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

### Common Sections
- `PACK`: Imports and exports
- `CORE`: Primary implementation
- `TEST`: Test functions
- `INIT`: Initialization and constants

### Test Naming Convention
All tests must follow: `test "<category>: <component>: <description>"`

Categories:
- `unit`: Individual function tests
- `integration`: Multi-component interaction tests
- `e2e`: End-to-end workflow tests
- `performance`: Performance validation tests
- `stress`: Extreme condition tests

Example:
```zig
test "unit: Parser: handles empty input gracefully" {
    // Test implementation
}
```

### Memory Safety
- Use `std.testing.allocator` in tests
- Always pair allocations with `defer deinit()` or `defer free()`
- Document memory ownership in function comments

## Development Workflow

1. Follow MCS guidelines for all new code
2. Place tests adjacent to implementation
3. Use descriptive test names with proper categories
4. Ensure comprehensive test coverage
5. Document public functions with structured doc comments

## Testing Requirements

### Critical: Test Discovery Pattern
**All module files MUST import their test files explicitly** following the Super-ZIG/io pattern:

```zig
// At the end of each module file (e.g., buffer.zig), before the closing section border:
test {
    _ = @import("buffer.test.zig");
}
```

**Why this is critical**: Without these imports, tests will NOT be discovered by `zig build test`. We discovered that 51% of our tests (64 out of 125) were not running because modules didn't import their test files.

### Test Organization
- Place test files adjacent to implementation: `module.zig` and `module.test.zig`
- For multiple test files per module, import all of them:
  ```zig
  test {
      _ = @import("token.test.zig");
      _ = @import("zero_copy_test.zig");
      _ = @import("memory_test.zig");
  }
  ```

### Test Requirements
- Every public function needs unit tests
- Integration tests for component interactions
- Use `std.testing.allocator` for memory-related tests
- Test both success and error paths
- Include edge cases and boundary conditions

## Style Enforcement

The project includes automated style checking via `docs/MCS_AUTOMATION.md`. Ensure all code follows MCS guidelines before committing.