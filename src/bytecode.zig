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

const ConstantType = enum(u8) {
    Utf8 = 1,
    Integer = 3,
    Float = 4,
    Long = 5,
    Double = 6,
    Class = 7,
    String = 8,
    Fieldref = 9,
    Methodref = 10,
    InterfaceMethodref = 11,
    NameAndType = 12,
    MethodHandle = 15,
    MethodType = 16,
    InvokeDynamic = 18,
};

const ConstantTypeInfo = union(enum) {
    fn from(t: ConstantType) ConstantTypeInfo {
        switch (t) {
            .Utf8 => {},
            .Integer => {},
            .Float => {},
            .Long => {},
            .Double => {},
            .Class => {},
            .String => {},
            .Fieldref => {},
            .Methodref => {},
            .InterfaceMethodref => {},
            .NameAndType => {},
            .MethodHandle => {},
            .MethodType => {},
            .InvokeDynamic => {},
        }
    }
};

const Constant = struct {
    tag: ConstantType,
    info: ConstantTypeInfo,

    fn initFromReader(_: Allocator, r: *reader.ReadManager) !Constant {
        const tagNumber = try r.readBENumber(u8);
        const tag: ConstantType = @enumFromInt(tagNumber);
        const info = ConstantTypeInfo.from(tag);

        return Constant{
            .tag = tag,
            .info = info,
        };
    }
};
