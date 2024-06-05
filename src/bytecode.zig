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

        const class = try ClassFile.initFromReader(self.allocator, &readManager);
        std.debug.print("{any}", .{class});

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

// NOTE: Section 4.4.1

const ClassInfo = struct {
    name_index: u16,
};

// NOTE: Section 4.4.2

const FieldrefInfo = struct {
    class_index: u16,
    name_and_type_index: u16,
};

const MethodrefInfo = struct {
    class_index: u16,
    name_and_type_index: u16,
};

const InterfaceMethodrefInfo = struct {
    class_index: u16,
    name_and_type_index: u16,
};

// NOTE: Section 4.4.3

const StringInfo = struct {
    string_index: u16,
};

// NOTE: Section 4.4.4

const IntegerInfo = struct {
    bytes: u32,
};

const FloatInfo = struct {
    bytes: u32,
};

// NOTE: Section 4.4.5

const LongInfo = struct {
    high_bytes: u32,
    low_bytes: u32,
};

const DoubleInfo = struct {
    high_bytes: u32,
    low_bytes: u32,
};

// NOTE: Section 4.4.6

const NameAndTypeInfo = struct {
    name_index: u16,
    descriptor_index: u16,
};

// NOTE: Section 4.4.7

const Utf8Info = struct {
    length: u16,
    bytes: []const u8,

    fn initFromReader(allocator: Allocator, r: *reader.ReadManager) !Utf8Info {
        const length = try r.readBENumber(u16);
        const bytes = try r.readAlloc(allocator, length);

        return .{
            .length = length,
            .bytes = bytes,
        };
    }
};

// NOTE: Section 4.4.8

const MethodHandleInfo = struct {
    reference_kind: u8,
    reference_index: u16,
};

// NOTE: Section 4.4.9

const MethodTypeInfo = struct {
    descriptor_index: u16,
};

// NOTE: Section 4.4.10

const InvokeDynamicInfo = struct {
    bootstrap_method_attr_index: u16,
    name_and_type_index: u16,
};

const ConstantTypeInfo = union(enum) {
    Utf8: Utf8Info,
    Integer: IntegerInfo,
    Float: FloatInfo,
    Long: LongInfo,
    Double: DoubleInfo,
    Class: ClassInfo,
    String: StringInfo,
    Fieldref: FieldrefInfo,
    Methodref: MethodrefInfo,
    InterfaceMethodref: InterfaceMethodrefInfo,
    NameAndType: NameAndTypeInfo,
    MethodHandle: MethodHandleInfo,
    MethodType: MethodTypeInfo,
    InvokeDynamic: InvokeDynamicInfo,

    fn from(t: ConstantType, allocator: Allocator, r: *reader.ReadManager) !ConstantTypeInfo {
        return switch (t) {
            .Utf8 => ConstantTypeInfo{ .Utf8 = try Utf8Info.initFromReader(allocator, r) },
            .Integer => ConstantTypeInfo{ .Integer = try r.readBEStruct(IntegerInfo) },
            .Float => ConstantTypeInfo{ .Float = try r.readBEStruct(FloatInfo) },
            .Long => ConstantTypeInfo{ .Long = try r.readBEStruct(LongInfo) },
            .Double => ConstantTypeInfo{ .Double = try r.readBEStruct(DoubleInfo) },
            .Class => ConstantTypeInfo{ .Class = try r.readBEStruct(ClassInfo) },
            .String => ConstantTypeInfo{ .String = try r.readBEStruct(StringInfo) },
            .Fieldref => ConstantTypeInfo{ .Fieldref = try r.readBEStruct(FieldrefInfo) },
            .Methodref => ConstantTypeInfo{ .Methodref = try r.readBEStruct(MethodrefInfo) },
            .InterfaceMethodref => ConstantTypeInfo{ .InterfaceMethodref = try r.readBEStruct(InterfaceMethodrefInfo) },
            .NameAndType => ConstantTypeInfo{ .NameAndType = try r.readBEStruct(NameAndTypeInfo) },
            .MethodHandle => ConstantTypeInfo{ .MethodHandle = try r.readBEStruct(MethodHandleInfo) },
            .MethodType => ConstantTypeInfo{ .MethodType = try r.readBEStruct(MethodTypeInfo) },
            .InvokeDynamic => ConstantTypeInfo{ .InvokeDynamic = try r.readBEStruct(InvokeDynamicInfo) },
        };
    }
};

const Constant = struct {
    tag: ConstantType,
    info: ConstantTypeInfo,

    fn initFromReader(allocator: Allocator, r: *reader.ReadManager) !Constant {
        const tagNumber = try r.readBENumber(u8);
        const tag: ConstantType = @enumFromInt(tagNumber);
        const info = try ConstantTypeInfo.from(tag, allocator, r);

        return Constant{
            .tag = tag,
            .info = info,
        };
    }
};
