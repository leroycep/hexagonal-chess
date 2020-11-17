const std = @import("std");
const Allocator = std.mem.Allocator;
const BitmapFont = @import("../bitmap_font.zig").BitmapFont;
const gamekit = @import("gamekit");
const gfx = gamekit.gfx;

pub const StartMenu = @import("./start_menu.zig").StartMenu;
pub const MultiplayerInGame = @import("./multiplayer_in_game.zig").MultiplayerInGame;

pub const Context = struct {
    allocator: *Allocator,
    current_screen: Screen,
    new_screen: ?Screen,
    batcher: gfx.Batcher,
    font: BitmapFont,

    pub fn update(this: *@This()) !void {
        if (this.new_screen) |new_screen| {
            this.current_screen.deinit(this);
            
            this.current_screen = new_screen;
            this.new_screen = null;
            
            try this.current_screen.init(this);
        }
        try this.current_screen.update(this);
    }

    pub fn render(this: *@This()) !void {
        try this.current_screen.render(this);
    }
};

pub const Screen = union(enum) {
    StartMenu: StartMenu,
    MultiplayerInGame: MultiplayerInGame,

    pub fn init(this: *@This(), context: *Context) !void {
        inline for (std.meta.fields(@This())) |field| {
            if (this.* == @field(@TagType(@This()), field.name)) {
                return @field(this, field.name).init(context);
            }
        }
    }

    pub fn deinit(this: *@This(), context: *Context) void {
        inline for (std.meta.fields(@This())) |field| {
            if (this.* == @field(@TagType(@This()), field.name)) {
                return @field(this, field.name).deinit(context);
            }
        }
    }

    pub fn update(this: *@This(), context: *Context) !void {
        inline for (std.meta.fields(@This())) |field| {
            if (this.* == @field(@TagType(@This()), field.name)) {
                return @field(this, field.name).update(context);
            }
        }
    }

    pub fn render(this: *@This(), context: *Context) !void {
        inline for (std.meta.fields(@This())) |field| {
            if (this.* == @field(@TagType(@This()), field.name)) {
                return @field(this, field.name).render(context);
            }
        }
    }
};
