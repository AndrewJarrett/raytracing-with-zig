const std = @import("std");

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

    // Materials
    const matGround = Material.init(
        .lambertian,
        .{ .albedo = Color.init(0.8, 0.8, 0.0), .prng = prngPtr },
    );
    const matCenter = Material.init(
        .lambertian,
        .{ .albedo = Color.init(0.1, 0.2, 0.5), .prng = prngPtr },
    );
    const matLeft = Material.init(
        .dielectric,
        .{ .refractionIndex = 1.0 / 1.33 },
    );
    const matRight = Material.init(
        .metal,
        .{ .albedo = Color.init(0.8, 0.6, 0.2), .fuzz = 1.0, .prng = prngPtr },
    );

    // World
    var world = HittableList.init(allocator);
    world.add(Hittable.init(
        .sphere,
        .{
            .center = Point3.init(0, -100.5, -1),
            .radius = 100,
            .mat = matGround,
        },
    ));
    world.add(Hittable.init(
        .sphere,
        .{
            .center = Point3.init(0, 0, -1.2),
            .radius = 0.5,
            .mat = matCenter,
        },
    ));
    world.add(Hittable.init(
        .sphere,
        .{
            .center = Point3.init(-1, 0, -1),
            .radius = 0.5,
            .mat = matLeft,
        },
    ));
    world.add(Hittable.init(
        .sphere,
        .{
            .center = Point3.init(1, 0, -1),
            .radius = 0.5,
            .mat = matRight,
        },
    ));

    // Camera
    const imgWidth = 400;
    const aspectRatio = 16.0 / 9.0;
    const camera = Camera.init(allocator, imgWidth, aspectRatio, null);
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
