const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;
const Io = std.Io;

const config = @import("config");

const Camera = @import("camera.zig").Camera;
const Image = @import("Image.zig");
const Point3 = @import("vec.zig").Point3;
const Scene = @import("Scene.zig");
const util = @import("util.zig");

const inf = std.math.inf(f64);

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    defer init.arena.deinit();
    const alloc = init.arena.allocator();

    // Generate the random scene
    var scene = Scene.init(alloc, io);
    defer scene.deinit();
    // Create Image
    var image = Image.init(gpa, io, config.imgWidth, config.aspectRatio);
    defer image.deinit();

    // Camera / render
    var camera = initCamera(alloc, threaded.io(), image, scene);
    try camera.render(config.seed);
}

fn initPrng(alloc: Allocator, io: Io, seed: ?u64) *DefaultPrng {
    const prng: *DefaultPrng = alloc.create(DefaultPrng) catch unreachable;
    prng.* = DefaultPrng.init(blk: {
        if (seed) |s| {
            break :blk s;
        } else {
            var s: u64 = undefined;
            io.random(std.mem.asBytes(&s));
            break :blk s;
        }
    });
    return prng;
}

fn initCamera(alloc: Allocator, io: Io, image: Image, scene: Scene) Camera {
    // Builv Camera
    return Camera.builder(alloc, io, image)
        .setScene(scene)
        .setDefocusAngle(0.6)
        .setFocusDist(10)
        .setViewport(Point3{ 13, 2, 3 }, Point3{ 0, 0, 0 }, 20)
        .setSamplesPerPixel(config.samplesPerPixel)
        .build();
}

// Since we are passing in a seed for the test options, we have a deterministic
// image being built.  We will compare the expected and actual image since the
// result will be the same every time.
test "main" {
    try std.testing.expect(config.imgWidth == 400);
    try std.testing.expect(config.aspectRatio == (16.0 / 9.0));
    try std.testing.expect(config.samplesPerPixel == 10);
    try std.testing.expect(config.seed != null);

    // Test main()
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    // Generate the random scene
    var scene = Scene.init(gpa, io);
    defer scene.deinit();
    scene.generateWorld(config.seed);

    var image = Image.init(gpa, io, config.imgWidth, config.aspectRatio);
    defer image.deinit();

    // Camera
    var camera = initCamera(gpa, io, image, scene);
    try camera.render(config.seed);

    const expected = try std.Io.Dir.cwd().readFileAlloc(io, "test-files/" ++ config.fileName, gpa, Io.Limit.limited(5e5));
    defer gpa.free(expected);

    const actual = try std.Io.Dir.cwd().readFileAlloc(io, "images/" ++ config.fileName, gpa, Io.Limit.limited(5e5));
    defer gpa.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
