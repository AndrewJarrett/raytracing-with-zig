const std = @import("std");
const util = @import("util.zig");
const Ray = @import("ray.zig").Ray;
const Hit = @import("hittable.zig").Hit;
const Color3 = @import("color.zig").Color3;
const Vec = @import("vec.zig").Vec;
const Vec3 = @import("vec.zig").Vec3;

const DefaultPrng = std.Random.DefaultPrng;

pub const Scatter = struct {
    scattered: Ray,
    attenuation: Color3,
};

pub const Lambertian = struct {
    albedo: Color3,

    pub fn init(albedo: Color3) Lambertian {
        return .{
            .albedo = albedo,
        };
    }

    pub fn scatter(self: Lambertian, ray: Ray, rec: Hit) ?Scatter {
        var dir = rec.normal + Vec.randomUnitVec(ray.prng);
        if (Vec.nearZero(dir)) {
            dir = rec.normal;
        }

        return .{
            .scattered = Ray.init(rec.point, dir, ray.prng),
            .attenuation = self.albedo,
        };
    }
};

pub const Metal = struct {
    albedo: Color3,
    fuzz: f64,

    pub fn init(albedo: Color3, fuzz: f64) Metal {
        return .{
            .albedo = albedo,
            .fuzz = fuzz,
        };
    }

    pub fn scatter(self: Metal, ray: Ray, rec: Hit) ?Scatter {
        var s: ?Scatter = null;

        const reflected = Vec.unit(Vec.reflect(ray.dir, rec.normal)) +
            Vec.mulScalar(Vec.randomUnitVec(ray.prng), self.fuzz);

        if (Vec.dot(reflected, rec.normal) > 0) {
            s = .{
                .scattered = Ray.init(rec.point, reflected, ray.prng),
                .attenuation = self.albedo,
            };
        }
        return s;
    }
};

pub const Dielectric = struct {
    refractionIndex: f64,

    pub fn init(refractionIndex: f64) Dielectric {
        return .{
            .refractionIndex = refractionIndex,
        };
    }

    pub fn scatter(self: Dielectric, ray: Ray, rec: Hit) ?Scatter {
        const refract = if (rec.front)
            1.0 / self.refractionIndex
        else
            self.refractionIndex;

        const unitDir = Vec.unit(ray.dir);
        const cosTheta: f64 = @min(Vec.dot(-unitDir, rec.normal), 1.0);
        const sinTheta: f64 = @sqrt(1.0 - cosTheta * cosTheta);

        const cannotRefract = refract * sinTheta > 1.0;
        const approxReflect = Dielectric.reflectance(cosTheta, refract);
        const direction = if (cannotRefract or approxReflect > util.randomDouble(ray.prng))
            Vec.reflect(unitDir, rec.normal)
        else
            Vec.refract(unitDir, rec.normal, refract);

        return .{
            .scattered = Ray.init(rec.point, direction, ray.prng),
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

pub const MaterialArgs = struct {
    albedo: Color3 = Color3{ 1, 1, 1 },
    fuzz: f64 = 0,
    refractionIndex: f64 = 1.0,
};

pub const Material = union(MaterialType) {
    lambertian: Lambertian,
    metal: Metal,
    dielectric: Dielectric,

    pub fn init(mat: MaterialType, args: MaterialArgs) Material {
        return switch (mat) {
            .lambertian => .{
                .lambertian = Lambertian.init(args.albedo),
            },
            .metal => .{
                .metal = Metal.init(args.albedo, args.fuzz),
            },
            .dielectric => .{
                .dielectric = Dielectric.init(args.refractionIndex),
            },
        };
    }

    pub fn scatter(self: Material, ray: Ray, rec: Hit) ?Scatter {
        return switch (self) {
            .lambertian => |l| l.scatter(ray, rec),
            .metal => |m| m.scatter(ray, rec),
            .dielectric => |d| d.scatter(ray, rec),
        };
    }
};

test "Scatter" {
    var prng = DefaultPrng.init(0xcafef00d);
    const s: Scatter = .{
        .scattered = Ray.init(
            Vec3{ 0, 0, 0 },
            Vec3{ 0, 0, -1 },
            &prng,
        ),
        .attenuation = Color3{ 1, 1, 1 },
    };

    const expectedRay = Ray.init(Vec3{ 0, 0, 0 }, Vec3{ 0, 0, -1 }, &prng);
    try std.testing.expectEqual(expectedRay, s.scattered);
    try std.testing.expectEqual(Color3{ 1, 1, 1 }, s.attenuation);
}

test "Lambertian" {
    const albedo = Color3{ 1, 1, 1 };
    var prng = DefaultPrng.init(0xabadcafe);
    var otherPrng = DefaultPrng.init(0xabadcafe);

    const lam = Lambertian.init(albedo);
    const normal = Vec3{ 0, 0, 1 };
    const s = lam.scatter(
        Ray.init(Vec3{ 0, 0, 0 }, Vec3{ 0, 0, -1 }, &prng),
        Hit{
            .point = Vec3{ 0, 0, -1 },
            .normal = normal,
            .mat = Material.init(.lambertian, .{ .albedo = albedo }),
            .t = 0,
            .front = true,
        },
    );
    const randVec = Vec.randomUnitVec(&otherPrng);
    const expectedRay = Ray.init(Vec3{ 0, 0, -1 }, normal + randVec, &prng);

    try std.testing.expectEqual(albedo, lam.albedo);
    try std.testing.expectEqual(albedo, s.?.attenuation);
    try std.testing.expectEqualDeep(expectedRay, s.?.scattered);
}

test "Metal" {
    const albedo = Color3{ 1, 1, 1 };
    var prng = DefaultPrng.init(0xabadcafe);

    const metal = Metal.init(albedo, 0);
    const normal = Vec3{ 0, 0, 1 };
    const point = Vec3{ 0, 0, -1 };
    const s = metal.scatter(
        Ray.init(Vec3{ 0, 0, 0 }, point, &prng),
        Hit{
            .point = point,
            .normal = normal,
            .mat = Material.init(.metal, .{ .albedo = albedo, .fuzz = 0 }),
            .t = 0,
            .front = true,
        },
    );
    const expectedRay = Ray.init(point, Vec.reflect(point, normal), &prng);

    try std.testing.expectEqual(albedo, metal.albedo);
    try std.testing.expectEqual(albedo, s.?.attenuation);
    try std.testing.expectEqualDeep(expectedRay, s.?.scattered);
}

test "Dielectric" {
    const albedo = Color3{ 1, 1, 1 };
    var prng = DefaultPrng.init(0xabadcafe);
    const refract = 1.50;

    const dielectric = Dielectric.init(refract);
    const normal = Vec3{ 0, 0, 1 };
    const point = Vec3{ 0, 0, -1 };
    const s = dielectric.scatter(
        Ray.init(Vec3{ 0, 0, 0 }, point, &prng),
        Hit{
            .point = point,
            .normal = normal,
            .mat = Material.init(.dielectric, .{ .refractionIndex = refract }),
            .t = 0,
            .front = true,
        },
    );
    const expectedRay = Ray.init(point, Vec.refract(point, normal, 1.0 / refract), &prng);

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

    const mat = Material.init(.metal, .{ .albedo = albedo, .fuzz = 0 });
    const normal = Vec3{ 0, 0, 1 };
    const point = Vec3{ 0, 0, -1 };
    const s = mat.scatter(
        Ray.init(Vec3{ 0, 0, 0 }, Vec3{ 0, 0, -1 }, &prng),
        Hit{
            .point = Vec3{ 0, 0, -1 },
            .normal = Vec3{ 0, 0, 1 },
            .mat = mat,
            .t = 0,
            .front = true,
        },
    );

    const expectedRay = Ray.init(point, Vec.reflect(point, normal), &prng);

    try std.testing.expectEqual(albedo, mat.metal.albedo);
    try std.testing.expectEqual(albedo, s.?.attenuation);
    try std.testing.expectEqualDeep(expectedRay, s.?.scattered);
}
