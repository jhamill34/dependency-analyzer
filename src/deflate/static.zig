const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;
const BitBuffer = @import("../bitbuffer.zig").BitBuffer;
const HuffmanTree = @import("../huffman.zig").HuffmanTree;

const core = @import("core.zig");

const STATIC_DISTANCE_LENGTHS = [_]u32{5} ** 32;
const STATIC_LITERAL_LENGTHS = [_]u32{8} ** 144 ++ [_]u8{9} ** 112 ++ [_]u8{7} ** 24 ++ [_]u8{8} ** 8;

pub const StaticInflate = struct {
    allocator: Allocator,

    pub fn inflate(self: StaticInflate, buffer: *BitBuffer, out: []u8, output_index: *usize) !void {
        const huffman_literal_tree = try HuffmanTree.init(
            self.allocator,
            &STATIC_LITERAL_LENGTHS,
        );
        defer huffman_literal_tree.deinit();

        const huffman_distance_tree = try HuffmanTree.init(
            self.allocator,
            &STATIC_DISTANCE_LENGTHS,
        );
        defer huffman_distance_tree.deinit();

        core.core_deflate(buffer, huffman_literal_tree, huffman_distance_tree, out, output_index);
    }
};
