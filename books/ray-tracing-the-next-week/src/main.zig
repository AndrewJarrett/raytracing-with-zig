const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultPrng = std.Random.DefaultPrng;
const Io = std.Io;

const config = @import("config");
const stdOptions = @import("std_options");

const Camera = @import("camera.zig").Camera;
const Image = @import("Image.zig");
const Color = @import("color.zig").Color;
const Point3 = @import("vec.zig").Point3;
const Scene = @import("Scene.zig");
const SceneType = @import("Scene.zig").SceneType;
const Object = @import("hittable.zig").Object;
const util = @import("util.zig");

const inf = std.math.inf(f64);

pub const std_options: std.Options = .{
    .log_level = @field(std.log.Level, @tagName(stdOptions.log_level)),
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const alloc = init.arena.allocator();

    // Use or generate a common seed
    const seed = initSeed(io);

    // Create threaded Io
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();

    const world = try alloc.alloc(Object, @intFromEnum(SceneType.chapter2));
    defer alloc.free(world);
    var scene = Scene{ .seed = seed, .world = world };
    scene.generateScene(.chapter2);

    // Create Image
    const height = Image.getHeightFromWidthAndRatio(config.imgWidth, config.aspectRatio);
    const size = @as(u32, config.imgWidth) * @as(u32, height);
    const pixels = try alloc.alloc(Color, size);
    const image = Image{ .width = config.imgWidth, .height = height, .pixels = pixels };

    // Camera / render
    var camera = initCamera(image, scene);
    try camera.render(threaded.io());
}

inline fn initSeed(io: Io) u64 {
    if (config.seed) |s| {
        return s;
    } else {
        var s: u64 = undefined;
        io.random(std.mem.asBytes(&s));
        return s;
    }
}

inline fn initCamera(image: Image, scene: Scene) Camera {
    // Build Camera
    return Camera.builder(image, scene)
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

    const world = try gpa.alloc(Object, @intFromEnum(SceneType.chapter2));
    defer gpa.free(world);

    // Use or generate a common seed
    const seed = initSeed(io);
    var scene = Scene{ .seed = seed, .world = world };
    scene.generateScene(.chapter2);

    const height = Image.getHeightFromWidthAndRatio(config.imgWidth, config.aspectRatio);
    const size = @as(u32, config.imgWidth) * @as(u32, height);
    const pixels = try gpa.alloc(Color, size);
    defer gpa.free(pixels);
    const image = Image{ .width = config.imgWidth, .height = height, .pixels = pixels };

    // Camera
    var camera = initCamera(image, scene);
    try camera.render(io);

    const expected = try std.Io.Dir.cwd().readFileAlloc(io, "test-files/" ++ config.fileName, gpa, Io.Limit.limited(5e5));
    defer gpa.free(expected);

    const actual = try std.Io.Dir.cwd().readFileAlloc(io, "images/" ++ config.fileName, gpa, Io.Limit.limited(5e5));
    defer gpa.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
