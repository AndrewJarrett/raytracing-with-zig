const std = @import("std");
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("hittable.zig").HitRecord;
const Color = @import("color.zig").Color;
const Vec3 = @import("vec.zig").Vec3;

const DefaultPrng = std.rand.DefaultPrng;

pub const Scatter = struct {
    scattered: Ray,
    attenuation: Color,
};

pub const Lambertian = struct {
    albedo: Color,
    prng: *DefaultPrng,

    pub fn init(albedo: Color, prng: *DefaultPrng) Lambertian {
        return .{
            .albedo = albedo,
            .prng = prng,
        };
    }

    pub fn scatter(self: Lambertian, ray: Ray, rec: HitRecord) ?Scatter {
        _ = ray;

        var dir = rec.normal.add(Vec3.randomUnitVec(self.prng));
        if (dir.nearZero()) {
            dir = rec.normal;
        }

        return .{
            .scattered = Ray.init(rec.point, dir),
            .attenuation = self.albedo,
        };
    }
};

pub const Metal = struct {
    albedo: Color,
    prng: *DefaultPrng,
    fuzz: f64,

    pub fn init(albedo: Color, fuzz: f64, prng: *DefaultPrng) Metal {
        return .{
            .albedo = albedo,
            .fuzz = fuzz,
            .prng = prng,
        };
    }

    pub fn scatter(self: Metal, ray: Ray, rec: HitRecord) ?Scatter {
        var s: ?Scatter = null;

        const reflected = ray.dir.reflect(rec.normal).unit()
            .add(Vec3.randomUnitVec(self.prng).mulScalar(self.fuzz));

        if (reflected.dot(rec.normal) > 0) {
            s = .{
                .scattered = Ray.init(rec.point, reflected),
                .attenuation = self.albedo,
            };
        }
        return s;
    }
};

pub const MaterialType = enum {
    lambertian,
    metal,
};

pub const MaterialArgs = struct {
    albedo: Color,
    fuzz: f64 = 0,
    prng: *DefaultPrng,
};

pub const Material = union(MaterialType) {
    lambertian: Lambertian,
    metal: Metal,

    pub fn init(mat: MaterialType, args: MaterialArgs) Material {
        return switch (mat) {
            .lambertian => .{
                .lambertian = Lambertian.init(args.albedo, args.prng),
            },
            .metal => .{
                .metal = Metal.init(args.albedo, args.fuzz, args.prng),
            },
        };
    }

    pub fn scatter(self: Material, ray: Ray, rec: HitRecord) ?Scatter {
        return switch (self) {
            .lambertian => |l| l.scatter(ray, rec),
            .metal => |m| m.scatter(ray, rec),
        };
    }
};

test "Scatter" {
    const s: Scatter = .{
        .scattered = Ray.init(
            Vec3.init(0, 0, 0),
            Vec3.init(0, 0, -1),
        ),
        .attenuation = Color.init(1, 1, 1),
    };

    try std.testing.expectEqual(
        Ray.init(
            Vec3.init(0, 0, 0),
            Vec3.init(0, 0, -1),
        ),
        s.scattered,
    );
    try std.testing.expectEqual(Color.init(1, 1, 1), s.attenuation);
}

test "Lambertian" {
    const albedo = Color.init(1, 1, 1);
    const prngPtr = try testPrng(0xabadcafe);
    const otherPrng = try testPrng(0xabadcafe);
    defer std.testing.allocator.destroy(prngPtr);
    defer std.testing.allocator.destroy(otherPrng);

    const lam = Lambertian.init(albedo, prngPtr);
    const normal = Vec3.init(0, 0, 1);
    const s = lam.scatter(
        Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, -1)),
        HitRecord{
            .point = Vec3.init(0, 0, -1),
            .normal = normal,
            .mat = Material.init(.lambertian, .{ .albedo = albedo, .prng = prngPtr }),
            .t = 0,
            .front = true,
        },
    );
    const randVec = Vec3.randomUnitVec(otherPrng);
    const expectedRay = Ray.init(Vec3.init(0, 0, -1), normal.add(randVec));

    try std.testing.expectEqual(albedo, lam.albedo);
    try std.testing.expectEqual(prngPtr, lam.prng);
    try std.testing.expectEqual(albedo, s.?.attenuation);
    try std.testing.expectEqualDeep(expectedRay, s.?.scattered);
}

test "Metal" {
    const albedo = Color.init(1, 1, 1);
    const prngPtr = try testPrng(0xabadcafe);
    defer std.testing.allocator.destroy(prngPtr);

    const metal = Metal.init(albedo, 0, prngPtr);
    const normal = Vec3.init(0, 0, 1);
    const point = Vec3.init(0, 0, -1);
    const s = metal.scatter(
        Ray.init(Vec3.init(0, 0, 0), point),
        HitRecord{
            .point = point,
            .normal = normal,
            .mat = Material.init(.metal, .{ .albedo = albedo, .fuzz = 0, .prng = prngPtr }),
            .t = 0,
            .front = true,
        },
    );
    const expectedRay = Ray.init(point, point.reflect(normal));

    try std.testing.expectEqual(albedo, metal.albedo);
    try std.testing.expectEqual(prngPtr, metal.prng);
    try std.testing.expectEqual(albedo, s.?.attenuation);
    try std.testing.expectEqualDeep(expectedRay, s.?.scattered);
}

test "MaterialType" {
    const lam: MaterialType = .lambertian;
    const metal: MaterialType = .metal;

    try std.testing.expectEqual("lambertian", @tagName(lam));
    try std.testing.expectEqual("metal", @tagName(metal));
}

test "Material" {
    const albedo = Color.init(1, 1, 1);
    const prngPtr = try testPrng(0xabadcafe);
    defer std.testing.allocator.destroy(prngPtr);

    const mat = Material.init(.metal, .{ .albedo = albedo, .fuzz = 0, .prng = prngPtr });
    const normal = Vec3.init(0, 0, 1);
    const point = Vec3.init(0, 0, -1);
    const s = mat.scatter(
        Ray.init(Vec3.init(0, 0, 0), Vec3.init(0, 0, -1)),
        HitRecord{
            .point = Vec3.init(0, 0, -1),
            .normal = Vec3.init(0, 0, 1),
            .mat = mat,
            .t = 0,
            .front = true,
        },
    );

    const expectedRay = Ray.init(point, point.reflect(normal));

    try std.testing.expectEqual(albedo, mat.metal.albedo);
    try std.testing.expectEqual(prngPtr, mat.metal.prng);
    try std.testing.expectEqual(albedo, s.?.attenuation);
    try std.testing.expectEqualDeep(expectedRay, s.?.scattered);
}

fn testPrng(seed: u64) !*DefaultPrng {
    const prngPtr = try std.testing.allocator.create(DefaultPrng);
    const prng = DefaultPrng.init(seed);
    prngPtr.* = prng;

    return prngPtr;
}
