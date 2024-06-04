const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;
const BitBuffer = @import("../bitbuffer.zig").BitBuffer;

pub const RawInflate = struct {
    pub fn inflate(_: RawInflate, buffer: *BitBuffer, out: []u8, output_index: *usize) !void {
        const len = buffer.get(16);
        _ = buffer.get(16);

        @memcpy(out[output_index.*..(output_index.* + len)], buffer.data[4..(len + 4)]);
        output_index.* += len;
    }
};
