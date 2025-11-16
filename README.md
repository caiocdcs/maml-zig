# maml-zig

A minimal, spec-compliant MAML (Minimal Abstract Markup Language) parser implementation in Zig.

## What is MAML?

MAML is a minimal configuration format designed to be easily readable by humans and easily parsed by machines. Think of it as a simpler alternative to JSON, TOML, or YAML.

Learn more at: https://maml.dev

## Features

- MAML v0.1 spec compliance
- Zero dependencies (only Zig standard library)
- Simple, clean API similar to `std.json`
- Parse and stringify support
- Proper memory management with allocators
- Comprehensive test coverage


## Installation

### Add to Your Project

Using build.zig.zon (recommended)

Add to your `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .maml_zig = .{
            .url = "https://github.com/caiocdcs/maml-zig/archive/refs/heads/main.tar.gz",
            // Run 'zig fetch' to get the hash
            .hash = "1220abcdef...",
        },
    },
}
```

Then in your `build.zig`:

```zig
const maml_zig = b.dependency("maml_zig", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("maml_zig", maml_zig.module("maml_zig"));
```

### Standalone

Clone the repository:

```bash
git clone https://github.com/caiocdcs/maml-zig.git
cd maml-zig
zig build
```

## Usage

### Parsing MAML

Use `parseFromSlice` to parse MAML from a string:

```zig
const std = @import("std");
const maml = @import("maml_zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source =
        \\{
        \\  name: "MAML"
        \\  version: 1
        \\  active: true
        \\  tags: ["minimal", "readable", "fast"]
        \\}
    ;

    // Parse MAML from slice
    var value = try maml.parseFromSlice(allocator, source);
    defer value.deinit(allocator);

    // Access object fields
    const name = value.object.get("name").?.string;
    const version = value.object.get("version").?.integer;
    const active = value.object.get("active").?.boolean;
    
    std.debug.print("Name: {s}\n", .{name});
    std.debug.print("Version: {d}\n", .{version});
    std.debug.print("Active: {}\n", .{active});

    // Access array elements
    const tags = value.object.get("tags").?.array;
    for (tags.items) |tag| {
        std.debug.print("Tag: {s}\n", .{tag.string});
    }
}
```

Alternative: You can also use `parse()` which works identically:

```zig
var value = try maml.parse(allocator, source);
defer value.deinit(allocator);
```

### Stringifying Values

Use `stringify` to convert any Zig value to MAML format:

```zig
const std = @import("std");
const maml = @import("maml_zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Define a struct
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

    // Stringify with formatting (2-space indentation)
    const formatted = try maml.stringify(allocator, person, .{ .indent = 2 });
    defer allocator.free(formatted);
    std.debug.print("Formatted:\n{s}\n", .{formatted});
    // Output:
    // {
    //   name: "Alice",
    //   age: 30,
    //   active: true
    // }

    // Stringify compact (no whitespace)
    const compact = try maml.stringify(allocator, person, .{ .indent = 0 });
    defer allocator.free(compact);
    std.debug.print("Compact: {s}\n", .{compact});
    // Output: {name: "Alice", age: 30, active: true}
}
```

### CLI Tool

Parse and validate MAML files:

```bash
# Build
zig build

# Parse a file
./zig-out/bin/maml_zig examples/full_example.maml
```

Or run directly:

```bash
zig build run -- examples/full_example.maml
```

## API Reference

### Parsing Functions

#### `parseFromSlice(allocator: Allocator, source: []const u8) !Value`

Parse MAML from a byte slice into a `Value` tree.

```zig
var value = try maml.parseFromSlice(allocator, "{ key: \"value\" }");
defer value.deinit(allocator);
```

#### `parse(allocator: Allocator, source: []const u8) !Value`

Alternative parsing function that works identically to `parseFromSlice()`.

```zig
var value = try maml.parse(allocator, "{ key: \"value\" }");
defer value.deinit(allocator);
```

### Stringification Functions

#### `stringify(allocator: Allocator, value: anytype, options: StringifyOptions) ![]u8`

Convert any Zig value into MAML format. Returns an owned string that must be freed by the caller.

Supports:
- Structs (as MAML objects)
- Arrays and slices (as MAML arrays)
- Primitives (integers, floats, booleans, strings)
- Optionals (null when empty)
- Enums (as strings)
- Nested structures

```zig
const Person = struct { name: []const u8, age: u32 };
const person = Person{ .name = "Alice", .age = 30 };

const result = try maml.stringify(allocator, person, .{ .indent = 2 });
defer allocator.free(result);
```

**StringifyOptions:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `indent` | `usize` | `2` | Number of spaces for indentation. Use `0` for compact output (no newlines). |
| `use_raw_strings` | `bool` | `true` | Use raw strings (`"""..."""`) for multiline content. |

**Examples:**

```zig
const Config = struct { port: u16, debug: bool };
const config = Config{ .port = 8080, .debug = true };

// Pretty-printed with 2-space indentation
const formatted = try maml.stringify(allocator, config, .{ .indent = 2 });

// Pretty-printed with 4-space indentation
const formatted4 = try maml.stringify(allocator, config, .{ .indent = 4 });

// Compact (single line, no spaces)
const compact = try maml.stringify(allocator, config, .{ .indent = 0 });

// Disable raw strings for multiline content
const escaped = try maml.stringify(allocator, config, .{ 
    .indent = 2, 
    .use_raw_strings = false 
});
```

### Value Types

The `Value` union represents all MAML data types:

| Variant | Zig Type | Description |
|---------|----------|-------------|
| `.object` | `std.StringArrayHashMap(Value)` | Key-value pairs (MAML object, preserves insertion order) |
| `.array` | `std.ArrayList(Value)` | Ordered list of values |
| `.string` | `[]const u8` | UTF-8 string |
| `.integer` | `i64` | 64-bit signed integer |
| `.float` | `f64` | 64-bit floating point number |
| `.boolean` | `bool` | `true` or `false` |
| `.null_value` | `void` | Null value |

**Memory Management:**

All `Value` instances own their memory and must be deinitialized:

```zig
var value = try maml.parseFromSlice(allocator, source);
defer value.deinit(allocator); // Required to free memory
```

### Error Handling

The parser returns descriptive errors:

- `UnterminatedString` - Missing closing quote
- `UnterminatedRawString` - Missing closing `"""`
- `InvalidEscape` - Invalid escape sequence in string
- `UnexpectedCharacter` - Invalid character in source
- `UnexpectedToken` - Token in wrong context
- `ExpectedColon` - Missing `:` in object
- `ExpectedRightBrace` - Missing `}` in object
- `ExpectedRightBracket` - Missing `]` in array
- `DuplicateKey` - Object has duplicate keys

## MAML Syntax

MAML supports the following data types:

- **Objects**: `{ key: "value", another: 42 }`
- **Arrays**: `[1, 2, 3]`
- **Strings**: `"hello world"`
- **Raw strings**: `"""multiline\ntext"""`
- **Numbers**: `42`, `3.14`, `1e-10`
- **Booleans**: `true`, `false`
- **Null**: `null`
- **Comments**: `# this is a comment`

See `examples/full_example.maml` for a complete example, or visit https://maml.dev/spec/v0.1 for the full specification.

## Building and Testing

Run all tests:
```bash
zig build test --summary all
```

Run the CLI tool:
```bash
zig build run -- examples/full_example.maml
```

Build for release:
```bash
zig build -Doptimize=ReleaseFast
```

## License

MIT License.
