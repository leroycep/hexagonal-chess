const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");
const Vec3f = platform.Vec3f;
const Vec2f = platform.Vec2f;
const vec2f = platform.vec2f;
const Vec2i = platform.Vec2i;
const vec2i = platform.vec2i;
const pi = std.math.pi;
const OBB = collision.OBB;
const board = @import("./board.zig");
const ArrayList = std.ArrayList;

const DEG_TO_RAD = std.math.pi / 180.0;

const VERT_CODE =
    \\ #version 300 es
    \\
    \\ in highp vec2 coordinates;
    \\ in lowp vec3 color;
    \\
    \\ out vec3 vertexColor;
    \\
    \\ uniform mat4 projectionMatrix;
    \\
    \\ void main(void) {
    \\   gl_Position = vec4(coordinates, 0.0, 1.0);
    \\   gl_Position *= projectionMatrix;
    \\   vertexColor = color;
    \\ }
;

const FRAG_CODE =
    \\ #version 300 es
    \\
    \\ in lowp vec3 vertexColor;
    \\
    \\ out lowp vec4 FragColor;
    \\
    \\ void main(void) {
    \\   FragColor = vec4(vertexColor, 1.0);
    \\ }
;

const Piece = struct {
    kind: Kind,
    color: Color,

    const Kind = enum {
        Pawn,
        Rook,
        Knight,
        Bishop,
        Queen,
        King,
    };

    const Color = enum {
        Black,
        White,
    };
};

const Board = board.Board(?Piece, 6);

var shaderProgram: platform.GLuint = undefined;
var boardBackgroundMesh: Mesh = undefined;
var projectionMatrixUniform: platform.GLint = undefined;
var renderer: platform.renderer.Renderer = undefined;
var mouse_pos = vec2f(100, 100);
var game_board = Board.init(null);
var translation = vec2f(150, -30);

pub fn onInit(context: *platform.Context) void {
    var vertShader = platform.glCreateShader(platform.GL_VERTEX_SHADER);
    platform.glShaderSource(vertShader, VERT_CODE);
    platform.glCompileShader(vertShader);

    var fragShader = platform.glCreateShader(platform.GL_FRAGMENT_SHADER);
    platform.glShaderSource(fragShader, FRAG_CODE);
    platform.glCompileShader(fragShader);

    shaderProgram = platform.glCreateProgram();
    platform.glAttachShader(shaderProgram, vertShader);
    platform.glAttachShader(shaderProgram, fragShader);
    platform.glLinkProgram(shaderProgram);
    platform.glUseProgram(shaderProgram);

    // Set up VAO
    boardBackgroundMesh = genBoardTileBackgroundVAO(context.alloc, shaderProgram) catch unreachable;

    projectionMatrixUniform = platform.glGetUniformLocation(shaderProgram, "projectionMatrix");

    renderer = platform.renderer.Renderer.init();

    game_board.set(vec2i(1, 4), Piece{ .kind = .Pawn, .color = .Black });
    game_board.set(vec2i(2, 4), Piece{ .kind = .Pawn, .color = .Black });
    game_board.set(vec2i(3, 4), Piece{ .kind = .Pawn, .color = .Black });
    game_board.set(vec2i(4, 4), Piece{ .kind = .Pawn, .color = .Black });
    game_board.set(vec2i(5, 4), Piece{ .kind = .Pawn, .color = .Black });
    game_board.set(vec2i(6, 3), Piece{ .kind = .Pawn, .color = .Black });
    game_board.set(vec2i(7, 2), Piece{ .kind = .Pawn, .color = .Black });
    game_board.set(vec2i(8, 1), Piece{ .kind = .Pawn, .color = .Black });
    game_board.set(vec2i(9, 0), Piece{ .kind = .Pawn, .color = .Black });
    game_board.set(vec2i(2, 3), Piece{ .kind = .Rook, .color = .Black });
    game_board.set(vec2i(3, 2), Piece{ .kind = .Knight, .color = .Black });
    game_board.set(vec2i(4, 1), Piece{ .kind = .Queen, .color = .Black });
    game_board.set(vec2i(5, 0), Piece{ .kind = .Bishop, .color = .Black });
    game_board.set(vec2i(5, 1), Piece{ .kind = .Bishop, .color = .Black });
    game_board.set(vec2i(5, 2), Piece{ .kind = .Bishop, .color = .Black });
    game_board.set(vec2i(6, 0), Piece{ .kind = .King, .color = .Black });
    game_board.set(vec2i(7, 0), Piece{ .kind = .Knight, .color = .Black });
    game_board.set(vec2i(8, 0), Piece{ .kind = .Rook, .color = .Black });

    game_board.set(vec2i(1, 10), Piece{ .kind = .Pawn, .color = .White });
    game_board.set(vec2i(2, 9), Piece{ .kind = .Pawn, .color = .White });
    game_board.set(vec2i(3, 8), Piece{ .kind = .Pawn, .color = .White });
    game_board.set(vec2i(4, 7), Piece{ .kind = .Pawn, .color = .White });
    game_board.set(vec2i(5, 6), Piece{ .kind = .Pawn, .color = .White });
    game_board.set(vec2i(6, 6), Piece{ .kind = .Pawn, .color = .White });
    game_board.set(vec2i(7, 6), Piece{ .kind = .Pawn, .color = .White });
    game_board.set(vec2i(8, 6), Piece{ .kind = .Pawn, .color = .White });
    game_board.set(vec2i(9, 6), Piece{ .kind = .Pawn, .color = .White });
    game_board.set(vec2i(2, 10), Piece{ .kind = .Rook, .color = .White });
    game_board.set(vec2i(3, 10), Piece{ .kind = .Knight, .color = .White });
    game_board.set(vec2i(4, 10), Piece{ .kind = .Queen, .color = .White });
    game_board.set(vec2i(5, 10), Piece{ .kind = .Bishop, .color = .White });
    game_board.set(vec2i(5, 9), Piece{ .kind = .Bishop, .color = .White });
    game_board.set(vec2i(5, 8), Piece{ .kind = .Bishop, .color = .White });
    game_board.set(vec2i(6, 9), Piece{ .kind = .King, .color = .White });
    game_board.set(vec2i(7, 8), Piece{ .kind = .Knight, .color = .White });
    game_board.set(vec2i(8, 7), Piece{ .kind = .Rook, .color = .White });
}

pub fn onEvent(context: *platform.Context, event: platform.Event) void {
    switch (event) {
        .Quit => {
            platform.quit();
        },
        .MouseMotion => |move_ev| {
            mouse_pos = move_ev.pos.intToFloat(f32);
        },
        else => {},
    }
}

pub fn update(context: *platform.Context, current_time: f64, delta: f64) void {}

pub fn render(context: *platform.Context, alpha: f64) void {
    platform.glUseProgram(shaderProgram);

    // Set the scaling matrix so that 1 unit = 1 pixel
    const screen_size = context.getScreenSize();
    const translationMatrix = [_]f32{
        1, 0, 0, translation.x(),
        0, 1, 0, translation.y(),
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
    const scalingMatrix = [_]f32{
        2 / @intToFloat(f32, screen_size.x()), 0,                                      0, -1,
        0,                                     -2 / @intToFloat(f32, screen_size.y()), 0, 1,
        0,                                     0,                                      1, 0,
        0,                                     0,                                      0, 1,
    };
    const projectionMatrix = platform.mat.mulMat4(scalingMatrix, translationMatrix);

    platform.glUniformMatrix4fv(projectionMatrixUniform, 1, platform.GL_FALSE, &projectionMatrix);

    // Clear the screen
    platform.glClearColor(0.5, 0.5, 0.5, 0.9);
    platform.glClear(platform.GL_COLOR_BUFFER_BIT);
    platform.glViewport(0, 0, 640, 480);

    // Draw the vertices
    platform.glBindVertexArray(boardBackgroundMesh.vao);
    platform.glDrawElements(platform.GL_TRIANGLES, boardBackgroundMesh.count, platform.GL_UNSIGNED_SHORT, null);

    const selection_pos = flat_hex_to_pixel(20, pixel_to_flat_hex(20, mouse_pos.sub(translation)));

    renderer.projectionMatrix = projectionMatrix;
    renderer.begin();

    var board_iter = game_board.iterator();
    while (board_iter.next()) |res| {
        if (res.tile.* == null) continue;
        const tile = res.tile.*.?;

        const piece_pos = flat_hex_to_pixel(20, res.pos);
        const color = switch (tile.color) {
            .Black => platform.Color.from_u32(0x000000FF),
            .White => platform.Color.from_u32(0xFFFFFFFF),
        };
        switch (tile.kind) {
            else => {
                renderer.pushRect(piece_pos, vec2f(20, 20), color, 0);
            },
        }
    }

    renderer.pushFlatHexagon(selection_pos, 20, platform.Color{ .r = 10, .g = 0xFF, .b = 10, .a = 0x33 }, 0);
    renderer.flush();
}

const Mesh = struct {
    vao: platform.GLuint,
    count: platform.GLsizei,
};

fn genBoardTileBackgroundVAO(allocator: *std.mem.Allocator, shader: platform.GLuint) !Mesh {
    const UNIT = 20;
    const HEXAGON_X = UNIT * std.math.cos(@as(f32, 60.0 * DEG_TO_RAD));
    const HEXAGON_Y = UNIT * std.math.sin(@as(f32, 60.0 * DEG_TO_RAD));

    var vertices = ArrayList(f32).init(allocator);
    defer vertices.deinit();
    var colors = ArrayList(u8).init(allocator);
    defer colors.deinit();
    var indices = ArrayList(u16).init(allocator);
    defer indices.deinit();

    var board_iter = game_board.iterator();
    while (board_iter.next()) |res| {
        const baseIdx = @intCast(u16, @divExact(vertices.items.len, 2));
        const pcoords = flat_hex_to_pixel(UNIT, res.pos);

        try vertices.appendSlice(&[_]f32{
            pcoords.x() - UNIT,      pcoords.y() + 0.0,
            pcoords.x() - HEXAGON_X, pcoords.y() + HEXAGON_Y,
            pcoords.x() + HEXAGON_X, pcoords.y() + HEXAGON_Y,
            pcoords.x() + UNIT,      pcoords.y() + 0.0,
            pcoords.x() + HEXAGON_X, pcoords.y() - HEXAGON_Y,
            pcoords.x() - HEXAGON_X, pcoords.y() - HEXAGON_Y,
        });

        // Add to color data
        {
            const color = switch (@mod(res.pos.x() + res.pos.y() * Board.SIZE, 3)) {
                0 => [_]u8{ 130, 102, 68 },
                1 => [_]u8{ 255, 235, 205 },
                2 => [_]u8{ 255, 150, 150 },
                else => unreachable,
            };

            var i: usize = 0;
            while (i < 6) : (i += 1) {
                try colors.appendSlice(&color);
            }
        }

        try indices.appendSlice(&[_]u16{
            baseIdx + 0, baseIdx + 1, baseIdx + 2,
            baseIdx + 0, baseIdx + 2, baseIdx + 3,
            baseIdx + 0, baseIdx + 3, baseIdx + 4,
            baseIdx + 0, baseIdx + 4, baseIdx + 5,
        });
    }

    // Set up VAO
    const vao = platform.glCreateVertexArray();
    platform.glBindVertexArray(vao);

    // Create buffers and load data into them
    const vertexBuffer = platform.glCreateBuffer();
    platform.glBindBuffer(platform.GL_ARRAY_BUFFER, vertexBuffer);
    platform.glBufferData(platform.GL_ARRAY_BUFFER, @intCast(c_long, vertices.items.len) * @sizeOf(f32), vertices.items.ptr, platform.GL_STATIC_DRAW);

    const coordinates = @intCast(c_uint, platform.glGetAttribLocation(shader, "coordinates"));
    platform.glVertexAttribPointer(coordinates, 2, platform.GL_FLOAT, platform.GL_FALSE, 0, null);
    platform.glEnableVertexAttribArray(coordinates);

    const colorBuffer = platform.glCreateBuffer();
    platform.glBindBuffer(platform.GL_ARRAY_BUFFER, colorBuffer);
    platform.glBufferData(platform.GL_ARRAY_BUFFER, @intCast(c_long, colors.items.len) * @sizeOf(u8), colors.items.ptr, platform.GL_STATIC_DRAW);

    const color_loc = @intCast(c_uint, platform.glGetAttribLocation(shader, "color"));
    platform.glVertexAttribPointer(color_loc, 3, platform.GL_UNSIGNED_BYTE, platform.GL_TRUE, 0, null);
    platform.glEnableVertexAttribArray(color_loc);

    const indexBuffer = platform.glCreateBuffer();
    platform.glBindBuffer(platform.GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    platform.glBufferData(platform.GL_ELEMENT_ARRAY_BUFFER, @intCast(c_long, indices.items.len) * @sizeOf(u16), indices.items.ptr, platform.GL_STATIC_DRAW);

    return Mesh{
        .vao = vao,
        .count = @intCast(platform.GLsizei, indices.items.len),
    };
}

fn flat_hex_to_pixel(size: f32, hex: Vec2i) Vec2f {
    var x = size * (3.0 / 2.0 * @intToFloat(f32, hex.v[0]));
    var y = size * (std.math.sqrt(@as(f32, 3.0)) / 2.0 * @intToFloat(f32, hex.v[0]) + std.math.sqrt(@as(f32, 3.0)) * @intToFloat(f32, hex.v[1]));
    return Vec2f.init(x, y);
}

fn pixel_to_flat_hex(size: f32, pixel: Vec2f) Vec2i {
    var q = (2.0 / 3.0 * pixel.v[0]) / size;
    var r = (-1.0 / 3.0 * pixel.v[0] + std.math.sqrt(@as(f32, 3)) / 3 * pixel.v[1]) / size;
    return hex_round(Vec2f.init(q, r)).floatToInt(i32);
}

fn hex_round(hex: Vec2f) Vec2f {
    return cube_to_axial(cube_round(axial_to_cube(hex)));
}

fn cube_round(cube: Vec3f) Vec3f {
    var rx = std.math.round(cube.x());
    var ry = std.math.round(cube.y());
    var rz = std.math.round(cube.z());

    var x_diff = std.math.absFloat(rx - cube.x());
    var y_diff = std.math.absFloat(ry - cube.y());
    var z_diff = std.math.absFloat(rz - cube.z());

    if (x_diff > y_diff and x_diff > z_diff) {
        rx = -ry - rz;
    } else if (y_diff > z_diff) {
        ry = -rx - rz;
    } else {
        rz = -rx - ry;
    }

    return Vec3f.init(rx, ry, rz);
}

fn axial_to_cube(axial: Vec2f) Vec3f {
    return platform.vec3f(
        axial.x(),
        -axial.x() - axial.y(),
        axial.y(),
    );
}

fn cube_to_axial(cube: Vec3f) Vec2f {
    return vec2f(cube.x(), cube.z());
}
