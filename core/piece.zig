const util = @import("util");
const Vec2i = util.Vec2i;

pub const Piece = struct {
    kind: Kind,
    color: Color,

    numMoves: u32 = 0,
    enPassant: ?Vec2i = null,

    pub const Kind = enum {
        Pawn,
        Rook,
        Knight,
        Bishop,
        Queen,
        King,
    };

    pub const Color = enum {
        Black,
        White,
    };

    pub fn withOneMoreMove(this: @This()) @This() {
        return .{
            .kind = this.kind,
            .color = this.color,
            .numMoves = this.numMoves + 1,
        };
    }

    pub fn updateEndOfTurn(this: *@This(), player: Color) void {
        if (player == this.color) {
            this.enPassant = null;
        }
    }
};
