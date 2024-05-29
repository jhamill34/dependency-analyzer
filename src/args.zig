const std = @import("std");

pub const Args = struct {
    filename: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, args: []const []const u8) Args {
        if (args.len != 1) {
            std.debug.panic("Not the correct number of arguments.", .{});
        }

        const filename = alloc.dupe(u8, args[0]) catch {
            std.debug.panic("Unable to copy memory.", .{});
        };

        return Args{
            .filename = filename,
            .allocator = alloc,
        };
    }

    pub fn deinit(self: Args) void {
        self.allocator.free(self.filename);
    }
};

test "parse arguments" {
    const args = [_][]const u8{"filename.txt"};
    const parsedArgs = Args.init(std.testing.allocator, &args);
    defer parsedArgs.deinit();

    try std.testing.expect(std.mem.eql(u8, parsedArgs.filename, "filename.txt"));
}
