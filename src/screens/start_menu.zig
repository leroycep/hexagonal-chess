const Context = @import("./screens.zig").Context;
const gamekit = @import("gamekit");
const gfx = gamekit.gfx;
const math = gamekit.math;
const util = @import("util");
const vec2f = util.vec2f;

pub const StartMenu = struct {
    pub fn init(this: *@This(), context: *Context) !void {}

    pub fn deinit(this: *@This(), context: *Context) void {}

    pub fn update(this: *@This(), context: *Context) !void {
        if (gamekit.input.keyPressed(.space)) {
            context.new_screen = .{ .MultiplayerInGame = .{} };
        }
    }

    pub fn render(this: *@This(), context: *Context) !void {
        const size_sdl_vec = gamekit.window.size();
        const size = util.vec2i(size_sdl_vec.w, size_sdl_vec.h).intToFloat(f32);

        gfx.beginPass(.{ .color = math.Color.fromRgbBytes(0x88, 0x88, 0x88) });
        context.batcher.begin();
        context.font.drawText(&context.batcher, "Hex Chess", vec2f(size.x / 2, 10), .{
            .color = math.Color.fromBytes(0x00, 0x00, 0x00, 0xFF),
            .textAlign = .Center,
            .textBaseline = .Top,
            .scale = 8,
        });
        context.batcher.end();
        gfx.endPass();
    }
};
