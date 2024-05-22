const std = @import("std");
const stdout = std.io.getStdOut().writer();

const add = @import("add");
const sub = @import("sub");

pub fn main() !void {
    const addR = add.add(10, 10);
    const subR = sub.sub(30, 10);
    try stdout.print("Hello, world, {d}, {d}", .{ addR, subR });
}
