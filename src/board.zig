const std = @import("std");
const platform = @import("./platform.zig");
const Vec2i = platform.Vec2i;

pub fn Board(comptime T: type, comptime side_len: comptime_int) type {
    return struct {
        tiles: [SIZE * SIZE]T,

        pub const SIDE_LEN = side_len;
        pub const SIZE = side_len * 2 - 1;

        const MIN_POS_SUM = side_len - 1;
        const MAX_POS_SUM = MIN_POS_SUM * 3;
        const ThisBoard = @This();

        pub fn init(filler: T) @This() {
            var this = @This(){
                .tiles = undefined,
            };
            std.mem.set(T, &this.tiles, filler);
            return this;
        }

        fn idx(this: @This(), pos: Vec2i) ?usize {
            if (pos.x() < 0 or pos.x() >= SIZE or pos.y() < 0 or pos.y() >= SIZE) {
                return null;
            }
            var q = @intCast(usize, pos.x());
            var r = @intCast(usize, pos.y());
            if (q + r < MIN_POS_SUM or q + r > MAX_POS_SUM) {
                return null;
            }
            return r * SIZE + q;
        }

        pub fn get(this: @This(), q: isize, r: isize) ?T {
            const i = this.idx(q, r) orelse return null;
            return this.tiles[i];
        }

        pub fn set(this: *@This(), q: usize, r: usize, value: T) void {
            const i = this.idx(q, r) orelse return;
            this.tiles[i] = value;
        }

        pub fn iterator(this: *@This()) Iterator {
            return .{
                .board = this,
                .pos = Vec2i.init(0, 0),
            };
        }

        const Iterator = struct {
            board: *ThisBoard,
            pos: Vec2i,

            const Result = struct {
                pos: Vec2i,
                tile: *T,
            };

            pub fn next(this: *@This()) ?Result {
                while (true) {
                    if (this.pos.y() > SIZE) return null;
                    defer {
                        this.pos.v[0] += 1;
                        if (this.pos.v[0] > SIZE) {
                            this.pos.v[0] = 0;
                            this.pos.v[1] += 1;
                        }
                    }

                    if (this.board.idx(this.pos)) |tile_idx| {
                        return Result{
                            .pos = this.pos,
                            .tile = &this.board.tiles[tile_idx],
                        };
                    }
                }
            }
        };
    };
}
