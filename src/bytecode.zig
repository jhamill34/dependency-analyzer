const std = @import("std");

const Allocator = @import("std").mem.Allocator;
const Writer = @import("./io.zig").Writer;
const reader = @import("./reader.zig");
const eql = @import("std").mem.eql;

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

        var infoBuffer: [128]u8 = [_]u8{0} ** 128;
        const class = try ClassFile.initFromReader(self.allocator, &readManager);
        for (class.fields) |f| {
            const name = class.constants[f.name_index];
            switch (name.info) {
                .Utf8 => |i| {
                    std.debug.print(" - Name={s} ", .{i.bytes});
                },
                else => {},
            }

            const descriptor = class.constants[f.descriptor_index];
            switch (descriptor.info) {
                .Utf8 => |i| {
                    std.debug.print("Desc={s} ", .{i.bytes});
                },
                else => {},
            }

            std.debug.print("\n", .{});
        }

        for (class.methods) |m| {
            const name = class.constants[m.name_index];
            switch (name.info) {
                .Utf8 => |i| {
                    std.debug.print(" - Name={s} ", .{i.bytes});
                },
                else => {},
            }

            const descriptor = class.constants[m.descriptor_index];
            switch (descriptor.info) {
                .Utf8 => |i| {
                    std.debug.print("Desc={s} ", .{i.bytes});
                },
                else => {},
            }

            std.debug.print("\n", .{});

            for (m.attributes) |ma| {
                try ma.decode(&infoBuffer, class.constants);
            }
        }

        return 0;
    }
};

const ClassFile = struct {
    minor_version: u16,
    major_version: u16,
    constants: []Constant,
    access_flags: u16,
    this_class: u16,
    super_class: u16,
    interfaces: []u16,
    fields: []FieldInfo,
    methods: []MethodInfo,
    attributes: []AttributeInfo,

    fn initFromReader(allocator: Allocator, r: *reader.ReadManager) !ClassFile {
        const major = try r.readBENumber(u16);
        const minor = try r.readBENumber(u16);

        const contant_count = try r.readBENumber(u16);
        var constants = try allocator.alloc(Constant, contant_count);
        for (1..contant_count) |i| {
            constants[i] = try Constant.initFromReader(allocator, r);
        }

        const access_flags = try r.readBENumber(u16);
        const this_class = try r.readBENumber(u16);
        const super_class = try r.readBENumber(u16);
        const interfaces_count = try r.readBENumber(u16);
        const interfaces = try allocator.alloc(u16, interfaces_count);
        for (0..interfaces_count) |i| {
            interfaces[i] = try r.readBENumber(u16);
        }

        const field_count = try r.readBENumber(u16);
        const fields = try allocator.alloc(FieldInfo, field_count);
        for (0..field_count) |i| {
            fields[i] = try FieldInfo.initFromReader(allocator, r);
        }

        const method_count = try r.readBENumber(u16);
        const methods = try allocator.alloc(MethodInfo, method_count);
        for (0..method_count) |i| {
            methods[i] = try MethodInfo.initFromReader(allocator, r);
        }

        const attribute_count = try r.readBENumber(u16);
        const attributes = try allocator.alloc(AttributeInfo, attribute_count);
        for (0..attribute_count) |i| {
            attributes[i] = try AttributeInfo.initFromReader(allocator, r);
        }

        return ClassFile{
            .minor_version = major,
            .major_version = minor,
            .constants = constants,
            .access_flags = access_flags,
            .this_class = this_class,
            .super_class = super_class,
            .interfaces = interfaces,
            .fields = fields,
            .methods = methods,
            .attributes = attributes,
        };
    }
};

const MethodInfo = struct {
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes: []AttributeInfo,

    fn initFromReader(allocator: Allocator, r: *reader.ReadManager) !MethodInfo {
        const access_flags = try r.readBENumber(u16);
        const name_index = try r.readBENumber(u16);
        const descriptor_index = try r.readBENumber(u16);

        const attributes_count = try r.readBENumber(u16);
        const attributes = try allocator.alloc(AttributeInfo, attributes_count);
        for (0..attributes_count) |i| {
            attributes[i] = try AttributeInfo.initFromReader(allocator, r);
        }

        return MethodInfo{
            .access_flags = access_flags,
            .name_index = name_index,
            .descriptor_index = descriptor_index,
            .attributes = attributes,
        };
    }
};

const FieldInfo = struct {
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes: []AttributeInfo,

    fn initFromReader(allocator: Allocator, r: *reader.ReadManager) !FieldInfo {
        const access_flags = try r.readBENumber(u16);
        const name_index = try r.readBENumber(u16);
        const descriptor_index = try r.readBENumber(u16);

        const attributes_count = try r.readBENumber(u16);
        const attributes = try allocator.alloc(AttributeInfo, attributes_count);
        for (0..attributes_count) |i| {
            attributes[i] = try AttributeInfo.initFromReader(allocator, r);
        }

        return FieldInfo{
            .access_flags = access_flags,
            .name_index = name_index,
            .descriptor_index = descriptor_index,
            .attributes = attributes,
        };
    }
};

const ConstantValueAttribute = struct {};

const AttributeInfo = struct {
    attribute_name_index: u16,
    info: []const u8,

    fn initFromReader(allocator: Allocator, r: *reader.ReadManager) !AttributeInfo {
        const attribute_name_index = try r.readBENumber(u16);
        const attribute_length = try r.readBENumber(u32);
        const info = try allocator.alloc(u8, attribute_length);
        _ = try r.read(info);

        return AttributeInfo{
            .attribute_name_index = attribute_name_index,
            .info = info,
        };
    }

    fn decode(self: AttributeInfo, buffer: []u8, constantTable: []Constant) !void {
        var infoSeeker = reader.BufferSeeker.init(self.info);
        var infoManager = reader.ReadManager.init(infoSeeker.reader(), buffer);

        const name = switch (constantTable[self.attribute_name_index].info) {
            .Utf8 => |i| i.bytes,
            else => {
                unreachable;
            },
        };

        if (eql(u8, name, "Code")) {
            const max_stack = try infoManager.readBENumber(u16);
            std.debug.print("Its a code, stack size is {d}\n", .{max_stack});
        } else {
            std.debug.print(".... nope... \n", .{});
        }
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
