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
    socket: Socket,
    frames: Frames,
    status: Status,

    user_data: usize,
    onopen: ?fn (*@This(), usize) void = null,
    onmessage: ?fn (*@This(), usize, msg: []const u8) void = null,
    onerror: ?fn (*@This(), usize, err: Error) void = null,
    onclose: ?fn (*@This(), usize) void = null,

    const Status = enum {
        Connecting,
        Open,
        Closing,
        Closed,
    };

    const Error = error{ EndOfStream, OutOfMemory } || Socket.RecvFromError;

    pub fn init(alloc: *Allocator, address: Address, user_data: usize) !*@This() {
        for (socket_slots) |*frames_socket_opt| {
            if (frames_socket_opt.* != null) continue;

            const sock_flags = std.os.SOCK_STREAM | std.os.SOCK_NONBLOCK | std.os.SOCK_CLOEXEC;
            const sockfd = try std.os.socket(address.any.family, sock_flags, std.os.IPPROTO_TCP);
            const socket = Socket{ .handle = sockfd };
            errdefer socket.close();

            var status = Status.Open;

            std.os.connect(sockfd, &address.any, address.getOsSockLen()) catch |e| switch (e) {
                error.WouldBlock => status = Status.Connecting,
                else => |other_err| return other_err,
            };

            frames_socket_opt.* = .{
                .alloc = alloc,
                .socket = socket,
                .frames = Frames.init(),
                .status = status,
                .user_data = user_data,
            };

            return &frames_socket_opt.*.?;
        }
        return error.OutOfSockets;
    }

    pub fn update(this: *@This()) void {
        if (this.status == .Closed) return;
        if (this.frames.update(this.alloc, this.socket.reader())) |message_recv_opt| {
            if (message_recv_opt) |message_recv| {
                defer this.alloc.free(message_recv);
                if (this.onmessage) |onmessage| {
                    onmessage(this, this.user_data, message_recv);
                }
            }
        } else |err| {
            switch (err) {
                error.ConnectionRefused => this.status = .Closed,
                else => {},
            }
            if (this.onerror) |onerror| {
                onerror(this, this.user_data, err);
            } else {
                std.log.warn("{}", .{err});
            }
        }
    }

    pub fn setOnMessage(this: *@This(), callback: fn (*@This(), usize, msg: []const u8) void) void {
        this.onmessage = callback;
    }

    pub fn setOnError(this: *@This(), callback: fn (*@This(), usize, err: Error) void) void {
        this.onerror = callback;
    }

    pub fn send(this: *@This(), msg: []const u8) !void {
        try this.socket.writer().writeIntLittle(u32, @intCast(u32, msg.len));
        try this.socket.writer().writeAll(msg);
    }
};

const Socket = struct {
    handle: std.os.fd_t,

    const RecvFromError = std.os.RecvFromError;

    pub fn recv(this: @This(), buffer: []u8) RecvFromError!usize {
        return std.os.recv(this.handle, buffer, 0);
    }

    const SendError = std.os.SendError;

    pub fn send(this: @This(), buffer: []const u8) SendError!usize {
        return std.os.send(this.handle, buffer, 0);
    }

    const is_windows = std.Target.current.os.tag == .windows;

    pub fn close(this: @This()) void {
        if (is_windows) {
            std.os.windows.CloseHandle(self.handle);
        } else {
            std.os.close(this.handle);
        }
    }

    pub const Reader = std.io.Reader(Socket, RecvFromError, recv);

    pub fn reader(this: @This()) Reader {
        return .{ .context = this };
    }

    pub const Writer = std.io.Writer(Socket, SendError, send);

    pub fn writer(this: @This()) Writer {
        return .{ .context = this };
    }
};
