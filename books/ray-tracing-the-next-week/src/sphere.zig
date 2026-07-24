const std = @import("std");

const Color3 = @import("color.zig").Color3;
const Dielectric = @import("material.zig").Dielectric;
const Hit = @import("hittable.zig").Hit;
const Interval = @import("interval.zig").Interval;
const Lambertian = @import("material.zig").Lambertian;
const Material = @import("material.zig").Material;
const Metal = @import("material.zig").Metal;
const Point3 = @import("vec.zig").Point3;
const Ray = @import("ray.zig").Ray;
const Vec = @import("vec.zig").Vec;
const Vec3 = @import("vec.zig").Vec3;

pub const Sphere = struct {
    center: Ray,
    radius: f64,
    mat: Material,

    pub fn init(center: Point3, radius: f64, mat: Material) Sphere {
        return .{
            .center = Ray{ .orig = center, .dir = Vec3{ 0, 0, 0 } },
            .radius = @max(0, radius),
            .mat = mat,
        };
    }

    pub fn initMoving(start: Point3, end: Point3, radius: f64, mat: Material) Sphere {
        return .{
            .center = Ray{ .orig = start, .dir = (end - start) },
            .radius = @max(0, radius),
            .mat = mat,
        };
    }

    pub fn hit(self: Sphere, ray: Ray, t: Interval) ?Hit {
        const current_center = self.center.at(ray.time);
        const oc = current_center - ray.orig;
        const a = Vec.lenSquared(ray.dir);
        const h = Vec.dot(ray.dir, oc);
        const c = Vec.lenSquared(oc) - self.radius * self.radius;

        const discriminant = h * h - a * c;
        if (discriminant < 0) return null;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest spot that lies in the acceptable range.
        var root = (h - sqrtd) / a;
        if (!t.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!t.surrounds(root)) return null;
        }

        const point = ray.at(root);
        const outwardNormal = Vec.divScalar(point - current_center, self.radius);
        const front: bool = Vec.dot(ray.dir, outwardNormal) < 0;
        return .{
            .t = root,
            .point = point,
            .normal = if (front) outwardNormal else -outwardNormal,
            .mat = self.mat,
            .front = front,
        };
    }
};

test "init()" {
    const center = Ray{};
    const radius = 1.0;
    const mat = Material.init(Lambertian{ .albedo = Color3{ 1, 1, 1 } });
    const sphere = Sphere.init(center.orig, radius, mat);

    try std.testing.expectEqual(Sphere, @TypeOf(sphere));
    try std.testing.expectEqual(Point3{ 0, 0, 0 }, sphere.center.orig);
    try std.testing.expectEqual(Vec3{ 0, 0, 0 }, sphere.center.dir);
    try std.testing.expectEqual(0, sphere.center.time);
    try std.testing.expectEqual(center, sphere.center);
    try std.testing.expectEqual(radius, sphere.radius);
    try std.testing.expectEqual(mat, sphere.mat);
}

test "initMoving()" {
    const start = Point3{ 0, 0, 0 };
    const end = Point3{ 0, 1, 1 };
    const radius = 1.0;
    const mat = Material.init(Lambertian{ .albedo = Color3{ 1, 1, 1 } });
    const sphere = Sphere.initMoving(start, end, radius, mat);

    try std.testing.expectEqual(Sphere, @TypeOf(sphere));
    try std.testing.expectEqual(start, sphere.center.orig);
    try std.testing.expectEqual(end - start, sphere.center.dir);
    try std.testing.expectEqual(0, sphere.center.time);
    try std.testing.expectEqual(Ray{ .orig = start, .dir = (end - start) }, sphere.center);
    try std.testing.expectEqual(radius, sphere.radius);
    try std.testing.expectEqual(mat, sphere.mat);
}

test "hit() success" {
    const center = Point3{ 0, 0, -2 };
    const radius = 1.0;
    const mat = Material.init(Lambertian{ .albedo = Color3{ 1, 1, 1 } });
    const sphere = Sphere.init(center, radius, mat);

    const ray = Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = Vec3{ 0, 0, -1 } };
    const hitRecord = sphere.hit(ray, Interval.init(0.0, 3.0));

    try std.testing.expect(hitRecord != null);
    try std.testing.expectEqual(1, hitRecord.?.t);
    try std.testing.expectEqualDeep(ray.at(-1), hitRecord.?.normal);
    try std.testing.expectEqualDeep(Vec3{ 0, 0, -1 }, hitRecord.?.point);
    try std.testing.expectEqual(true, hitRecord.?.front);
}

test "hit() hit out of range" {
    const center = Point3{ 0, 0, -2 };
    const radius = 1.0;
    const mat = Material.init(Lambertian{ .albedo = Color3{ 1, 1, 1 } });
    const sphere = Sphere.init(center, radius, mat);

    const ray = Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = Vec3{ 0, 0, -1 } };
    const hitRecord = sphere.hit(ray, Interval.init(0.0, 0.0));
    try std.testing.expect(hitRecord == null);
}

test "hit() no hit" {
    const center = Point3{ 0, 0, -2 };
    const radius = 1.0;
    const mat = Material.init(Lambertian{ .albedo = Color3{ 1, 1, 1 } });
    const sphere = Sphere.init(center, radius, mat);

    const ray = Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = Vec3{ 0, 0, 1 } };
    const hitRecord = sphere.hit(ray, Interval.init(0.0, 3.0));
    try std.testing.expect(hitRecord == null);
}
