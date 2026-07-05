const std = @import("std");
const Color = @import("color.zig").Color;
const Allocator = std.mem.Allocator;
const Io = std.Io;

const Self = @This();

alloc: Allocator,
io: Io,
width: usize,
height: usize,
pixels: []Color,

/// The preferred method of initialization is through the Camera struct and only
/// needs to be provided with the width of the image and the aspectRatio. The height
/// Interval.init(1e-3, inf)will be calculated automatically based on the width of the image and the aspectRatio.
pub fn init(alloc: Allocator, io: Io, width: usize, ratio: f64) Self {
    const height: usize = @intFromFloat(@as(f64, @floatFromInt(width)) / ratio);

    return .{
        .alloc = alloc,
        .io = io,
        .width = width,
        .height = if (height < 1) 1 else height,
        .pixels = alloc.alloc(Color, width * height) catch unreachable,
    };
}

pub fn deinit(self: *Self) void {
    self.alloc.free(self.pixels);
}

/// We don't need to store this as a separate struct field. It can be calculated if it is
/// ever needed after creation of the struct
pub fn aspectRatio(self: Self) f64 {
    return @as(f64, @floatFromInt(self.width)) / @as(f64, @floatFromInt(self.height));
}

/// Saves the pixels which contains the image information into the PPM specific format.
pub fn savePpm(self: Self, filename: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(self.io, filename, .{});
    defer file.close(self.io);

    var buf: [2048]u8 = undefined;
    var fileWriter = file.writer(self.io, &buf);
    const writer: *std.Io.Writer = &fileWriter.interface;

    _ = try writer.print("P3\n{d} {d}\n255\n", .{ self.width, self.height });

    for (self.pixels) |p| {
        _ = try writer.print("{f}\n", .{p});
    }

    try writer.flush();
}

// Saves the PPM in binary format
pub fn savePpmBinary(self: Self, filename: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(self.io, filename, .{});
    defer file.close(self.io);

    var buf: [2048]u8 = undefined;
    var fileWriter = file.writer(self.io, &buf);
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

test "init()" {
    const alloc = std.testing.allocator;
    const io = std.testing.io;

    var image = Self.init(alloc, io, 256, 0.5);
    defer image.deinit();

    try std.testing.expectEqual(256, image.width);
    try std.testing.expectEqual(512, image.height);
    try std.testing.expectEqual(0.5, image.aspectRatio());
    try std.testing.expectEqual((image.width * image.height), image.pixels.len);
}

test "Image" {
    const alloc = std.testing.allocator;
    const io = std.testing.io;

    const pixels = alloc.alloc(Color, 800 * 400) catch unreachable;
    var img = Self{ .alloc = alloc, .io = io, .width = 800, .height = 400, .pixels = pixels };
    defer img.deinit();

    var img2 = Self.init(alloc, io, 400, 1.0);
    defer img2.deinit();

    var imgHeightOne = Self.init(alloc, io, 1, 2.0);
    defer imgHeightOne.deinit();

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

    var image = Self.init(alloc, io, 1, 1);
    defer image.deinit();

    try image.savePpm("test.ppm");
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

    var image = Self.init(alloc, io, 1, 1);
    defer image.deinit();

    try image.savePpmBinary("test-binary.ppm");
    defer std.Io.Dir.cwd().deleteFile(io, "test-binary.ppm") catch unreachable;

    const expected = try std.Io.Dir.cwd().readFileAlloc(io, "test-files/test-binary.ppm", alloc, Io.Limit.limited(1024));
    defer alloc.free(expected);

    const actual = try std.Io.Dir.cwd().readFileAlloc(io, "test-binary.ppm", alloc, Io.Limit.limited(1024));
    defer alloc.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
