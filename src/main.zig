const std = @import("std");
const util = @import("util.zig");
const config = @import("config");

const Point3 = @import("vec.zig").Point3;
const Camera = @import("camera.zig").Camera;
const Scene = @import("Scene.zig");

const Allocator = std.mem.Allocator;
const DefaultPrng = std.rand.DefaultPrng;

const inf = std.math.inf(f64);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Generate the random scene
    var scene = Scene.init(allocator, config.seed);
    scene.generateWorld();

    // Camera
    const aspectRatio = 16.0 / 9.0;
    const camera = Camera.builder(allocator, config.imgWidth, aspectRatio)
        .setScene(scene)
        .setDefocusAngle(0.6)
        .setFocusDist(10)
        .setViewport(Point3{ 13, 2, 3 }, Point3{ 0, 0, 0 }, 20)
        .setSamplesPerPixel(config.samplesPerPixel)
        .build();
    defer camera.deinit();

    // Render
    try camera.render();
}

// Since we are passing in a seed for the test options, we have a deterministic 
// image being built.  We will compare the expected and actual image since the
// result will be the same every time.
test "main" {
    try std.testing.expect(config.imgWidth == 400);
    try std.testing.expect(config.samplesPerPixel == 10);
    try std.testing.expect(config.seed != null);

    try main();

    const expected = try std.fs.cwd().readFileAlloc(std.testing.allocator, "test-files/" ++ config.fileName, 5e5);
    defer std.testing.allocator.free(expected);

    const actual = try std.fs.cwd().readFileAlloc(std.testing.allocator, "images/" ++ config.fileName, 5e5);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
