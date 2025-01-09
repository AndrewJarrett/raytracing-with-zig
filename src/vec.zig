const std = @import("std");
const util = @import("util.zig");

const DefaultPrng = std.rand.DefaultPrng;
pub const Vec3 = @Vector(3, f64);
pub const Point3 = Vec3;

pub const Point = Vec;
pub const Vec = struct {
    v: Vec3,

    pub inline fn init(vx: f64, vy: f64, vz: f64) Vec {
        return .{
            .v = Vec3{ vx, vy, vz },
        };
    }

    pub inline fn zero() Vec3 {
        comptime return Vec3{ 0, 0, 0 };
    }

    pub inline fn splat(scalar: f64) Vec3 {
        return @as(Vec3, @splat(scalar));
    }

    pub inline fn nearZero(v: Vec3) bool {
        const s: Vec3 = @splat(1e-8);
        return @reduce(.And, v < s);
    }

    pub inline fn x(self: Vec) f64 {
        return self.v[0];
    }

    pub inline fn y(self: Vec) f64 {
        return self.v[1];
    }

    pub inline fn z(self: Vec) f64 {
        return self.v[2];
    }

    pub inline fn addScalar(v: Vec3, scalar: f64) Vec3 {
        return v + Vec.splat(scalar);
    }

    pub inline fn mulScalar(v: Vec3, scalar: f64) Vec3 {
        return v * Vec.splat(scalar);
    }

    pub inline fn divScalar(v: Vec3, scalar: f64) Vec3 {
        if (scalar == 0) {
            @panic("Trying to divide by zero!");
        }

        return v * Vec.splat(1.0 / scalar);
    }

    pub inline fn len(v: Vec3) f64 {
        return @sqrt(Vec.lenSquared(v));
    }

    pub inline fn lenSquared(v: Vec3) f64 {
        return @reduce(.Add, (v * v));
    }

    pub inline fn random(prng: *DefaultPrng) Vec3 {
        return .{
            util.randomDouble(prng),
            util.randomDouble(prng),
            util.randomDouble(prng),
        };
    }

    pub inline fn randomRange(min: f64, max: f64, prng: *DefaultPrng) Vec3 {
        return .{
            util.randomDoubleRange(min, max, prng),
            util.randomDoubleRange(min, max, prng),
            util.randomDoubleRange(min, max, prng),
        };
    }

    pub inline fn randomUnitVec(prng: *DefaultPrng) Vec3 {
        while (true) {
            const p = Vec.randomRange(-1, 1, prng);
            const lenSq = Vec.lenSquared(p);

            if (1e-160 < lenSq and lenSq <= 1) {
                return p / Vec.splat(@sqrt(lenSq));
            }
        }
    }

    pub inline fn randomInUnitDisk(prng: *DefaultPrng) Vec3 {
        while (true) {
            const p = Vec3{
                util.randomDoubleRange(-1, 1, prng),
                util.randomDoubleRange(-1, 1, prng),
                0,
            };
            const lenSq = Vec.lenSquared(p);
            if (lenSq < 1) return p;
        }
    }

    pub inline fn randomOnHemisphere(normal: Vec3, prng: *DefaultPrng) Vec3 {
        const onUnitSphere = Vec.randomUnitVec(prng);
        if (Vec.dot(onUnitSphere, normal) > 0.0) {
            return onUnitSphere;
        } else {
            return -onUnitSphere;
        }
    }

    pub inline fn reflect(v: Vec3, n: Vec3) Vec3 {
        return v - Vec.mulScalar(n * Vec.splat(Vec.dot(v, n)), 2);
    }

    pub inline fn refract(v: Vec3, n: Vec3, etaiOverEtat: f64) Vec3 {
        const cosTheta = @min(Vec.dot(-v, n), 1.0);
        const rPerp = Vec.mulScalar(v + Vec.mulScalar(n, cosTheta), etaiOverEtat);
        const rParallel = Vec.mulScalar(n, -@sqrt(@abs(1.0 - Vec.lenSquared(rPerp))));
        return rPerp + rParallel;
    }

    pub inline fn dot(v: Vec3, other: Vec3) f64 {
        return @reduce(.Add, v * other);
    }

    pub inline fn cross(v: Vec3, other: Vec3) Vec3 {
        return Vec3{
            v[1] * other[2] - v[2] * other[1],
            v[2] * other[0] - v[0] * other[2],
            v[0] * other[1] - v[1] * other[0],
        };
    }

    pub inline fn unit(v: Vec3) Vec3 {
        return Vec.divScalar(v, Vec.len(v));
    }

    pub fn format(self: Vec, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;

        try writer.print("{any}", .{self.v});
    }
};

test "init()" {
    const v = Vec.init(1.0, 0.0, 2.0);

    try std.testing.expectEqual(1.0, v.v[0]);
    try std.testing.expectEqual(0.0, v.v[1]);
    try std.testing.expectEqual(2.0, v.v[2]);
}

test "zero()" {
    const v = Vec.zero();

    try std.testing.expectEqual(0.0, v[0]);
    try std.testing.expectEqual(0.0, v[1]);
    try std.testing.expectEqual(0.0, v[2]);
}

test "nearZero()" {
    const zeroes = Vec.zero();
    const big = Vec3{ 1, 1, 1 };
    const small = Vec3{ 1e-9, 1e-9, 1e-9 };

    try std.testing.expect(Vec.nearZero(zeroes));
    try std.testing.expect(!Vec.nearZero(big));
    try std.testing.expect(Vec.nearZero(small));
}

test "x(), y(), and z()" {
    const v = Vec.init(1.0, 0.0, 2.0);

    try std.testing.expectEqual(1.0, v.x());
    try std.testing.expectEqual(0.0, v.y());
    try std.testing.expectEqual(2.0, v.z());
}

test "addScalar()" {
    const v = Vec.addScalar(Vec3{ 1.0, 0.0, 2.0 }, 2);

    try std.testing.expectEqual(3.0, v[0]);
    try std.testing.expectEqual(2.0, v[1]);
    try std.testing.expectEqual(4.0, v[2]);
}

test "mulScalar()" {
    const v = Vec.mulScalar(Vec3{ 1.0, 0.0, 2.0 }, 2.0);

    try std.testing.expectEqual(2.0, v[0]);
    try std.testing.expectEqual(0.0, v[1]);
    try std.testing.expectEqual(4.0, v[2]);
}

test "divScalar()" {
    const v = Vec.divScalar(Vec3{ 1.0, 0.0, 2.0 }, 2.0);

    try std.testing.expectEqual(0.5, v[0]);
    try std.testing.expectEqual(0.0, v[1]);
    try std.testing.expectEqual(1.0, v[2]);
}

test "len()" {
    const len = Vec.len(Vec3{ 1.0, 0.0, 2.0 });
    try std.testing.expectEqual(@sqrt(5.0), len);
}

test "lenSquared()" {
    const lenSquared = Vec.lenSquared(Vec3{ 1.0, 0.0, 2.0 });
    try std.testing.expectEqual(5.0, lenSquared);
}

test "random()" {
    var prng = DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        break :blk seed;
    });

    const tests = 10;
    for (0..tests) |_| {
        const vec = Vec.random(&prng);
        try std.testing.expect(0 <= vec[0] and vec[0] < 1.0);
        try std.testing.expect(0 <= vec[1] and vec[1] < 1.0);
        try std.testing.expect(0 <= vec[2] and vec[2] < 1.0);
    }

    // Ensure that two Random structs return the same output when given the
    // same seed
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec.random(&seededPrng);
    const actual = Vec.random(&newSeededPrng);
    try std.testing.expectEqual(expected, actual);
}

test "randomRange()" {
    var prng = DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        break :blk seed;
    });

    const tests = 10;
    for (0..tests) |_| {
        const vec = Vec.randomRange(1, 3, &prng);
        try std.testing.expect(1 <= vec[0] and vec[0] < 3);
        try std.testing.expect(1 <= vec[1] and vec[1] < 3);
        try std.testing.expect(1 <= vec[2] and vec[2] < 3);
    }

    // Ensure that two Random structs return the same output when given the
    // same seed
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec.randomRange(-1, 0, &seededPrng);
    const actual = Vec.randomRange(-1, 0, &newSeededPrng);
    try std.testing.expectEqual(expected, actual);
}

test "randomUnitVec()" {
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec.randomUnitVec(&seededPrng);
    const actual = Vec.randomUnitVec(&newSeededPrng);
    try std.testing.expectEqual(expected, actual);
}

test "randomInUnitDisk()" {
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec.randomInUnitDisk(&seededPrng);
    const actual = Vec.randomInUnitDisk(&newSeededPrng);
    try std.testing.expectEqual(expected, actual);
}

test "randomOnHemisphere()" {
    const normal = Vec3{ 1, 1, -1 };

    // Ensure that two Random structs return the same output when given the
    // same seed
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec.randomOnHemisphere(normal, &seededPrng);
    const actual = Vec.randomOnHemisphere(normal, &newSeededPrng);
    try std.testing.expectEqual(expected, actual);
}

test "dot()" {
    const dot = Vec.dot(Vec3{ 1.0, 0.0, 2.0 }, Vec3{ 1.0, 2.0, 3.0 });
    try std.testing.expectEqual(7.0, dot);
}

test "cross()" {
    const cross = Vec.cross(Vec3{ 1.0, 0.0, 2.0 }, Vec3{ 1.0, 2.0, 3.0 });

    try std.testing.expectEqual(-4.0, cross[0]);
    try std.testing.expectEqual(-1.0, cross[1]);
    try std.testing.expectEqual(2.0, cross[2]);
}

test "unit()" {
    const vec = Vec3{ 1.0, 0.0, 2.0 };
    const v = Vec.unit(vec);
    const len = @sqrt(5.0);

    try std.testing.expectEqual((1.0 / len), v[0]);
    try std.testing.expectEqual(0.0, v[1]);
    try std.testing.expectEqual((2.0 / len), v[2]);
}

test "Point alias" {
    const p = Point.zero();

    try std.testing.expectEqual(0, p[0]);
    try std.testing.expectEqual(0, p[1]);
    try std.testing.expectEqual(0, p[2]);
}

test "format()" {
    const v = Vec{ .v = Vec.zero() };
    const expected = "{ 0e0, 0e0, 0e0 }";

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{v});
    try std.testing.expectEqualStrings(expected, actual);
}
