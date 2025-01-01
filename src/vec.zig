const std = @import("std");
const util = @import("util.zig");

const DefaultPrng = std.rand.DefaultPrng;
pub const Point3 = Vec3;

pub const Vec3 = packed struct {
    v: @Vector(3, f64),

    pub fn init(vx: f64, vy: f64, vz: f64) Vec3 {
        return .{
            .v = [_]f64{ vx, vy, vz },
        };
    }

    pub fn zero() Vec3 {
        return .{
            .v = [_]f64{ 0, 0, 0 },
        };
    }

    pub fn nearZero(self: Vec3) bool {
        const s: @Vector(3, f64) = @splat(1e-8);
        return @reduce(.And, self.v < s);
    }

    pub fn x(self: Vec3) f64 {
        return self.v[0];
    }

    pub fn y(self: Vec3) f64 {
        return self.v[1];
    }

    pub fn z(self: Vec3) f64 {
        return self.v[2];
    }

    pub fn neg(self: Vec3) Vec3 {
        return .{ .v = -self.v };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .v = self.v + other.v };
    }

    pub fn addScalar(self: Vec3, scalar: f64) Vec3 {
        return .{ .v = self.v + @as(@Vector(3, f64), @splat(scalar)) };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{ .v = self.v - other.v };
    }

    pub fn mul(self: Vec3, other: Vec3) Vec3 {
        return .{ .v = self.v * other.v };
    }

    pub fn mulScalar(self: Vec3, scalar: f64) Vec3 {
        return .{ .v = self.v * @as(@Vector(3, f64), @splat(scalar)) };
    }

    pub fn divScalar(self: Vec3, scalar: f64) Vec3 {
        if (scalar == 0) {
            @panic("Trying to divide by zero!");
        }

        return .{ .v = self.v * @as(@Vector(3, f64), @splat(1 / scalar)) };
    }

    pub fn len(self: Vec3) f64 {
        return @sqrt(self.lenSquared());
    }

    pub fn lenSquared(self: Vec3) f64 {
        return @reduce(.Add, (self.v * self.v));
    }

    pub fn random(prng: *DefaultPrng) Vec3 {
        return Vec3.init(
            util.randomDouble(prng),
            util.randomDouble(prng),
            util.randomDouble(prng),
        );
    }

    pub fn randomRange(min: f64, max: f64, prng: *DefaultPrng) Vec3 {
        return Vec3.init(
            util.randomDoubleRange(min, max, prng),
            util.randomDoubleRange(min, max, prng),
            util.randomDoubleRange(min, max, prng),
        );
    }

    pub fn randomUnitVec(prng: *DefaultPrng) Vec3 {
        while (true) {
            const p = Vec3.randomRange(-1, 1, prng);
            const lenSq = p.lenSquared();

            if (1e-160 < lenSq and lenSq <= 1) {
                return p.divScalar(@sqrt(lenSq));
            }
        }
    }

    pub fn randomInUnitDisk(prng: *DefaultPrng) Vec3 {
        while (true) {
            const p = Vec3.init(
                util.randomDoubleRange(-1, 1, prng),
                util.randomDoubleRange(-1, 1, prng),
                0,
            );
            if (p.lenSquared() < 1) return p;
        }
    }

    pub fn randomOnHemisphere(normal: Vec3, prng: *DefaultPrng) Vec3 {
        var onUnitSphere = Vec3.randomUnitVec(prng);
        if (onUnitSphere.dot(normal) > 0.0) {
            return onUnitSphere;
        } else {
            return onUnitSphere.neg();
        }
    }

    pub fn reflect(self: Vec3, n: Vec3) Vec3 {
        return self.sub(n.mulScalar(self.dot(n) * 2));
    }

    pub fn refract(self: Vec3, n: Vec3, etaiOverEtat: f64) Vec3 {
        const cosTheta: f64 = @min(self.neg().dot(n), 1);
        const rPerp = self.add(n.mulScalar(cosTheta)).mulScalar(etaiOverEtat);
        const rParallel = n.mulScalar(-@sqrt(@abs(1.0 - rPerp.lenSquared())));
        return rPerp.add(rParallel);
    }

    pub fn dot(self: Vec3, other: Vec3) f64 {
        return @reduce(.Add, self.v * other.v);
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(
            self.v[1] * other.v[2] - self.v[2] * other.v[1],
            self.v[2] * other.v[0] - self.v[0] * other.v[2],
            self.v[0] * other.v[1] - self.v[1] * other.v[0],
        );
    }

    pub fn unit(self: Vec3) Vec3 {
        return self.divScalar(self.len());
    }

    pub fn format(self: Vec3, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;

        try writer.print("{d} {d} {d}", .{ self.v[0], self.v[1], self.v[2] });
    }
};

test "init()" {
    const v = Vec3.init(1.0, 0.0, 2.0);

    try std.testing.expectEqual(1.0, v.v[0]);
    try std.testing.expectEqual(0.0, v.v[1]);
    try std.testing.expectEqual(2.0, v.v[2]);

    // Ensure the Vec3 is packed
    try std.testing.expectEqual(64 * 3, @bitSizeOf(Vec3));
}

test "zero()" {
    const v = Vec3.zero();

    try std.testing.expectEqual(0.0, v.v[0]);
    try std.testing.expectEqual(0.0, v.v[1]);
    try std.testing.expectEqual(0.0, v.v[2]);
}

test "nearZero()" {
    const zeroes = Vec3.zero();
    const big = Vec3.init(1, 1, 1);
    const small = Vec3.init(1e-9, 1e-9, 1e-9);

    try std.testing.expect(zeroes.nearZero());
    try std.testing.expect(!big.nearZero());
    try std.testing.expect(small.nearZero());
}

test "x(), y(), and z()" {
    const v = Vec3.init(1.0, 0.0, 2.0);

    try std.testing.expectEqual(1.0, v.x());
    try std.testing.expectEqual(0.0, v.y());
    try std.testing.expectEqual(2.0, v.z());
}

test "neg()" {
    const v = Vec3.init(1.0, 0.0, 2.0).neg();

    try std.testing.expectEqual(-1.0, v.x());
    try std.testing.expectEqual(-0.0, v.y());
    try std.testing.expectEqual(-2.0, v.z());
}

test "add()" {
    const v = Vec3.init(1.0, 0.0, 2.0).add(
        Vec3.init(0.0, 1.0, -1.0),
    );

    try std.testing.expectEqual(1.0, v.x());
    try std.testing.expectEqual(1.0, v.y());
    try std.testing.expectEqual(1.0, v.z());
}

test "addScalar()" {
    const v = Vec3.init(1.0, 0.0, 2.0).addScalar(2);

    try std.testing.expectEqual(3.0, v.x());
    try std.testing.expectEqual(2.0, v.y());
    try std.testing.expectEqual(4.0, v.z());
}

test "sub()" {
    const v = Vec3.init(1.0, 0.0, 2.0).sub(
        Vec3.init(0.0, 1.0, -1.0),
    );

    try std.testing.expectEqual(1.0, v.x());
    try std.testing.expectEqual(-1.0, v.y());
    try std.testing.expectEqual(3.0, v.z());
}

test "mul()" {
    const v = Vec3.init(1.0, 0.0, 2.0).mul(
        Vec3.init(0.0, 1.0, -1.0),
    );

    try std.testing.expectEqual(0.0, v.x());
    try std.testing.expectEqual(0.0, v.y());
    try std.testing.expectEqual(-2.0, v.z());
}

test "mulScalar()" {
    const v = Vec3.init(1.0, 0.0, 2.0).mulScalar(2.0);

    try std.testing.expectEqual(2.0, v.x());
    try std.testing.expectEqual(0.0, v.y());
    try std.testing.expectEqual(4.0, v.z());
}

test "divScalar()" {
    const v = Vec3.init(1.0, 0.0, 2.0).divScalar(2.0);

    try std.testing.expectEqual(0.5, v.x());
    try std.testing.expectEqual(0.0, v.y());
    try std.testing.expectEqual(1.0, v.z());
}

test "len()" {
    const len = Vec3.init(1.0, 0.0, 2.0).len();
    try std.testing.expectEqual(@sqrt(5.0), len);
}

test "lenSquared()" {
    const lenSquared = Vec3.init(1.0, 0.0, 2.0).lenSquared();
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
        const vec = Vec3.random(&prng);
        try std.testing.expect(0 <= vec.x() and vec.x() < 1.0);
        try std.testing.expect(0 <= vec.y() and vec.y() < 1.0);
        try std.testing.expect(0 <= vec.z() and vec.z() < 1.0);
    }

    // Ensure that two Random structs return the same output when given the
    // same seed
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec3.random(&seededPrng);
    const actual = Vec3.random(&newSeededPrng);
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
        const vec = Vec3.randomRange(1, 3, &prng);
        try std.testing.expect(1 <= vec.x() and vec.x() < 3);
        try std.testing.expect(1 <= vec.y() and vec.y() < 3);
        try std.testing.expect(1 <= vec.z() and vec.z() < 3);
    }

    // Ensure that two Random structs return the same output when given the
    // same seed
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec3.randomRange(-1, 0, &seededPrng);
    const actual = Vec3.randomRange(-1, 0, &newSeededPrng);
    try std.testing.expectEqual(expected, actual);
}

test "randomUnitVec()" {
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec3.randomUnitVec(&seededPrng);
    const actual = Vec3.randomUnitVec(&newSeededPrng);
    try std.testing.expectEqual(expected, actual);
}

test "randomInUnitDisk()" {
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec3.randomInUnitDisk(&seededPrng);
    const actual = Vec3.randomInUnitDisk(&newSeededPrng);
    try std.testing.expectEqual(expected, actual);
}

test "randomOnHemisphere()" {
    const normal = Vec3.init(1, 1, -1);

    // Ensure that two Random structs return the same output when given the
    // same seed
    var seededPrng = DefaultPrng.init(0xcafef00d);
    var newSeededPrng = DefaultPrng.init(0xcafef00d);
    const expected = Vec3.randomOnHemisphere(normal, &seededPrng);
    const actual = Vec3.randomOnHemisphere(normal, &newSeededPrng);
    try std.testing.expectEqual(expected, actual);
}

test "dot()" {
    const dot = Vec3.init(1.0, 0.0, 2.0).dot(
        Vec3.init(1.0, 2.0, 3.0),
    );

    try std.testing.expectEqual(7.0, dot);
}

test "cross()" {
    const cross = Vec3.init(1.0, 0.0, 2.0).cross(
        Vec3.init(1.0, 2.0, 3.0),
    );

    try std.testing.expectEqual(-4.0, cross.x());
    try std.testing.expectEqual(-1.0, cross.y());
    try std.testing.expectEqual(2.0, cross.z());
}

test "unit()" {
    const v = Vec3.init(1.0, 0.0, 2.0).unit();
    const len = @sqrt(5.0);

    try std.testing.expectEqual((1.0 / len), v.x());
    try std.testing.expectEqual(0.0, v.y());
    try std.testing.expectEqual((2.0 / len), v.z());
}

test "Point3 alias" {
    const p = Point3.zero();

    try std.testing.expectEqual(0, p.x());
    try std.testing.expectEqual(0, p.y());
    try std.testing.expectEqual(0, p.z());
}

test "format()" {
    const v = Vec3.zero();
    const expected = "0 0 0";

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{v});
    try std.testing.expectEqualStrings(expected, actual);
}
