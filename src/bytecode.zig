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
                const attr = try ma.decode(self.allocator, &infoBuffer, class.constants);
                switch (attr) {
                    .Code => |c| {
                        for (c.code) |b| {
                            std.debug.print("      {d}\n", .{b});
                        }
                    },
                    else => {},
                }
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

// NOTE: Section 4.7.2
const ConstantValueAttribute = struct {
    constantvalue_index: u16,
};

// NOTE: Section 4.7.3
const CodeAttribute = struct {
    max_stack: u16,
    max_locals: u16,
    code: []const u8,
    exception_table: []Exception,
    attributes: []AttributeInfo,
};

const Exception = struct {
    start_pc: u16,
    end_pc: u16,
    handler_pc: u16,
    catch_type: u16,
};

// NOTE: Section 4.7.4
const StackMapTableAttribute = struct {
    // TODO:
};

// NOTE: Section 4.7.5
const ExceptionsAttribute = struct {
    exception_index_table: []u16,
};

// NOTE: Section 4.7.6
const InnerClassesAttribute = struct {
    classes: []InnerClass,
};

const InnerClass = struct {
    inner_class_info_index: u16,
    outer_class_info_index: u16,
    inner_name_index: u16,
    inner_class_access_flags: u16,
};

// NOTE: Section 4.7.7
const EnclosingMethodAttribute = struct {
    class_index: u16,
    method_index: u16,
};

// NOTE: Section 4.7.8
const SyntheticAttribute = struct {};

// NOTE: Section 4.7.9
const SignatureAttribute = struct {
    signature_index: u16,
};

// NOTE: Section 4.7.10
const SourceFileAttribute = struct {
    source_file_index: u16,
};

// NOTE: Section 4.7.11
const SourceDebugExtensionAttribute = struct {
    debug_extension: []const u8,
};

// NOTE: Section 4.7.12
const LineNumberTableAttribute = struct {
    line_number_table: []LineNumber,
};

const LineNumber = struct {
    start_pc: u16,
    line_number: u16,
};

// NOTE: Section 4.7.13
const LocalVariableTableAttribute = struct {
    local_variable_table: []LocalVariable,
};

const LocalVariable = struct {
    start_pc: u16,
    length: u16,
    name_index: u16,
    descriptor_index: u16,
    index: u16,
};

// NOTE: Section 4.7.14
const LocalVariableTypeTableAttribute = struct {
    local_variable_type_table: []LocalVariableType,
};

const LocalVariableType = struct {
    start_pc: u16,
    length: u16,
    name_index: u16,
    signature_index: u16,
    index: u16,
};

// NOTE: Section 4.7.15
const DeprecatedAttribute = struct {};

// NOTE: Section 4.7.16
const RuntimeVisibleAnnotationsAttribute = struct {
    // TODO:
};

// NOTE: Section 4.7.17
const RuntimeInvisibleAnnotationsAttribute = struct {
    // TODO:
};

// NOTE: Section 4.7.18
const RuntimeVisibleParameterAnnotationsAttribute = struct {
    // TODO:
};

// NOTE: Section 4.7.19
const RuntimeInvisibleParameterAnnotationsAttribute = struct {
    // TODO:
};

// NOTE: Section 4.7.20
const AnnotationDefaultAttribute = struct {
    // TODO:
};

// NOTE: Section 4.7.21
const BootstrapMethodsAttribute = struct {
    bootstrap_methods: []BootstrapMethod,
};

const BootstrapMethod = struct {
    bootstrap_method_ref: u16,
    bootstrap_arguments: []u16,
};

const AttribueInfoDetails = union(enum) {
    ConstantValue: ConstantValueAttribute,
    Code: CodeAttribute,
    StackMapTable: StackMapTableAttribute,
    Exceptions: ExceptionsAttribute,
    InnerClasses: InnerClassesAttribute,
    EnclosingMethod: EnclosingMethodAttribute,
    Synthetic: SyntheticAttribute,
    Signature: SignatureAttribute,
    SourceFile: SourceFileAttribute,
    SourceDebugExtension: SourceDebugExtensionAttribute,
    LineNumberTable: LineNumberTableAttribute,
    LocalVariableTable: LocalVariableTableAttribute,
    LocalVariableTypeTable: LocalVariableTypeTableAttribute,
    Deprecated: DeprecatedAttribute,
    RuntimeVisibleAnnotations: RuntimeVisibleAnnotationsAttribute,
    RuntimeInvisibleAnnotations: RuntimeInvisibleAnnotationsAttribute,
    RuntimeVisibleParameterAnnotations: RuntimeVisibleParameterAnnotationsAttribute,
    RuntimeInvisibleParameterAnnotations: RuntimeInvisibleParameterAnnotationsAttribute,
    AnnotationDefault: AnnotationDefaultAttribute,
    BootstrapMethods: BootstrapMethodsAttribute,
};

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

    fn decode(self: AttributeInfo, allocator: Allocator, buffer: []u8, constantTable: []Constant) !AttribueInfoDetails {
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
            const max_locals = try infoManager.readBENumber(u16);
            const code_length = try infoManager.readBENumber(u32);

            const code = try allocator.alloc(u8, code_length);
            _ = try infoManager.read(code);

            const exception_length = try infoManager.readBENumber(u16);
            const exceptions = try allocator.alloc(Exception, exception_length);
            for (0..exception_length) |i| {
                exceptions[i] = try infoManager.readBEStruct(Exception);
            }

            const attribute_length = try infoManager.readBENumber(u16);
            const attributes = try allocator.alloc(AttributeInfo, attribute_length);
            for (0..attribute_length) |i| {
                attributes[i] = try AttributeInfo.initFromReader(allocator, &infoManager);
            }

            const code_attr = CodeAttribute{
                .max_stack = max_stack,
                .max_locals = max_locals,
                .code = code,
                .exception_table = exceptions,
                .attributes = attributes,
            };

            return AttribueInfoDetails{ .Code = code_attr };
        } else if (eql(u8, name, "ConstantValue")) {
            const constant = try infoManager.readBEStruct(ConstantValueAttribute);

            return AttribueInfoDetails{ .ConstantValue = constant };
        } else if (eql(u8, name, "StackMapTable")) {
            return AttribueInfoDetails{ .StackMapTable = StackMapTableAttribute{} };
        } else if (eql(u8, name, "Exceptions")) {
            const exceptions_count = try infoManager.readBENumber(u16);
            const exceptions = try allocator.alloc(u16, exceptions_count);
            for (0..exceptions_count) |i| {
                exceptions[i] = try infoManager.readBENumber(u16);
            }

            return AttribueInfoDetails{
                .Exceptions = ExceptionsAttribute{
                    .exception_index_table = exceptions,
                },
            };
        } else if (eql(u8, name, "InnerClasses")) {
            const number_classes = try infoManager.readBENumber(u16);
            const classes = try allocator.alloc(InnerClass, number_classes);
            for (0..number_classes) |i| {
                classes[i] = try infoManager.readBEStruct(InnerClass);
            }

            return AttribueInfoDetails{
                .InnerClasses = InnerClassesAttribute{
                    .classes = classes,
                },
            };
        } else if (eql(u8, name, "EnclosingMethod")) {
            const encloding_method = try infoManager.readBEStruct(EnclosingMethodAttribute);

            return AttribueInfoDetails{
                .EnclosingMethod = encloding_method,
            };
        } else if (eql(u8, name, "Synthetic")) {
            return AttribueInfoDetails{ .Synthetic = SyntheticAttribute{} };
        } else if (eql(u8, name, "Signature")) {
            const signature = try infoManager.readBEStruct(SignatureAttribute);
            return AttribueInfoDetails{
                .Signature = signature,
            };
        } else if (eql(u8, name, "SourceFile")) {
            const source_file = try infoManager.readBEStruct(SourceFileAttribute);
            return AttribueInfoDetails{
                .SourceFile = source_file,
            };
        } else if (eql(u8, name, "SourceDebugExtension")) {
            return AttribueInfoDetails{
                .SourceDebugExtension = SourceDebugExtensionAttribute{
                    .debug_extension = self.info,
                },
            };
        } else if (eql(u8, name, "LineNumberTable")) {
            const table_length = try infoManager.readBENumber(u16);
            const table = try allocator.alloc(LineNumber, table_length);
            for (0..table_length) |i| {
                table[i] = try infoManager.readBEStruct(LineNumber);
            }

            return AttribueInfoDetails{
                .LineNumberTable = LineNumberTableAttribute{
                    .line_number_table = table,
                },
            };
        } else if (eql(u8, name, "LocalVariableTypeTable")) {
            const table_length = try infoManager.readBENumber(u16);
            const table = try allocator.alloc(LocalVariable, table_length);
            for (0..table_length) |i| {
                table[i] = try infoManager.readBEStruct(LocalVariable);
            }

            return AttribueInfoDetails{
                .LocalVariableTable = LocalVariableTableAttribute{
                    .local_variable_table = table,
                },
            };
        } else if (eql(u8, name, "LocalVariableTypeTable")) {
            const table_length = try infoManager.readBENumber(u16);
            const table = try allocator.alloc(LocalVariableType, table_length);
            for (0..table_length) |i| {
                table[i] = try infoManager.readBEStruct(LocalVariableType);
            }

            return AttribueInfoDetails{
                .LocalVariableTypeTable = LocalVariableTypeTableAttribute{
                    .local_variable_type_table = table,
                },
            };
        } else if (eql(u8, name, "Deprecated")) {
            return AttribueInfoDetails{ .Deprecated = DeprecatedAttribute{} };
        } else if (eql(u8, name, "RuntimeVisibleAnnotations")) {
            return AttribueInfoDetails{ .RuntimeVisibleAnnotations = RuntimeVisibleAnnotationsAttribute{} };
        } else if (eql(u8, name, "RuntimeInvisibleAnnotations")) {
            return AttribueInfoDetails{ .RuntimeInvisibleAnnotations = RuntimeInvisibleAnnotationsAttribute{} };
        } else if (eql(u8, name, "RuntimeVisibleParameterAnnotations")) {
            return AttribueInfoDetails{ .RuntimeVisibleParameterAnnotations = RuntimeVisibleParameterAnnotationsAttribute{} };
        } else if (eql(u8, name, "RuntimeInvisibleParameterAnnotations")) {
            return AttribueInfoDetails{ .RuntimeInvisibleParameterAnnotations = RuntimeInvisibleParameterAnnotationsAttribute{} };
        } else if (eql(u8, name, "AnnotationDefault")) {
            return AttribueInfoDetails{ .AnnotationDefault = AnnotationDefaultAttribute{} };
        } else if (eql(u8, name, "BootstrapMethods")) {
            const num_bootstrap_methods = try infoManager.readBENumber(u16);
            const bootstrap_methods = try allocator.alloc(BootstrapMethod, num_bootstrap_methods);
            for (0..num_bootstrap_methods) |i| {
                const ref = try infoManager.readBENumber(u16);
                const num_args = try infoManager.readBENumber(u16);
                const args = try allocator.alloc(u16, num_args);
                for (0..num_args) |j| {
                    args[j] = try infoManager.readBENumber(u16);
                }

                bootstrap_methods[i] = BootstrapMethod{
                    .bootstrap_method_ref = ref,
                    .bootstrap_arguments = args,
                };
            }

            return AttribueInfoDetails{
                .BootstrapMethods = BootstrapMethodsAttribute{
                    .bootstrap_methods = bootstrap_methods,
                },
            };
        } else {
            unreachable;
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
