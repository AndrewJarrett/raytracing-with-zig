const std = @import("std");
const Color = @import("color.zig").Color;
const Allocator = std.mem.Allocator;

pub const PPM = struct {
    width: usize,
    height: usize,
    pixels: []Color,
    allocator: Allocator,

    pub fn init(allocator: Allocator, width: usize, height: usize) PPM {
        return .{
            .width = width,
            .height = height,
            .pixels = allocator.alloc(Color, width * height) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PPM) void {
        self.allocator.free(self.pixels);
    }

    /// Saves the pixels which contains the image information into the PPM specific format.
    pub fn save(self: PPM, filename: []const u8) !void {
        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var bw = std.io.bufferedWriter(file.writer());
        const writer = bw.writer();

        _ = try writer.print("P3\n{d} {d}\n255\n", .{ self.width, self.height });

        for (self.pixels) |c| {
            _ = try writer.print("{s}\n", .{c});
        }

        try bw.flush();
    }
};

test "ppm struct" {
    var ppm = PPM.init(std.testing.allocator, 256, 512);
    defer ppm.deinit();

    try std.testing.expectEqual(256, ppm.width);
    try std.testing.expectEqual(512, ppm.height);
    try std.testing.expectEqual((ppm.width * ppm.height), ppm.pixels.len);
}

test "ppm save" {
    var ppm = PPM.init(std.testing.allocator, 1, 1);
    defer ppm.deinit();

    try ppm.save("test.ppm");
    defer std.fs.cwd().deleteFile("test.ppm") catch unreachable;

    const expected =
        \\P3
        \\1 1
        \\255
        \\0 0 0
        \\
    ;
    const actual = try std.fs.cwd().readFileAlloc(std.testing.allocator, "test.ppm", 1e6);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
