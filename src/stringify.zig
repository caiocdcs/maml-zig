const std = @import("std");
const Allocator = std.mem.Allocator;

/// Options for stringifying MAML
pub const StringifyOptions = struct {
    /// Number of spaces for indentation (0 = compact, no newlines)
    indent: usize = 2,

    /// Use raw strings for multiline content
    use_raw_strings: bool = true,
};

/// Stringify any Zig value into MAML format
/// Returns an owned string that must be freed by the caller
pub fn stringify(allocator: Allocator, value: anytype, options: StringifyOptions) ![]u8 {
    var buffer: std.ArrayList(u8) = .empty;
    errdefer buffer.deinit(allocator);

    try stringifyAny(buffer.writer(allocator), value, options, 0);
    return buffer.toOwnedSlice(allocator);
}

/// Internal function to stringify any Zig type
fn stringifyAny(writer: anytype, value: anytype, options: StringifyOptions, depth: usize) anyerror!void {
    const T = @TypeOf(value);
    const type_info = @typeInfo(T);

    switch (type_info) {
        .null => try writer.writeAll("null"),
        .bool => try writer.writeAll(if (value) "true" else "false"),
        .int, .comptime_int => try writer.print("{d}", .{value}),
        .float, .comptime_float => try writer.print("{d}", .{value}),
        .pointer => |ptr_info| {
            switch (ptr_info.size) {
                .one => try stringifyAny(writer, value.*, options, depth),
                .slice => {
                    if (ptr_info.child == u8) {
                        // String slice
                        try stringifyString(writer, value, options);
                    } else {
                        // Array of other types
                        try stringifySlice(writer, value, options, depth);
                    }
                },
                else => @compileError("Unsupported pointer type"),
            }
        },
        .array => |arr_info| {
            if (arr_info.child == u8) {
                // String array
                try stringifyString(writer, &value, options);
            } else {
                try stringifySlice(writer, &value, options, depth);
            }
        },
        .@"struct" => |struct_info| {
            // Check for specific container types using duck-typing
            if (@hasDecl(T, "items") and @hasDecl(T, "capacity")) {
                // ArrayList-like type
                try stringifySlice(writer, value.items, options, depth);
            } else if (@hasDecl(T, "count") and @hasDecl(T, "iterator")) {
                // HashMap-like type (StringHashMap, StringArrayHashMap, etc.)
                try stringifyHashMap(writer, value, options, depth);
            } else if (struct_info.is_tuple) {
                // Tuple - treat as array
                try stringifyTuple(writer, value, options, depth);
            } else {
                // Regular struct - treat as object
                try stringifyStruct(writer, value, options, depth);
            }
        },
        .optional => {
            if (value) |v| {
                try stringifyAny(writer, v, options, depth);
            } else {
                try writer.writeAll("null");
            }
        },
        .@"enum" => {
            try stringifyString(writer, @tagName(value), options);
        },
        .@"union" => |union_info| {
            if (union_info.tag_type) |_| {
                // Tagged union (like Value)
                inline for (union_info.fields) |field| {
                    if (@intFromEnum(value) == @intFromEnum(@field(@TypeOf(value), field.name))) {
                        try stringifyAny(writer, @field(value, field.name), options, depth);
                        return;
                    }
                }
            } else {
                @compileError("Untagged unions are not supported");
            }
        },
        .void => try writer.writeAll("null"),
        else => @compileError("Unsupported type: " ++ @typeName(T)),
    }
}

/// Stringify a struct as a MAML object
fn stringifyStruct(writer: anytype, value: anytype, options: StringifyOptions, depth: usize) !void {
    const T = @TypeOf(value);
    const type_info = @typeInfo(T);
    const struct_info = type_info.@"struct";

    try writer.writeByte('{');

    const compact = options.indent == 0;
    var first = true;

    inline for (struct_info.fields) |field| {
        if (!first) {
            try writer.writeByte(',');
        }

        if (!compact) {
            try writer.writeByte('\n');
            try writeIndent(writer, options.indent, depth + 1);
        } else if (!first) {
            try writer.writeByte(' ');
        }

        // Write key
        if (isValidIdentifier(field.name)) {
            try writer.writeAll(field.name);
        } else {
            try stringifyString(writer, field.name, options);
        }

        try writer.writeAll(": ");
        try stringifyAny(writer, @field(value, field.name), options, depth + 1);

        first = false;
    }

    if (!compact and !first) {
        try writer.writeByte('\n');
        try writeIndent(writer, options.indent, depth);
    }

    try writer.writeByte('}');
}

/// Stringify a tuple as a MAML array
fn stringifyTuple(writer: anytype, value: anytype, options: StringifyOptions, depth: usize) !void {
    const type_info = @typeInfo(@TypeOf(value));
    const fields = type_info.@"struct".fields;

    try writer.writeByte('[');

    if (fields.len == 0) {
        try writer.writeByte(']');
        return;
    }

    const compact = options.indent == 0;

    inline for (fields, 0..) |field, i| {
        if (i > 0) {
            try writer.writeByte(',');
        }

        if (!compact) {
            try writer.writeByte('\n');
            try writeIndent(writer, options.indent, depth + 1);
        } else if (i > 0) {
            try writer.writeByte(' ');
        }

        try stringifyAny(writer, @field(value, field.name), options, depth + 1);
    }

    if (!compact) {
        try writer.writeByte('\n');
        try writeIndent(writer, options.indent, depth);
    }

    try writer.writeByte(']');
}

/// Stringify a slice as a MAML array
/// Expects a slice or array type
fn stringifySlice(writer: anytype, slice: anytype, options: StringifyOptions, depth: usize) !void {
    try writer.writeByte('[');

    if (slice.len == 0) {
        try writer.writeByte(']');
        return;
    }

    const compact = options.indent == 0;

    for (slice, 0..) |item, i| {
        if (i > 0) {
            try writer.writeByte(',');
        }

        if (!compact) {
            try writer.writeByte('\n');
            try writeIndent(writer, options.indent, depth + 1);
        } else if (i > 0) {
            try writer.writeByte(' ');
        }

        try stringifyAny(writer, item, options, depth + 1);
    }

    if (!compact) {
        try writer.writeByte('\n');
        try writeIndent(writer, options.indent, depth);
    }

    try writer.writeByte(']');
}

/// Stringify a HashMap as a MAML object
/// Expects a HashMap type (StringHashMap, StringArrayHashMap, etc.)
/// Requires: .count(), .iterator(), key_ptr, value_ptr
fn stringifyHashMap(writer: anytype, map: anytype, options: StringifyOptions, depth: usize) !void {
    try writer.writeByte('{');

    if (map.count() == 0) {
        try writer.writeByte('}');
        return;
    }

    const compact = options.indent == 0;

    var it = map.iterator();
    var i: usize = 0;
    while (it.next()) |entry| {
        if (i > 0) {
            try writer.writeByte(',');
        }

        if (!compact) {
            try writer.writeByte('\n');
            try writeIndent(writer, options.indent, depth + 1);
        } else if (i > 0) {
            try writer.writeByte(' ');
        }

        // Write key
        const key_ptr = entry.key_ptr.*;
        const key_str = blk: {
            const K = @TypeOf(key_ptr);
            if (K == []const u8 or K == []u8) {
                break :blk key_ptr;
            } else {
                @compileError("HashMap keys must be strings");
            }
        };

        if (isValidIdentifier(key_str)) {
            try writer.writeAll(key_str);
        } else {
            try stringifyString(writer, key_str, options);
        }

        try writer.writeAll(": ");
        try stringifyAny(writer, entry.value_ptr.*, options, depth + 1);

        i += 1;
    }

    if (!compact) {
        try writer.writeByte('\n');
        try writeIndent(writer, options.indent, depth);
    }

    try writer.writeByte('}');
}

/// Stringify a string with proper escaping
fn stringifyString(writer: anytype, s: []const u8, options: StringifyOptions) !void {
    // Check if string contains newlines and use raw string if enabled
    if (options.use_raw_strings and std.mem.indexOf(u8, s, "\n") != null) {
        try writer.writeAll("\"\"\"");
        try writer.writeAll(s);
        try writer.writeAll("\"\"\"");
        return;
    }

    try writer.writeByte('"');
    for (s) |c| {
        switch (c) {
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            else => {
                if (c < 32 or c == 127) {
                    try writer.print("\\u{{{x}}}", .{c});
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
    try writer.writeByte('"');
}

/// Write indentation spaces
fn writeIndent(writer: anytype, indent: usize, depth: usize) !void {
    const spaces = indent * depth;
    var i: usize = 0;
    while (i < spaces) : (i += 1) {
        try writer.writeByte(' ');
    }
}

/// Check if a string is a valid MAML identifier (can be unquoted as a key)
fn isValidIdentifier(s: []const u8) bool {
    if (s.len == 0) return false;

    // Check for reserved words
    if (std.mem.eql(u8, s, "true") or
        std.mem.eql(u8, s, "false") or
        std.mem.eql(u8, s, "null"))
    {
        return false;
    }

    for (s, 0..) |c, i| {
        if (i == 0) {
            // First character must be letter or underscore
            if (!((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_')) {
                return false;
            }
        } else {
            // Subsequent characters can be letter, digit, underscore, or hyphen
            if (!((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or
                (c >= '0' and c <= '9') or c == '_' or c == '-'))
            {
                return false;
            }
        }
    }
    return true;
}
