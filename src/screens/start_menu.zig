const std = @import("std");
const Context = @import("./screens.zig").Context;
const gamekit = @import("gamekit");
const gfx = gamekit.gfx;
const math = gamekit.math;
const util = @import("util");
const vec2f = util.vec2f;
const Vec2f = util.Vec2f;

pub const StartMenu = struct {
    server_address: std.ArrayList(u8) = undefined,

    pub fn init(this: *@This(), context: *Context) !void {
        this.server_address = std.ArrayList(u8).init(context.allocator);
    }

    pub fn deinit(this: *@This(), context: *Context) void {
        this.server_address.deinit();
    }

    pub fn update(this: *@This(), context: *Context) !void {
        if (gamekit.input.text_input != null) {
            try this.server_address.appendSlice(gamekit.input.text_input.?);
        }
        if (gamekit.input.keyPressed(.backspace)) {
            pop_utf8_codepoint(&this.server_address);
        }
        if (gamekit.input.keyPressed(.key_return)) {
            std.log.debug("Server Address: {}", .{this.server_address.items});
            context.new_screen = .{ .MultiplayerInGame = .{ .serverAddress = this.server_address.toOwnedSlice() } };
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
        context.font.drawText(&context.batcher, this.server_address.items, size.scaleDiv(2), .{
            .color = math.Color.fromBytes(0x00, 0x00, 0x00, 0xFF),
            .textAlign = .Center,
            .textBaseline = .Middle,
            .scale = 4,
        });
        context.batcher.end();
        gfx.endPass();
    }
};

fn pop_utf8_codepoint(string: *std.ArrayList(u8)) void {
    if (string.items.len == 0) return;
    var new_len = string.items.len - 1;
    while (new_len > 0 and !is_leading_utf8_byte(string.items[new_len])) : (new_len -= 1) {}
    string.shrink(new_len);
}

fn is_leading_utf8_byte(c: u8) bool {
    const first_bit_set = (c & 0x80) != 0;
    const second_bit_set = (c & 0x40) != 0;
    return !first_bit_set or second_bit_set;
}
