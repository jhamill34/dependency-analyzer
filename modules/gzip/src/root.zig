const std = @import("std");

pub fn compress() bool {
    return true;
}

test "Testing compress" {
    try std.testing.expect(compress());
}
