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
            inline .sphere => .{ .sphere = Sphere.init(args.center, args.radius, args.mat) },
        };
    }

    pub inline fn hit(self: Hittable, ray: Ray, t: Interval) ?HitRecord {
        return switch (self) {
            inline .sphere => |s| s.hit(ray, t), // Doh!
        };
    }
};

// Not a "hitlist", but a...
pub const HittableList = struct {
    objects: ArrayList(Hittable),

    pub fn init() HittableList {
        return .{
            .objects = .empty,
        };
    }

    pub fn deinit(self: *HittableList, alloc: Allocator) void {
        self.objects.deinit(alloc);
    }

    pub fn clear(self: *HittableList, alloc: Allocator) void {
        self.objects.clearAndFree(alloc);
    }

    pub fn add(self: *HittableList, alloc: Allocator, object: Hittable) void {
        self.objects.append(alloc, object) catch unreachable;
    }

    pub fn hit(self: HittableList, ray: Ray, t: Interval) ?HitRecord {
        var hitRecord: ?HitRecord = null;
        var closest = t.max;

        for (self.objects.items) |item| {
            const tempRecord = item.hit(ray, Interval.init(t.min, closest));
            if (tempRecord) |rec| {
                hitRecord = tempRecord;
                closest = rec.t;
            }
        }

        return hitRecord;
    }
};

test "HitRecord" {
    const alloc = std.testing.allocator;

    const prngPtr = try testPrng(alloc, 0xabadcafe);
    defer alloc.destroy(prngPtr);

    const p = Point3{ 0, 0, 0 };
    const v = Vec3{ 0, 1, 0 };
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 } },
    );
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
    const alloc = std.testing.allocator;

    const prngPtr = try testPrng(alloc, 0xabadcafe);
    defer alloc.destroy(prngPtr);

    const center = Point3{ 0, 0, 0 };
    const radius = 1.0;
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 } },
    );
    const hittable = Hittable.init(.sphere, .{ .center = center, .radius = radius, .mat = mat });

    try std.testing.expectEqual("sphere", @tagName(hittable));
    try std.testing.expectEqual(center, hittable.sphere.center);
    try std.testing.expectEqual(radius, hittable.sphere.radius);
}

test "Hittable.hit()" {
    const alloc = std.testing.allocator;

    const prngPtr = try testPrng(alloc, 0xabadcafe);
    defer alloc.destroy(prngPtr);

    const center = Point3{ 0, 0, -2 };
    const radius = 1.0;
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 } },
    );
    const sphere = Sphere.init(center, radius, mat);
    const hittable = Hittable.init(.sphere, sphere);

    const ray = Ray.init(Vec3{ 0, 0, 0 }, Vec3{ 0, 0, -1 }, prngPtr);
    const hitRecord = hittable.hit(ray, Interval.init(0.0, 3.0));

    try std.testing.expect(hitRecord != null);
    try std.testing.expectEqual(1, hitRecord.?.t);
    try std.testing.expectEqualDeep(ray.at(-1), hitRecord.?.normal);
    try std.testing.expectEqualDeep(Vec3{ 0, 0, -1 }, hitRecord.?.point);
    try std.testing.expectEqual(true, hitRecord.?.front);
}

test "HittableList.init() and deinit()" {
    const alloc = std.testing.allocator;

    var hl = HittableList.init();
    defer hl.deinit(alloc);

    try std.testing.expectEqual(0, hl.objects.items.len);
}

test "HittableList.add()" {
    const alloc = std.testing.allocator;

    const prngPtr = try testPrng(alloc, 0xabadcafe);
    defer alloc.destroy(prngPtr);
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 } },
    );

    var hl = HittableList.init();
    defer hl.deinit(alloc);
    hl.add(alloc, Hittable.init(.sphere, .{ .center = Vec3{ 0, 0, -2 }, .radius = 1.0, .mat = mat }));
    hl.add(alloc, Hittable.init(.sphere, .{ .center = Vec3{ 0, 2, -2 }, .radius = 1.0, .mat = mat }));

    try std.testing.expectEqual(2, hl.objects.items.len);
}

test "HittableList.clear()" {
    const alloc = std.testing.allocator;

    const prngPtr = try testPrng(alloc, 0xabadcafe);
    defer alloc.destroy(prngPtr);
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 } },
    );

    var hl = HittableList.init();
    defer hl.deinit(alloc);

    hl.add(alloc, Hittable.init(.sphere, .{ .center = Vec3{ 0, 0, -2 }, .radius = 1.0, .mat = mat }));
    hl.add(alloc, Hittable.init(.sphere, .{ .center = Vec3{ 0, 2, -2 }, .radius = 1.0, .mat = mat }));

    hl.clear(alloc);
    try std.testing.expectEqual(0, hl.objects.items.len);
}

test "HittableList.hit()" {
    const alloc = std.testing.allocator;

    const prngPtr = try testPrng(alloc, 0xabadcafe);
    defer alloc.destroy(prngPtr);
    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 }, },
    );

    var hl = HittableList.init();
    defer hl.deinit(alloc);

    hl.add(alloc, Hittable.init(.sphere, .{ .center = Vec3{ 0, 0, -2 }, .radius = 1.0, .mat = mat }));
    hl.add(alloc, Hittable.init(.sphere, .{ .center = Vec3{ 0, 0, -3 }, .radius = 1.0, .mat = mat }));
    hl.add(alloc, Hittable.init(.sphere, .{ .center = Vec3{ 0, 0, -4 }, .radius = 1.0, .mat = mat }));
    hl.add(alloc, Hittable.init(.sphere, .{ .center = Vec3{ 0, 0, -5 }, .radius = 1.0, .mat = mat }));

    const ray: Ray = Ray.init(Vec3{ 0, 0, 0 }, Vec3{ 0, 0, -1 }, prngPtr);
    const hitRecord = hl.hit(ray, Interval.init(-6, 6));

    try std.testing.expect(hitRecord != null);
    try std.testing.expectEqual(1, hitRecord.?.t);
    try std.testing.expectEqualDeep(ray.at(1), hitRecord.?.point);
    try std.testing.expectEqualDeep(Vec3{ 0, 0, 1 }, hitRecord.?.normal);
    try std.testing.expectEqual(true, hitRecord.?.front);
}

fn testPrng(alloc: Allocator, seed: u64) !*DefaultPrng {
    const prngPtr = try alloc.create(DefaultPrng);
    const prng = DefaultPrng.init(seed);
    prngPtr.* = prng;

    return prngPtr;
}
