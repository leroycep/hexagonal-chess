const std = @import("std");
const gamekit = @import("gamekit");
const gfx = gamekit.gfx;
const math = gamekit.math;
const core = @import("core");
const Board = core.Board;
const util = @import("util");
const Vec2i = util.Vec2i;
const vec2i = util.vec2i;
const Vec2f = util.Vec2f;
const vec2f = util.vec2f;
const Vec3f = util.Vec3f;
const RGB = util.color.RGB;

const total_textures = 9;
const max_sprites_per_batch = 1000;
const HEX_RADIUS = 16;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;
var batcher: gfx.Batcher = undefined;
var textures: []gfx.Texture = undefined;
var game_board = Board.init(null);
var camera_offset = vec2f(0, 0);
var selected = vec2i(5, 5);

pub fn main() !void {
    try gamekit.run(.{
        .init = init,
        .shutdown = shutdown,
        .update = update,
        .render = render,
        .window = .{ .resizable = false, .width = 640, .height = 480 },
    });
}

fn init() !void {
    batcher = gfx.Batcher.init(allocator, max_sprites_per_batch);

    loadTextures();

    core.game.setupChess(&game_board);
}

fn shutdown() !void {
    _ = gpa.deinit();
}

fn update() !void {
    const center_tile_pos = flat_hex_to_pixel(HEX_RADIUS, vec2i(5, 5));
    camera_offset = vec2f(320, 240).sub(center_tile_pos);

    const gk_mousePos = gamekit.input.mousePos();
    const mousePos = vec2f(gk_mousePos.x, 480 - gk_mousePos.y);
    selected = pixel_to_flat_hex(HEX_RADIUS, mousePos.sub(camera_offset));
}

fn render() !void {
    gfx.beginPass(.{
        .color = math.Color.fromRgbBytes(0x88, 0x88, 0x88),
        .trans_mat = math.Mat32.initTransform(.{
            .x = camera_offset.x(),
            .y = camera_offset.y(),
        }),
    });
    batcher.begin();

    var board_iter = game_board.iterator();
    while (board_iter.next()) |res| {
        const pcoords = flat_hex_to_pixel(HEX_RADIUS, res.pos);

        const texture = textures[@intCast(usize, @mod(res.pos.x() + res.pos.y() * Board.SIZE, 3))];

        const color: u32 = if (res.pos.eql(selected)) 0xFF888888 else 0xFFFFFFFF;

        batcher.drawTex(math.Vec2{ .x = pcoords.x() - 16, .y = pcoords.y() - 14 }, color, texture);
    }

    board_iter = game_board.iterator();
    while (board_iter.next()) |res| {
        if (res.tile.* == null) continue;
        const tile = res.tile.*.?;

        const piece_pos = flat_hex_to_pixel(HEX_RADIUS, res.pos);
        const color: u32 = switch (tile.color) {
            .Black => 0xFF222222,
            .White => 0xFFFFFFFF,
        };
        const texture = switch (tile.kind) {
            .Pawn => textures[3],
            .Rook => textures[4],
            .Bishop => textures[5],
            .Knight => textures[6],
            .Queen => textures[7],
            .King => textures[8],
        };

        batcher.drawTex(math.Vec2{ .x = piece_pos.x(), .y = piece_pos.y() }, color, texture);
    }

    batcher.end();
    gfx.endPass();
}

fn loadTextures() void {
    textures = allocator.alloc(gfx.Texture, total_textures) catch unreachable;

    textures[0] = gfx.Texture.initFromFile(allocator, "assets/tile0.png", .nearest) catch unreachable;
    textures[1] = gfx.Texture.initFromFile(allocator, "assets/tile1.png", .nearest) catch unreachable;
    textures[2] = gfx.Texture.initFromFile(allocator, "assets/tile2.png", .nearest) catch unreachable;
    textures[3] = gfx.Texture.initFromFile(allocator, "assets/pawn.png", .nearest) catch unreachable;
    textures[4] = gfx.Texture.initFromFile(allocator, "assets/rook.png", .nearest) catch unreachable;
    textures[5] = gfx.Texture.initFromFile(allocator, "assets/bishop.png", .nearest) catch unreachable;
    textures[6] = gfx.Texture.initFromFile(allocator, "assets/knight.png", .nearest) catch unreachable;
    textures[7] = gfx.Texture.initFromFile(allocator, "assets/queen.png", .nearest) catch unreachable;
    textures[8] = gfx.Texture.initFromFile(allocator, "assets/king.png", .nearest) catch unreachable;
}

fn flat_hex_to_pixel(size: f32, hex: Vec2i) Vec2f {
    var x = size * (3.0 / 2.0 * @intToFloat(f32, hex.v[0]));
    var y = size * (std.math.sqrt(@as(f32, 3.0)) / 2.0 * @intToFloat(f32, hex.v[0]) + std.math.sqrt(@as(f32, 3.0)) * @intToFloat(f32, hex.v[1]));
    return Vec2f.init(x, y);
}

fn pixel_to_flat_hex(size: f32, pixel: Vec2f) Vec2i {
    var q = (2.0 / 3.0 * pixel.v[0]) / size;
    var r = (-1.0 / 3.0 * pixel.v[0] + std.math.sqrt(@as(f32, 3)) / 3 * pixel.v[1]) / size;
    return hex_round(Vec2f.init(q, r)).floatToInt(i32);
}

fn hex_round(hex: Vec2f) Vec2f {
    return cube_to_axial(cube_round(axial_to_cube(hex)));
}

fn cube_round(cube: Vec3f) Vec3f {
    var rx = std.math.round(cube.x());
    var ry = std.math.round(cube.y());
    var rz = std.math.round(cube.z());

    var x_diff = std.math.absFloat(rx - cube.x());
    var y_diff = std.math.absFloat(ry - cube.y());
    var z_diff = std.math.absFloat(rz - cube.z());

    if (x_diff > y_diff and x_diff > z_diff) {
        rx = -ry - rz;
    } else if (y_diff > z_diff) {
        ry = -rx - rz;
    } else {
        rz = -rx - ry;
    }

    return Vec3f.init(rx, ry, rz);
}

fn axial_to_cube(axial: Vec2f) Vec3f {
    return util.vec3f(
        axial.x(),
        -axial.x() - axial.y(),
        axial.y(),
    );
}

fn cube_to_axial(cube: Vec3f) Vec2f {
    return vec2f(cube.x(), cube.z());
}
