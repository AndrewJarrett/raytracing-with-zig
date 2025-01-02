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
const Material = @import("material.zig").Material;
const Scene = @import("Scene.zig");

const DefaultPrng = std.rand.DefaultPrng;
const Allocator = std.mem.Allocator;
pub const chapter = "chapter14";
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

const Viewport = struct {
    width: f64,
    height: f64,
    vFov: f64,

    pub fn init(img: Image, vFov: f64, focusDist: f64) Viewport {
        const theta = std.math.degreesToRadians(vFov);
        const h = @tan(theta / 2.0);
        const height = 2 * h * focusDist;
        const width = height * (@as(f64, @floatFromInt(img.width)) / @as(f64, @floatFromInt(img.height)));

        return .{
            .width = width,
            .height = height,
            .vFov = vFov,
        };
    }

    pub fn format(self: Viewport, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{d:.2}x{d:.2} @ {d}", .{ self.width, self.height, self.vFov });
    }
};

pub const Camera = struct {
    alloc: Allocator,
    image: Image,
    viewport: Viewport,
    scene: Scene,
    center: Point3 = defaultCameraCenter,
    samplesPerPixel: usize = defaultSamplesPerPixel,
    pixelSamplesScale: f64 = defaultPixelSamplesScale,
    bounceMax: usize = defaultBounceMax,
    lookFrom: Point3 = defaultLookFrom,
    lookAt: Point3 = defaultLookAt,
    vUp: Vec3 = defaultVUp,
    u: Vec3 = defaultU, // Camera frame basis vectors
    v: Vec3 = defaultV,
    w: Vec3 = defaultW,
    focusDist: f64 = defaultFocusDist,
    defocusDiskU: Vec3 = defaultDefocusDiskU, // Defocus disk horizontal radius
    defocusDiskV: Vec3 = defaultDefocusDiskV, // Defocus disk vertical radius
    defocusAngle: f64 = defaultDefocusAngle,
    du: Vec3, // Offset to pixel to the right
    dv: Vec3, // Offset to pixel below
    pixel0: Point3, // Location of pixel (0, 0)

    /// Provide an allocator, the width of the image, and an aspect ratio in order to setup a Camera.
    /// Uses the Builder pattern to construct a correct Camera. Do not set fields manually unless
    /// you are sure you set everything correctly (i.e. the width/height need to match the aspect
    /// ratio).
    pub fn init(alloc: Allocator, width: usize, aspectRatio: f64) *CameraBuilder {
        // Allocate space on the heap for the builder.
        const builderPtr = alloc.create(CameraBuilder) catch unreachable;
        builderPtr.* = CameraBuilder{
            .alloc = alloc,
            .image = Image.init(width, aspectRatio),
        };
        return builderPtr;
    }

    pub fn deinit(self: Camera) void {
        self.scene.deinit();
    }

    pub fn render(self: Camera) !void {
        // Setup Image/PPM
        var ppm = PPM.init(self.alloc, self.image.width, self.image.height);
        defer ppm.deinit();

        for (0..ppm.height) |j| {
            std.log.info("\rScanlines remaining: {d} ", .{ppm.height - j});
            for (0..ppm.width) |i| {
                var pixelColor = Color.init(0, 0, 0);
                // Anti-aliasing sampling
                for (0..self.samplesPerPixel) |_| {
                    const ray = self.getRay(i, j);
                    const color = self.rayColor(ray, 0, self.scene.world);
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
            if (rec.mat.scatter(ray, rec)) |s| {
                return Color.fromVec(
                    self.rayColor(s.scattered, depth + 1, world).pixel
                        .mul(s.attenuation.pixel),
                );
            } else {
                return Color.init(0, 0, 0);
            }
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

        const rayOrigin = if (self.defocusAngle <= 0)
            self.center
        else
            self.defocusDiskSample();

        return Ray.init(
            rayOrigin,
            pixelSample.sub(rayOrigin),
        );
    }

    /// Return a vector to a random point in the [-.5,-.5] - [+.5,+.5] unit square
    fn sampleSquare(self: Camera) Vec3 {
        return Vec3.init(
            util.randomDouble(self.scene.prng) - 0.5,
            util.randomDouble(self.scene.prng) - 0.5,
            0,
        );
    }

    /// Returns a random point in the camera defocus disk
    fn defocusDiskSample(self: Camera) Point3 {
        const p = Vec3.randomInUnitDisk(self.scene.prng);
        return self.center
            .add(self.defocusDiskU.mulScalar(p.x()))
            .add(self.defocusDiskV.mulScalar(p.y()));
    }
};

const defaultCameraCenter = Point3.init(0, 0, 0);
const defaultSamplesPerPixel = 100;
const defaultPixelSamplesScale = 1.0 / @as(f64, @floatFromInt(defaultSamplesPerPixel));
const defaultBounceMax = 50;
const defaultLookFrom = defaultCameraCenter;
const defaultLookAt = Point3.init(0, 0, -1);
const defaultVUp = Vec3.init(0, 1, 0);
const defaultW = defaultLookFrom.sub(defaultLookAt).unit();
const defaultU = defaultVUp.cross(defaultW).unit();
const defaultV = defaultW.cross(defaultU);
const defaultDefocusAngle = 0;
const defaultFocusDist = 10;
const defaultDefocusRadius = defaultFocusDist * @tan(std.math.degreesToRadians(defaultDefocusAngle / 2.0));
const defaultDefocusDiskU = defaultU.mulScalar(defaultDefocusRadius);
const defaultDefocusDiskV = defaultV.mulScalar(defaultDefocusRadius);
pub const CameraBuilder = struct {
    /// Required
    alloc: Allocator,
    image: Image,

    /// Configurable/buildable parameters
    scene: ?Scene = null,
    samplesPerPixel: ?usize = defaultSamplesPerPixel, // Count of random samples for each pixel
    bounceMax: ?usize = defaultBounceMax, // Maximum number of ray bounces into scene
    center: ?Point3 = defaultCameraCenter, // Camera center
    lookFrom: ?Point3 = defaultLookFrom, // Point camera is looking from
    lookAt: ?Point3 = defaultLookAt, // Point camera is looking at
    vUp: ?Vec3 = defaultVUp, // Camera-relative "up" direction
    defocusAngle: ?f64 = defaultDefocusAngle, // Variation angle of rays through each pixel
    focusDist: ?f64 = defaultFocusDist, // Distance from camera lookFrom point to plane of perfect focus

    /// Generated from other parameters
    viewport: ?Viewport = null,
    pixelSamplesScale: ?f64 = defaultPixelSamplesScale, // Color scale factor for a sum of pixel samples

    /// Sets the scene to be rendered
    pub fn setScene(self: *CameraBuilder, scene: Scene) *CameraBuilder {
        self.scene = scene;
        return self;
    }

    /// Sets the focusDist. Must be set before creating the viewport.
    pub fn setFocusDist(self: *CameraBuilder, focusDist: f64) *CameraBuilder {
        self.focusDist = focusDist;
        return self;
    }

    /// Sets the defocusAngle.
    pub fn setDefocusAngle(self: *CameraBuilder, defocusAngle: f64) *CameraBuilder {
        self.defocusAngle = defocusAngle;
        return self;
    }

    /// Sets the viewport related items like the camera's center, lookFrom,
    /// lookAt, vFov, and viewport parameters.
    pub fn setViewport(self: *CameraBuilder, lookFrom: Point3, lookAt: Point3, vFov: f64) *CameraBuilder {
        self.center = lookFrom;
        self.lookFrom = lookFrom;
        self.lookAt = lookAt;
        self.viewport = Viewport.init(self.image, vFov, self.focusDist.?);
        return self;
    }

    /// Set the samplesPerPixel and the related pixelSamplesScale parameter.
    pub fn setSamplesPerPixel(self: *CameraBuilder, samplesPerPixel: usize) *CameraBuilder {
        self.samplesPerPixel = samplesPerPixel;
        self.pixelSamplesScale = 1.0 / @as(f64, @floatFromInt(samplesPerPixel));
        return self;
    }

    /// Set the maximum number of times a given ray can bounce
    pub fn setBounceMax(self: *CameraBuilder, bounceMax: usize) *CameraBuilder {
        self.bounceMax = bounceMax;
        return self;
    }

    /// Set which direction is up.
    pub fn setVUp(self: *CameraBuilder, vUp: Vec3) *CameraBuilder {
        self.vUp = vUp;
        return self;
    }

    pub fn build(self: *CameraBuilder) Camera {
        // Make sure we free the builder when done
        defer self.alloc.destroy(self);

        // Create a blank scene if one doesn't exist
        const scene = if (self.scene) |s| s else Scene.init(self.alloc, null);

        const w = self.lookFrom.?.sub(self.lookAt.?).unit();
        const u = self.vUp.?.cross(w).unit();
        const v = w.cross(u);

        const vu = u.mulScalar(self.viewport.?.width);
        const vv = v.mulScalar(-self.viewport.?.height);
        const du = vu.divScalar(@floatFromInt(self.image.width));
        const dv = vv.divScalar(@floatFromInt(self.image.height));

        const viewportUpperLeft = self.center.?
            .sub(w.mulScalar(self.focusDist.?))
            .sub(vu.divScalar(2))
            .sub(vv.divScalar(2));

        const pixel0 = viewportUpperLeft.add(du.add(dv).mulScalar(0.5));

        const defocusRadius = self.focusDist.? * @tan(std.math.degreesToRadians(self.defocusAngle.? / 2.0));

        return .{
            .alloc = self.alloc,
            .image = self.image,
            .scene = scene,
            .viewport = self.viewport.?,
            .samplesPerPixel = self.samplesPerPixel.?,
            .pixelSamplesScale = self.pixelSamplesScale.?,
            .bounceMax = self.bounceMax.?,
            .center = self.center.?,
            .lookFrom = self.lookFrom.?,
            .lookAt = self.lookAt.?,
            .vUp = self.vUp.?,
            .u = u,
            .v = v,
            .w = w,
            .focusDist = self.focusDist.?,
            .defocusDiskU = u.mulScalar(defocusRadius),
            .defocusDiskV = v.mulScalar(defocusRadius),
            .defocusAngle = self.defocusAngle.?,
            .du = du,
            .dv = dv,
            .pixel0 = pixel0,
        };
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
    const vFov = 90;
    const height = 2.0 * @tan(std.math.degreesToRadians(vFov) / 2.0) * 2.0;
    const vp = Viewport{ .width = 16.0, .height = height, .vFov = 90 };
    const aspectRatio = @as(f64, @floatFromInt(16)) / @as(f64, @floatFromInt(9));
    const imgRatio = @as(f64, @floatFromInt(400)) / @as(f64, @floatFromInt(225));
    const img = Image.init(400, aspectRatio);
    const vp2 = Viewport.init(img, 90, 2.0);
    const expected = "16.00x4.00 @ 90";

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{vp});

    try std.testing.expectEqual(16.0, vp.width);
    try std.testing.expectEqual(height, vp.height);
    try std.testing.expectEqual(height * imgRatio, vp2.width);
    try std.testing.expectEqual(height, vp2.height);
    try std.testing.expectEqualStrings(expected, actual);
}

test "CameraBuilder" {
    const vFov = 90;

    var builder = Camera.init(std.testing.allocator, 400, (16.0 / 9.0));

    try std.testing.expectEqual(defaultCameraCenter, builder.center);
    try std.testing.expectEqual(defaultLookFrom, builder.lookFrom);
    try std.testing.expectEqual(defaultLookAt, builder.lookAt);
    try std.testing.expectEqual(defaultFocusDist, builder.focusDist);
    try std.testing.expectEqualDeep(null, builder.viewport);
    try std.testing.expectEqualDeep(null, builder.scene);
    try std.testing.expectEqual(defaultSamplesPerPixel, builder.samplesPerPixel);
    try std.testing.expectEqual(defaultPixelSamplesScale, builder.pixelSamplesScale);
    try std.testing.expectEqual(defaultBounceMax, builder.bounceMax);
    try std.testing.expectEqual(defaultVUp, builder.vUp);

    const scene = Scene.init(std.testing.allocator, 0xabadcafe);
    builder = builder.setScene(scene);
    try std.testing.expectEqualDeep(scene, builder.scene);

    builder = builder.setViewport(defaultLookFrom, defaultLookAt, vFov);
    try std.testing.expectEqual(defaultCameraCenter, builder.center);
    try std.testing.expectEqual(defaultLookFrom, builder.lookFrom);
    try std.testing.expectEqual(defaultLookAt, builder.lookAt);
    try std.testing.expectEqual(defaultFocusDist, builder.focusDist);
    try std.testing.expectEqualDeep(Viewport.init(builder.image, vFov, defaultFocusDist), builder.viewport);

    builder = builder.setFocusDist(defaultFocusDist);
    try std.testing.expectEqual(defaultFocusDist, builder.focusDist);

    builder = builder.setDefocusAngle(defaultDefocusAngle);
    try std.testing.expectEqual(defaultDefocusAngle, builder.defocusAngle);

    builder = builder.setVUp(defaultVUp);
    try std.testing.expectEqualDeep(defaultVUp, builder.vUp);

    builder = builder.setBounceMax(100);
    try std.testing.expectEqual(100, builder.bounceMax);

    builder = builder.setSamplesPerPixel(10);
    try std.testing.expectEqual(10, builder.samplesPerPixel);
    try std.testing.expectEqual(1 / @as(f64, @floatFromInt(10)), builder.pixelSamplesScale);

    const camera = builder.build();
    defer camera.deinit();

    try std.testing.expectEqual(defaultU, camera.u);
    try std.testing.expectEqual(defaultV, camera.v);
    try std.testing.expectEqual(defaultW, camera.w);
    try std.testing.expectEqual(10, camera.samplesPerPixel);
    try std.testing.expectEqual(1 / @as(f64, @floatFromInt(10)), camera.pixelSamplesScale);
    try std.testing.expectEqual(100, camera.bounceMax);
    try std.testing.expectEqual(defaultVUp, camera.vUp);
    try std.testing.expectEqualDeep(scene, camera.scene);
    try std.testing.expectEqual(0xabadcafe, camera.scene.seed);
    try std.testing.expectEqualDeep(Viewport.init(camera.image, vFov, defaultFocusDist), camera.viewport);
    try std.testing.expectEqual(defaultCameraCenter, camera.center);
    try std.testing.expectEqual(defaultLookFrom, camera.lookFrom);
    try std.testing.expectEqual(defaultLookAt, camera.lookAt);
    try std.testing.expectEqual(defaultFocusDist, camera.focusDist);
    try std.testing.expectEqual(defaultDefocusAngle, camera.defocusAngle);
    try std.testing.expectEqual(defaultDefocusDiskU, camera.defocusDiskU);
    try std.testing.expectEqual(defaultDefocusDiskV, camera.defocusDiskV);
}

test "Camera" {
    const cameraCenter = Vec3.init(0, 0, 0);
    const cameraVu = Vec3.init(4.0, 0, 0);
    const cameraVv = Vec3.init(0, -2.0, 0);
    const cameraUpperLeft = cameraCenter.sub(Vec3.init(0, 0, 2.0)).sub(cameraVu.divScalar(2)).sub(cameraVv.divScalar(2));
    const height = 2.0 * @tan(std.math.degreesToRadians(90) / 2.0);

    const scene = Scene.init(std.testing.allocator, 0xabadcafe);

    const camera = Camera{
        .alloc = std.testing.allocator,
        .image = .{
            .width = 800,
            .height = 400,
        },
        .viewport = .{
            .width = 4.0,
            .height = 2.0,
            .vFov = 90,
        },
        .scene = scene,
        .center = Vec3.init(0, 0, 0),
        .du = cameraVu.divScalar(800),
        .dv = cameraVv.divScalar(400),
        .pixel0 = cameraUpperLeft.add(cameraVu.divScalar(800).add(cameraVv.divScalar(400)).mulScalar(0.5)),
        .defocusAngle = defaultDefocusAngle,
        .focusDist = defaultFocusDist,
        .samplesPerPixel = defaultSamplesPerPixel,
        .pixelSamplesScale = defaultPixelSamplesScale,
    };
    defer camera.deinit();

    const init = Camera.init(std.testing.allocator, 400, (16.0 / 9.0))
        .setViewport(Point3.init(0, 0, 0), Point3.init(0, 0, -1), 90)
        .build();
    defer init.deinit();

    try std.testing.expectEqual(defaultFocusDist, camera.focusDist);
    try std.testing.expectEqual(800, camera.image.width);
    try std.testing.expectEqual(400, camera.image.height);
    try std.testing.expectEqual(2.0, camera.image.aspectRatio());
    try std.testing.expectEqual(4.0, camera.viewport.width);
    try std.testing.expectEqual(2.0, camera.viewport.height);
    try std.testing.expectEqual(0xabadcafe, camera.scene.seed);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, 0), camera.center);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, 0), camera.lookFrom);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, -1), camera.lookAt);
    try std.testing.expectEqualDeep(cameraVu.divScalar(800), camera.du);
    try std.testing.expectEqualDeep(cameraVv.divScalar(400), camera.dv);
    try std.testing.expectEqualDeep(Vec3.init(-1.9975, 0.9975, -2), camera.pixel0);
    try std.testing.expectEqual(defaultU, camera.u);
    try std.testing.expectEqual(defaultV, camera.v);
    try std.testing.expectEqual(defaultW, camera.w);
    try std.testing.expectEqual(defaultBounceMax, camera.bounceMax);
    try std.testing.expectEqual(defaultVUp, camera.vUp);
    try std.testing.expectEqual(defaultSamplesPerPixel, camera.samplesPerPixel);
    try std.testing.expectEqual(defaultPixelSamplesScale, camera.pixelSamplesScale);

    try std.testing.expectEqual(defaultFocusDist, init.focusDist);
    try std.testing.expectEqual(400, init.image.width);
    try std.testing.expectEqual(225, init.image.height);
    try std.testing.expectEqual(16.0 / 9.0, init.image.aspectRatio());
    try std.testing.expectEqual(height * init.focusDist * @as(f64, @floatFromInt(400)) / @as(f64, @floatFromInt(225)), init.viewport.width);
    try std.testing.expectEqual(height * init.focusDist, init.viewport.height);
    try std.testing.expectEqual(90, init.viewport.vFov);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, 0), init.center);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, 0), init.lookFrom);
    try std.testing.expectEqualDeep(Vec3.init(0, 0, -1), init.lookAt);
    try std.testing.expectEqualDeep(Vec3.init(8.888888888888888e-2, 0e0, 0e0), init.du);
    try std.testing.expectEqualDeep(Vec3.init(0, -8.888888888888888e-2, 0), init.dv);
    try std.testing.expectEqualDeep(Vec3.init(-1.773333333333333e1, 9.955555555555554e0, -1e1), init.pixel0);
    try std.testing.expectEqual(defaultU, init.u);
    try std.testing.expectEqual(defaultV, init.v);
    try std.testing.expectEqual(defaultW, init.w);
    try std.testing.expectEqual(defaultBounceMax, init.bounceMax);
    try std.testing.expectEqual(defaultVUp, init.vUp);
    try std.testing.expectEqual(defaultSamplesPerPixel, init.samplesPerPixel);
    try std.testing.expectEqual(defaultPixelSamplesScale, init.pixelSamplesScale);
    try std.testing.expectEqual(null, init.scene.seed);
}

test "Camera.render()" {
    // Generate the random scene using this seed
    var scene = Scene.init(std.testing.allocator, 0xdeadbeef);
    scene.generateWorld();

    // Figure out aspect ratio, image width, and set a deterministic seed
    const aspectRatio = 16.0 / 9.0;
    var camera = Camera.init(std.testing.allocator, 400, aspectRatio)
        .setScene(scene)
        .setDefocusAngle(0.6)
        .setFocusDist(10)
        .setSamplesPerPixel(10)
        .setViewport(Point3.init(13, 2, 3), Point3.init(0, 0, 0), 20)
        .build();
    defer camera.deinit();

    // Render and save the file
    try camera.render();

    const expected = try std.fs.cwd().readFileAlloc(std.testing.allocator, "test-files/" ++ chapter ++ ".ppm", 5e5);
    defer std.testing.allocator.free(expected);

    const actual = try std.fs.cwd().readFileAlloc(std.testing.allocator, "images/" ++ chapter ++ ".ppm", 5e5);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "Camera.sampleSquare()" {
    const camera = Camera.init(std.testing.allocator, 400, 1.0)
        .setViewport(Point3.init(0, 0, 0), Point3.init(0, 0, -1), 90)
        .build();
    defer camera.deinit();

    const tests = 10;
    for (0..tests) |_| {
        const sample = camera.sampleSquare();
        try std.testing.expect(-0.5 <= sample.x() and sample.x() <= 0.5);
        try std.testing.expect(-0.5 <= sample.y() and sample.y() <= 0.5);
        try std.testing.expectEqual(0, sample.z());
    }
}

test "Camera.defocusDiskSample()" {
    const camera = Camera.init(std.testing.allocator, 400, 1.0)
        .setViewport(Point3.init(0, 0, 0), Point3.init(0, 0, -1), 90)
        .build();
    defer camera.deinit();

    const tests = 10;
    for (0..tests) |_| {
        const sample = camera.defocusDiskSample();
        try std.testing.expect(-1 <= sample.x() and sample.x() <= 1);
        try std.testing.expect(-1 <= sample.y() and sample.y() <= 1);
        try std.testing.expectEqual(0, sample.z());
    }
}
