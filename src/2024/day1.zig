const std = @import("std");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    // Parse input data
    var data = try Data.parse(this.allocator, this.input);
    defer data.deinit();

    // Sort arrays in ascending order
    std.mem.sort(u64, data.left.items, {}, std.sort.asc(u64));
    std.mem.sort(u64, data.right.items, {}, std.sort.asc(u64));

    // Calculate distance between left and right values
    var distance: u64 = 0;
    for (data.left.items, data.right.items) |left, right| {
        distance += if (left > right) left - right else right - left;
    }

    return distance;
}

pub fn part2(this: *const Problem) !?u64 {
    // Parse input data
    var data = try Data.parse(this.allocator, this.input);
    defer data.deinit();

    // Count number of occurrences of each right value
    var counts = std.AutoHashMap(u64, u64).init(this.allocator);
    defer counts.deinit();

    for (data.right.items) |right| {
        const current = counts.get(right) orelse 0;
        try counts.put(right, current + 1);
    }

    // Calculate similarity score for left values
    var score: u64 = 0;
    for (data.left.items) |left| {
        const count = counts.get(left) orelse 0;
        score += @as(u64, left) * count;
    }

    return score;
}

const Data = struct {
    left: std.ArrayList(u64),
    right: std.ArrayList(u64),

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Data {
        // Allocate memory for storing left and right values
        var left = std.ArrayList(u64).init(allocator);
        var right = std.ArrayList(u64).init(allocator);
        errdefer left.deinit();
        errdefer right.deinit();

        // Read pairs of numbers from input
        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        while (lines.next()) |line| {
            var elements = std.mem.tokenizeScalar(u8, line, ' ');
            const left_value = try std.fmt.parseInt(u64, elements.next().?, 10);
            const right_value = try std.fmt.parseInt(u64, elements.next().?, 10);

            _ = try left.append(left_value);
            _ = try right.append(right_value);
        }

        return .{
            .left = left,
            .right = right,
        };
    }

    pub fn deinit(this: *Data) void {
        this.left.deinit();
        this.right.deinit();
    }
};

const example_input =
    \\3   4
    \\4   3
    \\2   5
    \\1   3
    \\3   9
    \\3   3
;

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(11, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(31, problem.part2());
}
