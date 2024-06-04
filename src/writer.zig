const std = @import("std");

const Writer = @import("./io.zig").Writer;

pub const FileWriter = struct {
    pub fn writer(fileRef: *std.fs.File) Writer {
        return Writer{
            .ptr = fileRef,
            .writeFn = writeFn,
        };
    }

    pub fn writeFn(ptr: *anyopaque, _: []const u8, data: []const u8) !usize {
        const self: *std.fs.File = @ptrCast(@alignCast(ptr));
        return self.write(data);
    }
};
