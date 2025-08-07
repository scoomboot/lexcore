// perf.test.zig — Test suite for performance utilities
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/utils/perf/test
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const perf = @import("perf.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: Timer: basic timing operations" {
        var timer = perf.Timer.start();
        
        // Do some work
        var sum: u64 = 0;
        for (0..1000) |i| {
            sum += i;
        }
        
        const elapsed_ns = timer.elapsedNanos();
        const elapsed_us = timer.elapsedMicros();
        const elapsed_ms = timer.elapsedMillis();
        const elapsed_s = timer.elapsedSeconds();
        
        // Basic sanity checks
        try testing.expect(elapsed_ns > 0);
        try testing.expect(elapsed_us <= elapsed_ns / 1000 + 1);
        try testing.expect(elapsed_ms <= elapsed_us / 1000 + 1);
        try testing.expect(elapsed_s >= 0.0);
        
        // Prevent optimization
        try testing.expect(sum == 499500);
    }
    
    test "unit: Timer: reset functionality" {
        var timer = perf.Timer.start();
        
        // Do some work
        std.time.sleep(1_000_000); // 1ms
        
        const first_elapsed = timer.elapsedNanos();
        timer.reset();
        const second_elapsed = timer.elapsedNanos();
        
        try testing.expect(first_elapsed > second_elapsed);
    }
    
    test "unit: Timer: lap functionality" {
        var timer = perf.Timer.start();
        
        // First lap
        std.time.sleep(1_000_000); // 1ms
        const lap1 = timer.lap();
        
        // Second lap should start from reset
        const lap2_start = timer.elapsedNanos();
        
        try testing.expect(lap1 > 0);
        try testing.expect(lap2_start < lap1);
    }
    
    test "unit: Benchmark: initialization and cleanup" {
        var bench = perf.Benchmark.init(testing.allocator, "test_bench");
        defer bench.deinit();
        
        try testing.expectEqualStrings("test_bench", bench.name);
        try testing.expect(bench.samples.items.len == 0);
    }
    
    test "unit: Benchmark: run simple benchmark" {
        var bench = perf.Benchmark.init(testing.allocator, "simple_bench");
        defer bench.deinit();
        
        const iterations = 10;
        
        const bench_fn = struct {
            fn run() !void {
                var sum: u64 = 0;
                for (0..100) |i| {
                    sum += i;
                }
                // Prevent optimization
                std.mem.doNotOptimizeAway(sum);
            }
        }.run;
        
        const result = try bench.run(iterations, null, bench_fn, null);
        
        try testing.expect(result.iterations == iterations);
        try testing.expect(result.total_time_ns > 0);
        try testing.expect(result.min_time_ns <= result.mean_time_ns);
        try testing.expect(result.max_time_ns >= result.mean_time_ns);
        try testing.expect(result.median_time_ns > 0);
    }
    
    test "unit: Benchmark: with setup and teardown" {
        var bench = perf.Benchmark.init(testing.allocator, "setup_teardown_bench");
        defer bench.deinit();
        
        // Use a global-like structure for this test
        const TestContext = struct {
            var setup_called: usize = 0;
            var teardown_called: usize = 0;
        };
        
        // Reset counters
        TestContext.setup_called = 0;
        TestContext.teardown_called = 0;
        
        const setup_fn = struct {
            fn setup() !void {
                TestContext.setup_called += 1;
            }
        }.setup;
        
        const bench_fn = struct {
            fn run() !void {
                // Simple work
                std.mem.doNotOptimizeAway(@as(u64, 42));
            }
        }.run;
        
        const teardown_fn = struct {
            fn teardown() !void {
                TestContext.teardown_called += 1;
            }
        }.teardown;
        
        const iterations = 5;
        _ = try bench.run(iterations, setup_fn, bench_fn, teardown_fn);
        
        try testing.expect(TestContext.setup_called == iterations);
        try testing.expect(TestContext.teardown_called == iterations);
    }
    
    test "unit: MemoryTracker: initialization" {
        const tracker = perf.MemoryTracker.init(testing.allocator);
        
        try testing.expect(tracker.allocations == 0);
        try testing.expect(tracker.deallocations == 0);
        try testing.expect(tracker.current_usage == 0);
        try testing.expect(tracker.peak_usage == 0);
    }
    
    test "unit: MemoryTracker: track allocations and deallocations" {
        var tracker = perf.MemoryTracker.init(testing.allocator);
        
        tracker.trackAlloc(100);
        try testing.expect(tracker.allocations == 1);
        try testing.expect(tracker.current_usage == 100);
        try testing.expect(tracker.peak_usage == 100);
        
        tracker.trackAlloc(200);
        try testing.expect(tracker.allocations == 2);
        try testing.expect(tracker.current_usage == 300);
        try testing.expect(tracker.peak_usage == 300);
        
        tracker.trackFree(100);
        try testing.expect(tracker.deallocations == 1);
        try testing.expect(tracker.current_usage == 200);
        try testing.expect(tracker.peak_usage == 300); // Peak unchanged
    }
    
    test "unit: MemoryTracker: get statistics" {
        var tracker = perf.MemoryTracker.init(testing.allocator);
        
        tracker.trackAlloc(500);
        tracker.trackAlloc(300);
        tracker.trackFree(300);
        
        const stats = tracker.getStats();
        
        try testing.expect(stats.allocations == 2);
        try testing.expect(stats.deallocations == 1);
        try testing.expect(stats.current_usage == 500);
        try testing.expect(stats.peak_usage == 800);
        try testing.expect(stats.leaked == true);
    }
    
    test "unit: MemoryTracker: reset tracking" {
        var tracker = perf.MemoryTracker.init(testing.allocator);
        
        tracker.trackAlloc(100);
        tracker.reset();
        
        try testing.expect(tracker.allocations == 0);
        try testing.expect(tracker.current_usage == 0);
        try testing.expect(tracker.peak_usage == 0);
    }
    
    test "unit: Throughput: bytes per second calculation" {
        const bytes: usize = 1_000_000; // 1 MB
        const elapsed_ns: u64 = 1_000_000_000; // 1 second
        
        const throughput = perf.Throughput.bytesPerSecond(bytes, elapsed_ns);
        try testing.expectApproxEqAbs(@as(f64, 1_000_000), throughput, 0.01);
    }
    
    test "unit: Throughput: items per second calculation" {
        const items: usize = 1000;
        const elapsed_ns: u64 = 500_000_000; // 0.5 seconds
        
        const throughput = perf.Throughput.itemsPerSecond(items, elapsed_ns);
        try testing.expectApproxEqAbs(@as(f64, 2000), throughput, 0.01);
    }
    
    test "unit: Throughput: format bytes display" {
        // Test different scales
        var buf = perf.Throughput.formatBytes(50);
        try testing.expect(std.mem.indexOf(u8, &buf, "B/s") != null);
        
        buf = perf.Throughput.formatBytes(5_000);
        try testing.expect(std.mem.indexOf(u8, &buf, "KB/s") != null);
        
        buf = perf.Throughput.formatBytes(5_000_000);
        try testing.expect(std.mem.indexOf(u8, &buf, "MB/s") != null);
        
        buf = perf.Throughput.formatBytes(5_000_000_000);
        try testing.expect(std.mem.indexOf(u8, &buf, "GB/s") != null);
    }
    
    test "performance: Timer: overhead measurement" {
        const iterations = 1000;
        var total: u64 = 0;
        
        for (0..iterations) |_| {
            const timer = perf.Timer.start();
            const elapsed = timer.elapsedNanos();
            total += elapsed;
        }
        
        const avg_overhead = total / iterations;
        
        // Timer overhead should be minimal (typically < 1 microsecond)
        try testing.expect(avg_overhead < 1000);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝