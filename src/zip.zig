const Allocator = @import("std").mem.Allocator;
const print = @import("std").debug.print;
const panic = @import("std").debug.panic;

const std = @import("std");

const ReadSeeker = @import("./io.zig").ReadSeeker;

const ReadManager = @import("./reader.zig").ReadManager;
const sliceToNumber = @import("./reader.zig").sliceToNumber;

const BitBuffer = @import("./bitbuffer.zig").BitBuffer;
const FileWriter = @import("./writer.zig").FileWriter;

const deflate = @import("./gzip.zig").deflate;

pub fn extractFromArchive(alloc: Allocator, readSeeker: ReadSeeker) !void {
    var buffer: [4096]u8 = undefined;
    var reader = ReadManager.init(readSeeker, &buffer);

    _ = try findEndOfCentralDirectoryRecord(&reader);

    const eocd = try EOCD.initFromReader(alloc, &reader);

    print("Central Directory found at position {d}\n", .{eocd.metadata.centralDirectoryOffset});
    print("Number of Files Found: {d}\n", .{eocd.metadata.recordCount});

    try reader.setCursor(eocd.metadata.centralDirectoryOffset);

    var records = try alloc.alloc(CentralDirectoryFile, eocd.metadata.recordCount);

    var currentRecord: u16 = 0;
    while (currentRecord < eocd.metadata.recordCount) {
        const record = try CentralDirectoryFile.initFromReader(alloc, &reader);
        records[currentRecord] = record;
        currentRecord += 1;
    }

    for (records) |record| {
        if (record.metadata.compressedSize > 0) {
            try reader.setCursor(record.metadata.relativeFileOffset);
            const localFile = try FileHeader.initFromReader(alloc, &reader);

            print("{s} (size: {d}, method: {d})\n", .{ localFile.fileName.?, localFile.metadata.compressedSize, localFile.metadata.method });

            const dirname = std.fs.path.dirname(localFile.fileName.?);
            try std.fs.cwd().makePath(dirname.?);
            var file = try std.fs.cwd().createFile(localFile.fileName.?, .{});

            var writer = FileWriter.writer(&file);

            const rawData = try reader.readAlloc(alloc, localFile.metadata.compressedSize);
            var bitbuffer = BitBuffer.init(
                rawData,
            );

            try deflate(&bitbuffer, &writer);

            file.close();
            alloc.free(rawData);

            localFile.deinit();
        }

        record.deinit();
    }
    alloc.free(records);
}

const ZipError = error{
    WrongMagicNumber,
    EOCDNotFound,
};

const FileHeaderMagic = 0x04034b50;
const CentralDirectoryMagic = 0x02014b50;
const EOCDMagic = 0x06054b50;

const FileHeaderMetadata = struct {
    minVersion: u16,
    flags: u16,
    method: u16,
    lastModificationTime: u16,
    lastModificationDate: u16,
    crc32: u32,
    compressedSize: u32,
    uncompressedSize: u32,
    fileNameLength: u16,
    extraFieldLength: u16,
};

const FileHeader = struct {
    metadata: FileHeaderMetadata,
    fileName: ?[]const u8,
    extraFields: ?[]const u8,
    allocator: Allocator,

    fn initFromReader(allocator: Allocator, reader: *ReadManager) !FileHeader {
        const magic = try reader.readNumber(u32);
        if (magic != FileHeaderMagic) {
            panic("File Header Magic Number doesn't match\n", .{});
        }

        const metadata = try reader.readStruct(FileHeaderMetadata);

        const fileName = if (metadata.fileNameLength > 0) try reader.readAlloc(allocator, metadata.fileNameLength) else null;
        const extraFields = if (metadata.extraFieldLength > 0) try reader.readAlloc(allocator, metadata.extraFieldLength) else null;

        return FileHeader{
            .metadata = metadata,
            .fileName = fileName,
            .extraFields = extraFields,
            .allocator = allocator,
        };
    }

    fn deinit(self: FileHeader) void {
        if (self.extraFields != null) {
            self.allocator.free(self.extraFields.?);
        }

        if (self.fileName != null) {
            self.allocator.free(self.fileName.?);
        }
    }
};

const CentralDirectoryFileMetadata = struct {
    versionMade: u16,
    versionNeeded: u16,
    flags: u16,
    compressionMethod: u16,
    lastModificationTime: u16,
    lastModificationDate: u16,
    crc32: u32,
    compressedSize: u32,
    uncompressedSize: u32,
    fileNameLength: u16,
    extraFieldLength: u16,
    commentLength: u16,
    diskNumber: u16,
    internalFileAttributes: u16,
    externalFileAttributes: u32,
    relativeFileOffset: u32,
};

const CentralDirectoryFile = struct {
    metadata: CentralDirectoryFileMetadata,
    fileName: ?[]const u8,
    extraField: ?[]const u8,
    comment: ?[]const u8,
    allocator: Allocator,

    fn initFromReader(allocator: Allocator, reader: *ReadManager) !CentralDirectoryFile {
        const magic = try reader.readNumber(u32);
        if (magic != CentralDirectoryMagic) {
            panic("Central Directory Magic Number doesn't match\n", .{});
        }

        const metadata = try reader.readStruct(CentralDirectoryFileMetadata);

        const fileName = if (metadata.fileNameLength > 0) try reader.readAlloc(allocator, metadata.fileNameLength) else null;
        const extraField = if (metadata.extraFieldLength > 0) try reader.readAlloc(allocator, metadata.extraFieldLength) else null;
        const comment = if (metadata.commentLength > 0) try reader.readAlloc(allocator, metadata.commentLength) else null;

        return CentralDirectoryFile{
            .metadata = metadata,
            .fileName = fileName,
            .extraField = extraField,
            .comment = comment,
            .allocator = allocator,
        };
    }

    fn deinit(self: CentralDirectoryFile) void {
        if (self.extraField != null) {
            self.allocator.free(self.extraField.?);
        }

        if (self.fileName != null) {
            self.allocator.free(self.fileName.?);
        }

        if (self.comment != null) {
            self.allocator.free(self.comment.?);
        }
    }
};

const EOCDMetadata = struct {
    currentDiskNumber: u16,
    centralDirectoryDiskNumber: u16,
    currentDiskRecordCount: u16,
    recordCount: u16,
    centralDirectoryBytes: u32,
    centralDirectoryOffset: u32,
    commentLength: u16,
};

const EOCD = struct {
    metadata: EOCDMetadata,
    comment: ?[]const u8,
    allocator: Allocator,

    fn initFromReader(allocator: Allocator, reader: *ReadManager) !EOCD {
        const magic = try reader.readNumber(u32);
        if (magic != EOCDMagic) {
            panic("EOCD Magic Number doesn't match.\n", .{});
        }

        const metadata = try reader.readStruct(EOCDMetadata);
        const comment = if (metadata.commentLength > 0) try reader.readAlloc(allocator, metadata.commentLength) else null;

        return EOCD{
            .metadata = metadata,
            .comment = comment,
            .allocator = allocator,
        };
    }

    fn deinit(self: EOCD) void {
        if (self.comment != null) {
            self.allocator.free(self.comment);
        }
    }
};

fn findEndOfCentralDirectoryRecord(reader: *ReadManager) !u64 {
    const endPos = try reader.readSeeker.getEndPos();
    const bufferSize = reader.buffer.len;

    var pos = endPos;
    print("File Size: {d}\n", .{pos});

    while (pos > 0) {
        const result = @subWithOverflow(pos, bufferSize);
        if (result[1] == 1) {
            pos = 0;
        } else {
            pos = result[0];
        }

        print("Current Position = {d}\n", .{pos});

        try reader.setCursor(pos);
        try reader.loadData();

        for (0..reader.buffer.len - 4) |i| {
            const magic = sliceToNumber(u32, reader.buffer[i..][0..4]);
            if (magic == EOCDMagic) {
                try reader.setCursor(i + pos);
                return i + pos;
            }
        }
    }

    return ZipError.EOCDNotFound;
}
