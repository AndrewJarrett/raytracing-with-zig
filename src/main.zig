const std = @import("std");
const PPM = @import("ppm.zig").PPM;
const Color = @import("color.zig").Color;
const Ray = @import("ray.zig").Ray;
const Point3 = @import("vec.zig").Point3;
const Vec3 = @import("vec.zig").Vec3;
const Allocator = std.mem.Allocator;

fn rayColor(r: Ray) Color {
    const unitDir = r.dir.unit(); // Normalize between -1 and 1
    const a = 0.5 * (unitDir.y() + 1.0); // Shift "up" by 1 and then divide in half to make it between 0 - 1
    // Linear interpolate: white * (1.0 - a) + blue * a -> as y changes, gradient changes from blue to white
    const vec = Color.init(1.0, 1.0, 1.0).pixel.mulScalar(1.0 - a)
        .add(Color.init(0.5, 0.7, 1.0).pixel.mulScalar(a));
    return Color.init(vec.x(), vec.y(), vec.z());
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Figure out aspect ratio, image width, and height
    const aspectRatio = 16.0 / 9.0;
    const imgWidth = 400;
    var imgHeight: usize = @intFromFloat(@as(f64, @floatFromInt(imgWidth)) / aspectRatio);
    imgHeight = if (imgHeight < 1) 1 else imgHeight;

    // Camera / viewport
    const focalLen = 1.0;
    const viewportHeight: f64 = 2.0;
    const viewportWidth: f64 =
        viewportHeight * (@as(f64, @floatFromInt(imgWidth)) / @as(f64, @floatFromInt(imgHeight)));
    const cameraCenter = Point3.init(0, 0, 0);

    // Viewport vectors
    const vu = Vec3.init(viewportWidth, 0, 0);
    const vv = Vec3.init(0, -viewportHeight, 0);
    const du = vu.divScalar(@floatFromInt(imgWidth));
    const dv = vv.divScalar(@floatFromInt(imgHeight));

    // Calculate location of the upper left pixel
    const viewUpperLeft = cameraCenter // (0, 0, 0)
        .sub(Vec3.init(0, 0, focalLen)) // (0, 0, -1)
        .sub(vu.divScalar(2)) // (-1.777.., 0, -1)
        .sub(vv.divScalar(2)); // (-1.777..., -2.0, -1)
    const pixel0 = viewUpperLeft.add(du.add(dv).mulScalar(0.5)); // Inset by half a pixel

    // Setup Image/PPM
    var ppm = PPM.init(allocator, imgWidth, imgHeight);
    defer ppm.deinit();

    // Write the pixels
    for (0..ppm.height) |j| {
        std.log.info("\rScanlines remaining: {d} ", .{ppm.height - j});
        for (0..ppm.width) |i| {
            const pixelCenter = pixel0
                .add(du.mulScalar(@floatFromInt(i)))
                .add(dv.mulScalar(@floatFromInt(j)));
            const rayDir = pixelCenter.sub(cameraCenter); // We don't really need to subtract (0, 0, 0) from the pixel center
            const ray = Ray.init(cameraCenter, rayDir);
            ppm.pixels[i + j * ppm.width] = rayColor(ray);
        }
    }
    std.log.info("\rDone.\n", .{});

    // Save the file
    try ppm.saveBinary("images/chapter4.ppm");
}

test "main" {
    try main();

    const expected = try std.fs.cwd().readFileAlloc(std.testing.allocator, "test-files/chapter4.ppm", 1.5e6);
    defer std.testing.allocator.free(expected);

    const actual = try std.fs.cwd().readFileAlloc(std.testing.allocator, "images/chapter4.ppm", 1.5e6);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
