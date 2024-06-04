const HuffmanTree = @import("../huffman.zig").HuffmanTree;
const BitBuffer = @import("../bitbuffer.zig").BitBuffer;

const HUFFMAN_EXTRA_LENGTH_BITS = [_]u8{
    0, 0, 0, 0,
    0, 0, 0, 0,
    1, 1, 1, 1,
    2, 2, 2, 2,
    3, 3, 3, 3,
    4, 4, 4, 4,
    5, 5, 5, 5,
    0,
};
const HUFFMAN_LENGTH = [_]u16{
    3,   4,   5,   6,
    7,   8,   9,   10,
    11,  13,  15,  17,
    19,  23,  27,  31,
    35,  43,  51,  59,
    67,  83,  99,  115,
    131, 163, 195, 227,
    258,
};

const HUFFMAN_EXTRA_DISTANCE_BITS = [_]u8{
    0,  0,  0,  0,
    1,  1,  2,  2,
    3,  3,  4,  4,
    5,  5,  6,  6,
    7,  7,  8,  8,
    9,  9,  10, 10,
    11, 11, 12, 12,
    13, 13,
};
const HUFFMAN_DISTANCE = [_]u32{
    1,     2,     3,    4,
    5,     7,     9,    13,
    17,    25,    33,   49,
    65,    97,    129,  193,
    257,   385,   513,  769,
    1025,  1537,  2049, 3073,
    4097,  6145,  8193, 12289,
    16385, 24577,
};

pub fn core_deflate(buffer: *BitBuffer, literal_tree: HuffmanTree, distance_tree: HuffmanTree, out: []u8, output_index: *usize) void {
    var value: u32 = literal_tree.lookup(buffer);
    while (value != 256) {
        if (value < 256) {
            out[output_index.*] = @truncate(value);
            output_index.* += 1;
        } else {
            const offset: u8 = @truncate(value - 257);
            const extra_bits = HUFFMAN_EXTRA_LENGTH_BITS[offset];

            const extra_length = buffer.get(extra_bits);
            const length = HUFFMAN_LENGTH[offset] + extra_length;

            const distance_code = distance_tree.lookup(buffer);
            const distance_extra_bits = HUFFMAN_EXTRA_DISTANCE_BITS[distance_code];

            const extra_distance = buffer.get(distance_extra_bits);
            const distance: usize = HUFFMAN_DISTANCE[distance_code] + extra_distance;

            const start = output_index.* - distance;

            for (0..length) |l| {
                out[output_index.* + l] = out[start + l];
            }

            output_index.* += length;
        }

        value = literal_tree.lookup(buffer);
    }
}
