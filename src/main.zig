const std = @import("std");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const args = Args.init(alloc);
    defer args.deinit();

    std.debug.print("Filename: {s}\n", .{args.filename});
}

const Args = struct {
    filename: []const u8,
    allocator: std.mem.Allocator,

    fn init(alloc: std.mem.Allocator) Args {
        const args = std.process.argsAlloc(alloc) catch {
            std.debug.panic("Unable to get args.", .{});
        };
        defer std.process.argsFree(alloc, args);

        if (args.len != 2) {
            std.debug.panic("Not the correct number of arguments.", .{});
        }

        // NOTE: We'll free this in thie deinit method
        const filename = alloc.dupe(u8, args[1]) catch {
            std.debug.panic("Unable to copy memory.", .{});
        };

        return Args{
            .filename = filename,
            .allocator = alloc,
        };
    }

    fn deinit(self: Args) void {
        self.allocator.free(self.filename);
    }
};
