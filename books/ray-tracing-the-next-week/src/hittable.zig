const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;

const Color3 = @import("color.zig").Color3;
const Interval = @import("interval.zig").Interval;
const Material = @import("material.zig").Material;
const Point3 = @import("vec.zig").Point3;
const Ray = @import("ray.zig").Ray;
const Sphere = @import("sphere.zig").Sphere;
const Vec3 = @import("vec.zig").Vec3;
const Lambertian = @import("material.zig").Lambertian;

pub const Hit = struct {
    point: Point3,
    normal: Vec3,
    mat: Material,
    t: f64,
    front: bool,
};

pub const Shape = enum {
    sphere,
};

pub const Object = union(Shape) {
    sphere: Sphere,

    pub fn init(shape: anytype) Object {
        return switch (@TypeOf(shape)) {
            Sphere => .{ .sphere = shape },
            else => @compileError("Unknown shape: " ++ @typeName(@TypeOf(shape))),
        };
    }

    pub fn hit(self: Object, ray: Ray, t: Interval) ?Hit {
        return switch (self) {
            .sphere => |s| s.hit(ray, t), // Doh!
        };
    }
};

test "Hit" {
    const p = Point3{ 0, 0, 0 };
    const v = Vec3{ 0, 1, 0 };
    const mat = Material.init(Lambertian{ .albedo = Color3{ 1, 1, 1 } });
    const t = 0.5;
    const rec: Hit = .{ .point = p, .normal = v, .mat = mat, .t = t, .front = true };

    try std.testing.expectEqualDeep(p, rec.point);
    try std.testing.expectEqualDeep(v, rec.normal);
    try std.testing.expectEqual(mat, rec.mat);
    try std.testing.expectEqual(t, rec.t);
    try std.testing.expectEqual(true, rec.front);
}

test "Shape" {
    const sphere = Shape.sphere;
    try std.testing.expectEqual("sphere", @tagName(sphere));
}

test "Object.init()" {
    const center = Point3{ 0, 0, 0 };
    const radius = 1.0;
    const mat = Material.init(Lambertian{ .albedo = Color3{ 1, 1, 1 } });
    const object = Object.init(Sphere.init(center, radius, mat));

    try std.testing.expectEqual("sphere", @tagName(object));
    try std.testing.expectEqual(center, object.sphere.center.orig);
    try std.testing.expectEqual(Vec3{ 0, 0, 0 }, object.sphere.center.dir);
    try std.testing.expectEqual(0, object.sphere.center.time);
    try std.testing.expectEqual(radius, object.sphere.radius);
}

test "Object.hit()" {
    const center = Point3{ 0, 0, -2 };
    const radius = 1.0;
    const mat = Material.init(Lambertian{ .albedo = Color3{ 1, 1, 1 } });
    const sphere = Sphere.init(center, radius, mat);
    const object = Object.init(sphere);

    const ray = Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = Vec3{ 0, 0, -1 } };
    const hit = object.hit(ray, Interval.init(0.0, 3.0));

    try std.testing.expect(hit != null);
    try std.testing.expectEqual(1, hit.?.t);
    try std.testing.expectEqualDeep(ray.at(-1), hit.?.normal);
    try std.testing.expectEqualDeep(Vec3{ 0, 0, -1 }, hit.?.point);
    try std.testing.expectEqual(true, hit.?.front);
}
