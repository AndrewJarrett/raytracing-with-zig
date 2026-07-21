const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const Color3 = @import("color.zig").Color3;
const Hit = @import("hittable.zig").Hit;
const Interval = @import("interval.zig").Interval;
const Material = @import("material.zig").Material;
const Object = @import("hittable.zig").Object;
const Point3 = @import("vec.zig").Point3;
const Ray = @import("ray.zig").Ray;
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
    chapter13 = 5,
    chapter14 = (1 + 22 * 22 + 3),
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
    return self.world[0..self.len];
}

pub fn generateScene(self: *Self, comptime sceneType: @EnumLiteral()) void {
    switch (sceneType) {
        inline .chapter13 => self.generateChapter13(),
        inline .chapter14 => self.generateChapter14(),
        else => return,
    }
}

fn generateChapter14(self: *Self) void {
    var prng = DefaultPrng.init(self.seed);

    // Materials and objects
    // Ground
    const matGround = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 0.5, 0.5, 0.5 } },
    );
    self.append(Object.init(.sphere, .{
        .center = Point3{ 0, -1000, 0 },
        .radius = 1000,
        .mat = matGround,
    }));

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
                // 5% chance of glass
                var sphereMaterial = Material.init(.dielectric, .{
                    .refractionIndex = 1.5,
                });

                if (chooseMat < 0.8) {
                    // 80% is diffuse material
                    const albedo = Vec.random(&prng) * Vec.random(&prng);
                    sphereMaterial = Material.init(.lambertian, .{
                        .albedo = albedo,
                    });
                } else if (chooseMat < 0.95) {
                    // 15% metal
                    const albedo = Vec.randomRange(0.5, 1, &prng);
                    const fuzz = util.randomDoubleRange(0, 0.5, &prng);
                    sphereMaterial = Material.init(.metal, .{
                        .albedo = albedo,
                        .fuzz = fuzz,
                    });
                }

                self.append(Object.init(.sphere, .{
                    .center = center,
                    .radius = 0.2,
                    .mat = sphereMaterial,
                }));
            }
        }
    }

    const mat1 = Material.init(
        .dielectric,
        .{ .refractionIndex = 1.5 },
    );
    self.append(Object.init(
        .sphere,
        .{ .center = Point3{ 0, 1, 0 }, .radius = 1, .mat = mat1 },
    ));

    const mat2 = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 0.4, 0.2, 0.1 } },
    );
    self.append(Object.init(
        .sphere,
        .{ .center = Point3{ -4, 1, 0 }, .radius = 1, .mat = mat2 },
    ));

    const mat3 = Material.init(
        .metal,
        .{ .albedo = Color3{ 0.7, 0.6, 0.5 }, .fuzz = 0 },
    );
    self.append(Object.init(
        .sphere,
        .{ .center = Point3{ 4, 1, 0 }, .radius = 1, .mat = mat3 },
    ));
}

fn generateChapter13(self: *Self) []Object {
    const matGround = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 0.8, 0.8, 0.0 } },
    );
    self.append(Object.init(.sphere, .{
        .center = Point3{ 0, -100.5, -1 },
        .radius = 100,
        .mat = matGround,
    }));

    const matCenter = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 0.1, 0.2, 0.5 } },
    );
    self.append(Object.init(
        .sphere,
        .{ .center = Point3{ 0, 0, -1.2 }, .radius = 0.5, .mat = matCenter },
    ));

    const matLeft = Material.init(
        .dielectric,
        .{ .refractionIndex = 1.5 },
    );
    self.append(Object.init(
        .sphere,
        .{ .center = Point3{ -1, 0, -1 }, .radius = 0.5, .mat = matLeft },
    ));

    const matBubble = Material.init(
        .dielectric,
        .{ .refractionIndex = 1.0 / 1.5 },
    );
    self.append(Object.init(
        .sphere,
        .{ .center = Point3{ -1, 0, -1 }, .radius = 0.4, .mat = matBubble },
    ));

    const matRight = Material.init(
        .metal,
        .{ .albedo = Color3{ 0.8, 0.6, 0.2 }, .fuzz = 1 },
    );
    self.append(Object.init(
        .sphere,
        .{ .center = Point3{ 1, 0, -1 }, .radius = 0.5, .mat = matRight },
    ));
}

test "Scene" {
    const alloc = std.testing.allocator;
    const seed = 0xabadcafe;

    const size = @intFromEnum(SceneType.chapter14);
    const world = try alloc.alloc(Object, size);
    defer alloc.free(world);

    var scene = Self{ .seed = seed, .world = world };

    // At first, the world is empty (but the slice has max length)
    try std.testing.expectEqual(0, scene.len);
    try std.testing.expectEqual(size, scene.world.len);

    scene.generateScene(.chapter14);

    // The world should not be empty and should contain all elements
    try std.testing.expectEqual(size - 3, scene.len);
    try std.testing.expectEqual(size - 3, scene.objects().len);
    try std.testing.expectEqualDeep(Interval.init(1e-3, inf), scene.interval);
}

test "Scene.hit()" {
    const alloc = std.testing.allocator;
    const seed = 0xabadcafe;
    var prng = DefaultPrng.init(seed);

    const mat = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 1, 1, 1 }, },
    );

    const world = try alloc.alloc(Object, 4);
    defer alloc.free(world);

    var scene = Self{ .seed = seed, .world = world };
    scene.append(Object.init(.sphere, .{ .center = Vec3{ 0, 0, -2 }, .radius = 1.0, .mat = mat }));
    scene.append(Object.init(.sphere, .{ .center = Vec3{ 0, 0, -3 }, .radius = 1.0, .mat = mat }));
    scene.append(Object.init(.sphere, .{ .center = Vec3{ 0, 0, -4 }, .radius = 1.0, .mat = mat }));
    scene.append(Object.init(.sphere, .{ .center = Vec3{ 0, 0, -5 }, .radius = 1.0, .mat = mat }));

    const ray: Ray = Ray.init(Vec3{ 0, 0, 0 }, Vec3{ 0, 0, -1 }, &prng);
    const maybeHit = scene.hit(ray, Interval.init(-6, 6));

    try std.testing.expect(maybeHit != null);
    try std.testing.expectEqual(1, maybeHit.?.t);
    try std.testing.expectEqualDeep(ray.at(1), maybeHit.?.point);
    try std.testing.expectEqualDeep(Vec3{ 0, 0, 1 }, maybeHit.?.normal);
    try std.testing.expectEqual(true, maybeHit.?.front);
}
