const std = @import("std");
const Vec = @import("vec.zig").Vec;
const Point = @import("vec.zig").Point;
const Point3 = @import("vec.zig").Point3;
const Vec3 = @import("vec.zig").Vec3;

pub const Ray = struct {
    orig: Point3,
    dir: Vec3,

    pub fn init(orig: Point3, dir: Vec3) Ray {
        return .{ .orig = orig, .dir = dir };
    }

    pub fn at(self: Ray, t: f64) Vec3 {
        return self.orig + (self.dir * Vec.splat(t));
    }

    pub fn format(self: *const Ray, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{any} -> {any}", .{ self.orig, self.dir });
    }
};

test "init()" {
    const ray = Ray.init(Point3{ 0, 0, 0 }, Vec3{ 1, 2, 3 });

    try std.testing.expectEqual(0, ray.orig[0]);
    try std.testing.expectEqual(0, ray.orig[1]);
    try std.testing.expectEqual(0, ray.orig[2]);

    try std.testing.expectEqual(1, ray.dir[0]);
    try std.testing.expectEqual(2, ray.dir[1]);
    try std.testing.expectEqual(3, ray.dir[2]);
}

test "at()" {
    const orig = Point3{ 0, 0, 0 };
    const dir = Vec3{ 1, 2, 3 };
    const ray = Ray.init(orig, dir);
    const t = 1.0;

    const expected = Vec3{ 1, 2, 3 };
    const actual = ray.at(t);
    try std.testing.expectEqual(expected, actual);
}

test "format()" {
    const orig = Point3{ 0, 0, 0 };
    const dir = Vec3{ 1, 2, 3 };
    const ray = Ray.init(orig, dir);

    const expected = "{ 0e0, 0e0, 0e0 } -> { 1e0, 2e0, 3e0 }";
    var buffer: [50]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{ray});
    //const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{ray});

    try std.testing.expectEqualStrings(expected, actual);
}
