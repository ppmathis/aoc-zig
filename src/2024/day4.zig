const std = @import("std");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    var grid = try Grid.create(this.allocator, this.input);
    defer grid.deinit();

    return grid.countWords("XMAS");
}

pub fn part2(this: *const Problem) !?u64 {
    var grid = try Grid.create(this.allocator, this.input);
    defer grid.deinit();

    return grid.countXmas();
}

const Grid = struct {
    rows: isize,
    cols: isize,
    data: std.ArrayList(u8),

    const Self = @This();

    pub fn create(allocator: std.mem.Allocator, input: []const u8) !Self {
        var self = Self{
            .rows = 0,
            .cols = 0,
            .data = std.ArrayList(u8).init(allocator),
        };

        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        while (lines.next()) |line| {
            // Increment rows and determine columns if not set
            self.rows += 1;
            if (self.cols == 0) {
                self.cols = @intCast(line.len);
            }

            // Ensure each line has the same number of columns
            if (line.len != self.cols) {
                std.debug.print("line has {d} columns, expected {d}\n", .{ line.len, self.cols });
                std.debug.print("line: {s}\n", .{line});
                return error.ColumnMismatch;
            }

            // Append line to data, this will add all characters
            try self.data.appendSlice(line);
        }

        return self;
    }

    pub fn countWords(self: *Self, needles: []const u8) u64 {
        var result: u64 = 0;
        var x: isize = 0;
        var y: isize = 0;

        while (y < self.rows) {
            while (x < self.cols) {
                // Check all 8 directions for possible matches
                result += if (self.countDirection(x, y, -1, -1, needles)) 1 else 0;
                result += if (self.countDirection(x, y, 0, -1, needles)) 1 else 0;
                result += if (self.countDirection(x, y, 1, -1, needles)) 1 else 0;
                result += if (self.countDirection(x, y, -1, 0, needles)) 1 else 0;
                result += if (self.countDirection(x, y, 1, 0, needles)) 1 else 0;
                result += if (self.countDirection(x, y, -1, 1, needles)) 1 else 0;
                result += if (self.countDirection(x, y, 0, 1, needles)) 1 else 0;
                result += if (self.countDirection(x, y, 1, 1, needles)) 1 else 0;

                // Move to next column
                x += 1;
            }

            // Move to next row
            x = 0;
            y += 1;
        }

        return result;
    }

    pub fn countXmas(self: *Self) u64 {
        var result: u64 = 0;
        var x: isize = 1;
        var y: isize = 1;

        while (y < self.rows - 1) {
            while (x < self.cols - 1) {
                // Check if current letter is 'A', otherwise skip
                const c = self.get(x, y) orelse unreachable;
                if (c != 'A') {
                    x += 1;
                    continue;
                }

                // Determine all corners of the XMAS pattern
                const corners: [4]u8 = .{
                    self.get(x - 1, y - 1) orelse unreachable,
                    self.get(x + 1, y - 1) orelse unreachable,
                    self.get(x + 1, y + 1) orelse unreachable,
                    self.get(x - 1, y + 1) orelse unreachable,
                };

                // Check corners for X-MAS pattern match
                const match =
                    std.mem.eql(u8, corners[0..4], "MMSS") or
                    std.mem.eql(u8, corners[0..4], "SSMM") or
                    std.mem.eql(u8, corners[0..4], "MSSM") or
                    std.mem.eql(u8, corners[0..4], "SMMS");

                // Increment result if match
                if (match) {
                    result += 1;
                }

                // Move to next column
                x += 1;
            }

            // Move to next row
            x = 1;
            y += 1;
        }

        return result;
    }

    pub fn countDirection(self: *Self, sx: isize, sy: isize, dx: isize, dy: isize, needles: []const u8) bool {
        var x = sx;
        var y = sy;

        for (needles) |needle| {
            // Get next letter from grid and bail out if null
            const c = self.get(x, y) orelse return false;

            // Bail out if letter doesn't match next needle
            if (c != needle) {
                return false;
            }

            // Move to next position
            x += dx;
            y += dy;
        }

        return true;
    }

    pub inline fn get(self: *Self, x: isize, y: isize) ?u8 {
        if (x < 0 or y < 0 or x >= self.cols or y >= self.rows) {
            return null;
        }

        const offset: usize = @intCast(y * self.cols + x);
        return self.data.items[offset];
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }
};

test "part 1: example" {
    const allocator = std.testing.allocator;
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;

    const problem = Problem{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(18, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;

    const problem = Problem{
        .input = input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(9, problem.part2());
}
