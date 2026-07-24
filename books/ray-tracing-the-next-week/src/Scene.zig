const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const Color3 = @import("color.zig").Color3;
const Dielectric = @import("material.zig").Dielectric;
const Hit = @import("hittable.zig").Hit;
const Interval = @import("Interval.zig");
const Lambertian = @import("material.zig").Lambertian;
const Material = @import("material.zig").Material;
const Metal = @import("material.zig").Metal;
const Object = @import("hittable.zig").Object;
const Point3 = @import("vec.zig").Point3;
const Ray = @import("ray.zig").Ray;
const Sphere = @import("sphere.zig").Sphere;
const util = @import("util.zig");
const Vec = @import("vec.zig").Vec;
const Vec3 = @import("vec.zig").Vec3;

const inf = std.math.inf(f64);

const Self = @This();
seed: u64,
world: []Object,
len: u16 = 0,
interval: Interval = Interval.init(1e-3, inf), // Default - edit field directly if needed

// The enum value is the size of the scene (number of objects)
pub const SceneType = enum(u16) {
    chapter2 = (1 + 22 * 22 + 3),
};

pub fn hit(self: Self, ray: Ray, t: Interval) ?Hit {
    var finalHit: ?Hit = null;
    var closest = t.max;

    for (self.objects()) |object| {
        const maybeHit = object.hit(ray, Interval.init(t.min, closest));
        if (maybeHit) |h| {
            finalHit = maybeHit;
            closest = h.t;
        }
    }

    return finalHit;
}

fn append(self: *Self, object: Object) void {
    assert(self.len < self.world.len);
    self.world[self.len] = object;
    self.len += 1;
    return;
}

pub fn objects(self: Self) []Object {
    assert(self.len <= self.world.len);
    return self.world[0..self.len];
}

pub fn generateScene(self: *Self, comptime sceneType: @EnumLiteral()) void {
    switch (sceneType) {
        .chapter2 => self.generateChapter2(),
        else => @compileError("Unsupported sceneType: " ++ @tagName(sceneType)),
    }
}

fn generateChapter2(self: *Self) void {
    var prng = DefaultPrng.init(self.seed);

    // Materials and objects
    // Ground
    const matGround = Material.init(Lambertian{ .albedo = Color3{ 0.5, 0.5, 0.5 } });
    self.append(Object.init(Sphere.init(Point3{ 0, -1000, 0 }, 1000, matGround)));

    // Generate random spheres and materials
    for (0..22) |a| {
        const xOffset: f64 = @as(f64, @floatFromInt(a)) - 11;
        for (0..22) |b| {
            const zOffset: f64 = @as(f64, @floatFromInt(b)) - 11;

            const chooseMat = util.randomDouble(&prng);
            const center = Point3{
                xOffset + 0.9 * util.randomDouble(&prng),
                0.2,
                zOffset + 0.9 * util.randomDouble(&prng),
            };

            if (Vec.len(center - Point3{ 4, 0.2, 0 }) > 0.9) {
                if (chooseMat < 0.8) {
                    // 80% is diffuse material
                    const albedo = Vec.random(&prng) * Vec.random(&prng);
                    const sphereMaterial = Material.init(Lambertian{ .albedo = albedo });
                    const final = center + Vec3{ 0, util.randomDoubleRange(&prng, 0, 0.5), 0 };
                    self.append(Object.init(Sphere.initMoving(center, final, 0.2, sphereMaterial)));
                } else if (chooseMat < 0.95) {
                    // 15% metal
                    const albedo = Vec.randomRange(0.5, 1, &prng);
                    const fuzz = util.randomDoubleRange(&prng, 0, 0.5);
                    const sphereMaterial = Material.init(Metal{ .albedo = albedo, .fuzz = fuzz });
                    self.append(Object.init(Sphere.init(center, 0.2, sphereMaterial)));
                } else {
                    // 5% chance of glass
                    const sphereMaterial = Material.init(Dielectric{ .refractionIndex = 1.5 });
                    self.append(Object.init(Sphere.init(center, 0.2, sphereMaterial)));
                }
            }
        }
    }

    const mat1 = Material.init(Dielectric{ .refractionIndex = 1.5 });
    self.append(Object.init(Sphere.init(Point3{ 0, 1, 0 }, 1, mat1)));

    const mat2 = Material.init(Lambertian{ .albedo = Color3{ 0.4, 0.2, 0.1 } });
    self.append(Object.init(Sphere.init(Point3{ -4, 1, 0 }, 1, mat2)));

    const mat3 = Material.init(Metal{ .albedo = Color3{ 0.7, 0.6, 0.5 }, .fuzz = 0 });
    self.append(Object.init(Sphere.init(Point3{ 4, 1, 0 }, 1, mat3)));
}

test "Scene.hit()" {
    const alloc = std.testing.allocator;
    const seed = 0xabadcafe;

    const mat = Material.init(Lambertian{ .albedo = Color3{ 1, 1, 1 }, });

    const world = try alloc.alloc(Object, 4);
    defer alloc.free(world);

    var scene = Self{ .seed = seed, .world = world };
    scene.append(Object.init(Sphere.init(Point3{ 0, 0, -2 }, 1.0, mat)));
    scene.append(Object.init(Sphere.init(Point3{ 0, 0, -3 }, 1.0, mat)));
    scene.append(Object.init(Sphere.init(Point3{ 0, 0, -4 }, 1.0, mat)));
    scene.append(Object.init(Sphere.init(Point3{ 0, 0, -5 }, 1.0, mat)));

    const ray: Ray = Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = Vec3{ 0, 0, -1 } };
    const maybeHit = scene.hit(ray, Interval.init(-6, 6));

    try std.testing.expect(maybeHit != null);
    try std.testing.expectEqual(1, maybeHit.?.t);
    try std.testing.expectEqualDeep(ray.at(1), maybeHit.?.point);
    try std.testing.expectEqualDeep(Vec3{ 0, 0, 1 }, maybeHit.?.normal);
    try std.testing.expectEqual(true, maybeHit.?.front);
}
