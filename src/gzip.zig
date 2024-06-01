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

pub fn inflate(buffer: *BitBuffer, writer: *Writer) !void {
    const lastBlock = buffer.get(1);
    const encodingMethod: EncodingMethod = @enumFromInt(buffer.get(2));

    if (lastBlock == 1) {
        print("Last block!\n", .{});
    } else {
        print("More blocks remain...\n", .{});
    }

    switch (encodingMethod) {
        .Raw => try raw_inflate(buffer, writer),
        .StaticHuffman => try static_inflate(buffer, writer),
        .DynamicHuffman => try dynamic_inflate(buffer, writer),
        else => {
            panic("Encoding method is reserved\n", .{});
        },
    }
}

fn raw_inflate(buffer: *BitBuffer, writer: *Writer) !void {
    print("Writing raw data...", .{});
    _ = try writer.write(buffer.data);
}

fn static_inflate(_: *BitBuffer, writer: *Writer) !void {
    print("Static inflate...", .{});
    _ = try writer.write("Static huffman isn't implemented, skipping...\n");
}

fn dynamic_inflate(_: *BitBuffer, writer: *Writer) !void {
    print("Dynamic inflate...", .{});
    _ = try writer.write("Dynamic huffman isn't implemented, skipping...\n");
}
