const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");
const Vec2f = platform.Vec2f;
const pi = std.math.pi;
const OBB = collision.OBB;

const DEG_TO_RAD = std.math.pi / 180.0;
const HEXAGON_SIZE = 40;
const HEXAGON_X = HEXAGON_SIZE * std.math.cos(@as(f32, 60.0 * DEG_TO_RAD));
const HEXAGON_Y = HEXAGON_SIZE * std.math.sin(@as(f32, 60.0 * DEG_TO_RAD));

const VERTS = [_]f32{
    100 + -HEXAGON_SIZE, 100 + 0.0,
    100 + -HEXAGON_X,    100 + HEXAGON_Y,
    100 + HEXAGON_X,     100 + HEXAGON_Y,
    100 + HEXAGON_SIZE,  100 + 0.0,
    100 + HEXAGON_X,     100 + -HEXAGON_Y,
    100 + -HEXAGON_X,    100 + -HEXAGON_Y,
};
const INDICES = [_]u16{ 0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5 };

const VERT_CODE =
    \\ attribute vec2 coordinates;
    \\ uniform mat4 projectionMatrix;
    \\
    \\ void main(void) {
    \\   gl_Position = vec4(coordinates, 0.0, 1.0);
    \\   gl_Position *= projectionMatrix;
    \\ }
;

const FRAG_CODE =
    \\ void main(void) {
    \\   gl_FragColor = vec4(1, 0.5, 0, 1.0);
    \\ }
;

var shaderProgram: platform.GLuint = undefined;
var vertexBuffer: platform.GLuint = undefined;
var indexBuffer: platform.GLuint = undefined;
var vao: platform.GLuint = undefined;
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
    vao = platform.glCreateVertexArray();
    platform.glBindVertexArray(vao);

    // Create buffers and load data into them
    vertexBuffer = platform.glCreateBuffer();
    platform.glBindBuffer(platform.GL_ARRAY_BUFFER, vertexBuffer);
    platform.glBufferData(platform.GL_ARRAY_BUFFER, VERTS.len * @sizeOf(f32), &VERTS, platform.GL_STATIC_DRAW);

    indexBuffer = platform.glCreateBuffer();
    platform.glBindBuffer(platform.GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    platform.glBufferData(platform.GL_ELEMENT_ARRAY_BUFFER, INDICES.len * @sizeOf(u16), &INDICES, platform.GL_STATIC_DRAW);

    var coordinates = @intCast(c_uint, platform.glGetAttribLocation(shaderProgram, "coordinates"));
    platform.glVertexAttribPointer(coordinates, 2, platform.GL_FLOAT, platform.GL_FALSE, 0, null);
    platform.glEnableVertexAttribArray(coordinates);

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
    platform.glDrawElements(platform.GL_TRIANGLES, INDICES.len, platform.GL_UNSIGNED_SHORT, null);
}
