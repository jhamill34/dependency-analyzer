const panic = @import("std").debug.panic;
const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;
const testing = @import("std").testing;

const BitBuffer = @import("bitbuffer.zig").BitBuffer;

pub const HuffmanTree = struct {
    tree: []i32,
    end: u32,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, lengths: []const u32) !HuffmanTree {
        const MAX_BITLENGTH = 32;

        // NOTE:
        // Step 1 - Count the number of each code's bitlength
        var counts: [MAX_BITLENGTH]u8 = [_]u8{0} ** MAX_BITLENGTH;
        for (lengths) |len| {
            counts[len] += 1;
        }

        // NOTE:
        // Step 2 - Determine the starting number for each bit length
        var code: u32 = 0;
        var nexts: [MAX_BITLENGTH]u32 = [_]u32{0} ** MAX_BITLENGTH;
        for (1..counts.len) |i| {
            code = (code + counts[i - 1]) << @truncate(1);
            nexts[i] = code;
        }

        // NOTE:
        // Step 3 - Generate the actual codes
        var generated_codes = try allocator.alloc(u32, lengths.len);
        defer allocator.free(generated_codes);

        var tree_size: usize = 0;
        for (lengths, 0..) |len, i| {
            if (len != 0) {
                generated_codes[i] = nexts[len];
                nexts[len] += 1;
                tree_size += 1;
            }
        }

        // NOTE: We can guarantee that all nodes will fit in this amount of memory
        // because a huffman tree is by definition a "Full Binary Tree"
        // if this wasn't the case then there would be binary patterns that are not
        // associated with literal values. A full binary tree with N leaves will always
        // have 2*N-1 total nodes. The representation we have is that every pair of
        // indicies is an interior node, which also implies that each index is actually
        // a branch. (See proof at bottom of file).
        const tree = try allocator.alloc(i32, tree_size * 2 - 2);
        @memset(tree, -1);

        // NOTE:
        // Step 4 - Insert the codes/literals into the huffman tree
        var end: u32 = 2;
        for (generated_codes, 0..) |gen_code, i| {
            const bit_length = lengths[i];

            var tree_index: u32 = 0;
            for (0..bit_length) |offset| {
                if (tree_index >= end) {
                    panic("Node doesn't exist", .{});
                }

                // NOTE: We adjust the current tree_index by determining if we're looking at
                // a left or right node
                tree_index = tree_index + (gen_code >> @truncate(bit_length - offset - 1) & 1);

                if (offset == (bit_length - 1)) {
                    // NOTE: This condition is the last iteration
                    // and we want to place the literal value
                    const literal: u32 = @truncate(i);
                    tree[tree_index] = @bitCast(literal);
                } else if (tree[tree_index] == -1) {
                    if (end >= tree.len) {
                        panic("Extra node was attempted to be inserted into the Huffman tree", .{});
                    }

                    // NOTE: We need to insert a node if there isn't anything there
                    tree[tree_index] = @bitCast(~end);
                    end += 2;
                }

                const symbol = tree[tree_index];

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

        return HuffmanTree{
            .tree = tree,
            .end = end,
            .allocator = allocator,
        };
    }

    pub fn lookup(self: *const Self, bit_buffer: *BitBuffer) u32 {
        var index: u32 = @truncate(bit_buffer.get(1));

        var value = self.tree[index];
        while (value < 0) {
            index = @bitCast(~value);
            index += @truncate(bit_buffer.get(1));
            value = self.tree[index];
        }

        return @bitCast(value);
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.tree);
    }
};

test "Construct a huffman tree" {
    // Based on the example given in RFC-1951
    // Assumes that A=0, B=1, C=2, etc.
    const lengths = [_]u32{ 3, 3, 3, 3, 3, 2, 4, 4 };
    const tree = try HuffmanTree.init(testing.allocator, &lengths);
    defer tree.deinit();

    // Assert what the actual tree looks like
    const expected_tree = [_]i16{ -3, -7, 5, -5, 0, 1, -9, -11, 2, 3, 4, -13, 6, 7 };
    for (0..tree.end) |i| {
        try testing.expect(expected_tree[i] == tree.tree[i]);
    }

    // Create the mock compressed file
    const buffer = [_]u8{ 0xca, 0xfe, 0xba, 0xbe, 0xfa };
    var bit_buffer = BitBuffer.init(&buffer);

    // Assert the decoded data
    const expected_decode = "ACEHGDEDHADH";
    var i: usize = 0;
    while (!bit_buffer.end()) {
        const val = @as(u8, @truncate(tree.lookup(&bit_buffer))) + 'A';

        try testing.expect(expected_decode[i] == val);

        i += 1;
    }
}

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
// B = T - 1 = 2N - 2
