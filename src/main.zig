const std = @import("std");
const util = @import("util.zig");

const Point3 = @import("vec.zig").Point3;
const Camera = @import("camera.zig").Camera;
const chapter = @import("camera.zig").chapter;
const Scene = @import("Scene.zig");

const Allocator = std.mem.Allocator;
const DefaultPrng = std.rand.DefaultPrng;

const inf = std.math.inf(f64);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Generate the random scene
    var scene = Scene.init(allocator, null);
    scene.generateWorld();

    // Camera
    //const imgWidth = 3840; // 4k image
    //const imgWidth = 1920; // FHD image
    //const imgWidth = 1200; // Final render from book
    const imgWidth = 400;
    const aspectRatio = 16.0 / 9.0;
    const camera = Camera.init(allocator, imgWidth, aspectRatio)
        .setScene(scene)
        .setDefocusAngle(0.6)
        .setFocusDist(10)
        .setViewport(Point3{ 13, 2, 3 }, Point3{ 0, 0, 0 }, 20)
        .setSamplesPerPixel(10)
    //.setSamplesPerPixel(500)
        .build();
    defer camera.deinit();

    // Render
    try camera.render();
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
