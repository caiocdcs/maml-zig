# maml-zig

A minimal, spec-compliant MAML (Minimal Abstract Markup Language) parser implementation in Zig.

## What is MAML?

MAML is a minimal configuration format designed to be easily readable by humans and easily parsed by machines. Think of it as a simpler alternative to JSON, TOML, or YAML.

Learn more at: https://maml.dev/spec/v0.1

## Features

- Full MAML v0.1 spec compliance
- Zero dependencies (only Zig standard library)
- Simple, clean API
- Proper memory management with allocators
- Comprehensive test coverage

## Installation

### Standalone

Clone the repository:

```bash
git clone https://github.com/caiocdcs/maml-zig.git
cd maml-zig
```

Build:

```bash
zig build
```

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

## Usage

### As a Library

```zig
const std = @import("std");
const maml = @import("maml_zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source =
        \\{
        \\  name: "My App"
        \\  version: 1
        \\  enabled: true
        \\}
    ;

    var value = try maml.parse(allocator, source);
    defer value.deinit(allocator);

    if (value == .object) {
        const name = value.object.get("name").?.string;
        std.debug.print("Name: {s}\n", .{name});
    }
}
```

### As a CLI Tool

Parse a MAML file:

```bash
# Build
zig build

# Parse a file
./zig-out/bin/maml_zig example.maml
```

Or run directly:

```bash
zig build run -- example.maml
```

## Value Types

The parser returns a `Value` union with these variants:

- `object` - Key-value pairs (std.StringHashMap)
- `array` - List of values (std.ArrayList)
- `string` - UTF-8 string
- `integer` - 64-bit signed integer
- `float` - 64-bit floating point
- `boolean` - true or false
- `null_value` - null

## Building and Testing

Run the example:
```bash
zig build run -- example.maml
```

Run all tests:
```bash
zig build test --summary all
```

## MAML Syntax

MAML supports:
- Objects: `{ key: "value" }`
- Arrays: `[1, 2, 3]`
- Strings: `"hello"`
- Raw strings: `"""multiline text"""`
- Numbers: `42`, `3.14`, `1e-10`
- Booleans: `true`, `false`
- Null: `null`
- Comments: `# comment`

See `example.maml` for a complete example.

For full syntax details, visit: https://maml.dev/spec/v0.1

## Error Handling

The parser returns descriptive errors:
- `UnterminatedString` - Missing closing quote
- `UnterminatedRawString` - Missing closing """
- `InvalidEscape` - Invalid escape sequence
- `UnexpectedCharacter` - Invalid character
- `UnexpectedToken` - Token in wrong context
- `ExpectedColon` - Missing : in object
- `DuplicateKey` - Object has duplicate keys

## License

MIT License.
