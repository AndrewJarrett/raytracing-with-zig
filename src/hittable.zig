const std = @import("std");
const Vec3 = @import("vec.zig").Vec3;
const Point3 = @import("vec.zig").Point3;
const Ray = @import("ray.zig").Ray;
const Sphere = @import("sphere.zig").Sphere;
const Interval = @import("interval.zig").Interval;
const Material = @import("material.zig").Material;
const Color3 = @import("color.zig").Color3;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;

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

    pub fn init(shape: Shape, args: anytype) Object {
        return switch (shape) {
            inline .sphere => .{ .sphere = Sphere.init(args.center, args.radius, args.mat) },
        };
    }

    pub inline fn hit(self: Object, ray: Ray, t: Interval) ?Hit {
        return switch (self) {
            inline .sphere => |s| s.hit(ray, t), // Doh!
        };
    }
};

test "Hit" {
    const p = Point3{ 0, 0, 0 };
    const v = Vec3{ 0, 1, 0 };
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 } },
    );
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
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 } },
    );
    const object = Object.init(.sphere, .{ .center = center, .radius = radius, .mat = mat });

    try std.testing.expectEqual("sphere", @tagName(object));
    try std.testing.expectEqual(center, object.sphere.center);
    try std.testing.expectEqual(radius, object.sphere.radius);
}

test "Object.hit()" {
    var prng = DefaultPrng.init(0xabadcafe);

    const center = Point3{ 0, 0, -2 };
    const radius = 1.0;
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 } },
    );
    const sphere = Sphere.init(center, radius, mat);
    const object = Object.init(.sphere, sphere);

    const ray = Ray.init(Vec3{ 0, 0, 0 }, Vec3{ 0, 0, -1 }, &prng);
    const hit = object.hit(ray, Interval.init(0.0, 3.0));

    try std.testing.expect(hit != null);
    try std.testing.expectEqual(1, hit.?.t);
    try std.testing.expectEqualDeep(ray.at(-1), hit.?.normal);
    try std.testing.expectEqualDeep(Vec3{ 0, 0, -1 }, hit.?.point);
    try std.testing.expectEqual(true, hit.?.front);
}
