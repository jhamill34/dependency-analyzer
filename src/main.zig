const std = @import("std");
const Args = @import("args.zig").Args;
const ReadSeeker = @import("io.zig").ReadSeeker;

const zip = @import("zip.zig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const args = getArgs(alloc);
    defer args.deinit();

    var file = std.fs.cwd().openFile(args.filename, .{ .mode = .read_only }) catch {
        std.debug.panic("Unable to open file", .{});
    };
    defer file.close();

    const readSeeker = FileReadSeeker.reader(&file);

    try zip.extractFromArchive(alloc, readSeeker);
}

fn getArgs(alloc: std.mem.Allocator) Args {
    const args = std.process.argsAlloc(alloc) catch {
        std.debug.panic("Failed to get arguments", .{});
    };
    defer std.process.argsFree(alloc, args);

    return Args.init(alloc, args[1..]);
}

const FileReadSeeker = struct {
    fn reader(fileRef: *std.fs.File) ReadSeeker {
        return ReadSeeker{
            .ptr = fileRef,
            .readFn = readFn,
            .seekToFn = seekToFn,
            .getEndPosFn = getEndPosFn,
        };
    }

    fn readFn(ptr: *anyopaque, data: []u8) !usize {
        const self: *const std.fs.File = @ptrCast(@alignCast(ptr));
        return self.read(data);
    }

    fn seekToFn(ptr: *anyopaque, location: u64) !void {
        const self: *const std.fs.File = @ptrCast(@alignCast(ptr));
        return self.seekTo(location);
    }

    fn getEndPosFn(ptr: *anyopaque) !u64 {
        const self: *const std.fs.File = @ptrCast(@alignCast(ptr));
        return self.getEndPos();
    }
};
