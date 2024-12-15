const std = @import("std");
const helpers = @import("helpers");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    // Initialize warehouse from provided input
    var warehouse = try Warehouse.parse(this.allocator, this.input);
    defer warehouse.deinit();

    // Simulate all moves in the warehouse
    try warehouse.simulate(null);

    // Calculate sum of all GPS coordinates of boxes
    return warehouse.sumGps();
}

pub fn part2(this: *const Problem) !?u64 {
    // Initialize warehouse from provided input
    var warehouse = try Warehouse.parse(this.allocator, this.input);
    defer warehouse.deinit();

    // Scale the warehouse map to double width
    const scaled_map = try scaleMap(this.allocator, warehouse.map);

    // Replace warehouse map with scaled map and adjust robot position
    warehouse.map.deinit();
    warehouse.map = scaled_map;
    warehouse.robot = helpers.Coords{ .x = warehouse.robot.x * 2, .y = warehouse.robot.y };

    // Simulate all moves in the warehouse
    try warehouse.simulate(null);

    return warehouse.sumGps();
}

fn scaleMap(allocator: std.mem.Allocator, original: helpers.Map(Tile)) !helpers.Map(Tile) {
    // Initialize scaled map with double width
    var scaled = try helpers.Map(Tile).init(allocator, original.cols * 2, original.rows, .Empty);
    errdefer scaled.deinit();

    // Copy original map to the scaled map
    var entries = original.iterate();
    while (entries.next()) |entry| {
        const original_coords = entry.coords;
        const scaled_coords = helpers.Coords{ .x = original_coords.x * 2, .y = original_coords.y };

        // Determine left and right tile
        const left_tile = switch (entry.tile.*) {
            .Empty => Tile.Empty,
            .Wall => Tile.Wall,
            .Robot => Tile.Robot,
            .Box => Tile.BoxLeft,
            else => return error.InvalidTile,
        };
        const right_tile = switch (entry.tile.*) {
            .Empty, .Robot => Tile.Empty,
            .Wall => Tile.Wall,
            .Box => Tile.BoxRight,
            else => return error.InvalidTile,
        };

        // Set both tiles to the scaled map
        _ = scaled.set(scaled_coords, left_tile);
        _ = scaled.set(scaled_coords.add(.{ .x = 1, .y = 0 }), right_tile);
    }

    return scaled;
}

const Direction = enum {
    Up,
    Down,
    Left,
    Right,

    const Self = @This();

    pub fn from(c: u8) ?Self {
        switch (c) {
            '^' => return Direction.Up,
            'v' => return Direction.Down,
            '<' => return Direction.Left,
            '>' => return Direction.Right,
            else => return null,
        }
    }

    pub fn vector(this: Self) helpers.Coords {
        switch (this) {
            .Up => return .{ .x = 0, .y = -1 },
            .Down => return .{ .x = 0, .y = 1 },
            .Left => return .{ .x = -1, .y = 0 },
            .Right => return .{ .x = 1, .y = 0 },
        }
    }
};

const Tile = enum {
    Empty,
    Wall,
    Robot,
    Box,
    // Additional double-box tiles for part 2
    BoxLeft,
    BoxRight,

    const Self = @This();

    pub fn from(c: u8) !Self {
        switch (c) {
            'O' => return Tile.Box,
            '@' => return Tile.Robot,
            '.' => return Tile.Empty,
            '#' => return Tile.Wall,
            else => return error.InvalidTile,
        }
    }

    pub fn isDoubleBox(this: Self) bool {
        return this == .BoxLeft or this == .BoxRight;
    }
};

const Warehouse = struct {
    map: helpers.Map(Tile),
    robot: helpers.Coords,
    moves: std.ArrayList(Direction),

    const Self = @This();

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Self {
        // Split input into map and moves
        var parts = std.mem.tokenizeSequence(u8, input, "\n\n");
        const map_data = parts.next().?;
        const moves_data = parts.next().?;

        // Initialize map from provided input
        var map = try helpers.Map(Tile).parse(allocator, map_data);
        errdefer map.deinit();

        // Initialize list for storing robot moves
        var moves = std.ArrayList(Direction).init(allocator);
        errdefer moves.deinit();

        // Parse robot moves and store them in reverse, to have a stack-like behavior
        var i: usize = moves_data.len;
        while (i > 0) {
            i -= 1;
            if (Direction.from(moves_data[i])) |direction| {
                _ = try moves.append(direction);
            }
        }

        // Determine starting position of the robot and remove it from the map
        var robot: ?helpers.Coords = null;
        var entries = map.iterate();
        while (entries.next()) |entry| {
            if (entry.tile.* != Tile.Robot) {
                continue;
            }

            if (robot != null) {
                return error.TooManyRobots;
            }

            robot = entry.coords;
            map.set(entry.coords, Tile.Empty);
        }

        // Ensure that the robot was found
        if (robot == null) {
            return error.NoRobot;
        }

        return .{
            .map = map,
            .robot = robot.?,
            .moves = moves,
        };
    }

    pub fn deinit(this: *Self) void {
        this.map.deinit();
        this.moves.deinit();
    }

    pub fn sumGps(this: *Self) u64 {
        var sum: u64 = 0;
        var entries = this.map.iterate();

        while (entries.next()) |entry| {
            if (entry.tile.* == .Box or entry.tile.* == .BoxLeft) {
                const gps = @as(u64, @intCast(entry.coords.y)) * 100 + @as(u64, @intCast(entry.coords.x));
                sum += gps;
            }
        }

        return sum;
    }

    pub fn draw(this: *Self) void {
        var entries = this.map.iterate();
        while (entries.next()) |entry| {
            var c: u8 = switch (entry.tile.*) {
                .Empty => '.',
                .Wall => '#',
                .Box => 'O',
                .BoxLeft => '[',
                .BoxRight => ']',
                .Robot => '@',
            };

            if (entry.coords.eql(this.robot)) {
                if (c == 'O' or c == '[' or c == ']') {
                    c = '!';
                } else {
                    c = '@';
                }
            }

            std.debug.print("{c}", .{c});
            if (entry.coords.x == this.map.cols - 1) {
                std.debug.print("\n", .{});
            }
        }
    }

    pub fn simulate(this: *Self, max_ticks: ?u64) !void {
        var ticks: u64 = 0;
        while (this.moves.items.len > 0) {
            // Perform a single tick
            try this.tick();
            ticks += 1;

            // If a maximum number of ticks is set, output the current state and check if the limit is reached
            if (max_ticks != null) {
                std.debug.print("========== Tick {d} ==========\n", .{ticks});
                this.draw();

                if (ticks >= max_ticks.?) {
                    break;
                }
            }
        }
    }

    fn tick(this: *Self) !void {
        // Get next move from the stack
        const move = this.moves.pop();

        // Determine target position and tile
        const target_pos = this.robot.add(move.vector());
        const target_tile = this.map.get(target_pos).?;

        // Act based on the target tile
        switch (target_tile) {
            .Empty => {
                // Next tile is empty, so always move the robot
                this.robot = target_pos;
            },
            .Box => {
                // If the single box can be pushed, move the robot as well, otherwise ignore the move
                if (this.pushSingleBox(target_pos, move)) {
                    this.robot = target_pos;
                }
            },
            .BoxLeft, .BoxRight => {
                // Clone current map tiles to ensure complete rollback in case of failure
                const tiles_clone = try this.map.tiles.clone();
                errdefer tiles_clone.deinit();

                // If the double box can be pushed, move the robot as well, otherwise ignore the move
                if (this.pushDoubleBox(target_pos, move)) {
                    this.robot = target_pos;
                    tiles_clone.deinit();
                } else {
                    this.map.tiles.deinit();
                    this.map.tiles = tiles_clone;
                }
            },
            .Wall, .Robot => {},
        }
    }

    fn pushSingleBox(this: *Self, pos: helpers.Coords, direction: Direction) bool {
        // Determine target position and tile
        const target_pos = pos.add(direction.vector());
        var target_tile = this.map.get(target_pos).?;

        // If multiple boxes occur in a row, try to move them all
        if (target_tile == .Box) {
            // If the next box cannot be pushed, this one cannot be pushed either
            if (!this.pushSingleBox(target_pos, direction)) {
                return false;
            }

            // Consider target tile as empty after pushing the box
            target_tile = .Empty;
        }

        // If the target tile is not empty, the box cannot be pushed
        if (target_tile != .Empty) {
            return false;
        }

        // Move the box to the target position
        this.map.set(target_pos, .Box);
        this.map.set(pos, .Empty);

        return true;
    }

    fn pushDoubleBox(this: *Self, left_pos: helpers.Coords, direction: Direction) bool {
        // Simplify further processing by ensuring this method always deals with the left box
        const left_tile = this.map.get(left_pos).?;
        if (left_tile == .BoxRight) {
            return this.pushDoubleBox(left_pos.add(.{ .x = -1, .y = 0 }), direction);
        }
        std.debug.assert(left_tile == .BoxLeft);

        // Determine position and tile of right box
        const right_pos = left_pos.add(.{ .x = 1, .y = 0 });
        const right_tile = this.map.get(right_pos).?;
        std.debug.assert(right_tile == .BoxRight);

        // Determine left target position and tile
        const left_target_pos = left_pos.add(direction.vector());
        var left_target_tile = this.map.get(left_target_pos).?;

        // If left box would push into the right side of this double box, assume the target is empty
        if (left_target_tile == .BoxRight and left_target_pos.eql(right_pos)) {
            left_target_tile = .Empty;
        }

        // If left box would push another box, try to move both boxes
        if (left_target_tile.isDoubleBox()) {
            // If the next box cannot be pushed, this one cannot be pushed either
            if (!this.pushDoubleBox(left_target_pos, direction)) {
                return false;
            }

            // Consider left target tile as empty after pushing the box
            left_target_tile = .Empty;
        }

        // Determine right target position and tile
        const right_target_pos = right_pos.add(direction.vector());
        var right_target_tile = this.map.get(right_target_pos).?;

        // If right box would push into the left side of this double box, assume the target is empty
        if (right_target_tile == .BoxLeft and right_target_pos.eql(left_pos)) {
            right_target_tile = .Empty;
        }

        // If right box would push another box, try to move both boxes
        if (right_target_tile.isDoubleBox()) {
            // If the next box cannot be pushed, this one cannot be pushed either
            if (!this.pushDoubleBox(right_target_pos, direction)) {
                return false;
            }

            // Consider right target tile as empty after pushing the box
            right_target_tile = .Empty;
        }

        // If the target tiles are not empty, the boxes cannot be pushed
        if (left_target_tile != .Empty or right_target_tile != .Empty) {
            return false;
        }

        // Move both tiles of double box to the target positions
        this.map.set(left_pos, .Empty);
        this.map.set(right_pos, .Empty);
        this.map.set(left_target_pos, .BoxLeft);
        this.map.set(right_target_pos, .BoxRight);

        return true;
    }
};

const example_input_small_p1 =
    \\########
    \\#..O.O.#
    \\##@.O..#
    \\#...O..#
    \\#.#.O..#
    \\#...O..#
    \\#......#
    \\########
    \\
    \\<^^>>>vv<v>>v<<
;

const example_input_small_p2 =
    \\#######
    \\#...#.#
    \\#.....#
    \\#..OO@#
    \\#..O..#
    \\#.....#
    \\#######
    \\
    \\<vv<<^^<<^^
;

const example_input_large =
    \\##########
    \\#..O..O.O#
    \\#......O.#
    \\#.OO..O.O#
    \\#..O@..O.#
    \\#O#..O...#
    \\#O..O..O.#
    \\#.OO.O.OO#
    \\#....O...#
    \\##########
    \\
    \\<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^
    \\vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v
    \\><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<
    \\<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^
    \\^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><
    \\^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^
    \\>^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^
    \\<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>
    \\^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>
    \\v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^
;

test "part 1: small example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input_small_p1,
        .allocator = allocator,
    };

    try std.testing.expectEqual(2028, problem.part1());
}

test "part 1: large example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input_large,
        .allocator = allocator,
    };

    try std.testing.expectEqual(10092, problem.part1());
}

test "part 2: small example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input_small_p2,
        .allocator = allocator,
    };

    try std.testing.expectEqual(618, problem.part2());
}

test "part 2: large example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input_large,
        .allocator = allocator,
    };

    try std.testing.expectEqual(9021, problem.part2());
}
