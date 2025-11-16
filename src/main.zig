const std = @import("std");
const maml = @import("maml_zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file.maml>\n", .{args[0]});
        std.debug.print("\nParse and validate a MAML file.\n", .{});
        std.process.exit(1);
    }

    const filename = args[1];

    // Read file
    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        std.debug.print("Error: Could not open file '{s}': {}\n", .{ filename, err });
        std.process.exit(1);
    };
    defer file.close();

    const source = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch |err| {
        std.debug.print("Error: Could not read file '{s}': {}\n", .{ filename, err });
        std.process.exit(1);
    };
    defer allocator.free(source);

    std.debug.print("Parsing file: {s}\n\n", .{filename});

    // Parse MAML
    var value = maml.parse(allocator, source) catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        std.process.exit(1);
    };
    defer value.deinit(allocator);

    std.debug.print("Successfully parsed!\n\n", .{});

    // Display parsed structure
    printValue(&value, 0);
}

fn printValue(value: *const maml.Value, indent: usize) void {
    switch (value.*) {
        .object => |map| {
            std.debug.print("{{\n", .{});
            var it = map.iterator();
            while (it.next()) |entry| {
                printIndent(indent + 2);
                std.debug.print("{s}: ", .{entry.key_ptr.*});
                printValue(entry.value_ptr, indent + 2);
            }
            printIndent(indent);
            std.debug.print("}}\n", .{});
        },
        .array => |arr| {
            std.debug.print("[\n", .{});
            for (arr.items) |*item| {
                printIndent(indent + 2);
                printValue(item, indent + 2);
            }
            printIndent(indent);
            std.debug.print("]\n", .{});
        },
        .string => |s| std.debug.print("\"{s}\"\n", .{s}),
        .integer => |i| std.debug.print("{d}\n", .{i}),
        .float => |f| std.debug.print("{d}\n", .{f}),
        .boolean => |b| std.debug.print("{}\n", .{b}),
        .null_value => std.debug.print("null\n", .{}),
    }
}

fn printIndent(n: usize) void {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        std.debug.print(" ", .{});
    }
}
