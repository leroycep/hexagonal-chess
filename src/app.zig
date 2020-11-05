const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");
const Vec2f = platform.Vec2f;
const pi = std.math.pi;
const OBB = collision.OBB;
const game = @import("game.zig");

const VERTS = [_]f32{
    -0.5, 0.5,  0.0,
    -0.5, -0.5, 0.0,
    0.5,  -0.5, 0.0,
};
const INDICES = [_]u16{ 0, 1, 2 };

const VERT_CODE =
    \\ attribute vec3 coordinates;
    \\
    \\ void main(void) {
    \\   gl_Position = vec4(coordinates, 1.0);
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
    platform.glVertexAttribPointer(coordinates, 3, platform.GL_FLOAT, platform.GL_FALSE, 0, null);
    platform.glEnableVertexAttribArray(coordinates);
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
    platform.glClearColor(0.5, 0.5, 0.5, 0.9);
    platform.glEnable(platform.GL_DEPTH_TEST);
    platform.glClear(platform.GL_COLOR_BUFFER_BIT | platform.GL_DEPTH_BUFFER_BIT);
    platform.glViewport(0, 0, 640, 480);
    platform.glDrawElements(platform.GL_TRIANGLES, INDICES.len, platform.GL_UNSIGNED_SHORT, null);
}
