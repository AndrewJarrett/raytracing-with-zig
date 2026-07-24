const std = @import("std");
const Writer = std.Io.Writer;

const Point = @import("vec.zig").Point;
const Point3 = @import("vec.zig").Point3;
const Vec = @import("vec.zig").Vec;
const Vec3 = @import("vec.zig").Vec3;

pub const Ray = struct {
    orig: Point3 = Point3{ 0, 0, 0 },
    dir: Vec3 = Vec3{ 0, 0, 0 },
    time: f64 = 0,

    pub fn at(self: Ray, t: f64) Vec3 {
        return self.orig + (self.dir * Vec.splat(t));
    }

    pub fn format(self: *const Ray, writer: anytype) !void {
        try writer.print("{any} -> {any} @ time: {d}", .{ self.orig, self.dir, self.time });
    }
};

test "Ray" {
    const ray = Ray{ .dir = Vec3{ 1, 2, 3 } };

    try std.testing.expectEqual(0, ray.orig[0]);
    try std.testing.expectEqual(0, ray.orig[1]);
    try std.testing.expectEqual(0, ray.orig[2]);

    try std.testing.expectEqual(1, ray.dir[0]);
    try std.testing.expectEqual(2, ray.dir[1]);
    try std.testing.expectEqual(3, ray.dir[2]);

    try std.testing.expectEqual(0, ray.time);
}

test "at()" {
    const dir = Vec3{ 1, 2, 3 };
    const ray = Ray{ .dir = dir, .time = 0.5 };
    const t = 1.0;

    const expected = Vec3{ 1, 2, 3 };
    const actual = ray.at(t);
    try std.testing.expectEqual(expected, actual);
}

test "format()" {
    const orig = Point3{ 0.1, 0.9, 0.5 };
    const ray = Ray{ .orig = orig, };

    const expected = "{ 0.1, 0.9, 0.5 } -> { 0, 0, 0 } @ time: 0";
    var buffer: [50]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..50], "{f}", .{ray});

    try std.testing.expectEqualStrings(expected, actual);
}
