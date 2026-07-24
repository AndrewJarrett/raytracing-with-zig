# raytracing-with-zig
This repo contains folders for work related to the following books on raytracing:
1. [Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html)
2. [Ray Tracing the Next Week](https://raytracing.github.io/books/RayTracingTheNextWeek.html)

# Building and Running
To build the tracer for each book, you must `cd` into the book's folder and run the following commands.
```bash
cd books/ray-tracing-in-one-weekend
zig build test
zig build run -Drelease=true
```
or
```bash
cd books/ray-tracing-the-next-week
zig build test
zig build run -Drelease=true
```

# Custom Build Options
All of the tests are deterministically seeded and yield the same image with each run. When running the release build (which defaults to `.ReleaseFast`), you can also provide other build time options such as a custom `seed` (in decimal instead of hex), `imageWidth`, `aspectRatio`, `samplesPerPixel`, `fileName`, `chunkSize`, and `logLevel`.

See `zig build -h` for more information on the options. Example custom command:
```bash
zig build run -Drelease=true -DlogLevel=debug -DaspectRatio=1.5 -Dseed=3405705229 -DfileName=final-render-multithreaded-1200-0xcafef00d.ppm
```
