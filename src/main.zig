const std = @import("std");
const Args = @import("./args.zig").Args;

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const args = getArgs(alloc);
    defer args.deinit();

    std.debug.print("Filename: {s}\n", .{args.filename});
}

fn getArgs(alloc: std.mem.Allocator) Args {
    const args = std.process.argsAlloc(alloc) catch {
        std.debug.panic("Failed to get arguments", .{});
    };
    defer std.process.argsFree(alloc, args);

    return Args.init(alloc, args[1..]);
}
