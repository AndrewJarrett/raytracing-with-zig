const std = @import("std");

const posInf = std.math.inf(f64);
const negInf = -std.math.inf(f64);

pub const Interval = struct {
    min: f64 = posInf,
    max: f64 = negInf,

    pub fn empty() Interval {
        return .{};
    }

    pub fn universe() Interval {
        return .{
            .min = negInf,
            .max = posInf,
        };
    }

    pub fn init(iMin: f64, iMax: f64) Interval {
        return .{
            .min = iMin,
            .max = iMax,
        };
    }

    pub fn size(self: Interval) f64 {
        return self.max - self.min;
    }

    pub fn contains(self: Interval, x: f64) bool {
        return self.min <= x and x <= self.max;
    }

    pub fn surrounds(self: Interval, x: f64) bool {
        return self.min < x and x < self.max;
    }
};

test "empty()" {
    const empty = Interval.empty();

    try std.testing.expectEqual(posInf, empty.min);
    try std.testing.expectEqual(negInf, empty.max);
}

test "universe()" {
    const universe = Interval.universe();

    try std.testing.expectEqual(negInf, universe.min);
    try std.testing.expectEqual(posInf, universe.max);
}

test "init()" {
    const int = Interval.init(0, 2);
    const empty = Interval{};

    try std.testing.expectEqual(0, int.min);
    try std.testing.expectEqual(2, int.max);
    try std.testing.expectEqual(posInf, empty.min);
    try std.testing.expectEqual(negInf, empty.max);
}

test "size()" {
    const int = Interval.init(0, 2);
    const empty = Interval.empty();
    const uni = Interval.universe();

    try std.testing.expectEqual(2, int.size());
    try std.testing.expectEqual(negInf, empty.size());
    try std.testing.expectEqual(posInf, uni.size());
}

test "contains()" {
    const int = Interval.init(0, 2);
    const empty = Interval.empty();
    const uni = Interval.universe();

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
    try std.testing.expect(!empty.contains(negInf));
    try std.testing.expect(!empty.contains(posInf));
    try std.testing.expect(!empty.contains(0));
}

test "surrounds()" {
    const int = Interval.init(0, 2);
    const empty = Interval.empty();
    const uni = Interval.universe();

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
    try std.testing.expect(!empty.surrounds(negInf));
    try std.testing.expect(!empty.surrounds(posInf));
    try std.testing.expect(!empty.contains(0));
    try std.testing.expect(!uni.surrounds(negInf));
    try std.testing.expect(!uni.surrounds(posInf));
}
