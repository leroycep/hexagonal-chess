const std = @import("std");
const Context = @import("./screens.zig").Context;
const net = @import("../net.zig");
const Sprite = @import("../sprite.zig").Sprite;
const core = @import("core");
const Board = core.Board;
usingnamespace @import("../hexagon.zig");
const ArrayList = std.ArrayList;
const gamekit = @import("gamekit");
const gfx = gamekit.gfx;
const math = gamekit.math;
const Allocator = std.mem.Allocator;

const util = @import("util");
const Vec2i = util.Vec2i;
const vec2i = util.vec2i;
const Vec2f = util.Vec2f;
const vec2f = util.vec2f;
const Vec3f = util.Vec3f;
const RGB = util.color.RGB;

const total_sprites = 10;
const HEX_RADIUS = 16;
const COLOR_SELECTED = RGB.from_hsluv(213.4, 92.2, 77.4).withAlpha(0x99);
const COLOR_MOVE = RGB.from_hsluv(131.4, 55.0, 54.2).withAlpha(0x99);
const COLOR_CAPTURE = RGB.from_hsluv(12.9, 55.0, 54.2).withAlpha(0x99);
const COLOR_MOVE_OTHER = COLOR_MOVE.withAlpha(0x44);
const COLOR_CAPTURE_OTHER = COLOR_CAPTURE.withAlpha(0x77);

pub const MultiplayerInGame = struct {
    serverAddress: []u8,
    allocator: *Allocator = undefined,
    socket: *net.FramesSocket = undefined,
    sprites: []Sprite = undefined,
    game: core.game.Game = undefined,
    clients_player: core.piece.Piece.Color = core.piece.Piece.Color.White,
    camera_offset: Vec2f = vec2f(0, 0),
    pos_hovered: Vec2i = vec2i(5, 5),
    pos_selected: ?Vec2i = null,
    moves_shown: ArrayList(core.moves.Move) = undefined,

    pub fn init(this: *@This(), context: *Context) !void {
        this.allocator = context.allocator;

        this.socket = try net.FramesSocket.init(this.allocator, this.serverAddress, @ptrToInt(this));
        this.socket.setOnMessage(onSocketMessage);

        this.loadTextures();

        this.game = core.game.Game.init(this.allocator);

        this.moves_shown = ArrayList(core.moves.Move).init(this.allocator);
    }

    pub fn deinit(this: *@This(), context: *Context) void {}

    pub fn update(this: *@This(), context: *Context) !void {
        net.update_sockets();

        const center_tile_pos = flat_hex_to_pixel(HEX_RADIUS, vec2i(5, 5));
        this.camera_offset = vec2f(320, 240).subv(center_tile_pos);

        const gk_mousePos = gamekit.input.mousePos();
        const mousePos = vec2f(gk_mousePos.x, gk_mousePos.y);
        const new_pos_hovered = pixel_to_flat_hex(HEX_RADIUS, mousePos.subv(this.camera_offset));
        if (!new_pos_hovered.eql(this.pos_hovered) and this.pos_selected == null) {
            this.moves_shown.shrinkRetainingCapacity(0);

            const tile = this.game.board.get(new_pos_hovered);
            if (tile != null and tile.? != null) {
                core.moves.getMovesForPieceAtLocation(this.game.board, new_pos_hovered, &this.moves_shown) catch unreachable;
            }
        }
        this.pos_hovered = new_pos_hovered;

        if (gamekit.input.mousePressed(.left)) {
            for (this.moves_shown.items) |shown_move| {
                if (shown_move.piece.color != this.game.currentPlayer) break;
                if (shown_move.piece.color != this.clients_player) break;
                if (shown_move.end_location.eql(this.pos_hovered)) {
                    const packet = core.protocol.ClientPacket{
                        .MovePiece = .{
                            .startPos = shown_move.start_location,
                            .endPos = shown_move.end_location,
                        },
                    };

                    var packet_data = ArrayList(u8).init(this.allocator);
                    defer packet_data.deinit();

                    try packet.stringify(packet_data.writer());

                    try this.socket.send(packet_data.items);
                    std.log.debug("Sending packet: {}", .{packet_data.items});

                    this.moves_shown.shrinkRetainingCapacity(0);
                    this.pos_selected = null;

                    return;
                }
            }

            this.moves_shown.shrinkRetainingCapacity(0);

            if (!std.meta.eql(this.pos_selected, this.pos_hovered)) {
                const tile = this.game.board.get(this.pos_hovered);
                if (tile != null and tile.? != null) {
                    core.moves.getMovesForPieceAtLocation(this.game.board, this.pos_hovered, &this.moves_shown) catch unreachable;
                    this.pos_selected = this.pos_hovered;
                } else {
                    this.pos_selected = null;
                }
            } else {
                this.pos_selected = null;
            }
        }
    }

    pub fn render(this: *@This(), context: *Context) !void {
        gfx.beginPass(.{
            .color = math.Color.fromRgbBytes(0x88, 0x88, 0x88),
            .trans_mat = math.Mat32.initTransform(.{
                .x = this.camera_offset.x,
                .y = this.camera_offset.y,
            }),
        });
        context.batcher.begin();

        var board_iter = this.game.board.iterator();
        while (board_iter.next()) |res| {
            const pcoords = flat_hex_to_pixel(HEX_RADIUS, res.pos);

            const sprite = this.sprites[@intCast(usize, @mod(res.pos.x + res.pos.y * Board.SIZE, 3))];

            sprite.draw(&context.batcher, pcoords, 0xFFFFFFFF);

            if (res.pos.eql(this.pos_hovered)) {
                this.sprites[9].draw(&context.batcher, pcoords, 0x88FFFFFF);
            }
        }

        if (this.pos_selected) |pos| {
            const pcoords = flat_hex_to_pixel(HEX_RADIUS, pos);
            const color = 0x88000000 | (@intCast(u32, COLOR_SELECTED.b) << 16) | (@intCast(u32, COLOR_SELECTED.g) << 8) | (@intCast(u32, COLOR_SELECTED.r));
            this.sprites[9].draw(&context.batcher, pcoords, color);
        }

        for (this.moves_shown.items) |move| {
            const move_pos = flat_hex_to_pixel(HEX_RADIUS, move.end_location);

            const move_color = if (move.piece.color == this.game.currentPlayer) COLOR_MOVE else COLOR_MOVE_OTHER;
            const capture_color = if (move.piece.color == this.game.currentPlayer) COLOR_CAPTURE else COLOR_CAPTURE_OTHER;

            const platform_color = if (move.captured_piece != null)
                capture_color
            else
                move_color;
            const color = 0x88000000 | (@intCast(u32, platform_color.b) << 16) | (@intCast(u32, platform_color.g) << 8) | (@intCast(u32, platform_color.r));

            this.sprites[9].draw(&context.batcher, move_pos, color);
        }

        board_iter = this.game.board.iterator();
        while (board_iter.next()) |res| {
            if (res.tile.* == null) continue;
            const tile = res.tile.*.?;

            const piece_pos = flat_hex_to_pixel(HEX_RADIUS, res.pos);
            const color: u32 = switch (tile.color) {
                .Black => 0xFF222222,
                .White => 0xFFFFFFFF,
            };
            const sprite = switch (tile.kind) {
                .Pawn => this.sprites[3],
                .Rook => this.sprites[4],
                .Bishop => this.sprites[5],
                .Knight => this.sprites[6],
                .Queen => this.sprites[7],
                .King => this.sprites[8],
            };

            sprite.draw(&context.batcher, piece_pos, color);
        }

        context.batcher.end();
        gfx.endPass();

        gfx.beginPass(.{ .color_action = .load });
        context.batcher.begin();

        // Draw captured pieces
        var captured_piece_pos = vec2f(16, 16);
        for (this.game.capturedPieces.white.items) |captured_piece| {
            const color: u32 = switch (captured_piece.color) {
                .Black => 0xFF222222,
                .White => 0xFFFFFFFF,
            };
            const sprite = switch (captured_piece.kind) {
                .Pawn => this.sprites[3],
                .Rook => this.sprites[4],
                .Bishop => this.sprites[5],
                .Knight => this.sprites[6],
                .Queen => this.sprites[7],
                .King => this.sprites[8],
            };

            sprite.draw(&context.batcher, captured_piece_pos, color);
            captured_piece_pos.x += 32;
        }
        captured_piece_pos = vec2f(16, 480 - 16);
        for (this.game.capturedPieces.black.items) |captured_piece| {
            const color: u32 = switch (captured_piece.color) {
                .Black => 0xFF222222,
                .White => 0xFFFFFFFF,
            };
            const sprite = switch (captured_piece.kind) {
                .Pawn => this.sprites[3],
                .Rook => this.sprites[4],
                .Bishop => this.sprites[5],
                .Knight => this.sprites[6],
                .Queen => this.sprites[7],
                .King => this.sprites[8],
            };

            sprite.draw(&context.batcher, captured_piece_pos, color);
            captured_piece_pos.x += 32;
        }

        // Draw turn indicators
        context.font.drawText(&context.batcher, "Your Color", vec2f(600, 460), .{
            .color = math.Color.fromBytes(0x00, 0x00, 0x00, 0xFF),
            .textAlign = .Right,
            .textBaseline = .Middle,
            .scale = 2,
        });
        this.sprites[9].draw(&context.batcher, vec2f(620, 460), switch (this.clients_player) {
            .White => 0xFFFFFFFF,
            .Black => 0xFF000000,
        });
        context.font.drawText(&context.batcher, "Turn", vec2f(600, 430), .{
            .color = math.Color.fromBytes(0x00, 0x00, 0x00, 0xFF),
            .textAlign = .Right,
            .textBaseline = .Middle,
            .scale = 2,
        });
        this.sprites[9].draw(&context.batcher, vec2f(620, 430), switch (this.game.currentPlayer) {
            .White => 0xFFFFFFFF,
            .Black => 0xFF000000,
        });
        context.batcher.end();
        gfx.endPass();
    }

    fn loadTextures(this: *@This()) void {
        this.sprites = this.allocator.alloc(Sprite, total_sprites) catch unreachable;

        this.sprites[0] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/tile0.png", .nearest) catch unreachable,
            .offset = vec2f(16, 14),
        };
        this.sprites[1] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/tile1.png", .nearest) catch unreachable,
            .offset = vec2f(16, 14),
        };
        this.sprites[2] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/tile2.png", .nearest) catch unreachable,
            .offset = vec2f(16, 14),
        };
        this.sprites[3] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/pawn.png", .nearest) catch unreachable,
            .offset = vec2f(9, 25 - 6),
        };
        this.sprites[4] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/rook.png", .nearest) catch unreachable,
            .offset = vec2f(11, 30 - 9),
        };
        this.sprites[5] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/bishop.png", .nearest) catch unreachable,
            .offset = vec2f(9, 36 - 6),
        };
        this.sprites[6] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/knight.png", .nearest) catch unreachable,
            .offset = vec2f(9, 27 - 6),
        };
        this.sprites[7] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/queen.png", .nearest) catch unreachable,
            .offset = vec2f(9, 32 - 6),
        };
        this.sprites[8] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/king.png", .nearest) catch unreachable,
            .offset = vec2f(11, 34 - 6),
        };
        this.sprites[9] = .{
            .texture = gfx.Texture.initFromFile(this.allocator, "assets/tile.png", .nearest) catch unreachable,
            .offset = vec2f(16, 14),
        };
    }
};

pub fn onSocketMessage(_socket: *net.FramesSocket, user_data: usize, message: []const u8) void {
    const this = @intToPtr(*MultiplayerInGame, user_data);

    const packet = core.protocol.ServerPacket.parse(this.allocator, message) catch |e| {
        std.log.err("Could not read packet: {}", .{e});
        return;
    };
    defer packet.parseFree(this.allocator);
    switch (packet) {
        .Init => |init_data| this.clients_player = init_data.color,
        .BoardUpdate => |board_update| {
            this.game.board = Board.deserialize(board_update);
            this.pos_selected = null;
            this.moves_shown.shrinkRetainingCapacity(0);
        },
        .TurnChange => |turn_change| this.game.currentPlayer = turn_change,
        .CapturedPiecesUpdate => |pieces_update| {
            this.game.capturedPieces.white.shrinkRetainingCapacity(0);
            this.game.capturedPieces.white.appendSlice(pieces_update.white) catch unreachable;
            this.game.capturedPieces.black.shrinkRetainingCapacity(0);
            this.game.capturedPieces.black.appendSlice(pieces_update.black) catch unreachable;
        },
        else => {},
    }
}
