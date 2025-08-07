// perf.zig — Performance measurement utilities for lexer
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/lib/lexer/utils/perf
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Timer for measuring elapsed time
    pub const Timer = struct {
        start_time: i128,
        
        /// Start a new timer
        pub fn start() Timer {
            return .{
                .start_time = std.time.nanoTimestamp(),
            };
        }
        
        /// Get elapsed time in nanoseconds
        pub fn elapsedNanos(self: *const Timer) u64 {
            const now = std.time.nanoTimestamp();
            return @intCast(now - self.start_time);
        }
        
        /// Get elapsed time in microseconds
        pub fn elapsedMicros(self: *const Timer) u64 {
            return self.elapsedNanos() / 1000;
        }
        
        /// Get elapsed time in milliseconds
        pub fn elapsedMillis(self: *const Timer) u64 {
            return self.elapsedNanos() / 1_000_000;
        }
        
        /// Get elapsed time in seconds
        pub fn elapsedSeconds(self: *const Timer) f64 {
            const nanos = self.elapsedNanos();
            return @as(f64, @floatFromInt(nanos)) / 1_000_000_000.0;
        }
        
        /// Reset the timer
        pub fn reset(self: *Timer) void {
            self.start_time = std.time.nanoTimestamp();
        }
        
        /// Get elapsed time and reset
        pub fn lap(self: *Timer) u64 {
            const elapsed = self.elapsedNanos();
            self.reset();
            return elapsed;
        }
    };
    
    /// Benchmark result
    pub const BenchmarkResult = struct {
        name: []const u8,
        iterations: usize,
        total_time_ns: u64,
        min_time_ns: u64,
        max_time_ns: u64,
        mean_time_ns: u64,
        median_time_ns: u64,
        std_dev_ns: u64,
        
        /// Format benchmark result for display
        pub fn format(
            self: BenchmarkResult,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            
            try writer.print("Benchmark: {s}\n", .{self.name});
            try writer.print("  Iterations: {d}\n", .{self.iterations});
            try writer.print("  Total:      {d:.3} ms\n", .{@as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000.0});
            try writer.print("  Mean:       {d:.3} µs\n", .{@as(f64, @floatFromInt(self.mean_time_ns)) / 1000.0});
            try writer.print("  Median:     {d:.3} µs\n", .{@as(f64, @floatFromInt(self.median_time_ns)) / 1000.0});
            try writer.print("  Min:        {d:.3} µs\n", .{@as(f64, @floatFromInt(self.min_time_ns)) / 1000.0});
            try writer.print("  Max:        {d:.3} µs\n", .{@as(f64, @floatFromInt(self.max_time_ns)) / 1000.0});
            try writer.print("  Std Dev:    {d:.3} µs\n", .{@as(f64, @floatFromInt(self.std_dev_ns)) / 1000.0});
        }
    };
    
    /// Benchmark runner
    pub const Benchmark = struct {
        allocator: std.mem.Allocator,
        name: []const u8,
        samples: std.ArrayList(u64),
        
        /// Initialize benchmark
        pub fn init(allocator: std.mem.Allocator, name: []const u8) Benchmark {
            return .{
                .allocator = allocator,
                .name = name,
                .samples = std.ArrayList(u64).init(allocator),
            };
        }
        
        /// Clean up benchmark
        pub fn deinit(self: *Benchmark) void {
            self.samples.deinit();
        }
        
        /// Run benchmark function
        pub fn run(
            self: *Benchmark,
            iterations: usize,
            setup_fn: ?*const fn () anyerror!void,
            bench_fn: *const fn () anyerror!void,
            teardown_fn: ?*const fn () anyerror!void,
        ) !BenchmarkResult {
            self.samples.clearRetainingCapacity();
            try self.samples.ensureTotalCapacity(iterations);
            
            var total_time: u64 = 0;
            
            for (0..iterations) |_| {
                if (setup_fn) |setup| {
                    try setup();
                }
                
                const timer = Timer.start();
                try bench_fn();
                const elapsed = timer.elapsedNanos();
                
                if (teardown_fn) |teardown| {
                    try teardown();
                }
                
                try self.samples.append(elapsed);
                total_time += elapsed;
            }
            
            // Calculate statistics
            std.mem.sort(u64, self.samples.items, {}, std.sort.asc(u64));
            
            const min = self.samples.items[0];
            const max = self.samples.items[self.samples.items.len - 1];
            const mean = total_time / iterations;
            const median = if (iterations % 2 == 0)
                (self.samples.items[iterations / 2 - 1] + self.samples.items[iterations / 2]) / 2
            else
                self.samples.items[iterations / 2];
            
            // Calculate standard deviation
            var variance: u64 = 0;
            for (self.samples.items) |sample| {
                const diff = if (sample > mean) sample - mean else mean - sample;
                variance += diff * diff;
            }
            variance /= iterations;
            const std_dev = std.math.sqrt(@as(f64, @floatFromInt(variance)));
            
            return BenchmarkResult{
                .name = self.name,
                .iterations = iterations,
                .total_time_ns = total_time,
                .min_time_ns = min,
                .max_time_ns = max,
                .mean_time_ns = mean,
                .median_time_ns = median,
                .std_dev_ns = @intFromFloat(std_dev),
            };
        }
    };
    
    /// Memory tracker for monitoring allocations
    pub const MemoryTracker = struct {
        allocator: std.mem.Allocator,
        allocations: usize,
        deallocations: usize,
        current_usage: usize,
        peak_usage: usize,
        
        /// Initialize memory tracker
        pub fn init(allocator: std.mem.Allocator) MemoryTracker {
            return .{
                .allocator = allocator,
                .allocations = 0,
                .deallocations = 0,
                .current_usage = 0,
                .peak_usage = 0,
            };
        }
        
        /// Track allocation
        pub fn trackAlloc(self: *MemoryTracker, size: usize) void {
            self.allocations += 1;
            self.current_usage += size;
            if (self.current_usage > self.peak_usage) {
                self.peak_usage = self.current_usage;
            }
        }
        
        /// Track deallocation
        pub fn trackFree(self: *MemoryTracker, size: usize) void {
            self.deallocations += 1;
            self.current_usage -|= size; // Saturating subtraction
        }
        
        /// Reset tracking
        pub fn reset(self: *MemoryTracker) void {
            self.allocations = 0;
            self.deallocations = 0;
            self.current_usage = 0;
            self.peak_usage = 0;
        }
        
        /// Get memory statistics
        pub fn getStats(self: *const MemoryTracker) MemoryStats {
            return .{
                .allocations = self.allocations,
                .deallocations = self.deallocations,
                .current_usage = self.current_usage,
                .peak_usage = self.peak_usage,
                .leaked = self.current_usage > 0,
            };
        }
    };
    
    /// Memory statistics
    pub const MemoryStats = struct {
        allocations: usize,
        deallocations: usize,
        current_usage: usize,
        peak_usage: usize,
        leaked: bool,
    };
    
    /// Throughput calculator
    pub const Throughput = struct {
        /// Calculate throughput in bytes per second
        pub fn bytesPerSecond(bytes: usize, elapsed_ns: u64) f64 {
            const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
            return @as(f64, @floatFromInt(bytes)) / seconds;
        }
        
        /// Calculate throughput in items per second
        pub fn itemsPerSecond(items: usize, elapsed_ns: u64) f64 {
            const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
            return @as(f64, @floatFromInt(items)) / seconds;
        }
        
        /// Format throughput for display
        pub fn formatBytes(bytes_per_sec: f64) [32]u8 {
            var buf: [32]u8 = undefined;
            
            if (bytes_per_sec >= 1_000_000_000) {
                _ = std.fmt.bufPrint(&buf, "{d:.2} GB/s", .{bytes_per_sec / 1_000_000_000}) catch unreachable;
            } else if (bytes_per_sec >= 1_000_000) {
                _ = std.fmt.bufPrint(&buf, "{d:.2} MB/s", .{bytes_per_sec / 1_000_000}) catch unreachable;
            } else if (bytes_per_sec >= 1000) {
                _ = std.fmt.bufPrint(&buf, "{d:.2} KB/s", .{bytes_per_sec / 1000}) catch unreachable;
            } else {
                _ = std.fmt.bufPrint(&buf, "{d:.2} B/s", .{bytes_per_sec}) catch unreachable;
            }
            
            return buf;
        }
    };
    
    // Import test files
    test {
        _ = @import("perf.test.zig");
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝