const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.mutex.Mutex;
const ArrayList = std.ArrayList;
const AutoHashMap = std.hash_map.AutoHashMap;
const Address = std.net.Address;
const NonblockingStreamServer = @import("./nonblocking_stream_server.zig").NonblockingStreamServer;
const protocol = @import("protocol");

const MAX_CLIENTS = 2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = &gpa.allocator;

    const localhost = try Address.parseIp("127.0.0.1", 8081);

    var server = NonblockingStreamServer.init(.{ .reuse_address = true });
    defer server.deinit();

    try server.listen(localhost);
    std.log.info("listening on {}", .{server.listen_address});

    // Create client threads
    var clients = AutoHashMap(std.os.fd_t, Client).init(alloc);
    defer {
        var clients_iter = clients.iterator();
        while (clients_iter.next()) |client| {
            client.value.connection.file.close();
        }

        clients.deinit();
    }

    var pollfds = std.ArrayList(std.os.pollfd).init(alloc);
    defer pollfds.deinit();

    try pollfds.append(.{
        .fd = server.sockfd.?,
        .events = std.os.POLLIN,
        .revents = undefined,
    });

    var running = true;
    var next_id: u32 = 0;

    while (running) {
        var poll_count = try std.os.poll(pollfds.items, -1);

        for (pollfds.items) |pollfd, pollfd_idx| {
            if (poll_count == 0) break;

            if (pollfd.revents & std.os.POLLIN != std.os.POLLIN) continue;
            poll_count -= 1;

            if (pollfd.fd == server.sockfd.?) {
                var new_connection = server.accept() catch |e| switch (e) {
                    error.WouldBlock => continue,
                    else => |oe| return oe,
                };

                if (pollfds.items.len >= MAX_CLIENTS + 1) {
                    new_connection.file.close();
                    continue;
                }

                try pollfds.append(.{
                    .fd = new_connection.file.handle,
                    .events = std.os.POLLIN,
                    .revents = undefined,
                });

                try clients.put(new_connection.file.handle, .{ .alloc = alloc, .connection = new_connection });

                std.log.info("{} connected", .{new_connection.address});
            } else if (clients.get(pollfd.fd)) |*client| {
                if (client.handle()) |message_opt| {
                    const message = message_opt orelse continue;
                    defer alloc.free(message);

                    if (std.mem.eql(u8, "exit", message)) {
                        disconnectClient(&pollfds, &clients, pollfd_idx);
                        break;
                    }
                    if (std.mem.eql(u8, "stop", message)) {
                        running = false;
                        break;
                    }

                    std.log.info("{}: {}", .{ client.connection.address, message });

                    broadcast(&clients, message);
                } else |err| switch (err) {
                    error.EndOfStream => {
                        disconnectClient(&pollfds, &clients, pollfd_idx);
                        break;
                    },
                    else => |other_err| return other_err,
                }
            }
        }
    }
}

fn disconnectClient(pollfds: *ArrayList(std.os.pollfd), clients: *AutoHashMap(std.os.fd_t, Client), pollfd_idx: usize) void {
    const client = clients.remove(pollfds.items[pollfd_idx].fd).?;
    client.value.connection.file.close();
    _ = pollfds.swapRemove(pollfd_idx);
    std.log.info("{} disconnected", .{client.value.connection.address});
}

fn broadcast(clients: *AutoHashMap(std.os.fd_t, Client), message: []const u8) void {
    var clients_iter = clients.iterator();
    while (clients_iter.next()) |client| {
        const writer = client.value.connection.file.writer();
        _ = writer.writeByte(@intCast(u8, message.len)) catch continue;
        _ = writer.write(message) catch continue;
    }
}

const Client = struct {
    alloc: *Allocator,
    connection: NonblockingStreamServer.Connection,
    frames: protocol.Frames = protocol.Frames.init(),

    pub fn handle(this: *@This()) !?[]u8 {
        const reader = this.connection.file.reader();
        return this.frames.update(this.alloc, reader);
    }
};
