const std = @import("std");
const fs = std.fs;
const Builder = std.build.Builder;
const sep_str = std.fs.path.sep_str;
const Cpu = std.Target.Cpu;
const Pkg = std.build.Pkg;
const gamekit = @import("./zig-gamekit/build.zig");
const GAMEKIT_PREFIX = "./zig-gamekit/";

const UTIL = std.build.Pkg{
    .name = "util",
    .path = "./util/util.zig",
};
const CORE = std.build.Pkg{
    .name = "core",
    .path = "./core/core.zig",
    .dependencies = &[_]Pkg{UTIL},
};

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const native = b.addExecutable("hex-chess", "src/main.zig");
    native.addPackage(UTIL);
    native.addPackage(CORE);
    gamekit.addGameKitToArtifact(b, native, target, GAMEKIT_PREFIX);
    native.setTarget(target);
    native.setBuildMode(mode);
    native.install();
    b.step("native", "Build native binary").dependOn(&native.step);

    // Server
    const server = b.addExecutable("hex-chess-server", "server/server.zig");
    server.addPackage(CORE);
    server.setTarget(target);
    server.setBuildMode(mode);
    server.install();
    b.step("server", "Build server binary").dependOn(&server.step);

    const test_server = b.addTest("server/server.zig");
    const test_core = b.addTest("core/core.zig");
    test_core.addPackage(UTIL);

    b.step("run", "Run the native binary").dependOn(&native.run().step);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_server.step);
    test_step.dependOn(&test_core.step);

    const all = b.step("all", "Build all binaries");
    all.dependOn(&native.step);
    all.dependOn(&server.step);
    all.dependOn(test_step);
}
