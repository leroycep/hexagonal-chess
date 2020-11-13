const std = @import("std");
const builtin = @import("builtin");
const Frames = @import("core").protocol.Frames;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Address = std.net.Address;

pub const MAX_SOCKETS = 3;

var socket_slots = [_]?FramesSocket{null} ** MAX_SOCKETS;
pub fn update_sockets() void {
    for (socket_slots) |*frames_socket_opt| {
        if (frames_socket_opt.*) |*frame_socket| {
            frame_socket.update();
        }
    }
}

pub const FramesSocket = struct {
    alloc: *Allocator,
    socket: std.fs.File,
    frames: Frames,

    onopen: ?fn (*@This()) void = null,
    onmessage: ?fn (*@This(), msg: []const u8) void = null,
    onerror: ?fn (*@This(), err: Error) void = null,
    onclose: ?fn (*@This()) void = null,

    //const Message = struct {
    //    address: Address,
    //    data: []const u8,
    //};

    const Error = error{ EndOfStream, OutOfMemory } || std.fs.File.ReadError;

    pub fn init(alloc: *Allocator, address: Address) !*@This() {
        for (socket_slots) |*frames_socket_opt| {
            if (frames_socket_opt.* != null) continue;

            const sock_flags = std.os.SOCK_STREAM | std.os.SOCK_NONBLOCK | std.os.SOCK_CLOEXEC;
            const sockfd = try std.os.socket(address.any.family, sock_flags, std.os.IPPROTO_TCP);
            const socket = std.fs.File{ .handle = sockfd };
            errdefer socket.close();

            std.os.connect(sockfd, &address.any, address.getOsSockLen()) catch |e| switch (e) {
                error.WouldBlock => {},
                else => |other_err| return other_err,
            };

            frames_socket_opt.* = .{
                .alloc = alloc,
                .socket = socket,
                .frames = Frames.init(),
            };

            return &frames_socket_opt.*.?;
        }
        return error.OutOfSockets;
    }

    pub fn update(this: *@This()) void {
        if (this.frames.update(this.alloc, this.socket.reader())) |message_recv_opt| {
            if (message_recv_opt) |message_recv| {
                defer this.alloc.free(message_recv);
                if (this.onmessage) |onmessage| {
                    onmessage(this, message_recv);
                }
            }
        } else |err| {
            if (this.onerror) |onerror| {
                onerror(this, err);
            } else {
                std.log.warn("{}", .{err});
            }
        }
    }

    pub fn setOnMessage(this: *@This(), callback: fn (*@This(), msg: []const u8) void) void {
        this.onmessage = callback;
    }

    pub fn setOnError(this: *@This(), callback: fn (*@This(), err: Error) void) void {
        this.onerror = callback;
    }

    pub fn send(this: *@This(), msg: []const u8) !void {
        try this.socket.writer().writeByte(@intCast(u8, msg.len));
        _ = try this.socket.writer().write(msg);
    }
};
