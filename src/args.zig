const panic = @import("std").debug.panic;
const testing = @import("std").testing;
const mem = @import("std").mem;

pub const Args = struct {
    filename: []const u8,
    allocator: mem.Allocator,

    pub fn init(alloc: mem.Allocator, args: []const []const u8) Args {
        if (args.len != 1) {
            panic("Not the correct number of arguments.", .{});
        }

        const filename = alloc.dupe(u8, args[0]) catch |err| switch (err) {
            mem.Allocator.Error.OutOfMemory => {
                panic("No memory available to allocate for filename", .{});
            },
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
    const parsedArgs = Args.init(testing.allocator, &args);
    defer parsedArgs.deinit();

    try testing.expect(mem.eql(u8, parsedArgs.filename, "filename.txt"));
}
