const std = @import("std");
const DefaultPrng = std.Random.DefaultPrng;

const Color3 = @import("color.zig").Color3;
const Hit = @import("hittable.zig").Hit;
const Ray = @import("ray.zig").Ray;
const Vec = @import("vec.zig").Vec;
const Vec3 = @import("vec.zig").Vec3;
const util = @import("util.zig");

pub const Scatter = struct {
    scattered: Ray,
    attenuation: Color3,
};

pub const Lambertian = struct {
    albedo: Color3 = Color3{ 1, 1, 1 },

    pub fn scatter(self: Lambertian, ray: Ray, rec: Hit, prng: *DefaultPrng) ?Scatter {
        var dir = rec.normal + Vec.randomUnitVec(prng);
        if (Vec.nearZero(dir)) {
            dir = rec.normal;
        }

        return .{
            .scattered = Ray{ .orig = rec.point, .dir = dir, .time = ray.time },
            .attenuation = self.albedo,
        };
    }
};

pub const Metal = struct {
    albedo: Color3 = Color3{ 1, 1, 1 },
    fuzz: f64 = 0,

    pub fn scatter(self: Metal, ray: Ray, rec: Hit, prng: *DefaultPrng) ?Scatter {
        var s: ?Scatter = null;

        const reflected = Vec.unit(Vec.reflect(ray.dir, rec.normal)) +
            Vec.mulScalar(Vec.randomUnitVec(prng), self.fuzz);

        if (Vec.dot(reflected, rec.normal) > 0) {
            s = .{
                .scattered = Ray{ .orig = rec.point, .dir = reflected, .time = ray.time },
                .attenuation = self.albedo,
            };
        }
        return s;
    }
};

pub const Dielectric = struct {
    refractionIndex: f64 = 1.0,

    pub fn scatter(self: Dielectric, ray: Ray, rec: Hit, prng: *DefaultPrng) ?Scatter {
        const refract = if (rec.front)
            1.0 / self.refractionIndex
        else
            self.refractionIndex;

        const unitDir = Vec.unit(ray.dir);
        const cosTheta: f64 = @min(Vec.dot(-unitDir, rec.normal), 1.0);
        const sinTheta: f64 = @sqrt(1.0 - cosTheta * cosTheta);

        const cannotRefract = refract * sinTheta > 1.0;
        const approxReflect = Dielectric.reflectance(cosTheta, refract);
        const direction = if (cannotRefract or approxReflect > util.randomDouble(prng))
            Vec.reflect(unitDir, rec.normal)
        else
            Vec.refract(unitDir, rec.normal, refract);

        return .{
            .scattered = Ray{ .orig = rec.point, .dir = direction, .time = ray.time },
            .attenuation = Color3{ 1, 1, 1 },
        };
    }

    /// Schlick's approximation for reflectance
    fn reflectance(cos: f64, refractIndex: f64) f64 {
        var r0: f64 = (1 - refractIndex) / (1 + refractIndex);
        r0 *= r0;
        return r0 + (1 - r0) * std.math.pow(f64, 1 - cos, 5);
    }
};

pub const MaterialType = enum {
    lambertian,
    metal,
    dielectric,
};

pub const Material = union(MaterialType) {
    lambertian: Lambertian,
    metal: Metal,
    dielectric: Dielectric,

    pub fn init(mat: anytype) Material {
        return switch (@TypeOf(mat)) {
            Lambertian => .{ .lambertian = mat },
            Metal => .{ .metal = mat },
            Dielectric => .{ .dielectric = mat },
            else => @compileError("Unknown material: " ++ @typeName(@TypeOf(mat))),
        };
    }

    pub fn scatter(self: Material, ray: Ray, rec: Hit, prng: *DefaultPrng) ?Scatter {
        return switch (self) {
            .lambertian => |l| l.scatter(ray, rec, prng),
            .metal => |m| m.scatter(ray, rec, prng),
            .dielectric => |d| d.scatter(ray, rec, prng),
        };
    }
};

test "Scatter" {
    const s: Scatter = .{
        .scattered = Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = Vec3{ 0, 0, -1 } },
        .attenuation = Color3{ 1, 1, 1 },
    };

    const expectedRay = Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = Vec3{ 0, 0, -1 } };
    try std.testing.expectEqual(expectedRay, s.scattered);
    try std.testing.expectEqual(Color3{ 1, 1, 1 }, s.attenuation);
}

test "Lambertian" {
    const albedo = Color3{ 1, 1, 1 };
    const seed = 0xabadcafe;
    var prng = DefaultPrng.init(seed);
    var otherPrng = DefaultPrng.init(seed);

    const lam = Lambertian{ .albedo = albedo };
    const normal = Vec3{ 0, 0, 1 };
    const s = lam.scatter(
        Ray{},
        Hit{
            .point = Vec3{ 0, 0, -1 },
            .normal = normal,
            .mat = Material.init(Lambertian{ .albedo = albedo }),
            .t = 0,
            .front = true,
        },
        &prng
    );
    const randVec = Vec.randomUnitVec(&otherPrng);
    const expectedRay = Ray{ .orig = Vec3{ 0, 0, -1 }, .dir = (normal + randVec) };

    try std.testing.expectEqual(albedo, lam.albedo);
    try std.testing.expectEqual(albedo, s.?.attenuation);
    try std.testing.expectEqualDeep(expectedRay, s.?.scattered);
}

test "Metal" {
    const albedo = Color3{ 1, 1, 1 };
    var prng = DefaultPrng.init(0xabadcafe);

    const metal = Metal{ .albedo = albedo, .fuzz = 0 };
    const normal = Vec3{ 0, 0, 1 };
    const point = Vec3{ 0, 0, -1 };
    const s = metal.scatter(
        Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = point },
        Hit{
            .point = point,
            .normal = normal,
            .mat = Material.init(Metal{ .albedo = albedo, .fuzz = 0 }),
            .t = 0,
            .front = true,
        },
        &prng,
    );
    const expectedRay = Ray{ .orig = point, .dir = Vec.reflect(point, normal) };

    try std.testing.expectEqual(albedo, metal.albedo);
    try std.testing.expectEqual(albedo, s.?.attenuation);
    try std.testing.expectEqualDeep(expectedRay, s.?.scattered);
}

test "Dielectric" {
    const albedo = Color3{ 1, 1, 1 };
    const refract = 1.50;
    var prng = DefaultPrng.init(0xabadcafe);

    const dielectric = Dielectric{ .refractionIndex = refract };
    const normal = Vec3{ 0, 0, 1 };
    const point = Vec3{ 0, 0, -1 };
    const s = dielectric.scatter(
        Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = point },
        Hit{
            .point = point,
            .normal = normal,
            .mat = Material.init(Dielectric{ .refractionIndex = refract }),
            .t = 0,
            .front = true,
        },
        &prng,
    );
    const expectedRay = Ray{ .orig = point, .dir = Vec.refract(point, normal, 1.0 / refract) };

    try std.testing.expectEqual(refract, dielectric.refractionIndex);
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
    const albedo = Color3{ 1, 1, 1 };
    var prng = DefaultPrng.init(0xabadcafe);

    const mat = Material.init(Metal{ .albedo = albedo, .fuzz = 0 });
    const normal = Vec3{ 0, 0, 1 };
    const point = Vec3{ 0, 0, -1 };
    const s = mat.scatter(
        Ray{ .orig = Vec3{ 0, 0, 0 }, .dir = Vec3{ 0, 0, -1 } },
        Hit{
            .point = Vec3{ 0, 0, -1 },
            .normal = Vec3{ 0, 0, 1 },
            .mat = mat,
            .t = 0,
            .front = true,
        },
        &prng,
    );

    const expectedRay = Ray{ .orig = point, .dir = Vec.reflect(point, normal) };

    try std.testing.expectEqual(albedo, mat.metal.albedo);
    try std.testing.expectEqual(albedo, s.?.attenuation);
    try std.testing.expectEqualDeep(expectedRay, s.?.scattered);
}
