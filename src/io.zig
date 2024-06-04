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

pub const Writer = struct {
    ptr: *anyopaque,
    writeFn: *const fn (ptr: *anyopaque, filename: []const u8, data: []const u8) anyerror!usize,

    pub fn write(self: Writer, filename: []const u8, data: []const u8) !usize {
        return self.writeFn(self.ptr, filename, data);
    }
};
