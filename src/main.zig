const std = @import("std");
const util = @import("util.zig");

const PPM = @import("ppm.zig").PPM;
const Color = @import("color.zig").Color;
const Color3 = @import("color.zig").Color3;
const Ray = @import("ray.zig").Ray;
const Point3 = @import("vec.zig").Point3;
const Vec3 = @import("vec.zig").Vec3;
const Sphere = @import("sphere.zig").Sphere;
const Hittable = @import("hittable.zig").Hittable;
const HittableList = @import("hittable.zig").HittableList;
const Interval = @import("interval.zig").Interval;
const Camera = @import("camera.zig").Camera;
const chapter = @import("camera.zig").chapter;
const Material = @import("material.zig").Material;

const Allocator = std.mem.Allocator;
const DefaultPrng = std.rand.DefaultPrng;

const inf = std.math.inf(f64);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create the World's PRNG
    const prngPtr = try allocator.create(DefaultPrng);
    prngPtr.* = DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        break :blk seed;
    });

    // World
    var world = HittableList.init(allocator);
    defer world.deinit();

    // Materials and objects
    // Ground
    const matGround = Material.init(
        .lambertian,
        .{ .albedo = Color.init(0.5, 0.5, 0.5), .prng = prngPtr },
    );
    world.add(Hittable.init(.sphere, .{
        .center = Point3.init(0, -1000, 0),
        .radius = 1000,
        .mat = matGround,
    }));

    // Generate random spheres and materials
    for (0..22) |a| {
        const xOffset: f64 = @as(f64, @floatFromInt(a)) - 11;
        for (0..22) |b| {
            const zOffset: f64 = @as(f64, @floatFromInt(b)) - 11;

            const chooseMat = util.randomDouble(prngPtr);
            const center = Point3.init(
                xOffset + 0.9 * util.randomDouble(prngPtr),
                0.2,
                zOffset + 0.9 * util.randomDouble(prngPtr),
            );

            if (center.sub(Point3.init(4, 0.2, 0)).len() > 0.9) {
                // 5% chance of glass
                var sphereMaterial = Material.init(.dielectric, .{
                    .refractionIndex = 1.5,
                    .prng = prngPtr,
                });

                if (chooseMat < 0.8) {
                    // 80% is diffuse material
                    const albedo = Color.fromVec(Color3.random(prngPtr).mul(Color3.random(prngPtr)));
                    sphereMaterial = Material.init(.lambertian, .{
                        .albedo = albedo,
                        .prng = prngPtr,
                    });
                } else if (chooseMat < 0.95) {
                    // 15% metal
                    const albedo = Color.fromVec(Color3.randomRange(0.5, 1, prngPtr));
                    const fuzz = util.randomDoubleRange(0, 0.5, prngPtr);
                    sphereMaterial = Material.init(.metal, .{
                        .albedo = albedo,
                        .fuzz = fuzz,
                        .prng = prngPtr,
                    });
                }

                world.add(Hittable.init(.sphere, .{
                    .center = center,
                    .radius = 0.2,
                    .mat = sphereMaterial,
                }));
            }
        }
    }

    const mat1 = Material.init(
        .dielectric,
        .{ .refractionIndex = 1.5, .prng = prngPtr },
    );
    world.add(Hittable.init(
        .sphere,
        .{ .center = Point3.init(0, 1, 0), .radius = 1, .mat = mat1 },
    ));

    const mat2 = Material.init(
        .lambertian,
        .{ .albedo = Color.init(0.4, 0.2, 0.1), .prng = prngPtr },
    );
    world.add(Hittable.init(
        .sphere,
        .{ .center = Point3.init(-4, 1, 0), .radius = 1, .mat = mat2 },
    ));

    const mat3 = Material.init(
        .metal,
        .{ .albedo = Color.init(0.7, 0.6, 0.5), .fuzz = 0, .prng = prngPtr },
    );
    world.add(Hittable.init(
        .sphere,
        .{ .center = Point3.init(4, 1, 0), .radius = 1, .mat = mat3 },
    ));

    // Camera
    const imgWidth = 1920;
    const aspectRatio = 16.0 / 9.0;
    const camera = Camera.init(allocator, imgWidth, aspectRatio)
        .setDefocusAngle(0.6)
        .setFocusDist(10)
        .setViewport(Point3.init(13, 2, 3), Point3.init(0, 0, 0), 20)
        .setSamplesPerPixel(500)
        .build();
    defer camera.deinit();

    // Render
    try camera.render(world);
}

// Since we are randomly sampling the actual image, we can't compare. We will
// actually compare the expected and actual image in the Camera render test
// which will use a deterministic seed instead. This test will only ensure the
// file is created.
test "main" {
    try main();

    const file = try std.fs.cwd().readFileAlloc(std.testing.allocator, "images/" ++ chapter ++ ".ppm", 5e5);
    defer std.testing.allocator.free(file);

    try std.testing.expect(file.len > 0);
}
