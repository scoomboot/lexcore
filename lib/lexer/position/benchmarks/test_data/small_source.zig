// Small Zig source file for benchmarking
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, World!\n", .{});
}

test "simple test" {
    const x = 42;
    try std.testing.expectEqual(@as(i32, 42), x);
}