const std = @import("std");

const Point3 = @import("vec.zig").Point3;
const Vec3 = @import("vec.zig").Vec3;

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
pub const Camera = struct {
    focalLength: f64 = 1.0,
    image: Image,
    viewport: Viewport,
    center: Point3 = defaultCameraCenter,
    du: Vec3,
    dv: Vec3,
    pixel0: Point3,

    /// Provide a focal length for the camera, the width of the image, and an
    /// aspect ratio in order to setup a Camera. Do not set fields manually unless you
    /// are sure you set everything correctly (i.e. the width/height need to match the aspect
    /// ratio.
    pub fn init(focalLength: f64, width: usize, aspectRatio: f64) Camera {
        const img = Image.init(width, aspectRatio);
        const vp = Viewport.init(img);
        const vu = Vec3.init(vp.width, 0, 0);
        const vv = Vec3.init(0, -vp.height, 0);
        const du = vu.divScalar(@floatFromInt(img.width));
        const dv = vv.divScalar(@floatFromInt(img.height));

        const viewportUpperLeft = defaultCameraCenter.sub(Vec3.init(0, 0, focalLength)).sub(vu.divScalar(2)).sub(vv.divScalar(2));
        const pixel0 = viewportUpperLeft.add(du.add(dv).mulScalar(0.5));

        return .{
            .focalLength = focalLength,
            .image = img,
            .viewport = vp,
            .center = defaultCameraCenter,
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
    const camera = Camera{
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
    };
    const init = Camera.init(1.0, 400, (16.0 / 9.0));

    std.debug.print("camera - du: {s}, dv: {s}, pixel0: {s}\n", .{ camera.du, camera.dv, camera.pixel0 });
    std.debug.print("init - du: {s}, dv: {s}, pixel0: {s}\n", .{ init.du, init.dv, init.pixel0 });

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
}
