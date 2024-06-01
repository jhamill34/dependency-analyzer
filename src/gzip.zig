const print = @import("std").debug.print;
const panic = @import("std").debug.panic;
const BitBuffer = @import("./bitbuffer.zig").BitBuffer;
const Writer = @import("./io.zig").Writer;

const EncodingMethod = enum(u32) {
    Raw = 0,
    StaticHuffman = 1,
    DynamicHuffman = 2,
    Reserved = 3,
};

pub fn deflate(buffer: *BitBuffer, writer: *Writer) !void {
    const lastBlock = buffer.get(1);
    const encodingMethod: EncodingMethod = @enumFromInt(buffer.get(2));

    if (lastBlock == 1) {
        print("Last block!\n", .{});
    } else {
        print("More blocks remain...\n", .{});
    }

    switch (encodingMethod) {
        .Raw => {
            print("Writing raw data...");
            _ = try writer.write(buffer.data);
        },
        .StaticHuffman => {
            _ = try writer.write("Static huffman isn't implemented, skipping...\n");
        },
        .DynamicHuffman => {
            _ = try writer.write("Dynamic huffman isn't implemented, skipping...\n");
        },
        else => {
            panic("Encoding method is reserved\n", .{});
        },
    }
}
