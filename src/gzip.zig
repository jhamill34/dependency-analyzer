const print = @import("std").debug.print;
const panic = @import("std").debug.panic;
const BitBuffer = @import("./bitbuffer.zig").BitBuffer;

const EncodingMethod = enum(u32) {
    Raw = 0,
    StaticHuffman = 1,
    DynamicHuffman = 2,
    Reserved = 3,
};

pub fn deflate(buffer: *BitBuffer) void {
    const lastBlock = buffer.get(1);
    const encodingMethod: EncodingMethod = @enumFromInt(buffer.get(2));

    if (lastBlock == 1) {
        print("Last block!\n", .{});
    } else {
        print("More blocks remain...\n", .{});
    }

    switch (encodingMethod) {
        .Raw => {
            print("Raw encoding isn't implemented, skipping...\n", .{});
        },
        .StaticHuffman => {
            print("Static huffman isn't implemented, skipping...\n", .{});
        },
        .DynamicHuffman => {
            print("Dynamic huffman isn't implemented, skipping...\n", .{});
        },
        else => {
            panic("Encoding method is reserved\n", .{});
        },
    }
}
