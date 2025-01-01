const std = @import("std");

const DefaultPrng = std.rand.DefaultPrng;

pub const pi = std.math.pi;

/// Convert degrees to radians as an f64
pub inline fn degToRad(degrees: f64) f64 {
    return degrees * std.math.pi / 180.0;
}

/// Return a double/f64 in the range of [0,1).
/// Can use a deterministic seed if provided, otherwise,
/// will use the OS to get a random seed.
pub inline fn randomDouble(prng: *DefaultPrng) f64 {
    return prng.random().float(f64);
}

/// Return a random double/f64 in a specific range of [min,max)
pub inline fn randomDoubleRange(min: f64, max: f64, prng: *DefaultPrng) f64 {
    return min + (max - min) * randomDouble(prng);
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
    var prng = DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        break :blk seed;
    });

    const tests = 10;
    for (0..tests) |_| {
        const result = randomDouble(&prng);
        try std.testing.expect(0.0 <= result and result < 1.0);
    }

    // Make sure that getting a random number from the same seed will
    // produce the same number (for the first generated number)
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);

    const expected = randomDouble(&seededPrng);
    const actual = randomDouble(&newSeededPrng);
    try std.testing.expectEqual(expected, actual);

    // Expect that the next number is not the same as the prior
    try std.testing.expect(expected != randomDouble(&seededPrng));
}

test "randomDoubleRange()" {
    var prng = DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        break :blk seed;
    });

    const tests = 10;
    const min = 1.0;
    const max = 10.0;
    for (0..tests) |t| {
        const i = @as(f64, @floatFromInt(t));
        const result = randomDoubleRange(i + min, i + max, &prng);
        try std.testing.expect(i + min <= result and result < i + max);
    }

    // Ensure that two different Random structs seeded with the same seed will
    // generate the same number when given the same seed.
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = randomDoubleRange(-1, 0, &seededPrng);
    const actual = randomDoubleRange(-1, 0, &newSeededPrng);
    try std.testing.expectEqual(expected, actual);

    // Ensure that the next random number is different from the prior call of
    // the random function when provided a Random struct that is seeded
    try std.testing.expect(expected != randomDoubleRange(-1, 0, &seededPrng));
}
