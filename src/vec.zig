const std = @import("std");

const Point3 = Vec3;
const Color3 = Vec3;

pub const Vec3 = struct {
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
        return std.math.sqrt(self.lenSquared());
    }

    pub fn lenSquared(self: Vec3) f64 {
        return @reduce(.Add, (self.v * self.v));
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
}

test "zero()" {
    const v = Vec3.zero();

    try std.testing.expectEqual(0.0, v.v[0]);
    try std.testing.expectEqual(0.0, v.v[1]);
    try std.testing.expectEqual(0.0, v.v[2]);
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
    try std.testing.expectEqual(std.math.sqrt(5.0), len);
}

test "lenSquared()" {
    const lenSquared = Vec3.init(1.0, 0.0, 2.0).lenSquared();
    try std.testing.expectEqual(5.0, lenSquared);
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
    const len = std.math.sqrt(5.0);

    try std.testing.expectEqual((1.0 / len), v.x());
    try std.testing.expectEqual(0.0, v.y());
    try std.testing.expectEqual((2.0 / len), v.z());
}

test "Point3 and Color3 aliases" {
    const p = Point3.zero();
    const c = Color3.init(0.5, 0.5, 0.5);

    try std.testing.expectEqual(0, p.x());
    try std.testing.expectEqual(0, p.y());
    try std.testing.expectEqual(0, p.z());

    try std.testing.expectEqual(0.5, c.x());
    try std.testing.expectEqual(0.5, c.y());
    try std.testing.expectEqual(0.5, c.z());
}

test "format()" {
    const v = Vec3.zero();
    const expected = "0 0 0";

    var buffer: [20]u8 = undefined;
    const actual = try std.fmt.bufPrint(buffer[0..expected.len], "{s}", .{v});
    try std.testing.expectEqualStrings(expected, actual);
}
