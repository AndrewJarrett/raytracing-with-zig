const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    //const lib = b.addStaticLibrary(.{
    //    .name = "ray-tracing-the-next-week",
    //    .root_source_file = b.path("src/root.zig"),
    //    .target = target,
    //    .optimize = optimize,
    //});

    //b.installArtifact(lib);

    const imgWidth = b.option(u16, "imgWidth", "width of the image in pixels (default 1200)") orelse 1200;
    const samplesPerPixel = b.option(u16, "samplesPerPixel", "samples per pixel to use (default 500)") orelse 500;
    const aspectRatio = b.option(f64, "aspectRatio", "aspect ratio to use (default 16/9)") orelse (16.0 / 9.0);
    const fileName = b.option([]const u8, "fileName", "name of the file to save (default chapter2.ppm)") orelse "chapter2.ppm";
    const seed = b.option(u64, "seed", "an optional random seed to use for deterministic results (default null)") orelse null;
    const chunkSize = b.option(u8, "chunkSize", "the amount of rows to process at one time. Less is more balanced, higher may be slightly faster (default 4)") orelse 4;
    const logLevel = b.option(std.log.Level, "logLevel", "the default logging level to output (default .Debug = '.debug', .ReleaseSate, .ReleaseFast, .ReleaseSmall = '.info')") orelse std.log.default_level;

    const buildOptions = b.addOptions();
    buildOptions.addOption(u16, "imgWidth", imgWidth);
    buildOptions.addOption(u16, "samplesPerPixel", samplesPerPixel);
    buildOptions.addOption(f64, "aspectRatio", aspectRatio);
    buildOptions.addOption([]const u8, "fileName", fileName);
    buildOptions.addOption(?u64, "seed", seed);
    buildOptions.addOption(u8, "chunkSize", chunkSize);

    const stdOptions = b.addOptions();
    stdOptions.addOption(std.log.Level, "log_level", logLevel);

    const exe = b.addExecutable(.{
        .name = "ray-tracing-the-next-week",
        .root_module = std.Build.Module.create(b, .{ 
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addOptions("config", buildOptions);
    exe.root_module.addOptions("std_options", stdOptions);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //const lib_unit_tests = b.addTest(.{
    //    .root_source_file = b.path("src/root.zig"),
    //    .target = target,
    //    .optimize = optimize,
    //});

    //const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = std.Build.Module.create(b, .{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        })
    });

    const testOptions = b.addOptions();
    testOptions.addOption(u16, "imgWidth", 400);
    testOptions.addOption(u16, "samplesPerPixel", 100);
    testOptions.addOption(f64, "aspectRatio", (16.0 / 9.0));
    testOptions.addOption([]const u8, "fileName", fileName);
    testOptions.addOption(?u64, "seed", 0xdeadbeef);
    testOptions.addOption(u8, "chunkSize", chunkSize);

    exe_unit_tests.root_module.addOptions("config", testOptions);
    exe_unit_tests.root_module.addOptions("std_options", stdOptions);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    //test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
