const std = @import("std");
const helpers = @import("helpers");
const Problem = @This();

const Set = helpers.Set;

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?usize {
    var map = try Map.parse(this.allocator, this.input);
    defer map.deinit();

    var guard = try Guard.init(this.allocator, &map);
    defer guard.deinit();
    try guard.moveUntilOutOfBounds();

    return guard.visited_tiles.count();
}

pub fn part2(this: *const Problem) !?usize {
    var map = try Map.parse(this.allocator, this.input);
    defer map.deinit();

    var guard = try Guard.init(this.allocator, &map);
    defer guard.deinit();
    try guard.moveUntilOutOfBounds();

    return try guard.checkForInfiniteLoops(this.allocator);
}

const Coords = struct {
    x: isize = 0,
    y: isize = 0,

    pub fn cmp(self: Coords, other: Coords) bool {
        return self.x == other.x and self.y == other.y;
    }
};

const Tile = enum {
    Free,
    Blocked,
};

const Corner = enum(usize) {
    TopLeft = 0,
    TopRight = 1,
    BottomLeft = 2,
    BottomRight = 3,
};

const Direction = enum {
    Up,
    Down,
    Left,
    Right,

    const Self = @This();

    pub fn nextDir(self: Self) Self {
        switch (self) {
            .Up => return .Right,
            .Right => return .Down,
            .Down => return .Left,
            .Left => return .Up,
        }
    }
};

const MoveResult = enum {
    Forward,
    Turn,
    InfiniteLoop,
    OutOfBounds,
};

const Guard = struct {
    map: *const Map,
    start_pos: Coords,
    current_pos: Coords,
    current_dir: Direction,
    loop_counter: u64 = 0,
    obstacle_tile: ?isize,
    visited_tiles: Set(isize),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, map: *const Map) !Self {
        const guard_pos = map.guard_pos orelse {
            return error.MissingGuard;
        };

        return .{
            .map = map,
            .start_pos = guard_pos,
            .current_pos = guard_pos,
            .current_dir = .Up,
            .loop_counter = 0,
            .obstacle_tile = null,
            .visited_tiles = Set(isize).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.visited_tiles.deinit();
    }

    pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
        return .{
            .map = self.map,
            .start_pos = self.start_pos,
            .current_pos = self.start_pos,
            .current_dir = self.current_dir,
            .obstacle_tile = self.obstacle_tile,
            .visited_tiles = Set(isize).init(allocator),
        };
    }

    pub fn reset(self: *Self) void {
        self.current_pos = self.start_pos;
        self.current_dir = .Up;
        self.obstacle_tile = null;
        self.visited_tiles.clear();
    }

    pub fn checkForInfiniteLoops(self: *Self, allocator: std.mem.Allocator) !u64 {
        var possible_loops = Set(isize).init(allocator);
        const start_idx = self.coordsToIndex(self.start_pos);

        var cloned = try self.clone(allocator);
        defer cloned.deinit();

        var tile_it = self.visited_tiles.data.keyIterator();
        while (tile_it.next()) |tile_idx_ptr| {
            // Skip start position of guard as possible obstacle
            if (tile_idx_ptr.* == start_idx) {
                continue;
            }

            // Reset guard clone and set obstacle tile to current tile
            cloned.reset();
            cloned.obstacle_tile = tile_idx_ptr.*;

            // Move guard clone until either out of bounds or infinite loop
            var move_result = try cloned.nextMove();
            while (move_result != .OutOfBounds and move_result != .InfiniteLoop) {
                move_result = try cloned.nextMove();
            }

            // Add to possible loops if guard clone ended in infinite loop
            if (move_result == .InfiniteLoop) {
                try possible_loops.add(tile_idx_ptr.*);
            }
        }

        return possible_loops.count();
    }

    pub fn moveUntilOutOfBounds(self: *Self) !void {
        while (try self.nextMove() != .OutOfBounds) {}
    }

    fn nextMove(self: *Self) !MoveResult {
        // Determine current tile index and add to set of visited tiles
        const current_idx = self.coordsToIndex(self.current_pos);
        try self.visited_tiles.add(current_idx);

        // Calculate next coordinates for guard
        var next_pos = self.current_pos;
        switch (self.current_dir) {
            .Up => next_pos.y -= 1,
            .Down => next_pos.y += 1,
            .Left => next_pos.x -= 1,
            .Right => next_pos.x += 1,
        }

        // Determine next tile when moving in current direction and cancel if out of bounds
        const next_idx = self.coordsToIndex(next_pos);
        const next_tile = self.map.get(next_pos) orelse {
            return .OutOfBounds;
        };

        // Turn to next direction (clockwise) if next tile is blocked
        if (next_tile == .Blocked or next_idx == self.obstacle_tile) {
            self.current_dir = self.current_dir.nextDir();
            return .Turn;
        }

        // If next tile has been visited before, increment loop counter, otherwise reset
        if (self.visited_tiles.contains(next_idx)) {
            self.loop_counter += 1;
        } else {
            self.loop_counter = 0;
        }

        // Assume infinite loop if guard visited more previously visited tiles than total visited tiles
        if (self.loop_counter > self.visited_tiles.count()) {
            return .InfiniteLoop;
        }

        // Otherwise move to next tile
        self.current_pos = next_pos;
        return .Forward;
    }

    inline fn coordsToIndex(self: *Self, coords: Coords) isize {
        return coords.x + coords.y * self.map.cols;
    }

    inline fn indexToCoords(self: *Self, index: ?isize) ?Coords {
        if (index == null) {
            return null;
        }

        return .{
            .x = @mod(index.?, self.map.cols),
            .y = @divFloor(index.?, self.map.cols),
        };
    }
};

const Map = struct {
    rows: isize,
    cols: isize,
    tiles: std.ArrayList(Tile),
    guard_pos: ?Coords,

    const Self = @This();

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Self {
        var self: Self = .{
            .rows = 0,
            .cols = 0,
            .tiles = std.ArrayList(Tile).init(allocator),
            .guard_pos = null,
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

            // Parse each character as tile
            var line_col: isize = 0;
            for (line) |c| {
                switch (c) {
                    '.' => try self.tiles.append(.Free),
                    '#' => try self.tiles.append(.Blocked),
                    '^' => {
                        try self.tiles.append(.Free);
                        self.guard_pos = .{
                            .x = line_col,
                            .y = self.rows - 1,
                        };
                    },
                    else => return error.IllegalTile,
                }

                line_col += 1;
            }
        }

        return self;
    }

    pub fn get(self: *const Self, coords: Coords) ?Tile {
        if (coords.x < 0 or coords.y < 0 or coords.x >= self.cols or coords.y >= self.rows) {
            return null;
        }

        const index: usize = @intCast(self.cols * coords.y + coords.x);
        return self.tiles.items[index];
    }

    pub fn deinit(self: *Self) void {
        self.tiles.deinit();
    }
};

const example_input =
    \\....#.....
    \\.........#
    \\..........
    \\..#.......
    \\.......#..
    \\..........
    \\.#..^.....
    \\........#.
    \\#.........
    \\......#...
;

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(41, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(6, problem.part2());
}
