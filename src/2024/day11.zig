const std = @import("std");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    return try processStones(this.allocator, this.input, 25);
}

pub fn part2(this: *const Problem) !?u64 {
    return try processStones(this.allocator, this.input, 75);
}

const StoneList = std.ArrayList(u64);
const NumberCache = std.AutoHashMap(struct { u64, u64 }, u64);

fn processStones(allocator: std.mem.Allocator, input: []const u8, blink_count: usize) !u64 {
    // Initialize list for storing stones
    var stones = StoneList.init(allocator);
    defer stones.deinit();

    // Initialize cache for storing scores of each stone
    var cache = NumberCache.init(allocator);
    defer cache.deinit();

    // Split input by whitespace and parse each number as a stone
    var parts = std.mem.tokenizeAny(u8, input, " \t\n\r");
    while (parts.next()) |part| {
        const stone = try std.fmt.parseUnsigned(u64, part, 10);
        try stones.append(stone);
    }

    // Process each stone individually and count total amount of stones
    var total_count: u64 = 0;
    for (stones.items) |stone| {
        const count = try blinkStone(stone, 0, blink_count, &cache);
        total_count += count;
    }

    return total_count;
}

fn blinkStone(stone: u64, depth: usize, max_depth: usize, cache: *NumberCache) !u64 {
    // Return 1 once maximum depth is reached, indicating a single stone
    if (depth >= max_depth) {
        return 1;
    }

    // Always attempt to fetch count from cache first
    if (cache.get(.{ depth, stone })) |cached_count| {
        return cached_count;
    }

    // Recursively process and count number of stones
    var count: usize = 0;
    if (stone == 0) {
        count = try blinkStone(1, depth + 1, max_depth, cache);
    } else if (splitStone(stone)) |split| {
        const left_count = try blinkStone(split.left, depth + 1, max_depth, cache);
        const right_count = try blinkStone(split.right, depth + 1, max_depth, cache);
        count = left_count + right_count;
    } else {
        count = try blinkStone(stone * 2024, depth + 1, max_depth, cache);
    }

    // Store calculated count in cache
    try cache.put(.{ depth, stone }, count);

    return count;
}

pub fn splitStone(stone: u64) ?struct { left: u64, right: u64 } {
    // If number of digits is not even, bail out
    const digits = countDigits(stone);
    if (digits % 2 != 0) {
        return null;
    }

    // Otherwise split the number in half, digit-wise
    const half_digits = digits / 2;
    const divisor = std.math.pow(u64, 10, half_digits);

    return .{
        .left = stone / divisor,
        .right = stone % divisor,
    };
}

fn countDigits(number: u64) usize {
    var digits: usize = 0;
    var tmp = number;
    while (tmp != 0) {
        tmp /= 10;
        digits += 1;
    }

    return digits;
}

const example_input = "125 17";

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(55312, problem.part1());
}
