const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;
const BitBuffer = @import("../bitbuffer.zig").BitBuffer;
const Writer = @import("../io.zig").Writer;

const HUFFMAN_CODE_LITERAL_ORDER = [_]usize{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

pub const DynamicInflate = struct {
    allocator: Allocator,

    pub fn inflate(_: DynamicInflate, buffer: *BitBuffer, writer: *Writer) !void {
        print("Dynamic inflate...\n", .{});

        const huffman_literal_count = buffer.get(5) + 257;
        const huffman_distance_count = buffer.get(5) + 1;
        const huffman_code_count = buffer.get(4) + 4;

        print("HLIT={d} HDIST={d} HCLEN={d}\n", .{
            huffman_literal_count,
            huffman_distance_count,
            huffman_code_count,
        });

        var huffman_code_lengths: [HUFFMAN_CODE_LITERAL_ORDER.len]u32 = [_]u32{0} ** HUFFMAN_CODE_LITERAL_ORDER.len;

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
};
