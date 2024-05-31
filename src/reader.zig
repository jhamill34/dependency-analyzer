const panic = @import("std").debug.panic;
const Allocator = @import("std").mem.Allocator;

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
            @memcpy(data[dataIndex..], self.buffer[self.current..][0..bytesLeft]);

            dataIndex += bytesLeft;

            try self.loadData();

            bytesLeft = self.loaded - self.current;
            remainingData = data.len - dataIndex;
        }

        @memcpy(data[dataIndex..], self.buffer[self.current..][0..remainingData]);
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
