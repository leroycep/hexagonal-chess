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
        else => {},
    }
}
