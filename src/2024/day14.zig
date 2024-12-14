const std = @import("std");
const helpers = @import("helpers");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,
map_size: helpers.Coords = .{ .x = 101, .y = 103 },

pub fn part1(this: *const Problem) !?u64 {
    // Initialize list for storing all robots
    var robots = std.ArrayList(Robot).init(this.allocator);
    defer robots.deinit();

    // Parse all robots with their positions and velocities
    var lines = std.mem.tokenizeScalar(u8, this.input, '\n');
    while (lines.next()) |line| {
        const robot = try Robot.parse(line, this.map_size);
        try robots.append(robot);
    }

    // Simulate all robots for 100 ticks
    for (robots.items) |*robot| {
        robot.simulate(100);
    }

    // Determine middle of map and initialize array for quadrants
    const middle_x = @divTrunc(this.map_size.x, 2);
    const middle_y = @divTrunc(this.map_size.y, 2);
    var quadrants = [4]u64{ 0, 0, 0, 0 };

    // Count number of robots in each quadrant
    for (robots.items) |robot| {
        if (robot.position.x < middle_x and robot.position.y < middle_y) {
            quadrants[0] += 1;
        } else if (robot.position.x > middle_x and robot.position.y < middle_y) {
            quadrants[1] += 1;
        } else if (robot.position.x < middle_x and robot.position.y > middle_y) {
            quadrants[2] += 1;
        } else if (robot.position.x > middle_x and robot.position.y > middle_y) {
            quadrants[3] += 1;
        }
    }

    // Calculate safety factor
    var safety_factor: u64 = 1;
    for (quadrants) |quadrant| {
        safety_factor *= quadrant;
    }

    return safety_factor;
}

pub fn part2(this: *const Problem) !?u64 {
    // Initialize list for storing all robots
    var robots = std.ArrayList(Robot).init(this.allocator);
    defer robots.deinit();

    // Parse all robots with their positions and velocities
    var lines = std.mem.tokenizeScalar(u8, this.input, '\n');
    while (lines.next()) |line| {
        const robot = try Robot.parse(line, this.map_size);
        try robots.append(robot);
    }

    // Initialize map for storing robot positions
    var map = try RobotMap.init(this.allocator, this.map_size.x, this.map_size.y, false);
    defer map.deinit();

    // Simulate robots until at least one is fully surrounded by others
    var ticks: u64 = 0;
    simulation: while (true) {
        // Simulate all robots for one tick
        for (robots.items) |*robot| {
            robot.simulate(1);
        }
        ticks += 1;

        // Update map with current robot positions
        map.clear(false);
        for (robots.items) |robot| {
            map.set(robot.position, true);
        }

        // Check if any robot is fully surrounded by others
        for (robots.items) |robot| {
            const top_left = map.get(.{ .x = robot.position.x - 1, .y = robot.position.y - 1 }) orelse false;
            const top = map.get(.{ .x = robot.position.x, .y = robot.position.y - 1 }) orelse false;
            const top_right = map.get(.{ .x = robot.position.x + 1, .y = robot.position.y - 1 }) orelse false;
            const right = map.get(.{ .x = robot.position.x + 1, .y = robot.position.y }) orelse false;
            const bottom_right = map.get(.{ .x = robot.position.x + 1, .y = robot.position.y + 1 }) orelse false;
            const bottom = map.get(.{ .x = robot.position.x, .y = robot.position.y + 1 }) orelse false;
            const bottom_left = map.get(.{ .x = robot.position.x - 1, .y = robot.position.y + 1 }) orelse false;
            const left = map.get(.{ .x = robot.position.x - 1, .y = robot.position.y }) orelse false;

            if (top_left and top and top_right and right and bottom_right and bottom and bottom_left and left) {
                break :simulation;
            }
        }
    }

    // Visualize map with robot positions
    if (false) {
        var entries = map.iterate();
        while (entries.next()) |entry| {
            if (entry.tile.*) {
                std.debug.print("X", .{});
            } else {
                std.debug.print(".", .{});
            }

            if (entry.coords.x == map.cols - 1) {
                std.debug.print("\n", .{});
            }
        }
    }

    return ticks;
}

const RobotMap = helpers.Map(bool);

const Robot = struct {
    map_size: helpers.Coords,
    position: helpers.Coords,
    velocity: helpers.Coords,

    const Self = @This();

    pub fn parse(input: []const u8, map_size: helpers.Coords) !Self {
        var parts = std.mem.tokenizeScalar(u8, input, ' ');
        const position = try Self.parseCoords(parts.next().?);
        const velocity = try Self.parseCoords(parts.next().?);

        return .{
            .map_size = map_size,
            .position = position,
            .velocity = velocity,
        };
    }

    pub fn simulate(this: *Self, ticks: isize) void {
        this.position.x = @mod(this.position.x + this.velocity.x * ticks, this.map_size.x);
        this.position.y = @mod(this.position.y + this.velocity.y * ticks, this.map_size.y);
    }

    fn parseCoords(input: []const u8) !helpers.Coords {
        var parts = std.mem.tokenizeScalar(u8, input, '=');
        _ = parts.next().?;
        const value = parts.next().?;

        var value_parts = std.mem.tokenizeScalar(u8, value, ',');
        const x = try std.fmt.parseInt(isize, value_parts.next().?, 10);
        const y = try std.fmt.parseInt(isize, value_parts.next().?, 10);

        return .{ .x = x, .y = y };
    }
};

const example_input =
    \\p=0,4 v=3,-3
    \\p=6,3 v=-1,-3
    \\p=10,3 v=-1,2
    \\p=2,0 v=2,-1
    \\p=0,0 v=1,3
    \\p=3,0 v=-2,-2
    \\p=7,6 v=-1,-3
    \\p=3,0 v=-1,-2
    \\p=9,3 v=2,3
    \\p=7,3 v=-1,2
    \\p=2,4 v=2,-3
    \\p=9,5 v=-3,-3
;

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
        .map_size = .{ .x = 11, .y = 7 },
    };

    try std.testing.expectEqual(12, problem.part1());
}
