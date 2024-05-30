const std = @import("std");

const r = @import("./reader.zig");
const Reader = r.Reader;

const ZipError = error{
    WrongMagicNumber,
    CantFindEOCD,
};

pub fn findEndOfCentralDirectoryRecord(reader: *Reader) !u64 {
    const endPos = try reader.fileRef.getEndPos();
    const bufferSize = reader.buffer.len;

    var pos = endPos;
    std.debug.print("File Size: {d}\n", .{pos});

    while (pos > 0) {
        const result = @subWithOverflow(pos, bufferSize);
        if (result[1] == 1) {
            pos = 0;
        } else {
            pos = result[0];
        }

        std.debug.print("Current Position = {d}\n", .{pos});

        try reader.setCursor(pos);
        try reader.loadData();

        for (0..reader.buffer.len - 4) |i| {
            const magic = r.sliceToNumber(u32, reader.buffer[i..][0..4]);
            if (magic == 0x06054b50) {
                try reader.setCursor(i + pos);
                return i + pos;
            }
        }
    }

    return ZipError.CantFindEOCD;
}

pub const FileHeader = struct {
    magic: u32,
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
    fileName: []const u8,
    extraFields: []const u8,

    pub fn parse(reader: *Reader) !FileHeader {
        const magic = try reader.readNumber(u32);
        if (magic != 0x04034b50) {
            return ZipError.WrongMagicNumber;
        }

        const minVersion = try reader.readNumber(u16);
        const flags = try reader.readNumber(u16);
        const method = try reader.readNumber(u16);
        const lastModificationTime = try reader.readNumber(u16);
        const lastModificationDate = try reader.readNumber(u16);
        const crc32 = try reader.readNumber(u32);
        const compressedSize = try reader.readNumber(u32);
        const uncompressedSize = try reader.readNumber(u32);
        const fileNameLength = try reader.readNumber(u16);
        const extraFieldLength = try reader.readNumber(u16);

        return FileHeader{
            .magic = magic,
            .minVersion = minVersion,
            .flags = flags,
            .method = method,
            .lastModificationTime = lastModificationTime,
            .lastModificationDate = lastModificationDate,
            .crc32 = crc32,
            .compressedSize = compressedSize,
            .uncompressedSize = uncompressedSize,
            .fileNameLength = fileNameLength,
            .extraFieldLength = extraFieldLength,
            .fileName = "filename",
            .extraFields = "extraFields",
        };
    }
};

pub const EndOfCentralDirectoryRecord = struct {
    magic: u32,
    currentDiskNumber: u16,
    centralDirectoryDiskNumber: u16,
    currentDiskRecordCount: u16,
    recordCount: u16,
    centralDirectoryBytes: u32,
    centralDirectoryOffset: u32,
    commentLength: u16,
    comment: []const u8,

    pub fn parse(reader: *Reader) !EndOfCentralDirectoryRecord {
        const magic = try reader.readNumber(u32);
        if (magic != 0x06054b50) {
            return ZipError.WrongMagicNumber;
        }

        const currentDiskNumber = try reader.readNumber(u16);
        const centralDirectoryDiskNumber = try reader.readNumber(u16);
        const currentDiskRecordCount = try reader.readNumber(u16);
        const recordCount = try reader.readNumber(u16);
        const centralDirectoryBytes = try reader.readNumber(u32);
        const centralDirectoryOffset = try reader.readNumber(u32);
        const commentLength = try reader.readNumber(u16);

        return EndOfCentralDirectoryRecord{
            .magic = magic,
            .currentDiskNumber = currentDiskNumber,
            .centralDirectoryDiskNumber = centralDirectoryDiskNumber,
            .currentDiskRecordCount = currentDiskRecordCount,
            .recordCount = recordCount,
            .centralDirectoryBytes = centralDirectoryBytes,
            .centralDirectoryOffset = centralDirectoryOffset,
            .commentLength = commentLength,
            .comment = "comment",
        };
    }
};
