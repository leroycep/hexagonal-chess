const std = @import("std");
const Allocator = std.mem.Allocator;
const core = @import("./core.zig");
const Vec2i = @import("util").Vec2i;

pub const Frames = union(enum) {
    WaitingForSize: void,
    WaitingForData: struct {
        buffer: []u8,
        bytes_recevied: usize,
    },

    pub fn init() @This() {
        return @This(){ .WaitingForSize = {} };
    }

    pub fn update(this: *@This(), alloc: *Allocator, reader: anytype) !?[]u8 {
        while (true) {
            switch (this.*) {
                .WaitingForSize => {
                    const n = reader.readIntLittle(u32) catch |e| switch (e) {
                        error.WouldBlock => return null,
                        else => |other_err| return other_err,
                    };
                    this.* = .{
                        .WaitingForData = .{
                            .buffer = try alloc.alloc(u8, n),
                            .bytes_recevied = 0,
                        },
                    };
                },

                .WaitingForData => |*data| {
                    data.bytes_recevied += reader.read(data.buffer[data.bytes_recevied..]) catch |e| switch (e) {
                        error.WouldBlock => return null,
                        else => |other_err| return other_err,
                    };
                    if (data.bytes_recevied == data.buffer.len) {
                        const message = data.buffer;
                        this.* = .{ .WaitingForSize = {} };
                        return message;
                    }
                },
            }
        }
    }
};

// Packets from the server
pub const ServerPacket = union(enum) {
    Init: struct {
        // The color the client will be
        color: core.piece.Piece.Color,
    },
    ErrorMessage: ServerError,
    BoardUpdate: core.Board.Serialized,
    TurnChange: core.piece.Piece.Color,
};

pub const ServerError = enum {
    IllegalMove,

    pub fn jsonStringify(this: @This(), options: std.json.StringifyOptions, writer: anytype) !void {
        const text = switch (this) {
            .IllegalMove => "IllegalMove",
        };
        try std.json.stringify(text, options, writer);
    }
};

// Packets from the client
pub const ClientPacket = union(enum) {
    MovePiece: struct {
        startPos: Vec2i,
        endPos: Vec2i,
    },
};
