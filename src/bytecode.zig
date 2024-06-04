const std = @import("std");

const Allocator = @import("std").mem.Allocator;
const Writer = @import("./io.zig").Writer;
const reader = @import("./reader.zig");

const BYTECODE_MAGIC = 0xcafebabe;

pub const BytecodeWriter = struct {
    allocator: Allocator,

    pub fn writer(self: *BytecodeWriter) Writer {
        return Writer{
            .ptr = self,
            .writeFn = writeFn,
        };
    }

    pub fn writeFn(ptr: *anyopaque, filename: []const u8, data: []const u8) !usize {
        const self: *BytecodeWriter = @ptrCast(@alignCast(ptr));
        std.debug.print("{s}\n", .{filename});

        var buffer: [1024]u8 = undefined;
        var seeker = reader.BufferSeeker.init(data);

        var readManager = reader.ReadManager.init(seeker.reader(), &buffer);

        const magic = try readManager.readBENumber(u32);
        if (magic != BYTECODE_MAGIC) {
            std.debug.print("Not a java class file...skipping\n", .{});
            return 0;
        }

        const class = ClassFile.initFromReader(self.allocator, &readManager);

        std.debug.print("{any}\n", .{class});

        return 0;
    }
};

const ClassFile = struct {
    minor_version: u16,
    major_version: u16,
    constants: []Constant,

    fn initFromReader(allocator: Allocator, r: *reader.ReadManager) !ClassFile {
        const major = try r.readBENumber(u16);
        const minor = try r.readBENumber(u16);

        const contant_count = try r.readBENumber(u16);
        var constants = try allocator.alloc(Constant, contant_count - 1);
        for (0..(contant_count - 1)) |i| {
            constants[i] = try Constant.initFromReader(allocator, r);
        }

        return ClassFile{
            .minor_version = major,
            .major_version = minor,
            .constants = constants,
        };
    }
};

const Constant = struct {
    tag: u8,

    fn initFromReader(_: Allocator, r: *reader.ReadManager) !Constant {
        const tag = try r.readBENumber(u8);

        return Constant{
            .tag = tag,
        };
    }
};
