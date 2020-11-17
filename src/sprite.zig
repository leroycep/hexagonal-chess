const gamekit = @import("gamekit");
const gfx = gamekit.gfx;
const math = gamekit.math;
const util = @import("util");
const Vec2f = util.Vec2f;

pub const Sprite = struct {
    texture: gfx.Texture,
    offset: Vec2f,

    pub fn draw(this: @This(), drawbatcher: *gfx.Batcher, pos: Vec2f, color: u32) void {
        const dpos = pos.subv(this.offset);
        drawbatcher.drawTex(math.Vec2{ .x = dpos.x, .y = dpos.y }, color, this.texture);
    }
};
