const std = @import("std");
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vec.zig").Vec3;
const Point3 = @import("vec.zig").Point3;
const HitRecord = @import("hittable.zig").HitRecord;
const Interval = @import("interval.zig").Interval;
const Material = @import("material.zig").Material;
const Color = @import("color.zig").Color;

const DefaultPrng = std.rand.DefaultPrng;

pub const Sphere = struct {
    center: Point3,
    radius: f64,
    mat: Material,

    pub fn init(center: Point3, radius: f64, mat: Material) Sphere {
        return .{
            .center = center,
            .radius = @max(0, radius),
            .mat = mat,
        };
    }

    pub fn hit(self: Sphere, ray: Ray, t: Interval) ?HitRecord {
        const oc: Vec3 = self.center.sub(ray.orig);
        const a = ray.dir.lenSquared();
        const h = ray.dir.dot(oc);
        const c = oc.lenSquared() - self.radius * self.radius;

        const discriminant = h * h - a * c;
        if (discriminant < 0) return null;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest spot that lies in the acceptable range.
        var root = (h - sqrtd) / a;
        //std.debug.print("a: {d}; h: {d}; c: {d}; discriminant: {d}; sqrtd: {d}; root: {d}; tMin: {d}; tMax: {d}\n", .{ a, h, c, discriminant, sqrtd, root, tMin, tMax });
        if (!t.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!t.surrounds(root)) return null;
        }

        const point = ray.at(root);
        const outwardNormal = point.sub(self.center).divScalar(self.radius);
        const front = if (ray.dir.dot(outwardNormal) > 0) false else true;
        return .{
            .t = root,
            .point = point,
            .normal = if (front) outwardNormal else outwardNormal.neg(),
            .mat = self.mat,
            .front = front,
        };
    }
};

test "init()" {
    const prngPtr = try std.testing.allocator.create(DefaultPrng);
    defer std.testing.allocator.destroy(prngPtr);
    const prng = DefaultPrng.init(0xabadcafe);
    prngPtr.* = prng;

    const center = Point3.init(0, 0, 0);
    const radius = 1.0;
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color.init(1, 1, 1), .prng = prngPtr },
    );
    const sphere = Sphere.init(center, radius, mat);

    try std.testing.expectEqual(Sphere, @TypeOf(sphere));
    try std.testing.expectEqual(center, sphere.center);
    try std.testing.expectEqual(radius, sphere.radius);
}

test "hit() success" {
    const prngPtr = try std.testing.allocator.create(DefaultPrng);
    defer std.testing.allocator.destroy(prngPtr);
    const prng = DefaultPrng.init(0xabadcafe);
    prngPtr.* = prng;

    const center = Point3.init(0, 0, -2);
    const radius = 1.0;
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color.init(1, 1, 1), .prng = prngPtr },
    );
    const sphere = Sphere.init(center, radius, mat);

    const ray = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, -1));
    const hitRecord = sphere.hit(ray, Interval.init(0.0, 3.0));

    try std.testing.expect(hitRecord != null);
    try std.testing.expectEqual(1, hitRecord.?.t);
    try std.testing.expectEqualDeep(ray.at(-1), hitRecord.?.normal);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, -1), hitRecord.?.point);
    try std.testing.expectEqual(true, hitRecord.?.front);
}

test "hit() hit out of range" {
    const prngPtr = try std.testing.allocator.create(DefaultPrng);
    defer std.testing.allocator.destroy(prngPtr);
    const prng = DefaultPrng.init(0xabadcafe);
    prngPtr.* = prng;

    const center = Point3.init(0, 0, -2);
    const radius = 1.0;
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color.init(1, 1, 1), .prng = prngPtr },
    );
    const sphere = Sphere.init(center, radius, mat);

    const ray = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, -1));
    const hitRecord = sphere.hit(ray, Interval.init(0.0, 0.0));
    try std.testing.expect(hitRecord == null);
}

test "hit() no hit" {
    const prngPtr = try std.testing.allocator.create(DefaultPrng);
    defer std.testing.allocator.destroy(prngPtr);
    const prng = DefaultPrng.init(0xabadcafe);
    prngPtr.* = prng;

    const center = Point3.init(0, 0, -2);
    const radius = 1.0;
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color.init(1, 1, 1), .prng = prngPtr },
    );
    const sphere = Sphere.init(center, radius, mat);

    const ray = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, 1));
    const hitRecord = sphere.hit(ray, Interval.init(0.0, 3.0));
    try std.testing.expect(hitRecord == null);
}
