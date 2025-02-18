const builtin = @import("builtin");
const std = @import("std");
const network = @import("network");
const input = @import("input.zig");

const log = std.log.default;
const http_log = std.log.scoped(.http);
const ws_log = std.log.scoped(.ws);

var thread_list: std.ArrayList(std.Thread) = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) log.warn("Memory leaked somewhere", .{}) else undefined;

    try network.init();
    defer network.deinit();

    var httpSock = try network.Socket.create(.ipv4, .tcp);
    try httpSock.bind(network.EndPoint{ .address = .{ .ipv4 = network.Address.IPv4.any }, .port = 734 });
    defer httpSock.close();

    thread_list = std.ArrayList(std.Thread).init(gpa.allocator());
    defer thread_list.deinit();

    defer for (thread_list.items) |t| {
        t.detach();
    };

    spawnThread(listenHTTP, .{ &httpSock, gpa.allocator() });

    while (std.io.getStdIn().reader().readByte() catch 'q' != 'q') {}

    log.info("Goodbye", .{});
}

pub fn spawnThread(comptime func: anytype, args: anytype) void {
    const thread = std.Thread.spawn(.{}, func, args) catch |e| {
        log.err("Failed to spawn thread: {s}", .{@errorName(e)});
        return;
    };
    thread_list.append(thread) catch {
        log.err("Failed to append thread to list", .{});
        std.process.abort();
    };
    log.info("New thread {d} spawned", .{@intFromPtr(thread.getHandle())});
}

pub fn listenHTTP(sock: *network.Socket, allocator: std.mem.Allocator) !void {
    try sock.listen();
    if (sock.getLocalEndPoint()) |e| {
        http_log.info("Listening on {d}.{d}.{d}.{d}:{d}", .{
            e.address.ipv4.value[0],
            e.address.ipv4.value[1],
            e.address.ipv4.value[2],
            e.address.ipv4.value[3],
            e.port,
        });
    } else |err| {
        http_log.err("Failed to get local endpoint: {s}", .{@errorName(err)});
    }

    while (true) {
        http_log.info("Waiting for a new connection", .{});
        errdefer |e| http_log.err("Something went wrong: {s}", .{@errorName(e)});
        var conn = try sock.accept();
        try conn.setReadTimeout(std.time.us_per_s * 5);

        http_log.info("Stablished connection", .{});

        const to_close = handleRequest(conn.reader(), conn.writer(), allocator) catch |e| rtn: {
            http_log.err("Failed to handle request: {s}", .{@errorName(e)});
            break :rtn true;
        };
        if (to_close) {
            http_log.info("Closing connection", .{});
            conn.close();
        }
    }
}

pub fn handleRequest(reader: network.Socket.Reader, writer: network.Socket.Writer, allocator: std.mem.Allocator) !bool {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    // Reads request line
    const request_line = try reader.readUntilDelimiterOrEofAlloc(alloc, '\n', 1024);
    if (request_line == null) return error.MissingRequest;
    var args = std.mem.split(u8, request_line.?, " ");
    if (!std.mem.eql(u8, args.next() orelse return error.MissingHTTPMethod, "GET")) return error.InvalidHTTPMethod;
    const path = args.next() orelse return error.MissingPath;
    if (!std.mem.startsWith(u8, args.next() orelse return error.MissingHTTPVersion, "HTTP")) return error.InvalidProtocol;

    // Reads headers
    var headers = std.StringHashMap([]const u8).init(alloc);
    defer headers.deinit();

    while (true) {
        const line = try reader.readUntilDelimiterOrEofAlloc(alloc, '\n', 1024);
        if (line) |h| {
            if (std.mem.trim(u8, h, " \r\n").len == 0) break;
            const colon = std.mem.indexOf(u8, h, ":");
            if (colon) |c| {
                const key = std.mem.trim(u8, h[0..c], " \r\n");
                const value = std.mem.trim(u8, h[c + 1 ..], " \r\n");
                try headers.put(key, value);
            }
        }
    }

    http_log.info("Received request: {s}", .{path});

    if (std.mem.eql(u8, path, "/")) {
        const index = @embedFile("res\\routes\\index.html");
        const response_template = @embedFile("res\\response.txt");
        http_log.info("Sending html page as response", .{});
        try writer.print(response_template, .{ "text/html", index.len, index });
    } else if (std.mem.eql(u8, path, "/cmds")) {
        if (headers.get("Connection")) |connection| {
            if (std.mem.containsAtLeast(u8, connection, 1, "Upgrade")) {
                if (headers.get("Sec-WebSocket-Key")) |key| {
                    const response_key = try generateHandshakeKey(key, alloc);
                    http_log.info("Generated response key: '{s}' -> '{s}'", .{ key, response_key });
                    const response_template = @embedFile("res\\upgrade_response.txt");
                    http_log.info("Sending handshake", .{});
                    try writer.print(response_template, .{response_key});
                    spawnThread(listenWS, .{ writer.context, allocator });
                    return false;
                } else {
                    http_log.warn("Found request with \"Connection: Upgrade\" but has missing key", .{});
                }
            }
        }
    } else if (std.mem.eql(u8, path, "/index.js")) {
        const script = @embedFile("res\\routes\\index.js");
        const response_template = @embedFile("res\\response.txt");
        http_log.info("Sending script as response", .{});
        try writer.print(response_template, .{ "text/javascript", script.len, script });
    } else if (std.mem.eql(u8, path, "/index.css")) {
        const style = @embedFile("res\\routes\\index.css");
        const response_template = @embedFile("res\\response.txt");
        http_log.info("Sending CSS as response", .{});
        try writer.print(response_template, .{ "text/css", style.len, style });
    } else {
        try writer.print("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n", .{});
        return error.InvalidPath;
    }

    return true;
}

pub fn generateHandshakeKey(key: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const concatenated_key = try std.mem.concat(allocator, u8, &.{ key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11" });
    defer allocator.free(concatenated_key);

    var hashed_key = [_]u8{0} ** std.crypto.hash.Sha1.digest_length;
    std.crypto.hash.Sha1.hash(concatenated_key, &hashed_key, .{});

    const base64 = std.base64.Base64Encoder.init(std.base64.standard_alphabet_chars, '=');
    const response_key = try allocator.alloc(u8, base64.calcSize(hashed_key.len));
    defer allocator.free(response_key);

    const final_key = try allocator.dupe(u8, base64.encode(response_key, &hashed_key));
    return final_key;
}

pub fn listenWS(ws_connection: network.Socket, allocator: std.mem.Allocator) !void {
    errdefer |e| ws_log.err("Something went wrong: {s}", .{@errorName(e)});
    var conn = ws_connection;
    try conn.setReadTimeout(null);
    defer {
        conn.close();
        ws_log.info("Connection closed", .{});
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const alloc = arena.allocator();
    var errorCount: u32 = 0;
    var payload: []const u8 = undefined;

    while (errorCount < 5) {
        defer _ = arena.reset(.free_all);

        ws_log.info("Waiting for new commands", .{});
        while (errorCount < 5) {
            payload = handleFrame(conn.reader(), alloc) catch |e| {
                if (e == error.CloseConnection) return;
                errorCount += 1;
                ws_log.err("Error on read frame (error count: {d}): {s}", .{ errorCount, @errorName(e) });
                continue;
            };
            break;
        }
        if (errorCount >= 5) {
            ws_log.err("Too many errors, closing connection", .{});
            return;
        }

        ws_log.info("Received command: {s}", .{payload});
        var args = std.mem.splitAny(u8, payload, " ");
        runCommand(&args, alloc) catch |e| {
            ws_log.err("Failed to handle command: {s}", .{@errorName(e)});
        };
    }
}

// https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers#format
// Flipped because of endians weirdness
const FrameHeader = packed struct {
    opcode: u4,
    rsv3: bool,
    rsv2: bool,
    rsv1: bool,
    fin: bool,
    payload_len: u7,
    mask: bool,
};

pub fn handleFrame(reader: network.Socket.Reader, allocator: std.mem.Allocator) ![]const u8 {
    var header_buf = [_]u8{0} ** @sizeOf(FrameHeader);
    _ = try reader.read(&header_buf);
    const header: FrameHeader = @bitCast(header_buf);
    ws_log.info("Received header 0b{b}{b}", .{ header_buf[0], header_buf[1] });

    if (header_buf[0] | header_buf[1] == 0) {
        return error.CloseConnection;
    }

    if (header.payload_len > 125) {
        return error.PayloadTooBig;
    }

    if (header.opcode == 0x8) {
        ws_log.info("Received close frame", .{});
        return error.CloseConnection;
    }

    if (!header.mask) {
        ws_log.err("Received frame without mask", .{});
        return error.CloseConnection;
    }

    var key = [_]u8{0} ** 4;
    const key_len = try reader.read(&key);

    if (key_len != 4) {
        return error.InvalidMask;
    }

    const payload = try allocator.alloc(u8, header.payload_len);
    defer allocator.free(payload);
    const payload_len = try reader.read(payload);
    ws_log.info("Received payload with size {d} expected {d}", .{ payload_len, header.payload_len });

    // try reader.skipBytes(999, .{});

    if (header.payload_len != payload_len) {
        return error.PayloadSizeMismatch;
    }

    const decoded_payload = try allocator.alloc(u8, payload_len);
    for (0..payload_len) |i| {
        decoded_payload[i] = payload[i] ^ key[i % 4];
    }
    return decoded_payload;
}

pub fn runCommand(args: *std.mem.SplitIterator(u8, .any), allocator: std.mem.Allocator) !void {
    _ = allocator;
    if (args.next()) |cmd| {
        if (std.mem.eql(u8, cmd, "EXTRA")) {
            if (args.next()) |extra| {
                if (std.mem.eql(u8, extra, "reload")) {
                    input.tap(.f5);
                } else if (std.mem.eql(u8, extra, "maximize")) {
                    input.tap(.f);
                } else if (std.mem.eql(u8, extra, "windows")) {
                    input.tap(.super);
                } else if (std.mem.eql(u8, extra, "search")) {
                    input.tap(.s);
                } else {
                    return error.InvalidCommandArgument;
                }
            }
        } else if (std.mem.eql(u8, cmd, "PRESS")) {
            if (args.next()) |k| {
                if (k.len == 1) {
                    var c = k[0];
                    if (std.ascii.isAlphabetic(c) and std.ascii.isLower(c)) {
                        c = std.ascii.toUpper(c);
                    }
                    input.tap(try input.VK.fromAscii(c));
                } else {
                    return error.InvalidCommandArgument;
                }
            }
        } else if (std.mem.eql(u8, cmd, "TYPE")) {
            while (args.next()) |text| {
                input.write(text);
                if (args.peek()) |_| input.tap(.space);
            }
        } else if (std.mem.eql(u8, cmd, "VOL")) {
            if (args.next()) |dir| {
                if (std.mem.eql(u8, dir, "up")) {
                    input.tap(.volume_up);
                } else if (std.mem.eql(u8, dir, "down")) {
                    input.tap(.volume_down);
                } else if (std.mem.eql(u8, dir, "mute")) {
                    input.tap(.volume_mute);
                } else {
                    return error.InvalidCommandArgument;
                }
            }
        } else if (std.mem.eql(u8, cmd, "NAV")) {
            if (args.next()) |dir| {
                if (std.mem.eql(u8, dir, "up")) {
                    input.tap(.up);
                } else if (std.mem.eql(u8, dir, "down")) {
                    input.tap(.down);
                } else if (std.mem.eql(u8, dir, "left")) {
                    input.tap(.left);
                } else if (std.mem.eql(u8, dir, "right")) {
                    input.tap(.right);
                } else if (std.mem.eql(u8, dir, "enter")) {
                    input.tap(.enter);
                } else if (std.mem.eql(u8, dir, "space")) {
                    input.tap(.space);
                } else if (std.mem.eql(u8, dir, "back")) {
                    input.tap(.escape);
                } else if (std.mem.eql(u8, dir, "backspace")) {
                    input.tap(.backspace);
                } else if (std.mem.eql(u8, dir, "tab")) {
                    input.tap(.tab);
                } else if (std.mem.eql(u8, dir, "s-tab")) {
                    input.press(.shift);
                    input.tap(.tab);
                    input.release(.shift);
                } else {
                    return error.InvalidCommandArgument;
                }
            }
        } else if (std.mem.eql(u8, cmd, "MEDIA")) {
            if (args.next()) |mode| {
                if (std.mem.eql(u8, mode, "play")) {
                    input.tap(.media_play_pause);
                } else if (std.mem.eql(u8, mode, "forward")) {
                    input.tap(.media_next);
                } else if (std.mem.eql(u8, mode, "backward")) {
                    input.tap(.media_prev);
                } else {
                    return error.InvalidCommandArgument;
                }
            }
        } else if (std.mem.eql(u8, cmd, "SHUTDOWN")) {
            input.tap(.sleep);
        } else {
            return error.InvalidCommand;
        }
    }
}
