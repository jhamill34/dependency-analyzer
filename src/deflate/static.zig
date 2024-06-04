const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;
const BitBuffer = @import("../bitbuffer.zig").BitBuffer;
const Writer = @import("../io.zig").Writer;

pub const StaticInflate = struct {
    allocator: Allocator,

    pub fn inflate(_: StaticInflate, _: *BitBuffer, writer: *Writer) !void {
        _ = try writer.write("Unimplemented static inflate... skipping\n");
    }
};
