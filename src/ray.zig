const std = @import("std");
const Point3 = @import("vec.zig").Point3;
const Vec3 = @import("vec.zig").Vec3;

pub const Ray = packed struct {
    orig: Point3,
    dir: Vec3,

    pub fn init(orig: Point3, dir: Vec3) Ray {
        return .{ .orig = orig, .dir = dir };
    }

    pub fn at(self: Ray, t: f64) Vec3 {
        return self.orig.add(self.dir.mulScalar(t));
    }

    pub fn format(self: Ray, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("[{s}] -> [{s}]", .{ self.orig, self.dir });
    }
};

test "init()" {
    const ray = Ray.init(Point3.init(0, 0, 0), Vec3.init(1, 2, 3));

    try std.testing.expectEqual(0, ray.orig.x());
    try std.testing.expectEqual(0, ray.orig.y());
    try std.testing.expectEqual(0, ray.orig.z());

    try std.testing.expectEqual(1, ray.dir.x());
    try std.testing.expectEqual(2, ray.dir.y());
    try std.testing.expectEqual(3, ray.dir.z());

    // Expect the ray is packed
    try std.testing.expectEqual(2 * 3 * 64, @bitSizeOf(Ray));
}

test "at()" {
    const orig = Point3.init(0, 0, 0);
    const dir = Vec3.init(1, 2, 3);
    const ray = Ray.init(orig, dir);
    const t = 1.0;

    const expected = Vec3.init(1, 2, 3);
    const actual = ray.at(t);
    try std.testing.expectEqual(expected, actual);
}

test "format()" {
    const orig = Point3.init(0, 0, 0);
    const dir = Vec3.init(1, 2, 3);
    const ray = Ray.init(orig, dir);

    const expected = "[0 0 0] -> [1 2 3]";
    var buffer: [25]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{ray});

    try std.testing.expectEqualStrings(expected, actual);
}
