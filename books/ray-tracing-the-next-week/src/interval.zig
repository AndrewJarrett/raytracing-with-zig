const std = @import("std");

const posInf = std.math.inf(f64);
const negInf = -std.math.inf(f64);

const Self = @This();
min: f64 = posInf,
max: f64 = negInf,

pub fn empty() Self {
    return .{};
}

pub fn universe() Self {
    return .{
        .min = negInf,
        .max = posInf,
    };
}

pub fn init(iMin: f64, iMax: f64) Self {
    return .{
        .min = iMin,
        .max = iMax,
    };
}

pub fn size(self: Self) f64 {
    return self.max - self.min;
}

pub fn contains(self: Self, x: f64) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: Self, x: f64) bool {
    return self.min < x and x < self.max;
}

pub fn clamp(self: Self, x: f64) f64 {
    return if (x < self.min)
        self.min
    else if (x > self.max)
        self.max
    else
        x;
}

pub fn expand(self: Self, delta: f64) Self {
    const padding = delta / 2;
    return Self.init(self.min - padding, self.max + padding);
}

test "empty()" {
    const emp = Self.empty();

    try std.testing.expectEqual(posInf, emp.min);
    try std.testing.expectEqual(negInf, emp.max);
}

test "universe()" {
    const universeInterval = Self.universe();

    try std.testing.expectEqual(negInf, universeInterval.min);
    try std.testing.expectEqual(posInf, universeInterval.max);
}

test "init()" {
    const int = Self.init(0, 2);
    const emp = Self{};

    try std.testing.expectEqual(0, int.min);
    try std.testing.expectEqual(2, int.max);
    try std.testing.expectEqual(posInf, emp.min);
    try std.testing.expectEqual(negInf, emp.max);
}

test "size()" {
    const int = Self.init(0, 2);
    const emp = Self.empty();
    const uni = Self.universe();

    try std.testing.expectEqual(2, int.size());
    try std.testing.expectEqual(negInf, emp.size());
    try std.testing.expectEqual(posInf, uni.size());
}

test "contains()" {
    const int = Self.init(0, 2);
    const emp = Self.empty();
    const uni = Self.universe();

    try std.testing.expect(int.contains(0));
    try std.testing.expect(int.contains(1));
    try std.testing.expect(int.contains(2));
    try std.testing.expect(int.contains(1.5));
    try std.testing.expect(uni.contains(0));
    try std.testing.expect(uni.contains(negInf));
    try std.testing.expect(uni.contains(posInf));
    try std.testing.expect(uni.contains(std.math.floatMax(f64)));
    try std.testing.expect(uni.contains(std.math.floatMin(f64)));

    try std.testing.expect(!int.contains(-0.00001));
    try std.testing.expect(!int.contains(2.0000001));
    try std.testing.expect(!int.contains(5));
    try std.testing.expect(!int.contains(-5));
    try std.testing.expect(!emp.contains(negInf));
    try std.testing.expect(!emp.contains(posInf));
    try std.testing.expect(!emp.contains(0));
}

test "surrounds()" {
    const int = Self.init(0, 2);
    const emp = Self.empty();
    const uni = Self.universe();

    try std.testing.expect(int.surrounds(0.00001));
    try std.testing.expect(int.surrounds(1));
    try std.testing.expect(int.surrounds(1.5));
    try std.testing.expect(int.surrounds(1.9999999));
    try std.testing.expect(uni.surrounds(0));
    try std.testing.expect(uni.surrounds(std.math.floatMax(f64)));
    try std.testing.expect(uni.surrounds(std.math.floatMin(f64)));

    try std.testing.expect(!int.surrounds(0));
    try std.testing.expect(!int.surrounds(2));
    try std.testing.expect(!int.surrounds(5));
    try std.testing.expect(!int.surrounds(-5));
    try std.testing.expect(!emp.surrounds(negInf));
    try std.testing.expect(!emp.surrounds(posInf));
    try std.testing.expect(!emp.contains(0));
    try std.testing.expect(!uni.surrounds(negInf));
    try std.testing.expect(!uni.surrounds(posInf));
}

test "clamp()" {
    const int = Self.init(0, 2);
    const emp = Self.empty();
    const uni = Self.universe();

    try std.testing.expectEqual(0, int.clamp(0));
    try std.testing.expectEqual(0, int.clamp(-1));
    try std.testing.expectEqual(1, int.clamp(1));
    try std.testing.expectEqual(2, int.clamp(2));
    try std.testing.expectEqual(2, int.clamp(3));

    try std.testing.expectEqual(posInf, emp.clamp(0));
    try std.testing.expectEqual(posInf, emp.clamp(-1));
    try std.testing.expectEqual(posInf, emp.clamp(1));
    try std.testing.expectEqual(negInf, emp.clamp(posInf));
    try std.testing.expectEqual(posInf, emp.clamp(negInf));

    try std.testing.expectEqual(0, uni.clamp(0));
    try std.testing.expectEqual(-1, uni.clamp(-1));
    try std.testing.expectEqual(1, uni.clamp(1));
    try std.testing.expectEqual(negInf, uni.clamp(negInf));
    try std.testing.expectEqual(posInf, uni.clamp(posInf));
}
