const std = @import("std");
const helpers = @import("helpers");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    // Initialize list of machines
    var machines = std.ArrayList(Machine).init(this.allocator);
    defer machines.deinit();

    // Parse each machine from input, separated by double newlines
    var lines = std.mem.tokenizeSequence(u8, this.input, "\n\n");
    while (lines.next()) |line| {
        const machine = try Machine.parse(line, 0);
        try machines.append(machine);
    }

    // Calculate total cost to solve each machine optimally
    var total_cost: u64 = 0;
    for (machines.items) |machine| {
        if (try machine.solve()) |cost| {
            total_cost += cost;
        }
    }

    return total_cost;
}

pub fn part2(this: *const Problem) !?u64 {
    // Initialize list of machines
    var machines = std.ArrayList(Machine).init(this.allocator);
    defer machines.deinit();

    // Parse each machine from input, separated by double newlines
    var lines = std.mem.tokenizeSequence(u8, this.input, "\n\n");
    while (lines.next()) |line| {
        const machine = try Machine.parse(line, 10000000000000);
        try machines.append(machine);
    }

    // Calculate total cost to solve each machine optimally
    var total_cost: u64 = 0;
    for (machines.items) |machine| {
        if (try machine.solve()) |cost| {
            total_cost += cost;
        }
    }

    return total_cost;
}

const Machine = struct {
    prize: helpers.Vec2(i64),
    velocity_a: helpers.Vec2(i64),
    velocity_b: helpers.Vec2(i64),

    const Self = @This();

    pub fn parse(input: []const u8, offset: i64) !Self {
        // Split input by newlines
        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        const line_button_a = lines.next().?;
        const line_button_b = lines.next().?;
        const line_prize = lines.next().?;

        // Parse coordinates for prize and buttons
        var prize = try Self.parseCoords(line_prize);
        const velocity_a = try Self.parseCoords(line_button_a);
        const velocity_b = try Self.parseCoords(line_button_b);

        // Apply offset to prize coordinates
        prize.x += offset;
        prize.y += offset;

        return .{
            .prize = prize,
            .velocity_a = velocity_a,
            .velocity_b = velocity_b,
        };
    }

    pub fn solve(this: *const Self) !?u64 {
        // Define short variable names for readability
        const px, const py = .{ this.prize.x, this.prize.y };
        const ax, const ay = .{ this.velocity_a.x, this.velocity_a.y };
        const bx, const by = .{ this.velocity_b.x, this.velocity_b.y };

        // Calculate determinant of matrix formed by (ax,ay) and (bx,by)
        const d = ax * by - ay * bx;

        // Check if the two directions are collinear
        if (d == 0) {
            // Ensure px is a multiple of ax, otherwise the prize is unreachable
            if (@mod(px, ax) != 0) {
                return null;
            }

            // Calculate multiple of ax to reach prize
            const s = @divTrunc(px, ax);

            // Ensure py is the same multiple of ay, otherwise the prize is unreachable
            if (s * ay != py) {
                return null;
            }

            // Calculate cost based on multiple of ax
            return 3 * @as(u64, @intCast(s));
        } else {
            // Solve system of equations to find multiples of ax and bx to reach prize
            // 1) ax*a + bx*b = px -> a = (px*by - py*bx) / d
            // 2) ay*a + by*b = py -> a = (ax*py - ay*px) / d

            // Calculate numerators for solving equations
            const num_a = px * by - py * bx;
            const num_b = ax * py - ay * px;

            // Bail out if numerators are not divisible by the determinant, as only integer solutions are valid
            if (@mod(num_a, d) != 0 or @mod(num_b, d) != 0) {
                return null;
            }

            // Compute a and b by dividing numerators by the determinant
            const a = @divTrunc(num_a, d);
            const b = @divTrunc(num_b, d);

            // Treat any negative solutions as invalid
            if (a < 0 or b < 0) return null;

            // Calculate cost based on 3a + b
            return 3 * @as(u64, @intCast(a)) + @as(u64, @intCast(b));
        }
    }

    fn parseCoords(input: []const u8) !helpers.Vec2(i64) {
        // Split string after colon, to remove the label like "Button A: "
        var parts = std.mem.tokenizeScalar(u8, input, ':');
        _ = parts.next().?;

        // Split X/Y coordinates by comma and space
        var parts_coords = std.mem.tokenizeAny(u8, parts.next().?, ", ");

        // Parse X and Y coordinate specifiers by splitting by "+" or "="
        var parts_x = std.mem.tokenizeAny(u8, parts_coords.next().?, "+=");
        var parts_y = std.mem.tokenizeAny(u8, parts_coords.next().?, "+=");

        // Skip key of each coordinate, e.g. "X" or "Y"
        _ = parts_x.next().?;
        _ = parts_y.next().?;

        // Parse X and Y coordinates
        return .{
            .x = try std.fmt.parseInt(i64, parts_x.next().?, 10),
            .y = try std.fmt.parseInt(i64, parts_y.next().?, 10),
        };
    }
};

const example_input =
    \\Button A: X+94, Y+34
    \\Button B: X+22, Y+67
    \\Prize: X=8400, Y=5400
    \\
    \\Button A: X+26, Y+66
    \\Button B: X+67, Y+21
    \\Prize: X=12748, Y=12176
    \\
    \\Button A: X+17, Y+86
    \\Button B: X+84, Y+37
    \\Prize: X=7870, Y=6450
    \\
    \\Button A: X+69, Y+23
    \\Button B: X+27, Y+71
    \\Prize: X=18641, Y=10279
;

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(480, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(875318608908, problem.part2());
}
