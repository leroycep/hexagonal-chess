const std = @import("std");
const ArrayList = std.ArrayList;
const platform = @import("./platform.zig");
const Vec2i = platform.Vec2i;
const vec2i = platform.vec2i;
const Piece = @import("./piece.zig").Piece;
const Board = @import("./board.zig").Board(?Piece, 6);

pub const Move = struct {
    // Where the piece will end up
    end_location: Vec2i,

    // The state of the piece after moving ot end location
    end_piece: Piece,

    // The location of the piece that will be captured, if any
    captured_piece: ?Vec2i,
};

pub fn getMovesForPieceAtLocation(board: Board, piece_location: Vec2i, possible_moves: *ArrayList(Move)) !void {
    const piece = board.get(piece_location) orelse return orelse return;

    switch (piece.kind) {
        .Pawn => {
            // TODO: account for promotion tiles
            const possible_attacks = switch (piece.color) {
                .Black => [2]Vec2i{ vec2i(-1, 0), vec2i(1, -1) },
                .White => [2]Vec2i{ vec2i(1, 0), vec2i(-1, 1) },
            };
            for (possible_attacks) |attack_location| {
                const tile = board.get(attack_location);
                if (tile == null) continue;
                if (tile.? == null) continue;
                if (tile.?.?.color == piece.color) continue;
                try possible_moves.append(.{
                    .end_location = attack_location,
                    .end_piece = piece.withOneMoreMove(),
                    .captured_piece = attack_location,
                });
            }

            const direction = switch (piece.color) {
                .Black => vec2i(0, 1),
                .White => vec2i(0, -1),
            };
            const one_forward = piece_location.add(direction);
            const tile_one_forward = board.get(one_forward);

            // Pawn can move forward if there is no one in front of them
            if (tile_one_forward == null or tile_one_forward.? != null) return;
            try possible_moves.append(.{
                .end_location = one_forward,
                .end_piece = piece.withOneMoreMove(),
                .captured_piece = null,
            });

            // Pawn can move two forward if it is their first move (and if they could move
            // forward one)
            if (piece.numMoves > 0) return;
            const two_forward = piece_location.add(direction.scalMul(2));
            const tile_two_forward = board.get(two_forward);
            if (tile_one_forward == null or tile_two_forward.? != null) return;
            // TODO: inform nearby opponent pawns that they can perform 'en passant'
            try possible_moves.append(.{
                .end_location = two_forward,
                .end_piece = piece.withOneMoreMove(),
                .captured_piece = null,
            });
        },
        .Rook => {
            try straightLineMoves(board, piece_location, &[6]Vec2i{
                vec2i(0, -1),
                vec2i(1, -1),
                vec2i(1, 0),
                vec2i(0, 1),
                vec2i(-1, 1),
                vec2i(-1, 0),
            }, 100, possible_moves);
        },
        .Bishop => {
            try straightLineMoves(board, piece_location, &[6]Vec2i{
                vec2i(1, -2),
                vec2i(2, -1),
                vec2i(1, 1),
                vec2i(-1, 2),
                vec2i(-2, 1),
                vec2i(-1, -1),
            }, 100, possible_moves);
        },
        .Queen => {
            try straightLineMoves(board, piece_location, &[12]Vec2i{
                // Rook moves
                vec2i(0, -1),
                vec2i(1, -1),
                vec2i(1, 0),
                vec2i(0, 1),
                vec2i(-1, 1),
                vec2i(-1, 0),
                // Bishop moves
                vec2i(1, -2),
                vec2i(2, -1),
                vec2i(1, 1),
                vec2i(-1, 2),
                vec2i(-2, 1),
                vec2i(-1, -1),
            }, 100, possible_moves);
        },
        .King => {
            try straightLineMoves(board, piece_location, &[12]Vec2i{
                // Rook moves
                vec2i(0, -1),
                vec2i(1, -1),
                vec2i(1, 0),
                vec2i(0, 1),
                vec2i(-1, 1),
                vec2i(-1, 0),
                // Bishop moves
                vec2i(1, -2),
                vec2i(2, -1),
                vec2i(1, 1),
                vec2i(-1, 2),
                vec2i(-2, 1),
                vec2i(-1, -1),
            }, 1, possible_moves);
        },
        .Knight => {
            const knight_possible_moves = [_]Vec2i{
                vec2i(1, -3),
                vec2i(2, -3),
                vec2i(3, -2),
                vec2i(3, -1),
                vec2i(2, 1),
                vec2i(1, 2),
                vec2i(-1, 3),
                vec2i(-2, 3),
                vec2i(-3, 1),
                vec2i(-3, 2),
                vec2i(-2, -1),
                vec2i(-1, -2),
            };

            for (knight_possible_moves) |move_offset| {
                const move_location = piece_location.add(move_offset);
                const tile = board.get(move_location) orelse continue;
                if (tile) |other_piece| {
                    if (other_piece.color == piece.color) continue;
                    // Capture other piece
                    try possible_moves.append(.{
                        .end_location = move_location,
                        .end_piece = piece.withOneMoreMove(),
                        .captured_piece = move_location,
                    });
                } else {
                    try possible_moves.append(.{
                        .end_location = move_location,
                        .end_piece = piece.withOneMoreMove(),
                        .captured_piece = null,
                    });
                }
            }
        },
    }
}

fn straightLineMoves(board: Board, piece_location: Vec2i, directions: []const Vec2i, max_distance: usize, possible_moves: *ArrayList(Move)) !void {
    const piece = board.get(piece_location) orelse return orelse return;

    for (directions) |direction| {
        var current_location = piece_location.add(direction);
        var distance: usize = 0;
        while (board.get(current_location)) |tile| : (current_location = current_location.add(direction)) {
            defer distance += 1;
            if (distance >= max_distance) break;

            if (tile) |other_piece| {
                if (other_piece.color != piece.color) {
                    // Capture other piece
                    try possible_moves.append(.{
                        .end_location = current_location,
                        .end_piece = piece.withOneMoreMove(),
                        .captured_piece = current_location,
                    });
                }
                break;
            } else {
                try possible_moves.append(.{
                    .end_location = current_location,
                    .end_piece = piece.withOneMoreMove(),
                    .captured_piece = null,
                });
            }
        }
    }
}
