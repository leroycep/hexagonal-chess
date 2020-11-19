const std = @import("std");
const gamekit = @import("gamekit");
const gfx = gamekit.gfx;
const math = gamekit.math;
const core = @import("core");
const Board = core.Board;
const util = @import("util");
const BitmapFont = @import("./bitmap_font.zig").BitmapFont;

const max_sprites_per_batch = 1000;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = &gpa.allocator;

const Context = @import("./screens/screens.zig").Context;

var screen_context: Context = undefined;

pub fn main() !void {
    try gamekit.run(.{
        .init = init,
        .shutdown = shutdown,
        .update = update,
        .render = render,
        .window = .{ .title = "Hex Chess", .resizable = false, .width = 640, .height = 480 },
    });
}

fn init() !void {
    screen_context = .{
        .allocator = allocator,
        .current_screen = .{ .StartMenu = .{} },
        .new_screen = null,
        .batcher = gfx.Batcher.init(allocator, max_sprites_per_batch),
        .font = try BitmapFont.initFromFile(allocator, "assets/PressStart2P_8.fnt"),
    };
    try screen_context.current_screen.init(&screen_context);
}

fn shutdown() !void {
    screen_context.current_screen.deinit(&screen_context);
    _ = gpa.deinit();
}

fn update() !void {
    try screen_context.update();
}

fn render() !void {
    try screen_context.render();
}
