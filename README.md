# LexCore

A high-performance, modular lexer library written in Zig, designed for building robust parsers and language tools.

## Features

- **High Performance**: Optimized tokenization with minimal allocations
- **Unicode Support**: Full UTF-8 support with proper character boundary handling
- **Comprehensive Error Handling**: Detailed error reporting with position tracking
- **Modular Design**: Clean separation of concerns with reusable components
- **Extensive Testing**: Unit, integration, and performance tests included
- **Zero Dependencies**: Pure Zig implementation with no external dependencies

## Installation

### As a Zig Module

Add `lexcore` to your `build.zig.zon`:

```zig
.dependencies = .{
    .lexcore = .{
        .url = "https://github.com/emoessner/lexcore/archive/refs/tags/v0.1.0.tar.gz",
        .hash = "...", // Use `zig fetch` to get the hash
    },
},
```

Then in your `build.zig`:

```zig
const lexcore = b.dependency("lexcore", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("lexcore", lexcore.module("lexcore"));
```

## Building from Source

### Prerequisites

- Zig 0.14.0 or later

### Build Commands

```bash
# Build the project
zig build

# Run the executable
zig build run

# Run all tests
zig build test

# Run tests with fuzzing
zig build test -- --fuzz

# Build in release mode
zig build -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=ReleaseSmall
```

## Usage

### Basic Example

```zig
const std = @import("std");
const lexcore = @import("lexcore");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a lexer instance
    var lexer = try lexcore.Lexer.init(allocator, "your source code here");
    defer lexer.deinit();

    // Tokenize
    while (try lexer.nextToken()) |token| {
        std.debug.print("Token: {}\n", .{token});
    }
}
```

## Architecture

### Module Structure

- **Library Module** (`lexcore`): Core lexer functionality exposed via `lib/root.zig`
- **Executable**: CLI tool for testing and demonstration (`src/main.zig`)

### Core Components

- **Lexer**: Main tokenization engine
- **Buffer**: Efficient input buffering with lookahead
- **Token**: Token representation and manipulation
- **Position**: Source position tracking
- **Error**: Comprehensive error handling
- **Utils**: Unicode handling and performance utilities

## Development

This project follows the Maysara Code Style (MCS), emphasizing code as art with structured organization and comprehensive testing.

### Testing

The project includes extensive test coverage:

- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Verify component interactions
- **Performance Tests**: Ensure performance requirements are met
- **Stress Tests**: Validate behavior under extreme conditions

Run tests with: `zig build test`

### Contributing

1. Follow the Maysara Code Style (see `docs/MCS.md`)
2. Ensure all tests pass
3. Add tests for new functionality
4. Document public APIs

## Documentation

- [API Documentation](https://emoessner.github.io/lexcore)
- [Maysara Code Style Guide](docs/MCS.md)
- [Test Naming Conventions](docs/TEST_NAMING_CONVENTIONS.md)
- [Architecture Overview](docs/LEXER_LIBRARY_PLAN.md)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

Developed with ❤️ by [emoessner](https://github.com/emoessner)

## Links

- **Repository**: https://github.com/emoessner/lexcore
- **Documentation**: https://emoessner.github.io/lexcore
- **Issues**: https://github.com/emoessner/lexcore/issues