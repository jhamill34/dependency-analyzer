const panic = @import("std").debug.panic;

const Allocator = @import("std").mem.Allocator;
const testing = @import("std").testing;
const mem = @import("std").mem;

pub const ReadSeeker = struct {
    ptr: *anyopaque,
    readFn: *const fn (ptr: *anyopaque, data: []u8) anyerror!usize,
    seekToFn: *const fn (ptr: *anyopaque, location: u64) anyerror!void,
    getEndPosFn: *const fn (ptr: *anyopaque) anyerror!u64,

    pub fn read(self: ReadSeeker, data: []u8) !usize {
        return self.readFn(self.ptr, data);
    }

    pub fn seekTo(self: ReadSeeker, location: u64) !void {
        return self.seekToFn(self.ptr, location);
    }

    pub fn getEndPos(self: ReadSeeker) !u64 {
        return self.getEndPosFn(self.ptr);
    }
};

pub const ReadManager = struct {
    buffer: []u8,
    current: usize = 0,
    loaded: usize = 0,
    readSeeker: ReadSeeker,

    const Self = @This();

    pub fn init(readSeeker: ReadSeeker, buffer: []u8) Self {
        return .{
            .current = 0,
            .loaded = 0,
            .buffer = buffer,
            .readSeeker = readSeeker,
        };
    }

    pub fn setCursor(self: *Self, location: u64) !void {
        try self.readSeeker.seekTo(location);

        self.loaded = 0;
        self.current = 0;
    }

    pub fn loadData(self: *Self) !void {
        const bytesLeft = self.loaded - self.current;

        if (bytesLeft > 0) {
            @memcpy(self.buffer[0..bytesLeft], self.buffer[self.current..self.loaded]);
        }

        self.loaded = bytesLeft;
        self.current = 0;
        self.loaded += try self.readSeeker.read(self.buffer[self.loaded..]);

        if (self.loaded == 0) {
            @memset(self.buffer, 0);
        }
    }

    pub fn readNumber(self: *Self, T: type) !T {
        const size = @sizeOf(T);

        const bytesLeft = self.loaded - self.current;
        if (bytesLeft < size) {
            try self.loadData();
        }

        var value: T = 0;
        for (self.buffer[self.current..][0..size], 0..) |b, i| {
            value |= @as(T, b) << @truncate(i * 8);
        }

        self.current += size;

        return value;
    }

    pub fn readStruct(self: *Self, T: type) !T {
        const typeInfo = @typeInfo(T);

        var result: T = undefined;

        inline for (typeInfo.Struct.fields) |f| {
            switch (@typeInfo(f.type)) {
                .Int => {
                    @field(result, f.name) = try self.readNumber(f.type);
                },
                else => {
                    panic("Unknown serialization type", .{});
                },
            }
        }

        return result;
    }

    pub fn read(self: *Self, data: []u8) !usize {
        var bytesLeft = self.loaded - self.current;
        if (bytesLeft >= data.len) {
            @memcpy(data, self.buffer[self.current..][0..data.len]);
            self.current += data.len;
            return data.len;
        }

        var dataIndex: usize = 0;
        var remainingData = data.len - dataIndex;
        while (remainingData > bytesLeft) {
            @memcpy(data[dataIndex..][0..bytesLeft], self.buffer[self.current..][0..bytesLeft]);

            self.current += bytesLeft;
            dataIndex += bytesLeft;

            try self.loadData();

            bytesLeft = self.loaded - self.current;
            remainingData = data.len - dataIndex;
        }

        @memcpy(data[dataIndex..][0..remainingData], self.buffer[self.current..][0..remainingData]);
        self.current += remainingData;

        return data.len;
    }

    pub fn readAlloc(self: *Self, allocator: Allocator, amount: usize) ![]const u8 {
        const data = try allocator.alloc(u8, amount);
        _ = try self.read(data);
        return data;
    }
};

pub fn sliceToNumber(T: type, buffer: []u8) T {
    var value: T = 0;
    for (buffer, 0..) |b, i| {
        value |= @as(T, b) << @truncate(i * 8);
    }

    return value;
}

const TestSeeker = struct {
    buffer: []const u8,
    cursor: usize,
    systemCalls: u8,

    fn init(buffer: []u8) TestSeeker {
        return TestSeeker{
            .buffer = buffer,
            .cursor = 0,
            .systemCalls = 0,
        };
    }

    fn reader(self: *TestSeeker) ReadSeeker {
        return ReadSeeker{
            .ptr = self,
            .readFn = readFn,
            .seekToFn = seekToFn,
            .getEndPosFn = getEndPosFn,
        };
    }

    fn readFn(ptr: *anyopaque, data: []u8) !usize {
        const self: *TestSeeker = @ptrCast(@alignCast(ptr));
        const bytesLeft = self.buffer.len - self.cursor;

        if (bytesLeft == 0) {
            return 0;
        }

        if (bytesLeft < data.len) {
            @memcpy(data[0..bytesLeft], self.buffer[self.cursor..]);
            self.systemCalls += 1;
            self.cursor = self.buffer.len;
            return bytesLeft;
        }

        @memcpy(data, self.buffer[self.cursor..][0..data.len]);
        self.systemCalls += 1;
        self.cursor += data.len;
        return data.len;
    }

    fn seekToFn(ptr: *anyopaque, location: u64) !void {
        const self: *TestSeeker = @ptrCast(@alignCast(ptr));
        self.cursor = location;
    }

    fn getEndPosFn(ptr: *anyopaque) !u64 {
        const self: *TestSeeker = @ptrCast(@alignCast(ptr));
        return self.buffer.len - 1;
    }
};

const TestStruct = struct {
    n1: u32,
    n2: u16,
    n3: u16,
};

test "Simple Reader" {
    // This is our buffer that we will use to reduce the number of system calls
    // For implementation details reasons, it needs to be at least as big as the
    // largest number you want to load
    // (i.e. if u32 then the smallest buffer needs to be 4)
    var buffer: [4]u8 = undefined;

    // This is mimicing a file
    var data = [_]u8{ 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x03, 0x00 };
    var testSeeker = TestSeeker.init(&data);

    // Create our interface
    const readSeeker = (&testSeeker).reader();

    // The manger will interface with our read seeker
    var reader = ReadManager.init(readSeeker, &buffer);

    try testing.expect(testSeeker.systemCalls == 0);

    const n1 = try reader.readNumber(u32);
    try testing.expect(n1 == 1);
    try testing.expect(testSeeker.systemCalls == 1);

    const n2 = try reader.readNumber(u16);
    try testing.expect(n2 == 2);
    try testing.expect(testSeeker.systemCalls == 2);

    const n3 = try reader.readNumber(u16);
    try testing.expect(testSeeker.systemCalls == 2);
    try testing.expect(n3 == 3);
}

test "Simple Reader of structs" {
    var buffer: [4]u8 = undefined;

    var data = [_]u8{ 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x03, 0x00 };
    var testSeeker = TestSeeker.init(&data);

    const readSeeker = (&testSeeker).reader();

    var reader = ReadManager.init(readSeeker, &buffer);

    try testing.expect(testSeeker.systemCalls == 0);

    const ts = try reader.readStruct(TestStruct);
    try testing.expect(testSeeker.systemCalls == 2);

    try testing.expect(ts.n1 == 1);
    try testing.expect(ts.n2 == 2);
    try testing.expect(ts.n3 == 3);
}

test "Simple Reader into buffer" {
    var buffer: [4]u8 = undefined;

    var data = [_]u8{
        0x01, 0x00, 'H', 'e',
        'l',  'l',  'o', 0x02,
        0x00, 0x00,
    };
    var testSeeker = TestSeeker.init(&data);

    const readSeeker = (&testSeeker).reader();

    var reader = ReadManager.init(readSeeker, &buffer);

    const n1 = try reader.readNumber(u16);
    try testing.expect(n1 == 1);

    const str = try reader.readAlloc(testing.allocator, 5);
    defer testing.allocator.free(str);

    try testing.expect(mem.eql(u8, "Hello", str));

    const n2 = try reader.readNumber(u16);
    try testing.expect(n2 == 2);

    const zero = try reader.readNumber(u16);
    try testing.expect(zero == 0);
}

test "Jump Cursor around" {
    var buffer: [4]u8 = undefined;

    var data = [_]u8{
        0x01, 0x00, 'H', 'e',
        'l',  'l',  'o', 0x02,
        0xab, 0xcd,
    };
    var testSeeker = TestSeeker.init(&data);

    const readSeeker = (&testSeeker).reader();

    var reader = ReadManager.init(readSeeker, &buffer);

    const end = try readSeeker.getEndPos();
    try reader.setCursor(end - 1);

    const n1 = try reader.readNumber(u16);
    try testing.expect(n1 == 0xcdab);
}
