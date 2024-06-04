const testing = @import("std").testing;

pub const BitBuffer = struct {
    buffer: u64,
    bufferCursor: usize,
    data: []const u8,
    dataCursor: usize,

    pub fn init(data: []const u8) BitBuffer {
        return BitBuffer{
            .buffer = 0,
            .bufferCursor = 0,
            .data = data,
            .dataCursor = 0,
        };
    }

    fn load(self: *BitBuffer) void {
        if (self.bufferCursor > 32) {
            // We can fit more than 32 but
            // we shouldn't do that to make sure
            // we don't overflow.
            return;
        }

        const nextByte = self.data[self.dataCursor];

        self.buffer |= @as(u64, nextByte) << @truncate(self.bufferCursor);
        self.bufferCursor += 8;
        self.dataCursor += 1;
    }

    pub fn end(self: BitBuffer) bool {
        return self.dataCursor == self.data.len and self.bufferCursor == 0;
    }

    pub fn get(self: *BitBuffer, num: u8) u32 {
        if (num > 32) {
            // At most we can extract out 32 bits
            return 0;
        }

        while (self.bufferCursor < num and self.dataCursor < self.data.len) {
            self.load();
        }

        const num_bits = if (num > self.bufferCursor) self.bufferCursor else num;

        const mask: u64 = (@as(u64, 1) << @truncate(num_bits)) - 1;
        const value = mask & self.buffer;

        self.buffer = self.buffer >> @truncate(num_bits);
        self.bufferCursor -= num_bits;

        return @truncate(value);
    }
};

test "Test Loading BitBuffer" {
    const data = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00 };
    var buffer = BitBuffer.init(&data);

    buffer.load();
    buffer.load();

    try testing.expect(buffer.buffer == 0x00000201);
}

test "Test Getting bits out of BitBuffer" {
    const data = [_]u8{ 0xab, 0xcd, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00 };
    var buffer = BitBuffer.init(&data);

    const n1 = buffer.get(3);
    try testing.expect(n1 == 0x03);

    const n2 = buffer.get(4);
    try testing.expect(n2 == 0x05);

    const n3 = buffer.get(1);
    try testing.expect(n3 == 0x01);

    const n4 = buffer.get(4);
    try testing.expect(n4 == 0x0d);
}

test "Loading big numbers" {
    const data = [_]u8{ 0xab, 0xcd, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 };
    var buffer = BitBuffer.init(&data);

    // Get 4 bits (this will load 8 bits, and leave 4 bits after the get)
    const n1 = buffer.get(4);
    try testing.expect(n1 == 0xb);

    // This will be allowed (max bits) but will have 38 bits in our buffer at some point.
    const n2 = buffer.get(32);
    try testing.expect(n2 == 0x50403cda);
}

// TODO: What should we do if we read after end is true?
test "Empty BitBuffer" {
    const data = [_]u8{ 0xab, 0xcd };
    var buffer = BitBuffer.init(&data);

    try testing.expect(!buffer.end());

    _ = buffer.get(4);
    try testing.expect(!buffer.end());

    _ = buffer.get(3);
    try testing.expect(!buffer.end());

    _ = buffer.get(1);
    try testing.expect(!buffer.end());

    // end of first byte

    _ = buffer.get(5);
    try testing.expect(!buffer.end());

    // 1
    const n1 = buffer.get(2);
    try testing.expect(n1 == 2);
    try testing.expect(!buffer.end());

    const n2 = buffer.get(2);
    try testing.expect(n2 == 1);
    try testing.expect(buffer.end());

    const n3 = buffer.get(2);
    try testing.expect(n3 == 0);
    try testing.expect(buffer.end());
}
