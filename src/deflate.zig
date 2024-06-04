const print = @import("std").debug.print;
const panic = @import("std").debug.panic;
const Allocator = @import("std").mem.Allocator;
const BitBuffer = @import("bitbuffer.zig").BitBuffer;
const Writer = @import("io.zig").Writer;
const HuffmanTree = @import("huffman.zig").HuffmanTree;

const RawInflate = @import("deflate/raw.zig").RawInflate;
const StaticInflate = @import("deflate/static.zig").StaticInflate;
const DynamicInflate = @import("deflate/dynamic.zig").DynamicInflate;

const EncodingMethod = enum(u32) {
    raw = 0,
    static_huffman = 1,
    dynamic_huffman = 2,
    reserved = 3,
};

const Inflatable = union(enum) {
    raw: RawInflate,
    static: StaticInflate,
    dynamic: DynamicInflate,

    fn initFrom(method: EncodingMethod, allocator: Allocator) Inflatable {
        return switch (method) {
            .raw => Inflatable{ .raw = RawInflate{ .allocator = allocator } },
            .static_huffman => Inflatable{ .static = StaticInflate{ .allocator = allocator } },
            .dynamic_huffman => Inflatable{ .dynamic = DynamicInflate{ .allocator = allocator } },
            else => {
                panic("Unknown encoding method!\n", .{});
            },
        };
    }

    fn inflate(self: Inflatable, buffer: *BitBuffer, writer: *Writer) !void {
        switch (self) {
            inline else => |case| return case.inflate(buffer, writer),
        }
    }
};

pub fn inflate(allocator: Allocator, buffer: *BitBuffer, writer: *Writer) !void {
    // TODO: This needs to happen in a loop! Each block can have a different
    // method
    const lastBlock = buffer.get(1);
    const method: EncodingMethod = @enumFromInt(buffer.get(2));

    if (lastBlock == 1) {
        print("Last block!\n", .{});
    } else {
        print("More blocks remain...\n", .{});
    }

    const inflatable = Inflatable.initFrom(method, allocator);
    try inflatable.inflate(buffer, writer);
}
