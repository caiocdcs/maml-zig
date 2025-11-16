const std = @import("std");
const Allocator = std.mem.Allocator;
const value_mod = @import("value.zig");
const Value = value_mod.Value;
const token_mod = @import("token.zig");
const Token = token_mod.Token;
const TokenType = token_mod.TokenType;
const lexer_mod = @import("lexer.zig");
const Lexer = lexer_mod.Lexer;
const LexerError = lexer_mod.LexerError;

pub const ParseError = error{
    UnexpectedToken,
    ExpectedColon,
    ExpectedRightBrace,
    ExpectedRightBracket,
    ExpectedKey,
    InvalidEscape,
    DuplicateKey,
    CodepointTooLarge,
    Utf8CannotEncodeSurrogateHalf,
} || std.fmt.ParseIntError || std.fmt.ParseFloatError || Allocator.Error || LexerError;

pub const Parser = struct {
    lexer: Lexer,
    current_token: Token,
    allocator: Allocator,

    pub fn init(allocator: Allocator, source: []const u8) !Parser {
        var lexer = Lexer.init(source);
        const token = try lexer.nextToken();
        return Parser{
            .lexer = lexer,
            .current_token = token,
            .allocator = allocator,
        };
    }

    fn advance(self: *Parser) !void {
        self.current_token = try self.lexer.nextToken();
    }

    fn check(self: *const Parser, token_type: TokenType) bool {
        return self.current_token.type == token_type;
    }

    fn match(self: *Parser, token_type: TokenType) !bool {
        if (self.check(token_type)) {
            try self.advance();
            return true;
        }
        return false;
    }

    pub fn parse(self: *Parser) !Value {
        return try self.parseValue();
    }

    fn parseValue(self: *Parser) ParseError!Value {
        return switch (self.current_token.type) {
            .left_brace => try self.parseObject(),
            .left_bracket => try self.parseArray(),
            .string => try self.parseString(),
            .raw_string => try self.parseRawString(),
            .integer => try self.parseInteger(),
            .float => try self.parseFloat(),
            .true_literal => try self.parseBoolean(true),
            .false_literal => try self.parseBoolean(false),
            .null_literal => try self.parseNull(),
            else => error.UnexpectedToken,
        };
    }

    fn parseObject(self: *Parser) ParseError!Value {
        var map = std.StringArrayHashMap(Value).init(self.allocator);
        errdefer {
            var it = map.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit(self.allocator);
            }
            map.deinit();
        }

        _ = try self.match(.left_brace);

        while (!self.check(.right_brace) and !self.check(.eof)) {
            const key = try self.parseKey();
            errdefer self.allocator.free(key);

            if (!try self.match(.colon)) return error.ExpectedColon;

            var value = try self.parseValue();
            errdefer value.deinit(self.allocator);

            if (map.contains(key)) {
                self.allocator.free(key);
                value.deinit(self.allocator);
                return error.DuplicateKey;
            }

            try map.put(key, value);

            _ = try self.match(.comma);
        }

        if (!try self.match(.right_brace)) return error.ExpectedRightBrace;

        return Value{ .object = map };
    }

    fn parseArray(self: *Parser) ParseError!Value {
        var arr: std.ArrayList(Value) = .empty;
        errdefer {
            for (arr.items) |*item| item.deinit(self.allocator);
            arr.deinit(self.allocator);
        }

        _ = try self.match(.left_bracket);

        while (!self.check(.right_bracket) and !self.check(.eof)) {
            var value = try self.parseValue();
            errdefer value.deinit(self.allocator);
            try arr.append(self.allocator, value);

            _ = try self.match(.comma);
        }

        if (!try self.match(.right_bracket)) return error.ExpectedRightBracket;

        return Value{ .array = arr };
    }

    fn parseKey(self: *Parser) ParseError![]const u8 {
        if (self.check(.string)) {
            return try self.parseStringContent();
        } else if (self.check(.identifier)) {
            const key = try self.allocator.dupe(u8, self.current_token.lexeme);
            try self.advance();
            return key;
        }
        return error.ExpectedKey;
    }

    fn parseString(self: *Parser) ParseError!Value {
        const content = try self.parseStringContent();
        return Value{ .string = content };
    }

    fn parseStringContent(self: *Parser) ParseError![]const u8 {
        const lexeme = self.current_token.lexeme;
        try self.advance();

        const content = lexeme[1 .. lexeme.len - 1];
        var result: std.ArrayList(u8) = .empty;
        errdefer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < content.len) {
            if (content[i] == '\\' and i + 1 < content.len) {
                i += 1;
                const escaped = content[i];
                const char: u8 = switch (escaped) {
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    '"' => '"',
                    '\\' => '\\',
                    'u' => {
                        i += 1;
                        if (i >= content.len or content[i] != '{') return error.InvalidEscape;
                        i += 1;
                        const start = i;
                        while (i < content.len and content[i] != '}') : (i += 1) {}
                        if (i >= content.len) return error.InvalidEscape;
                        const hex_str = content[start..i];
                        const codepoint = try std.fmt.parseInt(u21, hex_str, 16);
                        var utf8_buf: [4]u8 = undefined;
                        const len = try std.unicode.utf8Encode(codepoint, &utf8_buf);
                        try result.appendSlice(self.allocator, utf8_buf[0..len]);
                        i += 1;
                        continue;
                    },
                    else => return error.InvalidEscape,
                };
                try result.append(self.allocator, char);
            } else {
                try result.append(self.allocator, content[i]);
            }
            i += 1;
        }

        return result.toOwnedSlice(self.allocator);
    }

    fn parseRawString(self: *Parser) ParseError!Value {
        const lexeme = self.current_token.lexeme;
        try self.advance();

        const content = lexeme[3 .. lexeme.len - 3];
        const owned = try self.allocator.dupe(u8, content);
        return Value{ .string = owned };
    }

    fn parseInteger(self: *Parser) ParseError!Value {
        const value = try std.fmt.parseInt(i64, self.current_token.lexeme, 10);
        try self.advance();
        return Value{ .integer = value };
    }

    fn parseFloat(self: *Parser) ParseError!Value {
        const value = try std.fmt.parseFloat(f64, self.current_token.lexeme);
        try self.advance();
        return Value{ .float = value };
    }

    fn parseBoolean(self: *Parser, value: bool) ParseError!Value {
        try self.advance();
        return Value{ .boolean = value };
    }

    fn parseNull(self: *Parser) ParseError!Value {
        try self.advance();
        return Value{ .null_value = {} };
    }
};
