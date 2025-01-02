const std = @import("std");
const HittableList = @import("hittable.zig").HittableList;
const Hittable = @import("hittable.zig").Hittable;
const Material = @import("material.zig").Material;
const Color = @import("color.zig").Color;
const Color3 = @import("color.zig").Color3;
const Point3 = @import("vec.zig").Point3;
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const DefaultPrng = std.rand.DefaultPrng;

const Self = @This();
alloc: Allocator,
world: HittableList,
seed: ?u64 = null,
prng: *DefaultPrng,

pub fn init(allocator: Allocator, seed: ?u64) Self {
    // Create an empty world
    const world = HittableList.init(allocator);

    // Create a DefaultPrng using the optional seed if provided.
    // The pointer will be freed in the deinit method.
    const prngPtr = allocator.create(DefaultPrng) catch unreachable;
    prngPtr.* = DefaultPrng.init(seed: {
        if (seed) |s| {
            break :seed s;
        } else {
            var s: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&s)) catch unreachable;
            break :seed s;
        }
    });

    return .{
        .alloc = allocator,
        .world = world,
        .seed = seed,
        .prng = prngPtr,
    };
}

pub fn generateWorld(self: *Self) void {
    // Materials and objects
    // Ground
    const matGround = Material.init(
        .lambertian,
        .{ .albedo = Color.init(0.5, 0.5, 0.5), .prng = self.prng },
    );
    self.world.add(Hittable.init(.sphere, .{
        .center = Point3.init(0, -1000, 0),
        .radius = 1000,
        .mat = matGround,
    }));

    // Generate random spheres and materials
    for (0..22) |a| {
        const xOffset: f64 = @as(f64, @floatFromInt(a)) - 11;
        for (0..22) |b| {
            const zOffset: f64 = @as(f64, @floatFromInt(b)) - 11;

            const chooseMat = util.randomDouble(self.prng);
            const center = Point3.init(
                xOffset + 0.9 * util.randomDouble(self.prng),
                0.2,
                zOffset + 0.9 * util.randomDouble(self.prng),
            );

            if (center.sub(Point3.init(4, 0.2, 0)).len() > 0.9) {
                // 5% chance of glass
                var sphereMaterial = Material.init(.dielectric, .{
                    .refractionIndex = 1.5,
                    .prng = self.prng,
                });

                if (chooseMat < 0.8) {
                    // 80% is diffuse material
                    const albedo = Color.fromVec(Color3.random(self.prng).mul(Color3.random(self.prng)));
                    sphereMaterial = Material.init(.lambertian, .{
                        .albedo = albedo,
                        .prng = self.prng,
                    });
                } else if (chooseMat < 0.95) {
                    // 15% metal
                    const albedo = Color.fromVec(Color3.randomRange(0.5, 1, self.prng));
                    const fuzz = util.randomDoubleRange(0, 0.5, self.prng);
                    sphereMaterial = Material.init(.metal, .{
                        .albedo = albedo,
                        .fuzz = fuzz,
                        .prng = self.prng,
                    });
                }

                self.world.add(Hittable.init(.sphere, .{
                    .center = center,
                    .radius = 0.2,
                    .mat = sphereMaterial,
                }));
            }
        }
    }

    const mat1 = Material.init(
        .dielectric,
        .{ .refractionIndex = 1.5, .prng = self.prng },
    );
    self.world.add(Hittable.init(
        .sphere,
        .{ .center = Point3.init(0, 1, 0), .radius = 1, .mat = mat1 },
    ));

    const mat2 = Material.init(
        .lambertian,
        .{ .albedo = Color.init(0.4, 0.2, 0.1), .prng = self.prng },
    );
    self.world.add(Hittable.init(
        .sphere,
        .{ .center = Point3.init(-4, 1, 0), .radius = 1, .mat = mat2 },
    ));

    const mat3 = Material.init(
        .metal,
        .{ .albedo = Color.init(0.7, 0.6, 0.5), .fuzz = 0, .prng = self.prng },
    );
    self.world.add(Hittable.init(
        .sphere,
        .{ .center = Point3.init(4, 1, 0), .radius = 1, .mat = mat3 },
    ));
}

pub fn deinit(self: Self) void {
    self.world.deinit();
    self.alloc.destroy(self.prng);
}

test "Scene" {
    const seed = 0xabadcafe;
    var scene = Self.init(std.testing.allocator, seed);
    defer scene.deinit();

    // The world should be empty
    try std.testing.expectEqual(0, scene.world.objects.items.len);
    try std.testing.expectEqual(seed, scene.seed);

    // Generate the world now
    scene.generateWorld();

    // Should contain the ground, 3 big balls, and 22*22 little balls
    // Subtract any that don't meet the criteria (3 for this seed)
    try std.testing.expectEqual(1 + 3 + (22 * 22) - 3, scene.world.objects.items.len);
}
