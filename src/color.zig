const std = @import("std");
const Vec3 = @import("vec.zig").Vec3;
const Interval = @import("interval.zig").Interval;

pub const Color3 = Vec3;

/// Holds the RGB values for a pixel's color
pub const RGB = struct {
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
pub const Color = struct {
    pixel: Color3,

    pub fn init(r: f64, g: f64, b: f64) Color {
        return .{ .pixel = Color3{ r, g, b } };
    }

    pub fn fromValue(value: u24) Color {
        return .{
            .pixel = .{
                @as(f64, @floatFromInt((value & 0xff0000) >> 16)) / 255.999,
                @as(f64, @floatFromInt((value & 0x00ff00) >> 8)) / 255.999,
                @as(f64, @floatFromInt(value & 0x0000ff)) / 255.999,
            },
        };
    }

    pub fn toValue(self: Color) u24 {
        const rgb = self.toRgb();
        return (@as(u24, rgb.r) << 16) | (@as(u24, rgb.g) << 8) | rgb.b;
    }

    pub fn fromVec(vec: Vec3) Color {
        return .{ .pixel = vec };
    }

    pub fn toVec(self: Color) Vec3 {
        return @as(Vec3, self.pixel);
    }

    pub fn fromRgb(rgb: RGB) Color {
        return .{
            .pixel = .{
                @as(f64, @floatFromInt(rgb.r)) / 255.999,
                @as(f64, @floatFromInt(rgb.g)) / 255.999,
                @as(f64, @floatFromInt(rgb.b)) / 255.999,
            },
        };
    }

    pub fn toRgb(self: Color) RGB {
        const interval = Interval.init(0.000, 0.999);
        return .{
            .r = @intFromFloat(256 * interval.clamp(
                Color.linearToGamma(self.pixel[0]),
            )),
            .g = @intFromFloat(256 * interval.clamp(
                Color.linearToGamma(self.pixel[1]),
            )),
            .b = @intFromFloat(256 * interval.clamp(
                Color.linearToGamma(self.pixel[2]),
            )),
        };
    }

    inline fn linearToGamma(linear: f64) f64 {
        return if (linear > 0) @sqrt(linear) else 0;
    }

    pub fn format(self: Color, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}", .{self.toRgb()});
    }
};

test "Color3 alias" {
    const c = Color3{ 0.5, 0.5, 0.5 };

    try std.testing.expectEqual(0.5, c[0]);
    try std.testing.expectEqual(0.5, c[1]);
    try std.testing.expectEqual(0.5, c[2]);
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

    try std.testing.expectEqual(0.0, c.pixel[0]);
    try std.testing.expectEqual(0.5, c.pixel[1]);
    try std.testing.expectEqual(0.75, c.pixel[2]);
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

test "fromVec()" {
    const expected = Color{ .pixel = Color3{ 3, 2, 1 } };
    const actual = Color.fromVec(Color3{ 3, 2, 1 });
    try std.testing.expectEqual(expected, actual);
}

test "toVec()" {
    const expected = Vec3{ 3, 2, 1 };
    const actual = Color.fromVec(Vec3{ 3, 2, 1 }).toVec();
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
    try std.testing.expectEqual(181, rgb.g);
    try std.testing.expectEqual(221, rgb.b);
}

test "linearToGamma()" {
    try std.testing.expectEqual(0, Color.linearToGamma(-1));
    try std.testing.expectEqual(0, Color.linearToGamma(0));
    try std.testing.expectEqual(@sqrt(2.0), Color.linearToGamma(2));
    try std.testing.expectEqual(2, Color.linearToGamma(4));
    try std.testing.expectEqual(4, Color.linearToGamma(16));
    try std.testing.expectEqual(@sqrt(3.0), Color.linearToGamma(3));
}

test "format()" {
    const c = Color.init(0.0, 0.5, 0.75);
    const expected = "0 181 221";

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{c});
    try std.testing.expectEqualStrings(expected, actual);
}
