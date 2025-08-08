// position_tracking_demo.zig — Demo of position tracking integration
//
// repo   : https://github.com/scoomboot/lexcore  
// docs   : https://scoomboot.github.io/lexcore/examples
// author : https://github.com/scoomboot
//
// Developed with ❤️ by scoomboot.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const Buffer = @import("lexcore").Buffer;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub fn main() !void {
        const allocator = std.heap.page_allocator;
        
        const source =
            \\fn main() {
            \\    const greeting = "Hello, World!";
            \\    std.debug.print("{s}\n", .{greeting});
            \\}
        ;
        
        // Create buffer with position tracking enabled
        var buffer = try Buffer.initWithPositionTracking(allocator, source);
        defer buffer.deinit();
        
        const stdout = std.io.getStdOut().writer();
        
        try stdout.print("Lexing with position tracking:\n\n", .{});
        
        // Consume "fn "
        _ = try buffer.next(); // f
        _ = try buffer.next(); // n
        _ = try buffer.next(); // space
        
        if (buffer.getCurrentPosition()) |pos| {
            try stdout.print("After 'fn ': Line {d}, Column {d}, Offset {d}\n", .{ pos.line, pos.column, pos.offset });
        }
        
        // Mark position before identifier
        buffer.markPosition();
        
        // Consume "main"
        const identifier = try buffer.consumeIdentifier();
        
        if (buffer.getCurrentPosition()) |pos| {
            try stdout.print("After '{s}': Line {d}, Column {d}, Offset {d}\n", .{ identifier, pos.line, pos.column, pos.offset });
        }
        
        // Skip to next line
        while (!buffer.isAtEnd()) {
            const char = try buffer.next();
            if (char == '\n') break;
        }
        
        if (buffer.getCurrentPosition()) |pos| {
            try stdout.print("Start of line 2: Line {d}, Column {d}, Offset {d}\n", .{ pos.line, pos.column, pos.offset });
        }
        
        // Skip whitespace at start of line
        _ = try buffer.consumeWhitespace();
        
        if (buffer.getCurrentPosition()) |pos| {
            try stdout.print("After indentation: Line {d}, Column {d}, Offset {d}\n", .{ pos.line, pos.column, pos.offset });
        }
        
        // Restore to marked position
        try buffer.restoreMark();
        
        if (buffer.getCurrentPosition()) |pos| {
            try stdout.print("Restored to before 'main': Line {d}, Column {d}, Offset {d}\n", .{ pos.line, pos.column, pos.offset });
        }
        
        // Demonstrate disabling and re-enabling position tracking
        buffer.disablePositionTracking();
        try stdout.print("\nPosition tracking disabled\n", .{});
        
        _ = try buffer.next();
        if (buffer.getCurrentPosition() == null) {
            try stdout.print("Position is null (as expected)\n", .{});
        }
        
        try buffer.enablePositionTracking();
        try stdout.print("\nPosition tracking re-enabled\n", .{});
        
        if (buffer.getCurrentPosition()) |pos| {
            try stdout.print("Current position: Line {d}, Column {d}, Offset {d}\n", .{ pos.line, pos.column, pos.offset });
        }
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝