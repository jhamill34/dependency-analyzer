const std = @import("std");
const Args = @import("./args.zig").Args;
const Reader = @import("./reader.zig").Reader;

const zip = @import("./zip.zig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const args = getArgs(alloc);
    defer args.deinit();

    const file = std.fs.cwd().openFile(args.filename, .{ .mode = .read_only }) catch {
        std.debug.panic("Unable to open file", .{});
    };

    var buffer: [4096]u8 = undefined;
    var reader = Reader.init(file, &buffer);

    const pos = try zip.findEndOfCentralDirectoryRecord(&reader);

    std.debug.print("EOCD found at: {d}\n", .{pos});

    const eocd = try zip.EndOfCentralDirectoryRecord.parse(&reader);

    var string = std.ArrayList(u8).init(alloc);
    try std.json.stringify(eocd, .{}, string.writer());
    std.debug.print("{s}\n", .{string.items});
}

fn getArgs(alloc: std.mem.Allocator) Args {
    const args = std.process.argsAlloc(alloc) catch {
        std.debug.panic("Failed to get arguments", .{});
    };
    defer std.process.argsFree(alloc, args);

    return Args.init(alloc, args[1..]);
}
