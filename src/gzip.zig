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

const HuffmanTree = struct {
    tree: []i16,
    end: u16,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, lengths: []const u8) !HuffmanTree {
        // NOTE:
        // Step 0 - Allocate our huffman tree, this block of memory will be managed
        // by this struct. We will dealocate this tree when `deinit` is called

        // NOTE: We can guarantee that all nodes will fit in this amount of memory
        // because a huffman tree is by definition a "Full Binary Tree"
        // if this wasn't the case then there would be binary patterns that are not
        // associated with literal values. A full binary tree with N leaves will always
        // have 2*N-1 total nodes.
        //
        // NOTE:
        // Proof
        // N = number of leaves (i.e. literals),
        // I = number of internal nodes,
        // T = Total Nodes (i.e. size of our tree to allocate)
        // T = N + I
        // I = T - N
        // Total number of Edges, E:
        // E = I * 2 => For a full tree every internal node has an edge to another node
        // E = T - 1 => Every node except the root has an edge referencing it
        // E = I * 2 = T - 1
        // (T - N) * 2 = T - 1
        // 2T - 2N = T - 1
        // -T       -T
        //  T - 2N = -1
        //    + 2N =    + 2N
        // T = 2N - 1
        const tree = try allocator.alloc(i16, lengths.len * 2);
        @memset(tree, -1);
        var huff_tree = HuffmanTree{
            .tree = tree,
            .end = 0,
            .allocator = allocator,
        };

        try huff_tree.populate(lengths);

        return huff_tree;
    }

    fn populate(self: *Self, lengths: []const u8) !void {
        const MAX_BITLENGTH = 16;

        // NOTE:
        // Step 1 - Count the number of each code's bitlength
        var counts: [MAX_BITLENGTH]u8 = [_]u8{0} ** MAX_BITLENGTH;
        for (lengths) |len| {
            counts[len] += 1;
        }

        // NOTE:
        // Step 2 - Determine the starting number for each bit length
        var code: u16 = 0;
        var nexts: [MAX_BITLENGTH]u16 = [_]u16{0} ** MAX_BITLENGTH;
        for (1..counts.len) |i| {
            if (counts[i] != 0) {
                code = code + counts[i - 1] << @truncate(1);
                nexts[i] = code;
            }
        }

        // NOTE:
        // Step 3 - Generate the actual codes
        var generated_codes = try self.allocator.alloc(u16, lengths.len);
        defer self.allocator.free(generated_codes);

        for (lengths, 0..) |len, i| {
            generated_codes[i] = nexts[len];
            nexts[len] += 1;
        }

        // NOTE:
        // Step 4 - Insert the codes/literals into the huffman tree
        if (self.end >= self.tree.len) {
            panic("Extra node was attempted to be inserted into the Huffman tree", .{});
        }

        self.end += 2;
        for (generated_codes, 0..) |gen_code, i| {
            const bit_length = lengths[i];

            var tree_index: u16 = 0;
            for (0..bit_length) |offset| {
                if (tree_index >= self.end) {
                    panic("Node doesn't exist", .{});
                }

                // NOTE: We adjust the current tree_index by determining if we're looking at
                // a left or right node
                tree_index = tree_index + (gen_code >> @truncate(bit_length - offset - 1) & 1);

                if (offset == (bit_length - 1)) {
                    // NOTE: This condition is the last iteration
                    // and we want to place the literal value
                    const literal: u16 = @truncate(i);
                    self.tree[tree_index] = @bitCast(literal);
                } else if (self.tree[tree_index] == -1) {
                    if (self.end >= self.tree.len) {
                        panic("Extra node was attempted to be inserted into the Huffman tree", .{});
                    }

                    // NOTE: We need to insert a node if there isn't anything there
                    self.tree[tree_index] = @bitCast(~self.end);
                    self.end += 2;
                }

                const symbol = self.tree[tree_index];

                if (symbol < 0) {
                    // NOTE: take the 1s compliment to convert our number into a
                    // valid index
                    tree_index = @bitCast(~symbol);
                } else if (offset < bit_length - 1) {
                    // NOTE: We should never see a positive number
                    // unless we're on the last iteration
                    panic("Unexpected terminating node", .{});
                }
            }
        }
    }

    fn lookup(self: *Self, bit_buffer: *BitBuffer) u16 {
        var index: u16 = @truncate(bit_buffer.get(1));

        var value = self.tree[index];
        while (value < 0) {
            index = @bitCast(~value);
            index += @truncate(bit_buffer.get(1));
            value = self.tree[index];
        }

        return @bitCast(value);
    }

    fn deinit(self: Self) void {
        self.allocator.free(self.tree);
    }
};

test "Construct a huffman tree" {
    // Based on the example given in RFC-1951
    // Assumes that A=0, B=1, C=2, etc.
    const lengths = [_]u8{ 3, 3, 3, 3, 3, 2, 4, 4 };
    var tree = try HuffmanTree.init(testing.allocator, &lengths);
    defer tree.deinit();

    const expected_tree = [_]i16{ -3, -7, 5, -5, 0, 1, -9, -11, 2, 3, 4, -13, 6, 7 };

    for (0..tree.end) |i| {
        try testing.expect(expected_tree[i] == tree.tree[i]);
    }

    // 11001010  11111110  10111010  10111110
    const buffer = [_]u8{ 0xca, 0xfe, 0xba, 0xbe, 0xfa };
    var bit_buffer = BitBuffer.init(&buffer);

    const expected_decode = "ACEHGDEDHADH";
    var i: usize = 0;
    while (!bit_buffer.end()) {
        const val = @as(u8, @truncate(tree.lookup(&bit_buffer))) + 'A';

        try testing.expect(expected_decode[i] == val);

        i += 1;
    }
}
