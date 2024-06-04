const panic = @import("std").debug.panic;
const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;
const BitBuffer = @import("../bitbuffer.zig").BitBuffer;
const Writer = @import("../io.zig").Writer;
const HuffmanTree = @import("../huffman.zig").HuffmanTree;

const core = @import("core.zig");

const HUFFMAN_CODE_LITERAL_ORDER = [_]usize{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

const TOTAL_LITERALS = 286;
const TOTAL_DISTANCES = 32;

pub const DynamicInflate = struct {
    allocator: Allocator,

    pub fn inflate(self: DynamicInflate, buffer: *BitBuffer, out: []u8, output_index: *usize) !void {
        print("Dynamic inflate...\n", .{});

        const huffman_literal_count = buffer.get(5) + 257;
        const huffman_distance_count = buffer.get(5) + 1;
        const huffman_code_count = buffer.get(4) + 4;

        var huffman_code_lengths: [HUFFMAN_CODE_LITERAL_ORDER.len]u32 = [_]u32{0} ** HUFFMAN_CODE_LITERAL_ORDER.len;

        for (0..huffman_code_count) |i| {
            const len = buffer.get(3);
            const literal_index = HUFFMAN_CODE_LITERAL_ORDER[i];

            huffman_code_lengths[literal_index] = len;
        }

        const huffman_litdist_lengths = try self.allocator.alloc(
            u32,
            huffman_literal_count + huffman_distance_count,
        );
        defer self.allocator.free(huffman_litdist_lengths);

        {
            const code_length_tree = try HuffmanTree.init(self.allocator, &huffman_code_lengths);
            defer code_length_tree.deinit();

            var count_index: u32 = 0;
            while (count_index < huffman_litdist_lengths.len) {
                const literal = code_length_tree.lookup(buffer);

                if (literal < 16) {
                    huffman_litdist_lengths[count_index] = literal;
                    count_index += 1;
                } else if (literal == 16) {
                    const extra = buffer.get(2) + 3;
                    const prev_literal = huffman_litdist_lengths[count_index - 1];
                    @memset(huffman_litdist_lengths[count_index..(count_index + extra)], prev_literal);
                    count_index += extra;
                } else if (literal == 17) {
                    const extra = buffer.get(3) + 3;
                    @memset(huffman_litdist_lengths[count_index..(count_index + extra)], 0);
                    count_index += extra;
                } else if (literal == 18) {
                    const extra = buffer.get(7) + 11;
                    @memset(huffman_litdist_lengths[count_index..(count_index + extra)], 0);
                    count_index += extra;
                } else {
                    panic("Unknown literal value", .{});
                }
            }
        }

        const huffman_literal_tree = try HuffmanTree.init(
            self.allocator,
            huffman_litdist_lengths[0..huffman_literal_count],
        );
        defer huffman_literal_tree.deinit();

        const huffman_distance_tree = try HuffmanTree.init(
            self.allocator,
            huffman_litdist_lengths[huffman_literal_count..(huffman_literal_count + huffman_distance_count)],
        );
        defer huffman_distance_tree.deinit();

        core.core_deflate(buffer, huffman_literal_tree, huffman_distance_tree, out, output_index);
    }
};
