const std = @import("std");
const Color = @import("color.zig").Color;
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const PPM = struct {
    width: usize,
    height: usize,
    pixels: []Color,
    allocator: Allocator,
    io: Io,

    pub fn init(allocator: Allocator, io: Io, width: usize, height: usize) PPM {
        return .{
            .width = width,
            .height = height,
            .pixels = allocator.alloc(Color, width * height) catch unreachable,
            .allocator = allocator,
            .io = io,
        };
    }

    pub fn deinit(self: *PPM) void {
        self.allocator.free(self.pixels);
    }

    /// Saves the pixels which contains the image information into the PPM specific format.
    pub fn save(self: PPM, filename: []const u8) !void {
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
    pub fn saveBinary(self: PPM, filename: []const u8) !void {
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
};

test "init()" {
    var ppm = PPM.init(std.testing.allocator, std.testing.io, 256, 512);
    defer ppm.deinit();

    try std.testing.expectEqual(256, ppm.width);
    try std.testing.expectEqual(512, ppm.height);
    try std.testing.expectEqual((ppm.width * ppm.height), ppm.pixels.len);
}

test "save()" {
    const io = std.testing.io;

    var ppm = PPM.init(std.testing.allocator, std.testing.io, 1, 1);
    defer ppm.deinit();

    try ppm.save("test.ppm");
    defer std.Io.Dir.cwd().deleteFile(io, "test.ppm") catch unreachable;

    const expected =
        \\P3
        \\1 1
        \\255
        \\0 0 0
        \\
    ;
    const actual = try std.Io.Dir.cwd().readFileAlloc(io, "test.ppm", std.testing.allocator, Io.Limit.limited(1e6));
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "saveBinary()" {
    const io = std.testing.io;

    var ppm = PPM.init(std.testing.allocator, std.testing.io, 1, 1);
    defer ppm.deinit();

    try ppm.saveBinary("test-binary.ppm");
    defer std.Io.Dir.cwd().deleteFile(io, "test-binary.ppm") catch unreachable;

    const expected = try std.Io.Dir.cwd().readFileAlloc(io, "test-files/test-binary.ppm", std.testing.allocator, Io.Limit.limited(1024));
    defer std.testing.allocator.free(expected);

    const actual = try std.Io.Dir.cwd().readFileAlloc(io, "test-binary.ppm", std.testing.allocator, Io.Limit.limited(1024));
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
