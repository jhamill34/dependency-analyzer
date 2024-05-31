const print = @import("std").debug.print;

const BitBuffer = struct { buffer: u64 };

pub fn deflate(data: []const u8) void {
    print("DEFLATE: {d}\n", .{data.len});
}
