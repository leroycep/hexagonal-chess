pub const GLenum = c_uint;
pub const GLboolean = bool;
pub const GLbitfield = c_uint;
pub const GLbyte = i8;
pub const GLshort = i16;
pub const GLint = i32;
pub const GLsizei = i32;
pub const GLintptr = i64;
pub const GLsizeiptr = i64;
pub const GLubyte = u8;
pub const GLushort = u16;
pub const GLuint = u32;
pub const GLfloat = f32;
pub const GLclampf = f32;
pub const GL_VERTEX_SHADER = 35633;
pub const GL_FRAGMENT_SHADER = 35632;
pub const GL_ARRAY_BUFFER = 34962;
pub const GL_ELEMENT_ARRAY_BUFFER = 0x8893;
pub const GL_TRIANGLES = 4;
pub const GL_TRIANGLE_STRIP = 5;
pub const GL_STATIC_DRAW = 35044;
pub const GL_DYNAMIC_DRAW = 0x88E8;
pub const GL_FLOAT = 5126;
pub const GL_DEPTH_TEST = 2929;
pub const GL_LEQUAL = 515;
pub const GL_COLOR_BUFFER_BIT = 16384;
pub const GL_DEPTH_BUFFER_BIT = 256;
pub const GL_STENCIL_BUFFER_BIT = 1024;
pub const GL_TEXTURE_2D = 3553;
pub const GL_RGBA = 6408;
pub const GL_UNSIGNED_BYTE = 5121;
pub const GL_TEXTURE_MAG_FILTER = 10240;
pub const GL_TEXTURE_MIN_FILTER = 10241;
pub const GL_NEAREST = 9728;
pub const GL_TEXTURE0 = 33984;
pub const GL_BLEND = 3042;
pub const GL_SRC_ALPHA = 770;
pub const GL_ONE_MINUS_SRC_ALPHA = 771;
pub const GL_ONE = 1;
pub const GL_NO_ERROR = 0;
pub const GL_FALSE = 0;
pub const GL_TRUE = 1;
pub const GL_UNPACK_ALIGNMENT = 3317;

pub const GL_TEXTURE_WRAP_S = 10242;
pub const GL_CLAMP_TO_EDGE = 33071;
pub const GL_TEXTURE_WRAP_T = 10243;
pub const GL_PACK_ALIGNMENT = 3333;

pub const GL_FRAMEBUFFER = 0x8D40;
pub const GL_RGB = 6407;

pub const GL_COLOR_ATTACHMENT0 = 0x8CE0;
pub const GL_FRAMEBUFFER_COMPLETE = 0x8CD5;
pub const GL_CULL_FACE = 0x0B44;
pub const GL_CCW = 0x0901;
pub const GL_STREAM_DRAW = 0x88E0;

// Data Types
pub const GL_UNSIGNED_SHORT = 0x1403;
pub const GL_UNSIGNED_INT = 0x1405;

pub extern fn getScreenW() i32;
pub extern fn getScreenH() i32;
pub extern fn glActiveTexture(target: c_uint) void;
pub extern fn glAttachShader(program: c_uint, shader: c_uint) void;
pub extern fn glBindBuffer(type: c_uint, buffer_id: c_uint) void;
pub extern fn glBindVertexArray(vertex_array_id: c_uint) void;
pub extern fn glBindFramebuffer(target: c_uint, framebuffer: c_uint) void;
pub extern fn glBindTexture(target: c_uint, texture_id: c_uint) void;
pub extern fn glBlendFunc(x: c_uint, y: c_uint) void;
pub extern fn glBufferData(type: c_uint, count: c_long, data_ptr: *const c_void, draw_type: c_uint) void;
pub extern fn glCheckFramebufferStatus(target: GLenum) GLenum;
pub extern fn glClear(mask: GLbitfield) void;
pub extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
pub extern fn glCompileShader(shader: GLuint) void;
pub extern fn getShaderCompileStatus(shader: GLuint) GLboolean;
pub extern fn glCreateBuffer() c_uint;
pub extern fn glCreateFramebuffer() GLuint;
pub extern fn glCreateProgram() GLuint;
pub extern fn glCreateShader(shader_type: GLenum) GLuint;
pub extern fn glCreateTexture() c_uint;
pub extern fn glDeleteBuffer(id: c_uint) void;
pub extern fn glDeleteProgram(id: c_uint) void;
pub extern fn glDeleteShader(id: c_uint) void;
pub extern fn glDeleteTexture(id: c_uint) void;
pub extern fn glDepthFunc(x: c_uint) void;
pub extern fn glDetachShader(program: c_uint, shader: c_uint) void;
pub extern fn glDisable(cap: GLenum) void;
pub extern fn glCreateVertexArray() c_uint;
pub extern fn glDrawArrays(type: c_uint, offset: c_uint, count: c_uint) void;
pub extern fn glDrawElements(mode: GLenum, count: GLsizei, type: GLenum, offset: ?*const c_void) void;
pub extern fn glEnable(x: c_uint) void;
pub extern fn glEnableVertexAttribArray(x: c_uint) void;
pub extern fn glFramebufferTexture2D(target: GLenum, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint) void;
pub extern fn glFrontFace(mode: GLenum) void;
extern fn glGetAttribLocation_(program_id: c_uint, name_ptr: [*]const u8, name_len: c_uint) c_int;
pub fn glGetAttribLocation(program_id: c_uint, name: []const u8) c_int {
    return glGetAttribLocation_(program_id, name.ptr, name.len);
}
pub extern fn glGetError() c_int;
pub extern fn glGetShaderInfoLog(shader: GLuint, maxLength: GLsizei, length: ?*GLsizei, infoLog: ?[*]u8) void;
extern fn glGetUniformLocation_(program_id: c_uint, name_ptr: [*]const u8, name_len: c_uint) c_int;
pub fn glGetUniformLocation(program_id: c_uint, name: []const u8) c_int {
    return glGetUniformLocation_(program_id, name.ptr, name.len);
}
pub extern fn glLinkProgram(program: c_uint) void;
pub extern fn getProgramLinkStatus(program: c_uint) GLboolean;
pub extern fn glGetProgramInfoLog(program: GLuint, maxLength: GLsizei, length: ?*GLsizei, infoLog: ?[*]u8) void;
pub extern fn glPixelStorei(pname: GLenum, param: GLint) void;
extern fn glShaderSource_(shader: GLuint, string_ptr: [*]const u8, string_len: c_uint) void;
pub fn glShaderSource(shader: GLuint, string: []const u8) void {
    glShaderSource_(shader, string.ptr, string.len);
}
pub extern fn glTexImage2D(target: c_uint, level: c_uint, internal_format: c_uint, width: c_int, height: c_int, border: c_uint, format: c_uint, type: c_uint, data_ptr: ?[*]const u8, data_len: c_uint) void;
pub extern fn glTexParameterf(target: c_uint, pname: c_uint, param: f32) void;
pub extern fn glTexParameteri(target: c_uint, pname: c_uint, param: c_uint) void;
pub extern fn glUniform1f(location_id: c_int, x: f32) void;
pub extern fn glUniform1i(location_id: c_int, x: c_int) void;
pub extern fn glUniform4f(location_id: c_int, x: f32, y: f32, z: f32, w: f32) void;
pub extern fn glUniformMatrix4fv(location_id: c_int, data_len: c_int, transpose: c_uint, data_ptr: [*]const f32) void;
pub extern fn glUseProgram(program_id: c_uint) void;
pub extern fn glVertexAttribPointer(attrib_location: c_uint, size: c_uint, type: c_uint, normalize: c_uint, stride: c_uint, offset: ?*c_void) void;
pub extern fn glViewport(x: c_int, y: c_int, width: c_int, height: c_int) void;
