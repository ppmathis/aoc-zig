const std = @import("std");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    var data = try Data.parse(this.allocator, this.input);
    defer data.deinit();

    var result: u64 = 0;
    for (data.calibrations.items) |*calibration| {
        if (calibration.checkEquation(false)) {
            result += calibration.test_value;
        }
    }

    return result;
}

pub fn part2(this: *const Problem) !?u64 {
    var data = try Data.parse(this.allocator, this.input);
    defer data.deinit();

    var result: u64 = 0;
    for (data.calibrations.items) |*calibration| {
        if (calibration.checkEquation(true)) {
            result += calibration.test_value;
        }
    }

    return result;
}

const Data = struct {
    calibrations: std.ArrayList(Calibration),

    const Self = @This();

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Self {
        // Initialize list for storing calibrations
        var calibrations = std.ArrayList(Calibration).init(allocator);
        errdefer calibrations.deinit();

        // Process each line as calibration data
        var calibration_parts = std.mem.tokenizeScalar(u8, input, '\n');
        while (calibration_parts.next()) |part| {
            const calibration = try Calibration.parse(allocator, part);
            try calibrations.append(calibration);
        }

        return .{
            .calibrations = calibrations,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.calibrations.items) |*calibration| {
            calibration.deinit();
        }
        self.calibrations.deinit();
    }
};

const Calibration = struct {
    test_value: u64,
    numbers: std.ArrayList(u64),

    const Self = @This();

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Self {
        // Split input into test_value and number blocks
        var blocks = std.mem.tokenizeScalar(u8, input, ':');
        const test_value_block = blocks.next().?;
        const numbers_block = blocks.next().?;

        // Parse test value as u64
        const test_value = try std.fmt.parseInt(u64, test_value_block, 10);

        // Parse numbers as space-separated list of u64
        var numbers = std.ArrayList(u64).init(allocator);
        errdefer numbers.deinit();

        var number_parts = std.mem.tokenizeScalar(u8, numbers_block, ' ');
        while (number_parts.next()) |number_part| {
            const number = try std.fmt.parseInt(u64, number_part, 10);
            try numbers.append(number);
        }

        // Return the parsed calibration
        return .{
            .test_value = test_value,
            .numbers = numbers,
        };
    }

    pub fn checkEquation(self: *Self, has_concat: bool) bool {
        return self.dfs(1, self.numbers.items[0], has_concat);
    }

    pub fn deinit(self: *Self) void {
        self.numbers.deinit();
    }

    fn dfs(self: *Self, index: usize, current: u64, has_concat: bool) bool {
        const numbers = self.numbers.items;
        const target = self.test_value;

        // Once all numbers have been processed, check if result matches target
        if (index == numbers.len) {
            return current == target;
        }

        // Attempt calculation with '+'
        const add_result = current + numbers[index];
        if (add_result <= target and self.dfs(index + 1, add_result, has_concat)) {
            return true;
        }

        // Attempt calculation with '*'
        const mul_result = current * numbers[index];
        if (mul_result <= target and self.dfs(index + 1, mul_result, has_concat)) {
            return true;
        }

        // Attempt calculation with '||' if supported
        if (has_concat) {
            const concat_result = Self.concat(current, numbers[index]);
            if (concat_result <= target and self.dfs(index + 1, concat_result, has_concat)) {
                return true;
            }
        }

        // Bail out, neither option worked
        return false;
    }

    inline fn concat(a: u64, b: u64) u64 {
        var multiplier: u64 = 1;
        var tmp: u64 = b;
        while (tmp != 0) {
            multiplier *= 10;
            tmp /= 10;
        }

        return a * multiplier + b;
    }
};

const example_input =
    \\190: 10 19
    \\3267: 81 40 27
    \\83: 17 5
    \\156: 15 6
    \\7290: 6 8 6 15
    \\161011: 16 10 13
    \\192: 17 8 14
    \\21037: 9 7 18 13
    \\292: 11 6 16 20
;

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(3749, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(11387, problem.part2());
}
