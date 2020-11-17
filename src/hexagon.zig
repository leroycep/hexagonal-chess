const std = @import("std");
const util = @import("util");
const Vec2i = util.Vec2i;
const vec2i = util.vec2i;
const Vec2f = util.Vec2f;
const vec2f = util.vec2f;
const Vec3f = util.Vec3f;

pub fn flat_hex_to_pixel(size: f32, hex: Vec2i) Vec2f {
    var x = size * (3.0 / 2.0 * @intToFloat(f32, hex.x));
    var y = size * (std.math.sqrt(@as(f32, 3.0)) / 2.0 * @intToFloat(f32, hex.x) + std.math.sqrt(@as(f32, 3.0)) * @intToFloat(f32, hex.y));
    return Vec2f.init(x, y);
}

pub fn pixel_to_flat_hex(size: f32, pixel: Vec2f) Vec2i {
    var q = (2.0 / 3.0 * pixel.x) / size;
    var r = (-1.0 / 3.0 * pixel.x + std.math.sqrt(@as(f32, 3)) / 3 * pixel.y) / size;
    return hex_round(Vec2f.init(q, r)).floatToInt(i32);
}

pub fn hex_round(hex: Vec2f) Vec2f {
    return cube_to_axial(cube_round(axial_to_cube(hex)));
}

pub fn cube_round(cube: Vec3f) Vec3f {
    var rx = std.math.round(cube.x);
    var ry = std.math.round(cube.y);
    var rz = std.math.round(cube.z);

    var x_diff = std.math.absFloat(rx - cube.x);
    var y_diff = std.math.absFloat(ry - cube.y);
    var z_diff = std.math.absFloat(rz - cube.z);

    if (x_diff > y_diff and x_diff > z_diff) {
        rx = -ry - rz;
    } else if (y_diff > z_diff) {
        ry = -rx - rz;
    } else {
        rz = -rx - ry;
    }

    return Vec3f.init(rx, ry, rz);
}

pub fn axial_to_cube(axial: Vec2f) Vec3f {
    return util.vec3f(
        axial.x,
        -axial.x - axial.y,
        axial.y,
    );
}

pub fn cube_to_axial(cube: Vec3f) Vec2f {
    return vec2f(cube.x, cube.z);
}
