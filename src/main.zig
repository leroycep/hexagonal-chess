const std = @import("std");
const gamekit = @import("gamekit");
const gfx = gamekit.gfx;
const math = gamekit.math;
const core = @import("core");
const Board = core.Board;
const util = @import("util");
const platform = @import("./platform.zig");

const ArrayList = std.ArrayList;
const Vec2i = util.Vec2i;
const vec2i = util.vec2i;
const Vec2f = util.Vec2f;
const vec2f = util.vec2f;
const Vec3f = util.Vec3f;
const RGB = util.color.RGB;

const total_textures = 10;
const max_sprites_per_batch = 1000;
const HEX_RADIUS = 16;
const COLOR_SELECTED = RGB.from_hsluv(213.4, 92.2, 77.4).withAlpha(0x99);
const COLOR_MOVE = RGB.from_hsluv(131.4, 55.0, 54.2).withAlpha(0x99);
const COLOR_CAPTURE = RGB.from_hsluv(12.9, 55.0, 54.2).withAlpha(0x99);
const COLOR_MOVE_OTHER = COLOR_MOVE.withAlpha(0x44);
const COLOR_CAPTURE_OTHER = COLOR_CAPTURE.withAlpha(0x77);

var socket: *platform.net.FramesSocket = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;
var batcher: gfx.Batcher = undefined;
var textures: []gfx.Texture = undefined;
var game_board = Board.init(null);
var camera_offset = vec2f(0, 0);
var pos_hovered = vec2i(5, 5);
var pos_selected: ?Vec2i = null;
var moves_shown: ArrayList(core.moves.Move) = undefined;
var current_player = core.piece.Piece.Color.White;
var clients_player = core.piece.Piece.Color.White;

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
    const localhost = try std.net.Address.parseIp("127.0.0.1", 48836);
    socket = try platform.net.FramesSocket.init(allocator, localhost);
    socket.setOnMessage(onSocketMessage);

    batcher = gfx.Batcher.init(allocator, max_sprites_per_batch);

    loadTextures();

    moves_shown = ArrayList(core.moves.Move).init(allocator);
}

fn shutdown() !void {
    _ = gpa.deinit();
}

pub fn onSocketMessage(_socket: *platform.net.FramesSocket, message: []const u8) void {
    std.log.info("Received message {}", .{message});
    const packet = core.protocol.ServerPacket.parse(message) catch |e| {
        std.log.err("Could not read packet: {}", .{e});
        return;
    };
    switch (packet) {
        .Init => |init_data| clients_player = init_data.color,
        .BoardUpdate => |board_update| game_board = Board.deserialize(board_update),
        .TurnChange => |turn_change| current_player = turn_change,
        else => {},
    }
}

fn update() !void {
    platform.net.update_sockets();

    const center_tile_pos = flat_hex_to_pixel(HEX_RADIUS, vec2i(5, 5));
    camera_offset = vec2f(320, 240).sub(center_tile_pos);

    const gk_mousePos = gamekit.input.mousePos();
    const mousePos = vec2f(gk_mousePos.x, 480 - gk_mousePos.y);
    const new_pos_hovered = pixel_to_flat_hex(HEX_RADIUS, mousePos.sub(camera_offset));
    if (!new_pos_hovered.eql(pos_hovered) and pos_selected == null) {
        moves_shown.resize(0) catch unreachable;

        const tile = game_board.get(new_pos_hovered);
        if (tile != null and tile.? != null) {
            core.moves.getMovesForPieceAtLocation(game_board, new_pos_hovered, &moves_shown) catch unreachable;
        }
    }
    pos_hovered = new_pos_hovered;

    if (gamekit.input.mousePressed(.left)) {
        moves_shown.resize(0) catch unreachable;

        if (!std.meta.eql(pos_selected, pos_hovered)) {
            const tile = game_board.get(pos_hovered);
            if (tile != null and tile.? != null) {
                core.moves.getMovesForPieceAtLocation(game_board, pos_hovered, &moves_shown) catch unreachable;
                pos_selected = pos_hovered;
            } else {
                pos_selected = null;
            }
        } else {
            pos_selected = null;
        }
    }
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

        batcher.drawTex(math.Vec2{ .x = pcoords.x() - 16, .y = pcoords.y() - 14 }, 0xFFFFFFFF, texture);

        if (res.pos.eql(pos_hovered)) {
            batcher.drawTex(math.Vec2{ .x = pcoords.x() - 16, .y = pcoords.y() - 14 }, 0x88FFFFFF, textures[9]);
        }
    }

    if (pos_selected) |pos| {
        const pcoords = flat_hex_to_pixel(HEX_RADIUS, pos);
        const color = 0x88000000 | (@intCast(u32, COLOR_SELECTED.b) << 16) | (@intCast(u32, COLOR_SELECTED.g) << 8) | (@intCast(u32, COLOR_SELECTED.r));
        batcher.drawTex(math.Vec2{ .x = pcoords.x() - 16, .y = pcoords.y() - 14 }, color, textures[9]);
    }

    for (moves_shown.items) |move| {
        const move_pos = flat_hex_to_pixel(HEX_RADIUS, move.end_location);

        const move_color = if (move.piece.color == current_player) COLOR_MOVE else COLOR_MOVE_OTHER;
        const capture_color = if (move.piece.color == current_player) COLOR_CAPTURE else COLOR_CAPTURE_OTHER;

        const platform_color = if (std.meta.eql(move.captured_piece, move.end_location))
            capture_color
        else
            move_color;
        const color = 0x88000000 | (@intCast(u32, platform_color.b) << 16) | (@intCast(u32, platform_color.g) << 8) | (@intCast(u32, platform_color.r));

        batcher.drawTex(math.Vec2{ .x = move_pos.x() - 16, .y = move_pos.y() - 14 }, color, textures[9]);
    }

    board_iter = game_board.backwardsIterator();
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
    textures[9] = gfx.Texture.initFromFile(allocator, "assets/tile.png", .nearest) catch unreachable;
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
