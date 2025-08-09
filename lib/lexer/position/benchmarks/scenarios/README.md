# Position Tracking Scenario Benchmarks

This directory contains comprehensive scenario-based benchmarks for the position tracking system in LexCore.

## Benchmark Files

### small_file.zig
- Benchmarks for files < 1KB
- Tests tokenization, JSON parsing, and CSV processing
- Measures overhead of position tracking in small file scenarios
- Target: < 3% overhead

### medium_file.zig
- Benchmarks for files 1KB - 100KB
- Tests stream processing, log analysis, and code analysis
- Real-world parsing patterns with position tracking
- Target: < 3% overhead

### large_file.zig
- Benchmarks for files 100KB - 10MB
- Stress tests with large log files and JSON data
- Parallel processing benchmarks
- Memory usage analysis at scale
- Target: < 3% overhead

## Test Data

Test data files are located in `../test_data/` and include:
- Source code files (Zig, JavaScript)
- JSON data (small objects to large arrays)
- CSV files (tabular data)
- Log files (structured logs)
- Files with different encodings (ASCII, UTF-8, mixed)
- Files with different line endings (LF, CRLF, CR)

## Running Benchmarks

To run individual scenario benchmarks:
```bash
zig run lib/lexer/position/benchmarks/scenarios/small_file.zig
zig run lib/lexer/position/benchmarks/scenarios/medium_file.zig
zig run lib/lexer/position/benchmarks/scenarios/large_file.zig
```

To generate test data:
```bash
zig run lib/lexer/position/benchmarks/test_data/generate_test_data.zig
```

## Performance Goals

All scenarios aim to maintain position tracking overhead under 3% compared to parsing without position tracking, ensuring minimal performance impact in real-world usage.