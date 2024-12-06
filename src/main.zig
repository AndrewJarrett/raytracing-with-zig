const std = @import("std");
const Allocator = std.mem.Allocator;

/// Holds the RGB values for a pixel's color
pub const RGB = packed struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn format(self: RGB, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{d} {d} {d}", .{ self.r, self.g, self.b });
    }
};

/// Holds the color information for a specific pixel either
/// as a u24 integer value, or a packed RGB struct of 3 u8's.
pub const Color = packed struct {
    rgb: RGB,

    pub fn init(r: u8, g: u8, b: u8) Color {
        return .{ .rgb = .{
            .r = r,
            .g = g,
            .b = b,
        } };
    }

    pub fn fromValue(value: u24) Color {
        return .{ .rgb = .{
            .r = @intCast((value & 0xff0000) >> 16),
            .g = @intCast((value & 0x00ff00) >> 8),
            .b = @intCast(value & 0x0000ff),
        } };
    }

    pub fn format(self: Color, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}", .{self.rgb});
    }

    pub fn toValue(self: Color) u24 {
        return (@as(u24, self.rgb.r) << 16) | (@as(u24, self.rgb.g) << 8) | self.rgb.b;
    }
};

pub const PPM = struct {
    width: usize,
    height: usize,
    data: []Color,
    allocator: Allocator,

    pub fn init(allocator: Allocator, width: usize, height: usize) PPM {
        return .{
            .width = width,
            .height = height,
            .data = allocator.alloc(Color, width * height) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PPM) void {
        self.allocator.free(self.data);
    }

    /// Saves the data which contains the image information into the PPM specific format.
    pub fn save(self: PPM, filename: []const u8) !void {
        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var bw = std.io.bufferedWriter(file.writer());
        const writer = bw.writer();

        _ = try writer.print("P3\n{d} {d}\n255\n", .{ self.width, self.height });

        for (self.data) |c| {
            _ = try writer.print("{s}\n", .{c});
        }

        try bw.flush();
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Setup Image/PPM
    var ppm = PPM.init(allocator, 256, 256);
    defer ppm.deinit();

    // Write the pixels
    for (0..ppm.height) |j| {
        std.log.info("\rScanlines remaining: {d} ", .{ppm.height - j});
        for (0..ppm.width) |i| {
            const r: f64 = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(ppm.width - 1));
            const g: f64 = @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(ppm.height - 1));
            const b: f64 = 0.0;

            ppm.data[i + j * ppm.width] = Color{
                .rgb = .{
                    .r = @intFromFloat(255.999 * r),
                    .g = @intFromFloat(255.999 * g),
                    .b = @intFromFloat(255.999 * b),
                },
            };
        }
    }
    std.log.info("\rDone.\n", .{});

    // Save the file
    try ppm.save("images/chapter2.ppm");
}

test "rgb struct" {
    const rgb = RGB{ .r = 255, .g = 0, .b = 255 };
    const expected: []const u8 = "255 0 255";

    try std.testing.expectEqual(255, rgb.r);
    try std.testing.expectEqual(0, rgb.g);
    try std.testing.expectEqual(255, rgb.b);

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{rgb});
    try std.testing.expectEqualStrings(expected, actual);

    // Ensure the struct is packed
    try std.testing.expectEqual(24, @bitSizeOf(RGB));
}

test "color struct" {
    const r = 255;
    const g = 0;
    const b = 255;

    const expected: []const u8 = "255 0 255";

    // Test creating by struct instantiation
    const color = Color{ .rgb = .{ .r = r, .g = g, .b = b } };

    // Test the init method
    const colorInit = Color.init(r, g, b);

    try std.testing.expectEqual(r, color.rgb.r);
    try std.testing.expectEqual(g, color.rgb.g);
    try std.testing.expectEqual(r, color.rgb.b);
    try std.testing.expectEqual(colorInit.rgb.r, color.rgb.r);
    try std.testing.expectEqual(colorInit.rgb.g, color.rgb.g);
    try std.testing.expectEqual(colorInit.rgb.b, color.rgb.b);

    // Test creating from a u24 value
    const value: u24 = ((r << 16) | (g << 8) | b);
    const color2 = Color.fromValue(value);

    try std.testing.expectEqual(r, color2.rgb.r);
    try std.testing.expectEqual(g, color2.rgb.g);
    try std.testing.expectEqual(b, color2.rgb.b);

    // Test converting from RGB to a u24
    try std.testing.expectEqual(value, color.toValue());

    // Test format method
    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[g..expected.len], "{s}", .{color});
    try std.testing.expectEqualSlices(u8, expected, actual);

    // Ensure that the Color struct is packed
    try std.testing.expectEqual(24, @bitSizeOf(Color));
}

test "ppm struct" {
    var ppm = PPM.init(std.testing.allocator, 256, 512);
    defer ppm.deinit();

    try std.testing.expectEqual(256, ppm.width);
    try std.testing.expectEqual(512, ppm.height);
    try std.testing.expectEqual((ppm.width * ppm.height), ppm.data.len);
}

test "ppm save" {
    var ppm = PPM.init(std.testing.allocator, 1, 1);
    defer ppm.deinit();

    try ppm.save("test.ppm");
    defer std.fs.cwd().deleteFile("test.ppm") catch unreachable;

    // By default memory is 0b10101010101... or (170, 170, 170)
    // So our single pixel will be: 170 170 170
    const expected =
        \\P3
        \\1 1
        \\255
        \\170 170 170
        \\
    ;
    const actual = try std.fs.cwd().readFileAlloc(std.testing.allocator, "test.ppm", 1e6);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "main" {
    try main();

    const expected = try std.fs.cwd().readFileAlloc(std.testing.allocator, "test-files/chapter2.ppm", 1e6);
    defer std.testing.allocator.free(expected);

    const actual = try std.fs.cwd().readFileAlloc(std.testing.allocator, "images/chapter2.ppm", 1e6);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
