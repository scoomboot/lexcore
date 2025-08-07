// main.zig — Entry point for lexcore executable
//
// repo   : https://github.com/scoomboot/lexcore
// docs   : https://scoomboot.github.io/lexcore
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.



// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const lexcore = @import("lexcore");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝



// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub fn main() !void {
        // Prints to stderr for debugging
        std.debug.print("lexcore v{}.{}.{}\n", .{
            lexcore.version.major,
            lexcore.version.minor,
            lexcore.version.patch,
        });
        
        // TODO: Add CLI functionality for parsing Zig source files
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝



// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: main: basic memory management" {
        var list = std.ArrayList(i32).init(std.testing.allocator);
        defer list.deinit();
        
        try list.append(42);
        try std.testing.expectEqual(@as(i32, 42), list.pop());
    }

    test "unit: main: fuzz testing example" {
        const Context = struct {
            fn testOne(context: @This(), input: []const u8) anyerror!void {
                _ = context;
                // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
                try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
            }
        };
        try std.testing.fuzz(Context{}, Context.testOne, .{});
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝