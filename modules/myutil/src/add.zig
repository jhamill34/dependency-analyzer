const std = @import("std");

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "run add tests" {
    try std.testing.expect(add(10, 20) == 30);
}
