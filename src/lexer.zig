const std = @import("std");
const token = @import("token.zig");
const Token = token.Token;
const TokenType = token.TokenType;

pub const LexerError = error{
    UnterminatedString,
    UnterminatedRawString,
    UnexpectedCharacter,
};

pub const Lexer = struct {
    source: []const u8,
    start: usize = 0,
    current: usize = 0,
    line: usize = 1,
    column: usize = 1,

    pub fn init(source: []const u8) Lexer {
        return .{ .source = source };
    }

    fn isAtEnd(self: *const Lexer) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;
        self.column += 1;
        return c;
    }

    fn peek(self: *const Lexer) ?u8 {
        if (self.isAtEnd()) return null;
        return self.source[self.current];
    }

    fn peekNext(self: *const Lexer) ?u8 {
        if (self.current + 1 >= self.source.len) return null;
        return self.source[self.current + 1];
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.peek()) |c| {
            switch (c) {
                ' ', '\t' => _ = self.advance(),
                '\n' => {
                    _ = self.advance();
                    self.line += 1;
                    self.column = 1;
                },
                '\r' => {
                    _ = self.advance();
                    if (self.peek() == '\n') {
                        _ = self.advance();
                    }
                    self.line += 1;
                    self.column = 1;
                },
                '#' => self.skipComment(),
                else => return,
            }
        }
    }

    fn skipComment(self: *Lexer) void {
        while (self.peek()) |c| {
            if (c == '\n' or c == '\r') return;
            _ = self.advance();
        }
    }

    fn scanString(self: *Lexer) !Token {
        const line = self.line;
        const column = self.column - 1;
        _ = self.advance(); // consume opening "

        while (self.peek()) |c| {
            if (c == '"') {
                const lexeme = self.source[self.start .. self.current + 1];
                _ = self.advance();
                return Token{ .type = .string, .lexeme = lexeme, .line = line, .column = column };
            }
            if (c == '\\') {
                _ = self.advance();
                if (!self.isAtEnd()) _ = self.advance();
            } else {
                _ = self.advance();
            }
        }
        return error.UnterminatedString;
    }

    fn scanRawString(self: *Lexer) !Token {
        const line = self.line;
        const column = self.column - 1;
        _ = self.advance(); // first "
        _ = self.advance(); // second "
        _ = self.advance(); // third "

        if (self.peek() == '\n') {
            _ = self.advance();
            self.line += 1;
            self.column = 1;
        }

        var quote_count: usize = 0;
        while (!self.isAtEnd()) {
            const c = self.peek().?;
            if (c == '"') {
                quote_count += 1;
                _ = self.advance();
                if (quote_count == 3) {
                    const lexeme = self.source[self.start..self.current];
                    return Token{ .type = .raw_string, .lexeme = lexeme, .line = line, .column = column };
                }
            } else {
                quote_count = 0;
                if (c == '\n') {
                    self.line += 1;
                    self.column = 0;
                }
                _ = self.advance();
            }
        }
        return error.UnterminatedRawString;
    }

    fn scanNumber(self: *Lexer) Token {
        const line = self.line;
        const column = self.column - 1;
        var is_float = false;

        while (self.peek()) |c| {
            if (c >= '0' and c <= '9') {
                _ = self.advance();
            } else if (c == '.') {
                if (is_float) break;
                is_float = true;
                _ = self.advance();
            } else if (c == 'e' or c == 'E') {
                is_float = true;
                _ = self.advance();
                if (self.peek()) |next| {
                    if (next == '+' or next == '-') _ = self.advance();
                }
            } else {
                break;
            }
        }

        const lexeme = self.source[self.start..self.current];
        const token_type: TokenType = if (is_float) .float else .integer;
        return Token{ .type = token_type, .lexeme = lexeme, .line = line, .column = column };
    }

    fn scanIdentifier(self: *Lexer) Token {
        const line = self.line;
        const column = self.column - 1;

        while (self.peek()) |c| {
            if ((c >= 'a' and c <= 'z') or
                (c >= 'A' and c <= 'Z') or
                (c >= '0' and c <= '9') or
                c == '_' or c == '-')
            {
                _ = self.advance();
            } else {
                break;
            }
        }

        const lexeme = self.source[self.start..self.current];
        const token_type = if (std.mem.eql(u8, lexeme, "true"))
            TokenType.true_literal
        else if (std.mem.eql(u8, lexeme, "false"))
            TokenType.false_literal
        else if (std.mem.eql(u8, lexeme, "null"))
            TokenType.null_literal
        else
            TokenType.identifier;

        return Token{ .type = token_type, .lexeme = lexeme, .line = line, .column = column };
    }

    pub fn nextToken(self: *Lexer) LexerError!Token {
        self.skipWhitespace();
        self.start = self.current;

        if (self.isAtEnd()) {
            return Token{ .type = .eof, .lexeme = "", .line = self.line, .column = self.column };
        }

        const c = self.peek().?;
        const line = self.line;
        const column = self.column;

        return switch (c) {
            '{' => blk: {
                _ = self.advance();
                break :blk Token{ .type = .left_brace, .lexeme = self.source[self.start..self.current], .line = line, .column = column };
            },
            '}' => blk: {
                _ = self.advance();
                break :blk Token{ .type = .right_brace, .lexeme = self.source[self.start..self.current], .line = line, .column = column };
            },
            '[' => blk: {
                _ = self.advance();
                break :blk Token{ .type = .left_bracket, .lexeme = self.source[self.start..self.current], .line = line, .column = column };
            },
            ']' => blk: {
                _ = self.advance();
                break :blk Token{ .type = .right_bracket, .lexeme = self.source[self.start..self.current], .line = line, .column = column };
            },
            ':' => blk: {
                _ = self.advance();
                break :blk Token{ .type = .colon, .lexeme = self.source[self.start..self.current], .line = line, .column = column };
            },
            ',' => blk: {
                _ = self.advance();
                break :blk Token{ .type = .comma, .lexeme = self.source[self.start..self.current], .line = line, .column = column };
            },
            '"' => {
                if (self.peekNext() == '"' and self.current + 2 < self.source.len and self.source[self.current + 2] == '"') {
                    return try self.scanRawString();
                }
                return try self.scanString();
            },
            '-', '0'...'9' => self.scanNumber(),
            'a'...'z', 'A'...'Z', '_' => self.scanIdentifier(),
            else => error.UnexpectedCharacter,
        };
    }
};
