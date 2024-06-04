const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;
const BitBuffer = @import("../bitbuffer.zig").BitBuffer;
const Writer = @import("../io.zig").Writer;

pub const RawInflate = struct {
    allocator: Allocator,

    pub fn inflate(_: RawInflate, _: *BitBuffer, writer: *Writer) !void {
        _ = try writer.write("Unimplemented raw inflate... skipping\n");
    }
};
