const std = @import("std");
const gamekit = @import("gamekit");
const gfx = gamekit.gfx;
const math = gamekit.math;
const core = @import("core");
const Board = core.Board;
const util = @import("util");
const net = @import("./net.zig");

const ArrayList = std.ArrayList;
const Vec2i = util.Vec2i;
const vec2i = util.vec2i;
const Vec2f = util.Vec2f;
const vec2f = util.vec2f;
const Vec3f = util.Vec3f;
const RGB = util.color.RGB;

const total_sprites = 10;
const max_sprites_per_batch = 1000;
const HEX_RADIUS = 16;
const COLOR_SELECTED = RGB.from_hsluv(213.4, 92.2, 77.4).withAlpha(0x99);
const COLOR_MOVE = RGB.from_hsluv(131.4, 55.0, 54.2).withAlpha(0x99);
const COLOR_CAPTURE = RGB.from_hsluv(12.9, 55.0, 54.2).withAlpha(0x99);
const COLOR_MOVE_OTHER = COLOR_MOVE.withAlpha(0x44);
const COLOR_CAPTURE_OTHER = COLOR_CAPTURE.withAlpha(0x77);

var socket: *net.FramesSocket = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;
var batcher: gfx.Batcher = undefined;
var sprites: []Sprite = undefined;
var game_board = Board.init(null);
var camera_offset = vec2f(0, 0);
var pos_hovered = vec2i(5, 5);
var pos_selected: ?Vec2i = null;
var moves_shown: ArrayList(core.moves.Move) = undefined;
var current_player = core.piece.Piece.Color.White;
var clients_player = core.piece.Piece.Color.White;
var font: BitmapFont = undefined;

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
    socket = try net.FramesSocket.init(allocator, localhost);
    socket.setOnMessage(onSocketMessage);

    batcher = gfx.Batcher.init(allocator, max_sprites_per_batch);

    loadTextures();
    font = BitmapFont.initFromFile(allocator, "assets/PressStart2P_16.fnt") catch unreachable;

    moves_shown = ArrayList(core.moves.Move).init(allocator);
}

fn shutdown() !void {
    _ = gpa.deinit();
}

pub fn onSocketMessage(_socket: *net.FramesSocket, message: []const u8) void {
    const packet = core.protocol.ServerPacket.parse(message) catch |e| {
        std.log.err("Could not read packet: {}", .{e});
        return;
    };
    switch (packet) {
        .Init => |init_data| clients_player = init_data.color,
        .BoardUpdate => |board_update| {
            game_board = Board.deserialize(board_update);
            pos_selected = null;
            moves_shown.shrinkRetainingCapacity(0);
        },
        .TurnChange => |turn_change| current_player = turn_change,
        else => {},
    }
}

fn update() !void {
    net.update_sockets();

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
        for (moves_shown.items) |shown_move| {
            if (shown_move.piece.color != current_player) break;
            if (shown_move.piece.color != clients_player) break;
            if (shown_move.end_location.eql(pos_hovered)) {
                const packet = core.protocol.ClientPacket{
                    .MovePiece = .{
                        .startPos = shown_move.start_location,
                        .endPos = shown_move.end_location,
                    },
                };

                var packet_data = ArrayList(u8).init(allocator);
                defer packet_data.deinit();

                packet.stringify(packet_data.writer()) catch unreachable;

                socket.send(packet_data.items) catch unreachable;
                std.log.debug("Sending packet: {}", .{packet_data.items});

                moves_shown.shrinkRetainingCapacity(0);
                pos_selected = null;

                return;
            }
        }

        moves_shown.shrinkRetainingCapacity(0);

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

        const sprite = sprites[@intCast(usize, @mod(res.pos.x() + res.pos.y() * Board.SIZE, 3))];

        sprite.draw(&batcher, pcoords, 0xFFFFFFFF);

        if (res.pos.eql(pos_hovered)) {
            sprites[9].draw(&batcher, pcoords, 0x88FFFFFF);
        }
    }

    if (pos_selected) |pos| {
        const pcoords = flat_hex_to_pixel(HEX_RADIUS, pos);
        const color = 0x88000000 | (@intCast(u32, COLOR_SELECTED.b) << 16) | (@intCast(u32, COLOR_SELECTED.g) << 8) | (@intCast(u32, COLOR_SELECTED.r));
        sprites[9].draw(&batcher, pcoords, color);
    }

    for (moves_shown.items) |move| {
        const move_pos = flat_hex_to_pixel(HEX_RADIUS, move.end_location);

        const move_color = if (move.piece.color == current_player) COLOR_MOVE else COLOR_MOVE_OTHER;
        const capture_color = if (move.piece.color == current_player) COLOR_CAPTURE else COLOR_CAPTURE_OTHER;

        const platform_color = if (move.captured_piece != null)
            capture_color
        else
            move_color;
        const color = 0x88000000 | (@intCast(u32, platform_color.b) << 16) | (@intCast(u32, platform_color.g) << 8) | (@intCast(u32, platform_color.r));

        sprites[9].draw(&batcher, move_pos, color);
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
        const sprite = switch (tile.kind) {
            .Pawn => sprites[3],
            .Rook => sprites[4],
            .Bishop => sprites[5],
            .Knight => sprites[6],
            .Queen => sprites[7],
            .King => sprites[8],
        };

        sprite.draw(&batcher, piece_pos, color);
    }

    batcher.end();
    gfx.endPass();

    gfx.beginPass(.{ .color_action = .load });
    batcher.begin();
    font.drawText(&batcher, "Your Color", vec2f(600, 460), .{
        .color = math.Color.fromBytes(0x00, 0x00, 0x00, 0xFF),
        .textAlign = .Right,
        .textBaseline = .Middle,
    });
    sprites[9].draw(&batcher, vec2f(620, 460), switch (clients_player) {
        .White => 0xFFFFFFFF,
        .Black => 0xFF000000,
    });
    font.drawText(&batcher, "Turn", vec2f(600, 430), .{
        .color = math.Color.fromBytes(0x00, 0x00, 0x00, 0xFF),
        .textAlign = .Right,
        .textBaseline = .Middle,
    });
    sprites[9].draw(&batcher, vec2f(620, 430), switch (current_player) {
        .White => 0xFFFFFFFF,
        .Black => 0xFF000000,
    });
    batcher.end();
    gfx.endPass();
}

const Sprite = struct {
    texture: gfx.Texture,
    offset: Vec2f,

    pub fn draw(this: @This(), drawbatcher: *gfx.Batcher, pos: Vec2f, color: u32) void {
        const dpos = pos.sub(this.offset);
        drawbatcher.drawTex(math.Vec2{ .x = dpos.x(), .y = dpos.y() }, color, this.texture);
    }
};

fn loadTextures() void {
    sprites = allocator.alloc(Sprite, total_sprites) catch unreachable;

    sprites[0] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/tile0.png", .nearest) catch unreachable,
        .offset = vec2f(16, 14),
    };
    sprites[1] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/tile1.png", .nearest) catch unreachable,
        .offset = vec2f(16, 14),
    };
    sprites[2] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/tile2.png", .nearest) catch unreachable,
        .offset = vec2f(16, 14),
    };
    sprites[3] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/pawn.png", .nearest) catch unreachable,
        .offset = vec2f(9, 6),
    };
    sprites[4] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/rook.png", .nearest) catch unreachable,
        .offset = vec2f(11, 9),
    };
    sprites[5] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/bishop.png", .nearest) catch unreachable,
        .offset = vec2f(9, 6),
    };
    sprites[6] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/knight.png", .nearest) catch unreachable,
        .offset = vec2f(9, 6),
    };
    sprites[7] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/queen.png", .nearest) catch unreachable,
        .offset = vec2f(9, 6),
    };
    sprites[8] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/king.png", .nearest) catch unreachable,
        .offset = vec2f(11, 6),
    };
    sprites[9] = .{
        .texture = gfx.Texture.initFromFile(allocator, "assets/tile.png", .nearest) catch unreachable,
        .offset = vec2f(16, 14),
    };
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

const BitmapFont = struct {
    pages: []gfx.Texture,
    glyphs: std.AutoHashMap(u32, Glyph),
    lineHeight: f32,
    base: f32,
    scale: Vec2f,

    const Glyph = struct {
        page: u32,
        pos: Vec2f,
        size: Vec2f,
        offset: Vec2f,
        xadvance: f32,
    };

    fn initFromFile(alloc: *std.mem.Allocator, filename: [:0]const u8) !@This() {
        const contents = try gamekit.utils.fs.read(alloc, filename);
        defer alloc.free(contents);

        const base_path = std.fs.path.dirname(filename) orelse "./";

        var pages = ArrayList(gfx.Texture).init(alloc);
        var glyphs = std.AutoHashMap(u32, Glyph).init(alloc);
        var lineHeight: f32 = undefined;
        var base: f32 = undefined;
        var scaleW: f32 = 0;
        var scaleH: f32 = 0;
        var expected_num_pages: usize = 0;

        var line_iter = std.mem.tokenize(contents, "\n\r");
        while (line_iter.next()) |line| {
            var pair_iter = std.mem.tokenize(line, " \t");

            const kind = pair_iter.next() orelse continue;

            if (std.mem.eql(u8, "char", kind)) {
                var id: ?u32 = null;
                var x: f32 = undefined;
                var y: f32 = undefined;
                var width: f32 = undefined;
                var height: f32 = undefined;
                var xoffset: f32 = undefined;
                var yoffset: f32 = undefined;
                var xadvance: f32 = undefined;
                var page: u32 = undefined;

                while (pair_iter.next()) |pair| {
                    var kv_iter = std.mem.split(pair, "=");
                    const key = kv_iter.next().?;
                    const value = kv_iter.rest();

                    if (std.mem.eql(u8, "id", key)) {
                        id = try std.fmt.parseInt(u32, value, 10);
                    } else if (std.mem.eql(u8, "x", key)) {
                        x = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "y", key)) {
                        y = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "width", key)) {
                        width = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "height", key)) {
                        height = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "xoffset", key)) {
                        xoffset = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "yoffset", key)) {
                        yoffset = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "xadvance", key)) {
                        xadvance = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "page", key)) {
                        page = try std.fmt.parseInt(u32, value, 10);
                    } else if (std.mem.eql(u8, "chnl", key)) {
                        // TODO
                    } else {
                        std.log.warn("unknown pair for {} kind: {}", .{ kind, pair });
                    }
                }

                if (id == null) {
                    return error.InvalidFormat;
                }

                try glyphs.put(id.?, .{
                    .page = page,
                    .pos = vec2f(x, y),
                    .size = vec2f(width, height),
                    .offset = vec2f(xoffset, yoffset),
                    .xadvance = xadvance,
                });
            } else if (std.mem.eql(u8, "common", kind)) {
                while (pair_iter.next()) |pair| {
                    var kv_iter = std.mem.split(pair, "=");
                    const key = kv_iter.next().?;
                    const value = kv_iter.rest();

                    if (std.mem.eql(u8, "lineHeight", key)) {
                        lineHeight = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "base", key)) {
                        base = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "scaleW", key)) {
                        scaleW = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "scaleH", key)) {
                        scaleH = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "packed", key)) {
                        // TODO
                    } else if (std.mem.eql(u8, "pages", key)) {
                        expected_num_pages = try std.fmt.parseInt(usize, value, 10);
                    } else {
                        std.log.warn("unknown pair for {} kind: {}", .{ kind, pair });
                    }
                }
            } else if (std.mem.eql(u8, "page", kind)) {
                var id: u32 = @intCast(u32, pages.items.len);
                var page_filename = try alloc.alloc(u8, 0);
                defer alloc.free(page_filename);

                while (pair_iter.next()) |pair| {
                    var kv_iter = std.mem.split(pair, "=");
                    const key = kv_iter.next().?;
                    const value = kv_iter.rest();

                    if (std.mem.eql(u8, "id", key)) {
                        id = try std.fmt.parseInt(u32, value, 10);
                    } else if (std.mem.eql(u8, "file", key)) {
                        const trimmed = std.mem.trim(u8, value, "\"");
                        page_filename = try std.fs.path.join(alloc, &[_][]const u8{ base_path, trimmed });
                    } else {
                        std.log.warn("unknown pair for {} kind: {}", .{ kind, pair });
                    }
                }

                try pages.resize(id + 1);
                pages.items[id] = try gfx.Texture.initFromFile(allocator, page_filename, .nearest);
            }
        }

        if (pages.items.len != expected_num_pages) {
            std.log.warn("Font pages expected {} != font pages found {}", .{ expected_num_pages, pages.items.len });
        }

        return @This(){
            .pages = pages.toOwnedSlice(),
            .glyphs = glyphs,
            .lineHeight = lineHeight,
            .base = base,
            .scale = vec2f(scaleW, scaleH),
        };
    }

    pub fn deinit(this: *@This()) void {
        this.glyphs.allocator.free(this.pages);
        this.glyphs.deinit();
    }

    const TextAlign = enum { Left, Right };
    const TextBaseline = enum { Bottom, Middle };

    const DrawOptions = struct {
        textAlign: TextAlign = .Left,
        textBaseline: TextBaseline = .Bottom,
        color: math.Color = math.Color.white,
        scale: f32 = 1,
    };

    pub fn drawText(this: @This(), drawbatcher: *gfx.Batcher, text: []const u8, pos: Vec2f, options: DrawOptions) void {
        var x = pos.x();
        var y = switch (options.textBaseline) {
            .Bottom => pos.y(),
            .Middle => pos.y() - this.base - std.math.floor(this.lineHeight * options.scale / 2),
        };
        const direction: f32 = switch (options.textAlign) {
            .Left => 1,
            .Right => -1,
        };

        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            const char = switch (options.textAlign) {
                .Left => text[i],
                .Right => text[text.len - 1 - i],
            };
            if (this.glyphs.get(char)) |glyph| {
                const xadvance = (glyph.xadvance * options.scale);
                const texture = this.pages[glyph.page];
                const quad = math.Quad.init(glyph.pos.x(), glyph.pos.y(), glyph.size.x(), glyph.size.y(), this.scale.x(), this.scale.y());

                const textAlignOffset = switch (options.textAlign) {
                    .Left => 0,
                    .Right => -xadvance,
                };

                const mat = math.Mat32.initTransform(.{
                    .x = x + glyph.offset.x() + textAlignOffset,
                    .y = y + glyph.size.y() + glyph.offset.y(),
                    .sx = options.scale,
                    .sy = options.scale,
                });
                drawbatcher.draw(texture, quad, mat, options.color);

                x += direction * xadvance;
            }
        }
    }
};
