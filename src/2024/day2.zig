const std = @import("std");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    // Count number of safe reports
    var safe_reports: u64 = 0;
    var reports = std.mem.tokenizeScalar(u8, this.input, '\n');
    while (reports.next()) |report| {
        if (try validateReport(report, false)) {
            safe_reports += 1;
        }
    }

    return safe_reports;
}

pub fn part2(this: *const Problem) !?u64 {
    // Count number of safe reports with problem dampener
    var safe_reports: u64 = 0;
    var reports = std.mem.tokenizeScalar(u8, this.input, '\n');
    while (reports.next()) |report| {
        if (try validateReport(report, true)) {
            safe_reports += 1;
        }
    }

    return safe_reports;
}

const Direction = enum {
    Ascending,
    Descending,

    const Self = @This();

    pub fn determine(last: i64, current: i64) ?Self {
        if (last == current) {
            return null;
        } else if (last < current) {
            return .Ascending;
        } else {
            return .Descending;
        }
    }
};

fn validateReport(report: []const u8, dampener: bool) !bool {
    // Tokenize report into array of levels
    var levels = std.ArrayList(i64).init(std.heap.page_allocator);
    var level_tokens = std.mem.tokenizeScalar(u8, report, ' ');
    while (level_tokens.next()) |level_token| {
        const level = try std.fmt.parseInt(i64, level_token, 10);
        try levels.append(level);
    }

    // Validate report levels as-is for safety, then return result if safe or without problem dampener
    const normal_result = validateReportLevels(levels.items, null);
    if (normal_result.safe or !dampener) {
        return normal_result.safe;
    }

    // Retry report validation with either of [i-2, i-1, i] levels removed
    // This allows for a single level to be removed to get the report back to a safe state
    // If any index is out of bounds, the loop will skip it
    const violator_idx = normal_result.violator.?;
    for (0..3) |offset| {
        if (offset <= violator_idx) {
            const dampened_result = validateReportLevels(levels.items, violator_idx - offset);
            if (dampened_result.safe) {
                return true;
            }
        }
    }

    return false;
}

fn validateReportLevels(levels: []const i64, skip_index: ?usize) struct { safe: bool, violator: ?usize } {
    var last_level_opt: ?i64 = null;
    var expected_dir: ?Direction = null;

    for (levels, 0..) |level, i| {
        // Skip to next level if index is to be skipped
        if (skip_index) |skip| {
            if (i == skip) {
                continue;
            }
        }

        // Obtain last level or skip if first level
        const last_level = last_level_opt orelse {
            last_level_opt = level;
            continue;
        };

        // Determine current direction and bail out if it doesn't match the report direction
        const current_dir = Direction.determine(last_level, level);
        if (expected_dir) |dir| {
            if (current_dir != dir) {
                return .{ .safe = false, .violator = i };
            }
        } else {
            expected_dir = current_dir;
        }

        // Bail out if level difference is not within bounds
        const level_diff = @abs(level - last_level);
        if (level_diff < 1 or level_diff > 3) {
            return .{ .safe = false, .violator = i };
        }

        // Update last level
        last_level_opt = level;
    }

    return .{ .safe = true, .violator = null };
}

test "part 1: example" {
    const allocator = std.testing.allocator;
    const input =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;

    const problem = Problem{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(2, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;
    const input =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;

    const problem = Problem{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(4, problem.part2());
}

test "part 2: increment" {
    const allocator = std.testing.allocator;
    const input =
        \\6 10 11 12
        \\6 7 11 10
        \\6 7 8 12
    ;

    const problem = Problem{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(3, problem.part2());
}

test "part 2: direction change" {
    const allocator = std.testing.allocator;
    const input =
        \\4 5 3 2 1
        \\5 2 3 4 5
        \\1 2 3 5 4
        \\5 2 3
        \\1 4 2
        \\2 1 5
    ;

    const problem = Problem{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(6, problem.part2());
}
