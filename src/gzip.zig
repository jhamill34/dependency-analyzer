const print = @import("std").debug.print;
const panic = @import("std").debug.panic;
const Allocator = @import("std").mem.Allocator;
const BitBuffer = @import("./bitbuffer.zig").BitBuffer;
const Writer = @import("./io.zig").Writer;

const testing = @import("std").testing;

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

fn raw_inflate(_: *BitBuffer, writer: *Writer) !void {
    print("Writing raw data...", .{});
    _ = try writer.write("Raw data isn't implemented, skipping...\n");
}

fn static_inflate(_: *BitBuffer, writer: *Writer) !void {
    print("Static inflate...", .{});
    _ = try writer.write("Static huffman isn't implemented, skipping...\n");
}

const HUFFMAN_CODE_LITERAL_ORDER = [_]usize{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

fn dynamic_inflate(buffer: *BitBuffer, writer: *Writer) !void {
    print("Dynamic inflate...\n", .{});

    const huffman_literal_count = buffer.get(5) + 257;
    const huffman_distance_count = buffer.get(5) + 1;
    const huffman_code_count = buffer.get(4) + 4;

    print("HLIT={d} HDIST={d} HCLEN={d}\n", .{
        huffman_literal_count,
        huffman_distance_count,
        huffman_code_count,
    });

    var huffman_code_lengths: [HUFFMAN_CODE_LITERAL_ORDER.len]u32 = undefined;
    @memset(&huffman_code_lengths, 0);

    for (0..huffman_code_count) |i| {
        const len = buffer.get(3);
        const literal_index = HUFFMAN_CODE_LITERAL_ORDER[i];

        huffman_code_lengths[literal_index] = len;
    }

    for (huffman_code_lengths, 0..) |len, i| {
        print("  {d} {d}\n", .{ i, len });
    }

    _ = try writer.write("Dynamic huffman isn't implemented, skipping...\n");
}

const HuffmanNode = packed struct {
    left: i32,
    right: i32,
};

const HuffmanTree = struct {
    tree: []HuffmanNode,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, _: []const u8) !HuffmanTree {
        const tree = try allocator.alloc(HuffmanNode, 10);

        return HuffmanTree{
            .tree = tree,
            .allocator = allocator,
        };
    }

    fn deinit(self: Self) void {
        self.allocator.free(self.tree);
    }
};

test "Construct a huffman tree" {
    // Based on the example given in RFC-1951
    // Assumes that A=0, B=1, C=2, etc.
    const lengths = [_]u8{ 3, 3, 3, 3, 3, 2, 4, 4 };
    const result = try HuffmanTree.init(testing.allocator, &lengths);
    defer result.deinit();
}
