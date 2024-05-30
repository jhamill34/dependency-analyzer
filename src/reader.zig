const std = @import("std");

pub const Reader = struct {
    buffer: []u8,
    current: usize = 0,
    loaded: usize = 0,
    fileRef: std.fs.File,

    const Self = @This();

    pub fn init(file: std.fs.File, buffer: []u8) Self {
        return .{
            .current = 0,
            .loaded = 0,
            .buffer = buffer,
            .fileRef = file,
        };
    }

    pub fn setCursor(self: *Self, location: u64) !void {
        try self.fileRef.seekTo(location);

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
        self.loaded += try self.fileRef.read(self.buffer[self.loaded..]);
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
};

pub fn sliceToNumber(T: type, buffer: []u8) T {
    var value: T = 0;
    for (buffer, 0..) |b, i| {
        value |= @as(T, b) << @truncate(i * 8);
    }

    return value;
}
