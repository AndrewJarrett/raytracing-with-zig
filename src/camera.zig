const std = @import("std");
const util = @import("util.zig");

const Point3 = @import("vec.zig").Point3;
const Vec3 = @import("vec.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const Color = @import("color.zig").Color;
const Color3 = @import("color.zig").Color3;
const HittableList = @import("hittable.zig").HittableList;
const Interval = @import("interval.zig").Interval;
const PPM = @import("ppm.zig").PPM;

const DefaultPrng = std.rand.DefaultPrng;
const Allocator = std.mem.Allocator;
pub const chapter = "chapter9";
const inf = std.math.inf(f64);

const Image = struct {
    width: usize = 100,
    height: usize = 100,

    /// The preferred method of initialization is through the Camera struct and only
    /// needs to be provided with the width of the image and the aspectRatio. The height
    /// will be calculated automatically based on the width of the image and the aspectRatio.
    pub fn init(width: usize, ratio: f64) Image {
        const height: usize = @intFromFloat(@as(f64, @floatFromInt(width)) / ratio);

        return .{
            .width = width,
            .height = if (height < 1) 1 else height,
        };
    }

    /// We don't need to store this as a separate struct field. It can be calculated if it is
    /// ever needed after creation of the struct
    pub fn aspectRatio(self: Image) f64 {
        return @as(f64, @floatFromInt(self.width)) / @as(f64, @floatFromInt(self.height));
    }

    pub fn format(self: Image, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{d}x{d} ({d})", .{ self.width, self.height, self.aspectRatio() });
    }
};

const defaultViewportHeight = 2.0;
const Viewport = struct {
    width: f64,
    height: f64 = defaultViewportHeight,

    pub fn init(img: Image) Viewport {
        const height = defaultViewportHeight;
        const width = height * (@as(f64, @floatFromInt(img.width)) / @as(f64, @floatFromInt(img.height)));

        return .{
            .width = width,
            .height = height,
        };
    }

    pub fn format(self: Viewport, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{d}x{d}", .{ self.width, self.height });
    }
};

const defaultCameraCenter = Point3.init(0, 0, 0);
const defaultFocalLength = 1.0;
const defaultSamplesPerPixel = 100;
const defaultPixelSamplesScale = 1.0 / @as(f64, @floatFromInt(defaultSamplesPerPixel));
const defaultBounceMax = 50;
pub const Camera = struct {
    alloc: Allocator,
    focalLength: f64 = defaultFocalLength,
    image: Image,
    viewport: Viewport,
    center: Point3 = defaultCameraCenter,
    du: Vec3,
    dv: Vec3,
    pixel0: Point3,
    samplesPerPixel: usize = defaultSamplesPerPixel,
    pixelSamplesScale: f64 = defaultPixelSamplesScale,
    bounceMax: usize = defaultBounceMax,
    seed: ?u64 = null,
    prng: *DefaultPrng,

    /// Provide a focal length for the camera, the width of the image, and an
    /// aspect ratio in order to setup a Camera. Do not set fields manually unless you
    /// are sure you set everything correctly (i.e. the width/height need to match the aspect
    /// ratio.
    pub fn init(alloc: Allocator, width: usize, aspectRatio: f64, seed: ?u64) Camera {
        const img = Image.init(width, aspectRatio);
        const vp = Viewport.init(img);
        const vu = Vec3.init(vp.width, 0, 0);
        const vv = Vec3.init(0, -vp.height, 0);
        const du = vu.divScalar(@floatFromInt(img.width));
        const dv = vv.divScalar(@floatFromInt(img.height));

        const viewportUpperLeft = defaultCameraCenter.sub(Vec3.init(0, 0, defaultFocalLength)).sub(vu.divScalar(2)).sub(vv.divScalar(2));
        const pixel0 = viewportUpperLeft.add(du.add(dv).mulScalar(0.5));

        // If there is a seed provided, then initialize the PRNG with that seed
        // otherwise, we get a random seed. Make sure we allocate space on the
        // heap because we will be passing the pointer around.
        const prngPtr = alloc.create(DefaultPrng) catch unreachable;
        const prng = prng: {
            if (seed) |s| {
                break :prng DefaultPrng.init(s);
            } else {
                break :prng DefaultPrng.init(blk: {
                    var randSeed: u64 = undefined;
                    std.posix.getrandom(std.mem.asBytes(&randSeed)) catch unreachable;
                    break :blk randSeed;
                });
            }
        };
        prngPtr.* = prng;

        return .{
            .alloc = alloc,
            .focalLength = defaultFocalLength,
            .image = img,
            .viewport = vp,
            .center = defaultCameraCenter,
            .du = du,
            .dv = dv,
            .pixel0 = pixel0,
            .samplesPerPixel = defaultSamplesPerPixel,
            .pixelSamplesScale = defaultPixelSamplesScale,
            .bounceMax = defaultBounceMax,
            .seed = seed,
            .prng = prngPtr,
        };
    }

    pub fn deinit(self: Camera) void {
        self.alloc.destroy(self.prng);
    }

    pub fn render(self: Camera, world: HittableList) !void {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        // Setup Image/PPM
        var ppm = PPM.init(allocator, self.image.width, self.image.height);
        defer ppm.deinit();

        for (0..ppm.height) |j| {
            std.log.info("\rScanlines remaining: {d} ", .{ppm.height - j});
            for (0..ppm.width) |i| {
                var pixelColor = Color.init(0, 0, 0);
                // Anti-aliasing sampling
                for (0..self.samplesPerPixel) |_| {
                    const ray = self.getRay(i, j);
                    const color = self.rayColor(ray, 0, world);
                    pixelColor.pixel = pixelColor.pixel.add(color.pixel);
                }
                const avgColor = Color.fromVec(pixelColor.pixel.mulScalar(self.pixelSamplesScale));
                ppm.pixels[i + j * ppm.width] = avgColor;
            }
        }
        std.log.info("\rDone.\n", .{});

        // Save the file
        try ppm.saveBinary("images/" ++ chapter ++ ".ppm");
    }

    fn rayColor(self: Camera, ray: Ray, depth: usize, world: HittableList) Color {
        if (depth >= self.bounceMax) return Color.init(0, 0, 0);

        if (world.hit(ray, Interval.init(1e-3, inf))) |rec| {
            // Update ray to randomly bounce in a new direction
            const newRay = Ray.init(
                rec.point,
                rec.normal.add(Vec3.randomUnitVec(self.prng)),
            );
            return Color.fromVec(self.rayColor(newRay, depth + 1, world).pixel.mulScalar(0.5));
        }

        // Translate the y value to be between 0-1.
        const unitDir = ray.dir.unit();
        const a = 0.5 * (unitDir.y() + 1.0);

        // Linear interpolate: white * (1.0 - a) + blue * a -> as y changes,
        // gradient changes from blue to white
        const vec = Color.init(1.0, 1.0, 1.0).pixel.mulScalar(1.0 - a)
            .add(Color.init(0.5, 0.7, 1.0).pixel.mulScalar(a));

        return Color.fromVec(vec);
    }

    /// Gets a Camera Ray that originates from the origin point and is directed
    /// towards a randomized sample point around the pixel location (i, j)
    fn getRay(self: Camera, i: usize, j: usize) Ray {
        const randomOffset = self.sampleSquare();
        const pixelSample = self.pixel0
            .add(self.du.mulScalar(@as(f64, @floatFromInt(i)) + randomOffset.x()))
            .add(self.dv.mulScalar(@as(f64, @floatFromInt(j)) + randomOffset.y()));

        return Ray.init(self.center, pixelSample.sub(self.center));
    }

    /// Return a vector to a random point in the [-.5,-.5] - [+.5,+.5] unit square
    fn sampleSquare(self: Camera) Vec3 {
        return Vec3.init(
            util.randomDouble(self.prng) - 0.5,
            util.randomDouble(self.prng) - 0.5,
            0,
        );
    }
};

test "Image" {
    const img = Image{ .width = 800, .height = 400 };
    const img2 = Image.init(400, 1.0);
    const default = Image{};
    const imgHeightOne = Image.init(1, 2.0);
    const expected = "400x400 (1)";

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{img2});

    try std.testing.expectEqual(800, img.width);
    try std.testing.expectEqual(400, img.height);
    try std.testing.expectEqual(2.0, img.aspectRatio());
    try std.testing.expectEqual(400, img2.width);
    try std.testing.expectEqual(400, img2.height);
    try std.testing.expectEqual(1.0, img2.aspectRatio());
    try std.testing.expectEqual(100, default.width);
    try std.testing.expectEqual(100, default.height);
    try std.testing.expectEqual(1.0, default.aspectRatio());
    try std.testing.expectEqual(1, imgHeightOne.width);
    try std.testing.expectEqual(1, imgHeightOne.height);
    try std.testing.expectEqual(1.0, imgHeightOne.aspectRatio());
    try std.testing.expectEqualStrings(expected, actual);
}

test "Viewport" {
    const vp = Viewport{ .width = 16.0, .height = 2.0 };
    const aspectRatio = @as(f64, @floatFromInt(16)) / @as(f64, @floatFromInt(9));
    const imgRatio = @as(f64, @floatFromInt(400)) / @as(f64, @floatFromInt(225));
    const img = Image.init(400, aspectRatio);
    const vp2 = Viewport.init(img);
    const expected = "16x2";

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{vp});

    try std.testing.expectEqual(16.0, vp.width);
    try std.testing.expectEqual(2.0, vp.height);
    try std.testing.expectEqual(2.0 * imgRatio, vp2.width);
    try std.testing.expectEqual(2.0, vp2.height);
    try std.testing.expectEqualStrings(expected, actual);
}

test "Camera" {
    const cameraCenter = Vec3.init(0, 0, 0);
    const cameraVu = Vec3.init(4.0, 0, 0);
    const cameraVv = Vec3.init(0, -2.0, 0);
    const cameraUpperLeft = cameraCenter.sub(Vec3.init(0, 0, 2.0)).sub(cameraVu.divScalar(2)).sub(cameraVv.divScalar(2));

    const prngPtr = try std.testing.allocator.create(DefaultPrng);
    const prng = DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        break :blk seed;
    });
    prngPtr.* = prng;

    const camera = Camera{
        .alloc = std.testing.allocator,
        .focalLength = 2.0,
        .image = .{
            .width = 800,
            .height = 400,
        },
        .viewport = .{
            .width = 4.0,
            .height = 2.0,
        },
        .center = Vec3.init(0, 0, 0),
        .du = cameraVu.divScalar(800),
        .dv = cameraVv.divScalar(400),
        .pixel0 = cameraUpperLeft.add(cameraVu.divScalar(800).add(cameraVv.divScalar(400)).mulScalar(0.5)),
        .samplesPerPixel = defaultSamplesPerPixel,
        .pixelSamplesScale = defaultPixelSamplesScale,
        .prng = prngPtr,
    };
    defer camera.deinit();

    const init = Camera.init(std.testing.allocator, 400, (16.0 / 9.0), 0xdeadbeef);
    defer init.deinit();

    try std.testing.expectEqual(2.0, camera.focalLength);
    try std.testing.expectEqual(800, camera.image.width);
    try std.testing.expectEqual(400, camera.image.height);
    try std.testing.expectEqual(2.0, camera.image.aspectRatio());
    try std.testing.expectEqual(4.0, camera.viewport.width);
    try std.testing.expectEqual(2.0, camera.viewport.height);
    try std.testing.expectEqual(Vec3.init(0, 0, 0), camera.center);
    try std.testing.expectEqual(cameraVu.divScalar(800), camera.du);
    try std.testing.expectEqual(cameraVv.divScalar(400), camera.dv);
    try std.testing.expectEqual(Vec3.init(-1.9975, 0.9975, -2), camera.pixel0);
    try std.testing.expectEqual(defaultSamplesPerPixel, camera.samplesPerPixel);
    try std.testing.expectEqual(defaultPixelSamplesScale, camera.pixelSamplesScale);
    try std.testing.expectEqual(null, camera.seed);

    try std.testing.expectEqual(1.0, init.focalLength);
    try std.testing.expectEqual(400, init.image.width);
    try std.testing.expectEqual(225, init.image.height);
    try std.testing.expectEqual(16.0 / 9.0, init.image.aspectRatio());
    try std.testing.expectEqual(2.0 * @as(f64, @floatFromInt(400)) / @as(f64, @floatFromInt(225)), init.viewport.width);
    try std.testing.expectEqual(2.0, init.viewport.height);
    try std.testing.expectEqual(Vec3.init(0, 0, 0), init.center);
    try std.testing.expectEqual(Vec3.init(0.008888888888888889, 0, 0), init.du);
    try std.testing.expectEqual(Vec3.init(0, -0.008888888888888889, 0), init.dv);
    try std.testing.expectEqual(Vec3.init(-1.7733333333333332, 0.9955555555555555, -1), init.pixel0);
    try std.testing.expectEqual(defaultSamplesPerPixel, init.samplesPerPixel);
    try std.testing.expectEqual(defaultPixelSamplesScale, init.pixelSamplesScale);
    try std.testing.expectEqual(0xdeadbeef, init.seed);
}

test "Camera.render()" {
    const Hittable = @import("hittable.zig").Hittable;

    // Figure out aspect ratio, image width, and set a deterministic seed
    const aspectRatio = 16.0 / 9.0;
    var camera = Camera.init(std.testing.allocator, 400, aspectRatio, 0xdeadbeef);
    defer camera.deinit();

    // World
    var world = HittableList.init(std.testing.allocator);
    defer world.deinit();
    world.add(Hittable.init(.sphere, .{ .center = Point3.init(0, 0, -1), .radius = 0.5 }));
    world.add(Hittable.init(.sphere, .{ .center = Point3.init(0, -100.5, -1), .radius = 100 }));

    // Render and save the file
    try camera.render(world);

    const expected = try std.fs.cwd().readFileAlloc(std.testing.allocator, "test-files/" ++ chapter ++ ".ppm", 5e5);
    defer std.testing.allocator.free(expected);

    const actual = try std.fs.cwd().readFileAlloc(std.testing.allocator, "images/" ++ chapter ++ ".ppm", 5e5);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "Camera.sampleSquare()" {
    const camera = Camera.init(std.testing.allocator, 400, 1.0, null);
    defer camera.deinit();

    const tests = 1e6;
    for (0..tests) |_| {
        const sample = camera.sampleSquare();
        try std.testing.expect(-0.5 <= sample.x() and sample.x() <= 0.5);
        try std.testing.expect(-0.5 <= sample.y() and sample.y() <= 0.5);
        try std.testing.expectEqual(0, sample.z());
    }
}
