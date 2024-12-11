const std = @import("std");
const Vec3 = @import("vec.zig").Vec3;

pub const Color3 = Vec3;

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
    pixel: Color3,

    pub fn init(r: f64, g: f64, b: f64) Color {
        return .{
            .pixel = Color3.init(r, g, b),
        };
    }

    pub fn fromValue(value: u24) Color {
        return .{ .pixel = Color3.init(
            @as(f64, @floatFromInt((value & 0xff0000) >> 16)) / 255.999,
            @as(f64, @floatFromInt((value & 0x00ff00) >> 8)) / 255.999,
            @as(f64, @floatFromInt(value & 0x0000ff)) / 255.999,
        ) };
    }

    pub fn toValue(self: Color) u24 {
        const rgb = self.toRgb();
        return (@as(u24, rgb.r) << 16) | (@as(u24, rgb.g) << 8) | rgb.b;
    }

    pub fn fromRgb(rgb: RGB) Color {
        return .{
            .pixel = Color3.init(
                @as(f64, @floatFromInt(rgb.r)) / 255.999,
                @as(f64, @floatFromInt(rgb.g)) / 255.999,
                @as(f64, @floatFromInt(rgb.b)) / 255.999,
            ),
        };
    }

    pub fn toRgb(self: Color) RGB {
        return .{
            .r = @intFromFloat(255.999 * self.pixel.x()),
            .g = @intFromFloat(255.999 * self.pixel.y()),
            .b = @intFromFloat(255.999 * self.pixel.z()),
        };
    }

    pub fn format(self: Color, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}", .{self.toRgb()});
    }
};

test "Color3 alias" {
    const c = Color3.init(0.5, 0.5, 0.5);

    try std.testing.expectEqual(0.5, c.x());
    try std.testing.expectEqual(0.5, c.y());
    try std.testing.expectEqual(0.5, c.z());
}

test "rgb struct" {
    const rgb = RGB{ .r = 255, .g = 0, .b = 255 };
    const expected = "255 0 255";

    try std.testing.expectEqual(255, rgb.r);
    try std.testing.expectEqual(0, rgb.g);
    try std.testing.expectEqual(255, rgb.b);

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{rgb});
    try std.testing.expectEqualStrings(expected, actual);

    // Ensure the struct is packed
    try std.testing.expectEqual(24, @bitSizeOf(RGB));
}

test "init()" {
    const c = Color.init(0.0, 0.5, 0.75);

    try std.testing.expectEqual(0.0, c.pixel.x());
    try std.testing.expectEqual(0.5, c.pixel.y());
    try std.testing.expectEqual(0.75, c.pixel.z());

    // Ensure the Color struct is packed
    try std.testing.expectEqual(64 * 3, @bitSizeOf(Color));
}

test "fromValue()" {
    const value: u24 = ((255 << 16) | (0 << 8) | 255);
    const c = Color.fromValue(value);

    try std.testing.expectEqual(255, c.toRgb().r);
    try std.testing.expectEqual(0, c.toRgb().g);
    try std.testing.expectEqual(255, c.toRgb().b);
}

test "toValue()" {
    const expected: u24 = ((255 << 16) | (0 << 8) | 255);
    const actual = Color.init(1.0, 0.0, 1.0).toValue();
    try std.testing.expectEqual(expected, actual);
}

test "fromRgb()" {
    const c = Color.fromRgb(.{ .r = 255, .g = 0, .b = 255 });

    try std.testing.expectEqual(255, c.toRgb().r);
    try std.testing.expectEqual(0, c.toRgb().g);
    try std.testing.expectEqual(255, c.toRgb().b);
}

test "toRgb()" {
    const rgb = Color.init(0.0, 0.5, 0.75).toRgb();

    try std.testing.expectEqual(0, rgb.r);
    try std.testing.expectEqual(127, rgb.g);
    try std.testing.expectEqual(191, rgb.b);
}

test "format()" {
    const c = Color.init(0.0, 0.5, 0.75);
    const expected = "0 127 191";

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{c});
    try std.testing.expectEqualStrings(expected, actual);
}
