const std = @import("std");

pub const TokenType = enum {
    left_brace,
    right_brace,
    left_bracket,
    right_bracket,
    colon,
    comma,
    string,
    raw_string,
    integer,
    float,
    true_literal,
    false_literal,
    null_literal,
    identifier,
    eof,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,
};
