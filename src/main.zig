const std = @import("std");
const PPM = @import("ppm.zig").PPM;
const Color = @import("color.zig").Color;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Setup Image/PPM
    var ppm = PPM.init(allocator, 256, 256);
    defer ppm.deinit();

    // Write the pixels
    for (0..ppm.height) |j| {
        std.log.info("\rScanlines remaining: {d} ", .{ppm.height - j});
        for (0..ppm.width) |i| {
            ppm.pixels[i + j * ppm.width] = Color.init(
                @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(ppm.width - 1)),
                @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(ppm.height - 1)),
                0.0,
            );
        }
    }
    std.log.info("\rDone.\n", .{});

    // Save the file
    try ppm.save("images/chapter3.ppm");
}

test "main" {
    try main();

    const expected = try std.fs.cwd().readFileAlloc(std.testing.allocator, "test-files/chapter2.ppm", 1e6);
    defer std.testing.allocator.free(expected);

    const actual = try std.fs.cwd().readFileAlloc(std.testing.allocator, "images/chapter2.ppm", 1e6);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
