const std = @import("std");
const Allocator = std.mem.Allocator;

// Public exports
pub const Value = @import("value.zig").Value;
pub const ParseError = @import("parser.zig").ParseError;
pub const Parser = @import("parser.zig").Parser;
pub const Lexer = @import("lexer.zig").Lexer;
pub const Token = @import("token.zig").Token;
pub const TokenType = @import("token.zig").TokenType;

const stringify_mod = @import("stringify.zig");
pub const StringifyOptions = stringify_mod.StringifyOptions;

/// Parse MAML source into a Value tree
pub fn parse(allocator: Allocator, source: []const u8) !Value {
    var parser = try Parser.init(allocator, source);
    return try parser.parse();
}

/// Parse MAML from a byte slice into a Value tree
/// This is the recommended API for parsing MAML
pub fn parseFromSlice(allocator: Allocator, source: []const u8) !Value {
    var parser = try Parser.init(allocator, source);
    return try parser.parse();
}

/// Stringify any Zig value into MAML format
/// Returns an owned string that must be freed by the caller
///
/// Example:
///   const Person = struct { name: []const u8, age: u32 };
///   const person = Person{ .name = "Alice", .age = 30 };
///   const maml_str = try maml.stringify(allocator, person, .{});
///   defer allocator.free(maml_str);
pub fn stringify(allocator: Allocator, value: anytype, options: StringifyOptions) ![]u8 {
    return try stringify_mod.stringify(allocator, value, options);
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

test "parseFromSlice - simple values" {
    const allocator = std.testing.allocator;

    // String
    var v1 = try parseFromSlice(allocator, "\"hello\"");
    defer v1.deinit(allocator);
    try std.testing.expectEqualStrings("hello", v1.string);

    // Integer
    var v2 = try parseFromSlice(allocator, "42");
    defer v2.deinit(allocator);
    try std.testing.expectEqual(@as(i64, 42), v2.integer);

    // Boolean
    var v3 = try parseFromSlice(allocator, "true");
    defer v3.deinit(allocator);
    try std.testing.expect(v3.boolean == true);

    // Null
    var v4 = try parseFromSlice(allocator, "null");
    defer v4.deinit(allocator);
    try std.testing.expect(v4 == .null_value);
}

test "parseFromSlice - object" {
    const allocator = std.testing.allocator;
    const source = "{ name: \"John\", age: 30, active: true }";

    var value = try parseFromSlice(allocator, source);
    defer value.deinit(allocator);

    try std.testing.expect(value == .object);
    try std.testing.expectEqualStrings("John", value.object.get("name").?.string);
    try std.testing.expectEqual(@as(i64, 30), value.object.get("age").?.integer);
    try std.testing.expect(value.object.get("active").?.boolean == true);
}

test "parseFromSlice - array" {
    const allocator = std.testing.allocator;
    const source = "[1, 2, 3, 4, 5]";

    var value = try parseFromSlice(allocator, source);
    defer value.deinit(allocator);

    try std.testing.expect(value == .array);
    try std.testing.expectEqual(@as(usize, 5), value.array.items.len);
    try std.testing.expectEqual(@as(i64, 3), value.array.items[2].integer);
}

test "stringify - primitives" {
    const allocator = std.testing.allocator;

    // Null
    const r1 = try stringify(allocator, null, .{});
    defer allocator.free(r1);
    try std.testing.expectEqualStrings("null", r1);

    // Boolean
    const r2 = try stringify(allocator, true, .{});
    defer allocator.free(r2);
    try std.testing.expectEqualStrings("true", r2);

    // Integer
    const r3 = try stringify(allocator, @as(i32, 42), .{});
    defer allocator.free(r3);
    try std.testing.expectEqualStrings("42", r3);

    // Float
    const r4 = try stringify(allocator, @as(f32, 3.14), .{});
    defer allocator.free(r4);
    try std.testing.expectEqualStrings("3.14", r4);

    // String
    const r5 = try stringify(allocator, "hello", .{});
    defer allocator.free(r5);
    try std.testing.expectEqualStrings("\"hello\"", r5);
}

test "stringify - struct" {
    const allocator = std.testing.allocator;

    const Person = struct {
        name: []const u8,
        age: u32,
        active: bool,
    };

    const person = Person{
        .name = "Alice",
        .age = 30,
        .active = true,
    };

    const result = try stringify(allocator, person, .{ .indent = 0 });
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "name: \"Alice\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "age: 30") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "active: true") != null);
}

test "stringify - struct formatted" {
    const allocator = std.testing.allocator;

    const Config = struct {
        port: u16,
        debug: bool,
    };

    const config = Config{
        .port = 8080,
        .debug = false,
    };

    const result = try stringify(allocator, config, .{ .indent = 2 });
    defer allocator.free(result);

    try std.testing.expect(std.mem.startsWith(u8, result, "{\n"));
    try std.testing.expect(std.mem.endsWith(u8, result, "\n}"));
}

test "stringify - array slice" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const result = try stringify(allocator, &numbers, .{ .indent = 0 });
    defer allocator.free(result);

    try std.testing.expectEqualStrings("[1, 2, 3, 4, 5]", result);
}

test "stringify - nested struct" {
    const allocator = std.testing.allocator;

    const Address = struct {
        city: []const u8,
        zip: u32,
    };

    const Person = struct {
        name: []const u8,
        address: Address,
    };

    const person = Person{
        .name = "Bob",
        .address = .{
            .city = "NYC",
            .zip = 10001,
        },
    };

    const result = try stringify(allocator, person, .{ .indent = 2 });
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "name: \"Bob\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "city: \"NYC\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "zip: 10001") != null);
}

test "stringify - optional values" {
    const allocator = std.testing.allocator;

    const Data = struct {
        required: []const u8,
        optional: ?i32,
    };

    const data1 = Data{
        .required = "test",
        .optional = 42,
    };

    const r1 = try stringify(allocator, data1, .{ .indent = 0 });
    defer allocator.free(r1);
    try std.testing.expect(std.mem.indexOf(u8, r1, "optional: 42") != null);

    const data2 = Data{
        .required = "test",
        .optional = null,
    };

    const r2 = try stringify(allocator, data2, .{ .indent = 0 });
    defer allocator.free(r2);
    try std.testing.expect(std.mem.indexOf(u8, r2, "optional: null") != null);
}

test "stringify - enum" {
    const allocator = std.testing.allocator;

    const Status = enum { active, inactive, pending };

    const result = try stringify(allocator, Status.active, .{});
    defer allocator.free(result);

    try std.testing.expectEqualStrings("\"active\"", result);
}

test "stringify - Value type (backward compatibility)" {
    const allocator = std.testing.allocator;
    var obj = std.StringArrayHashMap(Value).init(allocator);

    const key = try allocator.dupe(u8, "test");
    const str = try allocator.dupe(u8, "value");
    try obj.put(key, Value{ .string = str });

    var value = Value{ .object = obj };
    defer value.deinit(allocator);

    const result = try stringify(allocator, value, .{ .indent = 0 });
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "test: \"value\"") != null);
}

test "stringify - round trip" {
    const allocator = std.testing.allocator;
    const source =
        \\{
        \\  name: "MAML"
        \\  version: 1
        \\  active: true
        \\}
    ;

    var value1 = try parseFromSlice(allocator, source);
    defer value1.deinit(allocator);

    const stringified = try stringify(allocator, value1, .{});
    defer allocator.free(stringified);

    var value2 = try parseFromSlice(allocator, stringified);
    defer value2.deinit(allocator);

    try std.testing.expectEqualStrings("MAML", value2.object.get("name").?.string);
    try std.testing.expectEqual(@as(i64, 1), value2.object.get("version").?.integer);
    try std.testing.expect(value2.object.get("active").?.boolean == true);
}

test "object preserves insertion order" {
    const allocator = std.testing.allocator;
    const source = "{ first: 1, second: 2, third: 3, fourth: 4 }";

    var value = try parseFromSlice(allocator, source);
    defer value.deinit(allocator);

    // Check keys are in insertion order
    const keys = value.object.keys();
    try std.testing.expectEqualStrings("first", keys[0]);
    try std.testing.expectEqualStrings("second", keys[1]);
    try std.testing.expectEqualStrings("third", keys[2]);
    try std.testing.expectEqualStrings("fourth", keys[3]);

    // Verify stringify maintains order
    const stringified = try stringify(allocator, value, .{ .indent = 0 });
    defer allocator.free(stringified);

    // Keys should appear in the same order
    const first_pos = std.mem.indexOf(u8, stringified, "first").?;
    const second_pos = std.mem.indexOf(u8, stringified, "second").?;
    const third_pos = std.mem.indexOf(u8, stringified, "third").?;
    const fourth_pos = std.mem.indexOf(u8, stringified, "fourth").?;

    try std.testing.expect(first_pos < second_pos);
    try std.testing.expect(second_pos < third_pos);
    try std.testing.expect(third_pos < fourth_pos);
}
