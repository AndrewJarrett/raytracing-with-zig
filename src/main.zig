const std = @import("std");

pub fn main() !void {

    // Image
    const imgWidth: usize = 256;
    const imgHeight: usize = 256;

    // Render
    const stdout = std.io.getStdOut();
    var bw = std.io.bufferedWriter(stdout.writer());
    const writer = bw.writer();

    _ = try writer.print("P3\n{d} {d}\n255\n", .{ imgWidth, imgHeight });

    // Write the pixels
    for (0..imgHeight) |j| {
        std.log.info("\rScanlines remaining: {d} ", .{imgHeight - j});
        for (0..imgWidth) |i| {
            const r: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(imgWidth - 1));
            const g: f32 = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(imgHeight - 1));
            const b: f32 = 0.0;

            const ir: usize = @intFromFloat(255.999 * r);
            const ig: usize = @intFromFloat(255.999 * g);
            const ib: usize = @intFromFloat(255.999 * b);

            _ = try writer.print("{d} {d} {d}\n", .{ ir, ig, ib });
        }
    }
    std.log.info("\rDone.           \n", .{});

    try bw.flush();
}

test "simple test" {}
