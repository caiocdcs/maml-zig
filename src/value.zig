const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Value = union(enum) {
    object: std.StringHashMap(Value),
    array: std.ArrayList(Value),
    string: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,
    null_value,

    pub fn deinit(self: *Value, allocator: Allocator) void {
        switch (self.*) {
            .object => |*map| {
                var it = map.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                map.deinit();
            },
            .array => |*arr| {
                for (arr.items) |*item| {
                    item.deinit(allocator);
                }
                arr.deinit(allocator);
            },
            .string => |s| allocator.free(s),
            else => {},
        }
    }
};
