pub fn Board(comptime T: type, comptime S: comptime_int) type {
    return struct {
        tiles: [S * S]T,

        pub const SIZE = S;

        pub fn init(filler: T) @This() {
            var this = @This(){
                .tiles = undefined,
            };
            std.mem.fill(T, this.tiles, filler);
            return this;
        }

        fn idx(this: @This(), q: usize, r: usize) usize {
            return r * S + q;
        }
        
        pub fn get(this: @This(), q: usize, r: usize) T {
            const i = this.idx(q, r);
            return this.tiles[i];
        }

        pub fn set(this: *@This(), q: usize, r: usize, value: T) void {
            this.tiles[this.idx(q, r)] = value;
        }
    };
}
