const std = @import("std");
const Ray = @import("ray.zig").Ray;
const Vec3 = @import("vec.zig").Vec3;
const Point3 = @import("vec.zig").Point3;
const HitRecord = @import("hittable.zig").HitRecord;

pub const Sphere = struct {
    center: Point3,
    radius: f64,

    pub fn init(center: Point3, radius: f64) Sphere {
        return .{
            .center = center,
            .radius = @max(0, radius),
        };
    }

    pub fn hit(self: Sphere, ray: Ray, tMin: f64, tMax: f64) ?HitRecord {
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
        if (root <= tMin or tMax <= root) {
            root = (h + sqrtd) / a;
            if (root <= tMin or tMax <= root) return null;
        }

        const point = ray.at(root);
        const outwardNormal = point.sub(self.center).divScalar(self.radius);
        const front = if (ray.dir.dot(outwardNormal) > 0) false else true;
        return .{
            .t = root,
            .point = point,
            .normal = if (front) outwardNormal else outwardNormal.neg(),
            .front = front,
        };
    }
};

test "init()" {
    const center = Point3.init(0, 0, 0);
    const radius = 1.0;
    const sphere = Sphere.init(center, radius);

    try std.testing.expectEqual(Sphere, @TypeOf(sphere));
    try std.testing.expectEqual(center, sphere.center);
    try std.testing.expectEqual(radius, sphere.radius);
}

test "hit() success" {
    const center = Point3.init(0, 0, -2);
    const radius = 1.0;
    const sphere = Sphere.init(center, radius);

    const ray = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, -1));
    const hitRecord = sphere.hit(ray, 0.0, 3.0);

    try std.testing.expect(hitRecord != null);
    try std.testing.expectEqual(1, hitRecord.?.t);
    try std.testing.expectEqualDeep(ray.at(-1), hitRecord.?.normal);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, -1), hitRecord.?.point);
    try std.testing.expectEqual(true, hitRecord.?.front);
}

test "hit() hit out of range" {
    const center = Point3.init(0, 0, -2);
    const radius = 1.0;
    const sphere = Sphere.init(center, radius);

    const ray = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, -1));
    const hitRecord = sphere.hit(ray, 0.0, 0.0);
    try std.testing.expect(hitRecord == null);
}

test "hit() no hit" {
    const center = Point3.init(0, 0, -2);
    const radius = 1.0;
    const sphere = Sphere.init(center, radius);

    const ray = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, 1));
    const hitRecord = sphere.hit(ray, 0.0, 3.0);
    try std.testing.expect(hitRecord == null);
}
