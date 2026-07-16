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
    const alloc = init.arena.allocator();

    // Use or generate a common seed
    const seed = initSeed(io);
    std.log.info("Using seed: 0x{x}", .{ seed });

    // Generate the random scene
    var scene = Scene.init(gpa, io);
    defer scene.deinit();
    scene.generateWorld(seed);

    // Create threaded Io
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();

    // Create Image
    var image = Image.init(alloc, io, config.imgWidth, config.aspectRatio);
    defer image.deinit();
    std.log.info("Rendering image: {f}", .{ image });

    // Camera / render
    var camera = initCamera(gpa, threaded.io(), image, seed, scene);
    try camera.render(alloc);
}

fn initSeed(io: Io) u64 {
    var seed: u64 = undefined;

    if (config.seed) |s| {
        seed = s;
    } else {
        var s: u64 = undefined;
        io.random(std.mem.asBytes(&s));
        seed = s;
    }

    return seed;
}

fn initCamera(alloc: Allocator, io: Io, image: Image, seed: u64, scene: Scene) Camera {
    // Builv Camera
    return Camera.builder(alloc, io, image, seed)
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
    //std.testing.log_level = .info;

    try std.testing.expect(config.imgWidth == 400);
    try std.testing.expect(config.aspectRatio == (16.0 / 9.0));
    try std.testing.expect(config.samplesPerPixel == 10);
    try std.testing.expect(config.seed != null);

    // Test main()
    const io = std.testing.io;
    const gpa = std.testing.allocator;

    // Use or generate a common seed
    const seed = initSeed(io);

    // Generate the random scene
    var scene = Scene.init(gpa, io);
    defer scene.deinit();
    scene.generateWorld(seed);

    var image = Image.init(gpa, io, config.imgWidth, config.aspectRatio);
    defer image.deinit();

    // Camera
    var camera = initCamera(gpa, io, image, seed, scene);
    try camera.render(gpa);
    defer camera.deinit(gpa);

    const expected = try std.Io.Dir.cwd().readFileAlloc(io, "test-files/" ++ config.fileName, gpa, Io.Limit.limited(5e5));
    defer gpa.free(expected);

    const actual = try std.Io.Dir.cwd().readFileAlloc(io, "images/" ++ config.fileName, gpa, Io.Limit.limited(5e5));
    defer gpa.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
