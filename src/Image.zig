const std = @import("std");
const Color = @import("color.zig").Color;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const assert = std.debug.assert;

const Self = @This();

width: u16,
height: u16,
pixels: []Color,

// Use to determine the height for an image given a width and aspect ratio
pub inline fn getHeightFromWidthAndRatio(comptime width: u16, comptime ratio: f64) u16 {
    return @intFromFloat(@as(f64, @floatFromInt(width)) / ratio);
}

/// We don't need to store this as a separate struct field. It can be calculated if it is
/// ever needed after creation of the struct
pub fn aspectRatio(self: Self) f64 {
    assert(self.height >= 1);

    return @as(f64, @floatFromInt(self.width)) / @as(f64, @floatFromInt(self.height));
}

/// Saves the pixels which contains the image information into the PPM specific format.
pub fn savePpm(self: Self, io: Io, filename: []const u8) !void {
    assert(filename.len > 0);

    var file = try std.Io.Dir.cwd().createFile(io, filename, .{});
    defer file.close(io);

    var buf: [2048]u8 = undefined;
    var fileWriter = file.writer(io, &buf);
    const writer: *std.Io.Writer = &fileWriter.interface;

    _ = try writer.print("P3\n{d} {d}\n255\n", .{ self.width, self.height });

    for (self.pixels) |p| {
        _ = try writer.print("{f}\n", .{p});
    }

    try writer.flush();
}

// Saves the PPM in binary format
pub fn savePpmBinary(self: Self, io: Io, filename: []const u8) !void {
    assert(filename.len > 0);

    var file = try std.Io.Dir.cwd().createFile(io, filename, .{});
    defer file.close(io);

    var buf: [2048]u8 = undefined;
    var fileWriter = file.writer(io, &buf);
    const writer: *std.Io.Writer = &fileWriter.interface;

    _ = try writer.print("P6\n{d} {d}\n255\n", .{ self.width, self.height });

    for (self.pixels) |b| {
        const rgb = b.toRgb();
        _ = try writer.writeByte(rgb.r);
        _ = try writer.writeByte(rgb.g);
        _ = try writer.writeByte(rgb.b);
    }
    _ = try writer.print("\n", .{});

    try writer.flush();
}

pub fn format(self: Self, writer: anytype) !void {
    try writer.print("{d}x{d} ({d})", .{ self.width, self.height, self.aspectRatio() });
}

test "struct" {
    const alloc = std.testing.allocator;

    const pixels = try alloc.alloc(Color, 256*512);
    defer alloc.free(pixels);
    var image = Self{ .width = 256, .height = 512, .pixels = pixels };

    try std.testing.expectEqual(256, image.width);
    try std.testing.expectEqual(512, image.height);
    try std.testing.expectEqual(0.5, image.aspectRatio());
    try std.testing.expectEqual((@as(u32, image.width) * @as(u32, image.height)), image.pixels.len);
}

test "Image" {
    const alloc = std.testing.allocator;

    const pixels = try alloc.alloc(Color, 800 * 400);
    defer alloc.free(pixels);
    var img = Self{ .width = 800, .height = 400, .pixels = pixels };

    const pixels2 = try alloc.alloc(Color, 400 * 400);
    defer alloc.free(pixels2);
    var img2 = Self{ .width = 400, .height = 400, .pixels = pixels2 };

    const pixels3 = try alloc.alloc(Color, 1 * 1);
    defer alloc.free(pixels3);
    var imgHeightOne = Self{ .width = 1, .height = 1, .pixels = pixels3 };

    const expected = "400x400 (1)";

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{f}", .{img2});

    try std.testing.expectEqual(800, img.width);
    try std.testing.expectEqual(400, img.height);
    try std.testing.expectEqual(2.0, img.aspectRatio());
    try std.testing.expectEqual(400, img2.width);
    try std.testing.expectEqual(400, img2.height);
    try std.testing.expectEqual(1.0, img2.aspectRatio());
    try std.testing.expectEqual(1, imgHeightOne.width);
    try std.testing.expectEqual(1, imgHeightOne.height);
    try std.testing.expectEqual(1.0, imgHeightOne.aspectRatio());
    try std.testing.expectEqualStrings(expected, actual);
}

test "savePpm()" {
    const alloc = std.testing.allocator;
    const io = std.testing.io;

    const pixels = try alloc.alloc(Color, 1);
    defer alloc.free(pixels);
    var image = Self{ .width = 1, .height = 1, .pixels = pixels };

    try image.savePpm(io, "test.ppm");
    defer std.Io.Dir.cwd().deleteFile(io, "test.ppm") catch unreachable;

    const expected =
        \\P3
        \\1 1
        \\255
        \\0 0 0
        \\
    ;
    const actual = try std.Io.Dir.cwd().readFileAlloc(io, "test.ppm", alloc, Io.Limit.limited(1e6));
    defer alloc.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "savePpmBinary()" {
    const alloc = std.testing.allocator;
    const io = std.testing.io;

    const pixels = try alloc.alloc(Color, 1);
    defer alloc.free(pixels);
    var image = Self{ .width = 1, .height = 1, .pixels = pixels };

    try image.savePpmBinary(io, "test-binary.ppm");
    defer std.Io.Dir.cwd().deleteFile(io, "test-binary.ppm") catch unreachable;

    const expected = try std.Io.Dir.cwd().readFileAlloc(io, "test-files/test-binary.ppm", alloc, Io.Limit.limited(1024));
    defer alloc.free(expected);

    const actual = try std.Io.Dir.cwd().readFileAlloc(io, "test-binary.ppm", alloc, Io.Limit.limited(1024));
    defer alloc.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
