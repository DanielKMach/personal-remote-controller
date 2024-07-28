const main = @import("main.zig");
const testing = @import("std").testing;

test "key generation" {
    // Test keys from https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers#server_handshake_response
    const request_key = "dGhlIHNhbXBsZSBub25jZQ==";
    const expected = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=";
    const actual = try main.generateHandshakeKey(request_key, testing.allocator);
    defer testing.allocator.free(actual);
    try testing.expectEqualStrings(expected, actual);
}
