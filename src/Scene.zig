const std = @import("std");
const HittableList = @import("hittable.zig").HittableList;
const Hittable = @import("hittable.zig").Hittable;
const Material = @import("material.zig").Material;
const Color3 = @import("color.zig").Color3;
const Vec = @import("vec.zig").Vec;
const Point3 = @import("vec.zig").Point3;
const util = @import("util.zig");
const Interval = @import("interval.zig").Interval;

const inf = std.math.inf(f64);

const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;

const Self = @This();
alloc: Allocator,
world: HittableList,
interval: Interval = Interval.init(1e-3, inf), // Default - edit field directly if needed

pub fn init(allocator: Allocator) Self {
    return .{
        .alloc = allocator,
        .world = HittableList.init(),
    };
}

pub fn generateWorld(self: *Self, prng: *DefaultPrng) void {
    // Materials and objects
    // Ground
    const matGround = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 0.5, 0.5, 0.5 }, .prng = prng },
    );
    self.world.add(self.alloc, Hittable.init(.sphere, .{
        .center = Point3{ 0, -1000, 0 },
        .radius = 1000,
        .mat = matGround,
    }));

    // Generate random spheres and materials
    for (0..22) |a| {
        const xOffset: f64 = @as(f64, @floatFromInt(a)) - 11;
        for (0..22) |b| {
            const zOffset: f64 = @as(f64, @floatFromInt(b)) - 11;

            const chooseMat = util.randomDouble(prng);
            const center = Point3{
                xOffset + 0.9 * util.randomDouble(prng),
                0.2,
                zOffset + 0.9 * util.randomDouble(prng),
            };

            if (Vec.len(center - Point3{ 4, 0.2, 0 }) > 0.9) {
                // 5% chance of glass
                var sphereMaterial = Material.init(.dielectric, .{
                    .refractionIndex = 1.5,
                    .prng = prng,
                });

                if (chooseMat < 0.8) {
                    // 80% is diffuse material
                    const albedo = Vec.random(prng) * Vec.random(prng);
                    sphereMaterial = Material.init(.lambertian, .{
                        .albedo = albedo,
                        .prng = prng,
                    });
                } else if (chooseMat < 0.95) {
                    // 15% metal
                    const albedo = Vec.randomRange(0.5, 1, prng);
                    const fuzz = util.randomDoubleRange(0, 0.5, prng);
                    sphereMaterial = Material.init(.metal, .{
                        .albedo = albedo,
                        .fuzz = fuzz,
                        .prng = prng,
                    });
                }

                self.world.add(self.alloc, Hittable.init(.sphere, .{
                    .center = center,
                    .radius = 0.2,
                    .mat = sphereMaterial,
                }));
            }
        }
    }

    const mat1 = Material.init(
        .dielectric,
        .{ .refractionIndex = 1.5, .prng = prng },
    );
    self.world.add(self.alloc, Hittable.init(
        .sphere,
        .{ .center = Point3{ 0, 1, 0 }, .radius = 1, .mat = mat1 },
    ));

    const mat2 = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 0.4, 0.2, 0.1 }, .prng = prng },
    );
    self.world.add(self.alloc, Hittable.init(
        .sphere,
        .{ .center = Point3{ -4, 1, 0 }, .radius = 1, .mat = mat2 },
    ));

    const mat3 = Material.init(
        .metal,
        .{ .albedo = Color3{ 0.7, 0.6, 0.5 }, .fuzz = 0, .prng = prng },
    );
    self.world.add(self.alloc, Hittable.init(
        .sphere,
        .{ .center = Point3{ 4, 1, 0 }, .radius = 1, .mat = mat3 },
    ));
}

pub fn generateChapter13(self: *Self, prng: *DefaultPrng) void {
    const matGround = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 0.8, 0.8, 0.0 }, .prng = prng },
    );
    self.world.add(self.alloc, Hittable.init(.sphere, .{
        .center = Point3{ 0, -100.5, -1 },
        .radius = 100,
        .mat = matGround,
    }));

    const matCenter = Material.init(
        .lambertian,
        .{ .albedo = Color3{ 0.1, 0.2, 0.5 }, .prng = prng },
    );
    self.world.add(self.alloc, Hittable.init(
        .sphere,
        .{ .center = Point3{ 0, 0, -1.2 }, .radius = 0.5, .mat = matCenter },
    ));

    const matLeft = Material.init(
        .dielectric,
        .{ .refractionIndex = 1.5, .prng = prng },
    );
    self.world.add(self.alloc, Hittable.init(
        .sphere,
        .{ .center = Point3{ -1, 0, -1 }, .radius = 0.5, .mat = matLeft },
    ));

    const matBubble = Material.init(
        .dielectric,
        .{ .refractionIndex = 1.0 / 1.5, .prng = prng },
    );
    self.world.add(self.alloc, Hittable.init(
        .sphere,
        .{ .center = Point3{ -1, 0, -1 }, .radius = 0.4, .mat = matBubble },
    ));

    const matRight = Material.init(
        .metal,
        .{ .albedo = Color3{ 0.8, 0.6, 0.2 }, .fuzz = 1, .prng = prng },
    );
    self.world.add(self.alloc, Hittable.init(
        .sphere,
        .{ .center = Point3{ 1, 0, -1 }, .radius = 0.5, .mat = matRight },
    ));
}

pub fn deinit(self: *Self) void {
    self.world.deinit(self.alloc);
}

test "Scene" {
    const seed = 0xabadcafe;
    var prng = DefaultPrng.init(seed);

    var scene = Self.init(std.testing.allocator);
    defer scene.deinit();

    // The world should be empty
    try std.testing.expectEqual(0, scene.world.objects.items.len);
    try std.testing.expectEqualDeep(Interval.init(1e-3, inf), scene.interval);

    // Generate the world now
    scene.generateWorld(&prng);

    // Should contain the ground, 3 big balls, and 22*22 little balls
    // Subtract any that don't meet the criteria (3 for this seed)
    try std.testing.expectEqual(1 + 3 + (22 * 22) - 3, scene.world.objects.items.len);
}
