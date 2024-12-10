const std = @import("std");
const Vec3 = @import("vec.zig").Vec3;
const Point3 = @import("vec.zig").Point3;
const Ray = @import("ray.zig").Ray;

const Sphere = @import("sphere.zig").Sphere;

pub const HitRecord = struct {
    point: Point3,
    normal: Vec3,
    t: f64,
};

pub const HittableType = enum {
    sphere,
};

pub const Hittable = union(HittableType) {
    sphere: Sphere,

    pub fn init(hittable: HittableType, args: anytype) Hittable {
        return switch (hittable) {
            .sphere => .{ .sphere = Sphere.init(args.center, args.radius) },
        };
    }

    pub fn hit(self: Hittable, ray: Ray, tMin: f64, tMax: f64) ?HitRecord {
        return switch (self) {
            .sphere => |s| s.hit(ray, tMin, tMax), // Doh!
        };
    }
};

test "HitRecord" {
    const p = Point3.init(0, 0, 0);
    const v = Vec3.init(0, 1, 0);
    const t = 0.5;
    const rec = .{ .point = p, .normal = v, .t = t };

    try std.testing.expectEqualDeep(p, rec.point);
    try std.testing.expectEqualDeep(v, rec.normal);
    try std.testing.expectEqual(t, rec.t);
}

test "HittableType" {
    const sphere = HittableType.sphere;
    try std.testing.expectEqual("sphere", @tagName(sphere));
}

test "Hittable.init()" {
    const center = Point3.init(0, 0, 0);
    const radius = 1.0;
    const hittable = Hittable.init(.sphere, .{ .center = center, .radius = radius });

    try std.testing.expectEqual("sphere", @tagName(hittable));
    try std.testing.expectEqual(center, hittable.sphere.center);
    try std.testing.expectEqual(radius, hittable.sphere.radius);
}

test "Hittable.hit()" {
    const center = Point3.init(0, 0, -2);
    const radius = 1.0;
    const sphere = Sphere.init(center, radius);
    const hittable = Hittable.init(.sphere, sphere);

    const ray = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, -1));
    const hitRecord = hittable.hit(ray, 0.0, 3.0);

    try std.testing.expect(hitRecord != null);
    try std.testing.expectEqual(1, hitRecord.?.t);
    try std.testing.expectEqualDeep(ray.at(-1), hitRecord.?.normal);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, -1), hitRecord.?.point);
}
