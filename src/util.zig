const std = @import("std");

const pi = std.math.pi;

/// Convert degrees to radians as an f64
pub inline fn degToRad(degrees: f64) f64 {
    return degrees * std.math.pi / 180.0;
}

/// Return a double/f64 in the range of [0,1).
/// Can use a deterministic seed if provided, otherwise,
/// will use the OS to get a random seed.
pub inline fn randomDouble(seed: ?u64) f64 {
    var prng = std.rand.DefaultPrng.init(blk: {
        if (seed) |s| {
            break :blk s;
        } else {
            var newSeed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&newSeed)) catch unreachable;
            break :blk newSeed;
        }
    });
    const rand = prng.random();

    const max = std.math.maxInt(u64);
    const intInRange = rand.intRangeLessThan(u64, 0, max);
    return @as(f64, @floatFromInt(intInRange)) / @as(f64, @floatFromInt(max));
}

/// Return a randomg double/f64 in a specfic range of [min,max)
pub inline fn randomDoubleRange(min: f64, max: f64, seed: ?u64) f64 {
    return min + (max - min) * randomDouble(seed);
}

test "degToRad()" {
    try std.testing.expectEqual(0, degToRad(0));
    try std.testing.expectEqual(pi / 2.0, degToRad(90));
    try std.testing.expectEqual(pi, degToRad(180));
    try std.testing.expectEqual((3.0 * pi) / 2.0, degToRad(270));
    try std.testing.expectEqual(2.0 * pi, degToRad(360));
    try std.testing.expectEqual(3.0 * pi, degToRad(540));
}

test "randomDouble()" {
    const tests = 1e6;
    for (0..tests) |_| {
        const result = randomDouble(null);
        try std.testing.expect(0.0 <= result and result < 1.0);
    }

    const expected = randomDouble(0xcafef00d);
    const actual = randomDouble(0xcafef00d);
    try std.testing.expectEqual(expected, actual);
}

test "randomDoubleRange()" {
    const tests = 1e6;
    const min = 1.0;
    const max = 10.0;
    for (0..tests) |t| {
        const i = @as(f64, @floatFromInt(t));
        const result = randomDoubleRange(i + min, i + max, null);
        try std.testing.expect(i + min <= result and result < i + max);
    }

    const expected = randomDoubleRange(-1, 0, 0xcafef00d);
    const actual = randomDoubleRange(-1, 0, 0xcafef00d);
    try std.testing.expectEqual(expected, actual);
}
