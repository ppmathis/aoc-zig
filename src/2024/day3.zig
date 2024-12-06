const std = @import("std");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    return parse(this.input, false);
}

pub fn part2(this: *const Problem) !?u64 {
    return parse(this.input, true);
}

const ParserFn = fn (*ParserState) ParserError!void;

const ParserError = error{
    InvalidNumber,
    UnexpectedCharacter,
    UnexpectedEnd,
};

const ParserState = struct {
    data: []const u8,
    position: usize,
    mul_enabled: bool,
    mul_conditional: bool,
    result: u64,
};

pub fn parse(data: []const u8, mul_conditional: bool) u64 {
    var state = ParserState{
        .data = data,
        .position = 0,
        .mul_enabled = true,
        .mul_conditional = mul_conditional,
        .result = 0,
    };

    while (state.position < state.data.len) {
        // Handle supported expressions, or advance by one character if no match
        if (tryExpression(&state, "do(", parseDo)) {
            continue;
        } else if (tryExpression(&state, "don't(", parseDont)) {
            continue;
        } else if (tryExpression(&state, "mul(", parseMul)) {
            continue;
        } else {
            state.position += 1;
        }
    }

    return state.result;
}

fn tryExpression(state: *ParserState, prefix: []const u8, func: ParserFn) bool {
    // Skip if expression prefix does not match
    if (!peekEquals(state, prefix)) {
        return false;
    }

    // Store original position, then execute method and rollback on failure
    const original_position = state.position;
    func(state) catch {
        state.position = original_position;
        return false;
    };

    // Return true if expression was successfully parsed
    return true;
}

fn peekEquals(state: *ParserState, expected: []const u8) bool {
    const start = state.position;
    const end = state.position + expected.len;
    if (end > state.data.len) {
        return false;
    }

    return std.mem.eql(u8, state.data[start..end], expected);
}

fn parseDo(state: *ParserState) ParserError!void {
    try parseLiteral(state, "do()");
    state.mul_enabled = true;
}

fn parseDont(state: *ParserState) ParserError!void {
    try parseLiteral(state, "don't()");
    state.mul_enabled = false;
}

fn parseMul(state: *ParserState) ParserError!void {
    // Parse mul(a,b) expression
    try parseLiteral(state, "mul(");
    const first = try parseNumber(state);
    try parseLiteral(state, ",");
    const second = try parseNumber(state);
    try parseLiteral(state, ")");

    // Calculate product and add to result
    if (!state.mul_conditional or state.mul_enabled) {
        state.result += first * second;
    }
}

fn parseLiteral(state: *ParserState, expected: []const u8) ParserError!void {
    const start = state.position;
    const end = start + expected.len;
    if (end > state.data.len) {
        return ParserError.UnexpectedEnd;
    }

    if (!std.mem.eql(u8, state.data[start..end], expected)) {
        return ParserError.UnexpectedCharacter;
    }

    state.position = end;
}

fn parseNumber(state: *ParserState) ParserError!u64 {
    const start = state.position;
    var end = start;

    // Scan for continuous digits and advance end
    while (start < state.data.len) {
        if (state.data[end] >= '0' and state.data[end] <= '9') {
            end += 1;
        } else {
            break;
        }
    }

    // If start == end, then no digits were found
    if (start == end) {
        return ParserError.UnexpectedEnd;
    }

    // Attempt to parse number as u64
    const number = std.fmt.parseInt(u64, state.data[start..end], 10) catch {
        return ParserError.InvalidNumber;
    };

    // Advance position to end and return number
    state.position = end;
    return number;
}

test "part 1: example" {
    const allocator = std.testing.allocator;
    const input =
        \\xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))
    ;

    const problem = Problem{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(161, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;
    const input =
        \\xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))
    ;

    const problem = Problem{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(48, problem.part2());
}
