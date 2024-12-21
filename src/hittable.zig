const std = @import("std");
const Vec3 = @import("vec.zig").Vec3;
const Point3 = @import("vec.zig").Point3;
const Ray = @import("ray.zig").Ray;
const Sphere = @import("sphere.zig").Sphere;
const Interval = @import("interval.zig").Interval;
const Material = @import("material.zig").Material;
const Color = @import("color.zig").Color;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const DefaultPrng = std.rand.DefaultPrng;

pub const HitRecord = struct {
    point: Point3,
    normal: Vec3,
    mat: Material,
    t: f64,
    front: bool,
};

pub const HittableType = enum {
    sphere,
};

pub const Hittable = union(HittableType) {
    sphere: Sphere,

    pub fn init(hittable: HittableType, args: anytype) Hittable {
        return switch (hittable) {
            .sphere => .{ .sphere = Sphere.init(args.center, args.radius, args.mat) },
        };
    }

    pub fn hit(self: Hittable, ray: Ray, t: Interval) ?HitRecord {
        return switch (self) {
            .sphere => |s| s.hit(ray, t), // Doh!
        };
    }
};

// Not a "hitlist", but a...
pub const HittableList = struct {
    objects: ArrayList(Hittable),

    pub fn init(allocator: Allocator) HittableList {
        return .{
            .objects = ArrayList(Hittable).init(allocator),
        };
    }

    pub fn deinit(self: HittableList) void {
        self.objects.deinit();
    }

    pub fn clear(self: *HittableList) void {
        self.objects.clearAndFree();
    }

    pub fn add(self: *HittableList, object: Hittable) void {
        self.objects.append(object) catch unreachable;
    }

    pub fn hit(self: HittableList, ray: Ray, t: Interval) ?HitRecord {
        var hitRecord: ?HitRecord = null;
        var closest = t.max;

        for (self.objects.items) |item| {
            const tempRecord = item.hit(ray, Interval.init(t.min, closest));
            if (tempRecord) |rec| {
                hitRecord = rec;
                closest = rec.t;
            }
        }

        return hitRecord;
    }
};

test "HitRecord" {
    const prngPtr = try testPrng(0xabadcafe);
    defer std.testing.allocator.destroy(prngPtr);

    const p = Point3.init(0, 0, 0);
    const v = Vec3.init(0, 1, 0);
    const mat = Material.init(.lambertian, Color.init(1, 1, 1), prngPtr);
    const t = 0.5;
    const rec = .{ .point = p, .normal = v, .mat = mat, .t = t };

    try std.testing.expectEqualDeep(p, rec.point);
    try std.testing.expectEqualDeep(v, rec.normal);
    try std.testing.expectEqual(mat, rec.mat);
    try std.testing.expectEqual(t, rec.t);
}

test "HittableType" {
    const sphere = HittableType.sphere;
    try std.testing.expectEqual("sphere", @tagName(sphere));
}

test "Hittable.init()" {
    const prngPtr = try testPrng(0xabadcafe);
    defer std.testing.allocator.destroy(prngPtr);

    const center = Point3.init(0, 0, 0);
    const radius = 1.0;
    const mat = Material.init(.lambertian, Color.init(1, 1, 1), prngPtr);
    const hittable = Hittable.init(.sphere, .{ .center = center, .radius = radius, .mat = mat });

    try std.testing.expectEqual("sphere", @tagName(hittable));
    try std.testing.expectEqual(center, hittable.sphere.center);
    try std.testing.expectEqual(radius, hittable.sphere.radius);
}

test "Hittable.hit()" {
    const prngPtr = try testPrng(0xabadcafe);
    defer std.testing.allocator.destroy(prngPtr);

    const center = Point3.init(0, 0, -2);
    const radius = 1.0;
    const mat = Material.init(.lambertian, Color.init(1, 1, 1), prngPtr);
    const sphere = Sphere.init(center, radius, mat);
    const hittable = Hittable.init(.sphere, sphere);

    const ray = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, -1));
    const hitRecord = hittable.hit(ray, Interval.init(0.0, 3.0));

    try std.testing.expect(hitRecord != null);
    try std.testing.expectEqual(1, hitRecord.?.t);
    try std.testing.expectEqualDeep(ray.at(-1), hitRecord.?.normal);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, -1), hitRecord.?.point);
    try std.testing.expectEqual(true, hitRecord.?.front);
}

test "HittableList.init() and deinit()" {
    const hl = HittableList.init(std.testing.allocator);
    defer hl.deinit();

    try std.testing.expectEqual(0, hl.objects.items.len);
}

test "HittableList.add()" {
    const prngPtr = try testPrng(0xabadcafe);
    defer std.testing.allocator.destroy(prngPtr);
    const mat = Material.init(.lambertian, Color.init(1, 1, 1), prngPtr);

    var hl = HittableList.init(std.testing.allocator);
    defer hl.deinit();
    hl.add(Hittable.init(.sphere, .{ .center = Vec3.init(0, 0, -2), .radius = 1.0, .mat = mat }));
    hl.add(Hittable.init(.sphere, .{ .center = Vec3.init(0, 2, -2), .radius = 1.0, .mat = mat }));

    try std.testing.expectEqual(2, hl.objects.items.len);
}

test "HittableList.clear()" {
    const prngPtr = try testPrng(0xabadcafe);
    defer std.testing.allocator.destroy(prngPtr);
    const mat = Material.init(.lambertian, Color.init(1, 1, 1), prngPtr);

    var hl = HittableList.init(std.testing.allocator);
    defer hl.deinit();

    hl.add(Hittable.init(.sphere, .{ .center = Vec3.init(0, 0, -2), .radius = 1.0, .mat = mat }));
    hl.add(Hittable.init(.sphere, .{ .center = Vec3.init(0, 2, -2), .radius = 1.0, .mat = mat }));

    hl.clear();
    try std.testing.expectEqual(0, hl.objects.items.len);
}

test "HittableList.hit()" {
    const prngPtr = try testPrng(0xabadcafe);
    defer std.testing.allocator.destroy(prngPtr);
    const mat = Material.init(.lambertian, Color.init(1, 1, 1), prngPtr);

    var hl = HittableList.init(std.testing.allocator);
    defer hl.deinit();

    hl.add(Hittable.init(.sphere, .{ .center = Vec3.init(0, 0, -2), .radius = 1.0, .mat = mat }));
    hl.add(Hittable.init(.sphere, .{ .center = Vec3.init(0, 0, -3), .radius = 1.0, .mat = mat }));
    hl.add(Hittable.init(.sphere, .{ .center = Vec3.init(0, 0, -4), .radius = 1.0, .mat = mat }));
    hl.add(Hittable.init(.sphere, .{ .center = Vec3.init(0, 0, -5), .radius = 1.0, .mat = mat }));

    const ray: Ray = Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, -1));
    const hitRecord = hl.hit(ray, Interval.init(-6, 6));

    try std.testing.expect(hitRecord != null);
    try std.testing.expectEqual(1, hitRecord.?.t);
    try std.testing.expectEqualDeep(ray.at(1), hitRecord.?.point);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, 1), hitRecord.?.normal);
    try std.testing.expectEqual(true, hitRecord.?.front);
}

fn testPrng(seed: u64) !*DefaultPrng {
    const prngPtr = try std.testing.allocator.create(DefaultPrng);
    const prng = DefaultPrng.init(seed);
    prngPtr.* = prng;

    return prngPtr;
}
