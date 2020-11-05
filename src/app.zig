const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");
const Vec2f = platform.Vec2f;
const vec2f = platform.vec2f;
const Vec2i = platform.Vec2i;
const vec2i = platform.vec2i;
const pi = std.math.pi;
const OBB = collision.OBB;
const Board = @import("./board.zig").Board(bool, 11);
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

var shaderProgram: platform.GLuint = undefined;
var boardMesh: Mesh = undefined;
var projectionMatrixUniform: platform.GLint = undefined;

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
    boardMesh = genBoardTileBackgroundVAO(context.alloc, shaderProgram) catch unreachable;

    projectionMatrixUniform = platform.glGetUniformLocation(shaderProgram, "projectionMatrix");
}

pub fn onEvent(context: *platform.Context, event: platform.Event) void {
    switch (event) {
        .Quit => {
            platform.quit();
        },
        else => {},
    }
}

pub fn update(context: *platform.Context, current_time: f64, delta: f64) void {}

pub fn render(context: *platform.Context, alpha: f64) void {
    // Set the scaling matrix so that 1 unit = 1 pixel
    const screen_size = context.getScreenSize();
    const scalingMatrix = [_]f32{
        2 / @intToFloat(f32, screen_size.x()), 0,                                      0, -1,
        0,                                     -2 / @intToFloat(f32, screen_size.y()), 0, 1,
        0,                                     0,                                      1, 0,
        0,                                     0,                                      0, 1,
    };

    platform.glUniformMatrix4fv(projectionMatrixUniform, 1, platform.GL_FALSE, &scalingMatrix);

    // Clear the screen
    platform.glClearColor(0.5, 0.5, 0.5, 0.9);
    platform.glClear(platform.GL_COLOR_BUFFER_BIT);
    platform.glViewport(0, 0, 640, 480);

    // Draw the vertices
    platform.glBindVertexArray(boardMesh.vao);
    platform.glDrawElements(platform.GL_TRIANGLES, boardMesh.count, platform.GL_UNSIGNED_SHORT, null);
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

    var r: i32 = 0;
    while (r < Board.SIZE) : (r += 1) {
        var q: i32 = 0;
        while (q < Board.SIZE) : (q += 1) {
            if (q + r < 5 or q + r > 15) continue;
            const baseIdx = @intCast(u16, @divExact(vertices.items.len, 2));
            const pcoords = flat_hex_to_pixel(UNIT, Vec2i.init(q, r));

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
                const color = switch (@mod(q + r * Board.SIZE, 3)) {
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
