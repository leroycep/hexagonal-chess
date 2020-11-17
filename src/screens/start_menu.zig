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
        gfx.beginPass(.{ .color = math.Color.fromRgbBytes(0x88, 0x88, 0x88) });
        context.batcher.begin();
        context.font.drawText(&context.batcher, "Your Color", vec2f(600, 460), .{
            .color = math.Color.fromBytes(0x00, 0x00, 0x00, 0xFF),
            .textAlign = .Right,
            .textBaseline = .Middle,
            .scale = 2,
        });
        context.font.drawText(&context.batcher, "Turn", vec2f(600, 430), .{
            .color = math.Color.fromBytes(0x00, 0x00, 0x00, 0xFF),
            .textAlign = .Right,
            .textBaseline = .Middle,
            .scale = 2,
        });
        context.batcher.end();
        gfx.endPass();
    }
};
