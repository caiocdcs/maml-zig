const std = @import("std");
const Allocator = std.mem.Allocator;

// Public exports
pub const Value = @import("value.zig").Value;
pub const ParseError = @import("parser.zig").ParseError;
pub const Parser = @import("parser.zig").Parser;
pub const Lexer = @import("lexer.zig").Lexer;
pub const Token = @import("token.zig").Token;
pub const TokenType = @import("token.zig").TokenType;

/// Parse MAML source into a Value tree
pub fn parse(allocator: Allocator, source: []const u8) !Value {
    var parser = try Parser.init(allocator, source);
    return try parser.parse();
}

// Tests
test "parse string" {
    const allocator = std.testing.allocator;
    var value = try parse(allocator, "\"hello\"");
    defer value.deinit(allocator);

    try std.testing.expect(value == .string);
    try std.testing.expectEqualStrings("hello", value.string);
}

test "parse integer" {
    const allocator = std.testing.allocator;
    var value = try parse(allocator, "42");
    defer value.deinit(allocator);

    try std.testing.expect(value == .integer);
    try std.testing.expectEqual(@as(i64, 42), value.integer);
}

test "parse boolean" {
    const allocator = std.testing.allocator;
    var value1 = try parse(allocator, "true");
    defer value1.deinit(allocator);
    var value2 = try parse(allocator, "false");
    defer value2.deinit(allocator);

    try std.testing.expect(value1.boolean == true);
    try std.testing.expect(value2.boolean == false);
}

test "parse null" {
    const allocator = std.testing.allocator;
    var value = try parse(allocator, "null");
    defer value.deinit(allocator);

    try std.testing.expect(value == .null_value);
}

test "parse array" {
    const allocator = std.testing.allocator;
    var value = try parse(allocator, "[1, 2, 3]");
    defer value.deinit(allocator);

    try std.testing.expect(value == .array);
    try std.testing.expectEqual(@as(usize, 3), value.array.items.len);
}

test "parse object" {
    const allocator = std.testing.allocator;
    var value = try parse(allocator, "{ foo: \"bar\" }");
    defer value.deinit(allocator);

    try std.testing.expect(value == .object);
    const result = value.object.get("foo").?;
    try std.testing.expectEqualStrings("bar", result.string);
}

test "parse raw string" {
    const allocator = std.testing.allocator;
    var value = try parse(allocator, "\"\"\"hello\\nworld\"\"\"");
    defer value.deinit(allocator);

    try std.testing.expect(value == .string);
    try std.testing.expectEqualStrings("hello\\nworld", value.string);
}

test "parse complex object" {
    const allocator = std.testing.allocator;
    const source =
        \\{
        \\  name: "MAML"
        \\  version: 1
        \\  active: true
        \\  tags: ["minimal", "readable"]
        \\}
    ;
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    try std.testing.expect(value == .object);
    try std.testing.expectEqualStrings("MAML", value.object.get("name").?.string);
    try std.testing.expectEqual(@as(i64, 1), value.object.get("version").?.integer);
    try std.testing.expect(value.object.get("active").?.boolean == true);
}
