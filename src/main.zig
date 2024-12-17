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

const Allocator = std.mem.Allocator;

const inf = std.math.inf(f64);

fn rayColor(ray: Ray, world: HittableList) Color {
    // Find the point where we hit the sphere
    const hitRecord = world.hit(ray, Interval.init(0, inf));
    if (hitRecord) |rec| {
        const n: Vec3 = rec.normal.add(Color3.init(1, 1, 1)).mulScalar(0.5);
        return Color.init(n.x(), n.y(), n.z());
    }

    const unitDir = ray.dir.unit(); // Normalize between -1 and 1
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

    // World
    var world = HittableList.init(allocator);
    world.add(Hittable.init(.sphere, .{ .center = Point3.init(0, 0, -1), .radius = 0.5 }));
    world.add(Hittable.init(.sphere, .{ .center = Point3.init(0, -100.5, -1), .radius = 100 }));

    // Camera
    const imgWidth = 400;
    const aspectRatio = 16.0 / 9.0;
    const camera = Camera.init(imgWidth, aspectRatio, 0xdeadbeef);

    // Render
    try camera.render(world);
}

// Since we are randomly sampling the actual image, we can't compare. We will
// actually compare the expected and actual image in the Camera render test
// which will use a deterministic seed instead. This test will only ensure the
// file is created.
test "main" {
    try main();

    const file = try std.fs.cwd().readFileAlloc(std.testing.allocator, "images/chapter7.ppm", 5e5);
    defer std.testing.allocator.free(file);

    try std.testing.expect(file.len > 0);
}
