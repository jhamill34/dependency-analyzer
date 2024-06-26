const Allocator = @import("std").mem.Allocator;
const ArenaAllocator = @import("std").heap.ArenaAllocator;
const File = @import("std").fs.File;
const print = @import("std").debug.print;
const panic = @import("std").debug.panic;

const std = @import("std");

const ReadSeeker = @import("io.zig").ReadSeeker;

const ReadManager = @import("reader.zig").ReadManager;
const sliceToNumber = @import("reader.zig").sliceToNumber;

const BitBuffer = @import("bitbuffer.zig").BitBuffer;
const Writer = @import("io.zig").Writer;

const inflate = @import("deflate.zig").inflate;

pub fn extractFromArchive(alloc: Allocator, readSeeker: ReadSeeker, writer: Writer) !void {
    var buffer: [4096]u8 = undefined;
    var reader = ReadManager.init(readSeeker, &buffer);

    _ = try findEndOfCentralDirectoryRecord(&reader);

    const eocd = try EOCD.initFromReader(alloc, &reader);

    print("Central Directory found at position {d}\n", .{eocd.metadata.centralDirectoryOffset});
    print("Number of Files Found: {d}\n", .{eocd.metadata.recordCount});

    try reader.setCursor(eocd.metadata.centralDirectoryOffset);

    var arena = ArenaAllocator.init(alloc);
    defer arena.deinit();

    const arena_allocator = arena.allocator();
    var records = try arena_allocator.alloc(CentralDirectoryFile, eocd.metadata.recordCount);
    for (0..eocd.metadata.recordCount) |currentRecord| {
        records[currentRecord] = try CentralDirectoryFile.initFromReader(arena_allocator, &reader);
    }

    var rawData: ?[]u8 = null;
    var output: ?[]u8 = null;

    // TODO: Can this be threaded?
    for (records) |record| {
        if (record.metadata.compressedSize > 0) {
            try reader.setCursor(record.metadata.relativeFileOffset);

            // NOTE: even though the localFile goes out of scope the memory allocated
            // might seem like its leaked but since they're part of
            // the arena allocator they'll get cleaned up at the end of this function.
            const localFile = try FileHeader.initFromReader(arena_allocator, &reader);

            // NOTE: To limit the number of times we need to ask the heap for
            // memory we use a shared buffer here. If the exising slice is large enough
            // we'll just use those memory locations and overwrite data as needed.
            // If we can't fit our data in there we'll just grow the slice to the
            // correct size by freeing the existing slice and reallocating the
            // correct amount.
            const compressedSize = localFile.metadata.compressedSize;
            if (rawData == null or rawData.?.len < compressedSize) {
                if (rawData != null) {
                    alloc.free(rawData.?);
                }

                rawData = try alloc.alloc(u8, compressedSize);
            }

            const uncompressedSize = localFile.metadata.uncompressedSize;
            if (output == null or output.?.len < uncompressedSize) {
                if (output != null) {
                    alloc.free(output.?);
                }

                output = try alloc.alloc(u8, uncompressedSize);
            }

            const rawDataSlice = rawData.?[0..compressedSize];
            _ = try reader.read(rawDataSlice);

            var bitbuffer = BitBuffer.init(rawDataSlice);

            try inflate(alloc, &bitbuffer, output.?);
            _ = try writer.write(localFile.fileName.?, output.?);
        }
    }

    if (rawData != null) {
        alloc.free(rawData.?);
    }
}

fn createFile(fileName: []const u8) !File {
    const dirname = std.fs.path.dirname(fileName);
    try std.fs.cwd().makePath(dirname.?);

    return try std.fs.cwd().createFile(fileName, .{});
}

const ZipError = error{
    WrongMagicNumber,
    EOCDNotFound,
};

const FileHeaderMagic = 0x04034b50;
const CentralDirectoryMagic = 0x02014b50;
const EOCDMagic = 0x06054b50;

const FileHeaderMetadata = packed struct {
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

const CentralDirectoryFileMetadata = packed struct {
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

const EOCDMetadata = packed struct {
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
