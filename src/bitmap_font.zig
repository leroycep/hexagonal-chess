const std = @import("std");
const gamekit = @import("gamekit");
const gfx = gamekit.gfx;
const math = gamekit.math;

const ArrayList = std.ArrayList;

const util = @import("util");
const Vec2f = util.Vec2f;
const vec2f = util.vec2f;

pub const BitmapFont = struct {
    pages: []gfx.Texture,
    glyphs: std.AutoHashMap(u32, Glyph),
    lineHeight: f32,
    base: f32,
    scale: Vec2f,

    const Glyph = struct {
        page: u32,
        pos: Vec2f,
        size: Vec2f,
        offset: Vec2f,
        xadvance: f32,
    };

    pub fn initFromFile(allocator: *std.mem.Allocator, filename: [:0]const u8) !@This() {
        const contents = try gamekit.utils.fs.read(allocator, filename);
        defer allocator.free(contents);

        const base_path = std.fs.path.dirname(filename) orelse "./";

        var pages = ArrayList(gfx.Texture).init(allocator);
        var glyphs = std.AutoHashMap(u32, Glyph).init(allocator);
        var lineHeight: f32 = undefined;
        var base: f32 = undefined;
        var scaleW: f32 = 0;
        var scaleH: f32 = 0;
        var expected_num_pages: usize = 0;

        var line_iter = std.mem.tokenize(contents, "\n\r");
        while (line_iter.next()) |line| {
            var pair_iter = std.mem.tokenize(line, " \t");

            const kind = pair_iter.next() orelse continue;

            if (std.mem.eql(u8, "char", kind)) {
                var id: ?u32 = null;
                var x: f32 = undefined;
                var y: f32 = undefined;
                var width: f32 = undefined;
                var height: f32 = undefined;
                var xoffset: f32 = undefined;
                var yoffset: f32 = undefined;
                var xadvance: f32 = undefined;
                var page: u32 = undefined;

                while (pair_iter.next()) |pair| {
                    var kv_iter = std.mem.split(pair, "=");
                    const key = kv_iter.next().?;
                    const value = kv_iter.rest();

                    if (std.mem.eql(u8, "id", key)) {
                        id = try std.fmt.parseInt(u32, value, 10);
                    } else if (std.mem.eql(u8, "x", key)) {
                        x = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "y", key)) {
                        y = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "width", key)) {
                        width = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "height", key)) {
                        height = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "xoffset", key)) {
                        xoffset = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "yoffset", key)) {
                        yoffset = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "xadvance", key)) {
                        xadvance = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "page", key)) {
                        page = try std.fmt.parseInt(u32, value, 10);
                    } else if (std.mem.eql(u8, "chnl", key)) {
                        // TODO
                    } else {
                        std.log.warn("unknown pair for {} kind: {}", .{ kind, pair });
                    }
                }

                if (id == null) {
                    return error.InvalidFormat;
                }

                try glyphs.put(id.?, .{
                    .page = page,
                    .pos = vec2f(x, y),
                    .size = vec2f(width, height),
                    .offset = vec2f(xoffset, yoffset),
                    .xadvance = xadvance,
                });
            } else if (std.mem.eql(u8, "common", kind)) {
                while (pair_iter.next()) |pair| {
                    var kv_iter = std.mem.split(pair, "=");
                    const key = kv_iter.next().?;
                    const value = kv_iter.rest();

                    if (std.mem.eql(u8, "lineHeight", key)) {
                        lineHeight = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "base", key)) {
                        base = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "scaleW", key)) {
                        scaleW = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "scaleH", key)) {
                        scaleH = try std.fmt.parseFloat(f32, value);
                    } else if (std.mem.eql(u8, "packed", key)) {
                        // TODO
                    } else if (std.mem.eql(u8, "pages", key)) {
                        expected_num_pages = try std.fmt.parseInt(usize, value, 10);
                    } else {
                        std.log.warn("unknown pair for {} kind: {}", .{ kind, pair });
                    }
                }
            } else if (std.mem.eql(u8, "page", kind)) {
                var id: u32 = @intCast(u32, pages.items.len);
                var page_filename = try allocator.alloc(u8, 0);
                defer allocator.free(page_filename);

                while (pair_iter.next()) |pair| {
                    var kv_iter = std.mem.split(pair, "=");
                    const key = kv_iter.next().?;
                    const value = kv_iter.rest();

                    if (std.mem.eql(u8, "id", key)) {
                        id = try std.fmt.parseInt(u32, value, 10);
                    } else if (std.mem.eql(u8, "file", key)) {
                        const trimmed = std.mem.trim(u8, value, "\"");
                        page_filename = try std.fs.path.join(allocator, &[_][]const u8{ base_path, trimmed });
                    } else {
                        std.log.warn("unknown pair for {} kind: {}", .{ kind, pair });
                    }
                }

                try pages.resize(id + 1);
                pages.items[id] = try gfx.Texture.initFromFile(allocator, page_filename, .nearest);
            }
        }

        if (pages.items.len != expected_num_pages) {
            std.log.warn("Font pages expected {} != font pages found {}", .{ expected_num_pages, pages.items.len });
        }

        return @This(){
            .pages = pages.toOwnedSlice(),
            .glyphs = glyphs,
            .lineHeight = lineHeight,
            .base = base,
            .scale = vec2f(scaleW, scaleH),
        };
    }

    pub fn deinit(this: *@This()) void {
        this.glyphs.allocator.free(this.pages);
        this.glyphs.deinit();
    }

    const TextAlign = enum { Left, Right };
    const TextBaseline = enum { Bottom, Middle, Top };

    const DrawOptions = struct {
        textAlign: TextAlign = .Left,
        textBaseline: TextBaseline = .Bottom,
        color: math.Color = math.Color.white,
        scale: f32 = 1,
    };

    pub fn drawText(this: @This(), drawbatcher: *gfx.Batcher, text: []const u8, pos: Vec2f, options: DrawOptions) void {
        var x = pos.x;
        var y = switch (options.textBaseline) {
            .Top => pos.y - this.base - std.math.floor(this.lineHeight * options.scale / 2),
            .Bottom => pos.y + this.base + std.math.floor(this.lineHeight * options.scale / 2),
            .Middle => pos.y,
        };
        const direction: f32 = switch (options.textAlign) {
            .Left => 1,
            .Right => -1,
        };

        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            const char = switch (options.textAlign) {
                .Left => text[i],
                .Right => text[text.len - 1 - i],
            };
            if (this.glyphs.get(char)) |glyph| {
                const xadvance = (glyph.xadvance * options.scale);
                const texture = this.pages[glyph.page];
                const quad = math.Quad.init(glyph.pos.x, glyph.pos.y, glyph.size.x, glyph.size.y, this.scale.x, this.scale.y);

                const textAlignOffset = switch (options.textAlign) {
                    .Left => 0,
                    .Right => -xadvance,
                };

                const mat = math.Mat32.initTransform(.{
                    .x = x + glyph.offset.x + textAlignOffset,
                    .y = y + glyph.offset.y - glyph.size.y,
                    .sx = options.scale,
                    .sy = options.scale,
                });
                drawbatcher.draw(texture, quad, mat, options.color);

                x += direction * xadvance;
            }
        }
    }
};
