const std = @import("std");
const helpers = @import("helpers");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    // Parse input into a map
    var map = try Map.parse(this.allocator, this.input);
    defer map.deinit();

    // Initialize set for storing trail ends
    var trails = TrailSet.init(this.allocator);
    defer trails.deinit();

    // Check all tiles for potential trails
    var entries = map.iterate();
    while (entries.next()) |entry| {
        _ = try findTrails(&map, &trails, entry.coords, entry.coords, 0);
    }

    return trails.count();
}

pub fn part2(this: *const Problem) !?u64 {
    // Parse input into a map
    var map = try Map.parse(this.allocator, this.input);
    defer map.deinit();

    // Check all tiles for potential trails
    var result: u64 = 0;
    var entries = map.iterate();
    while (entries.next()) |entry| {
        result += try findTrails(&map, null, entry.coords, entry.coords, 0);
    }

    return result;
}

pub fn findTrails(map: *const Map, trails: ?*TrailSet, start: helpers.Coords, current: helpers.Coords, current_depth: u8) !u64 {
    // Bail out if current position is out of bounds
    const current_tile = map.get(current) orelse return 0;

    // Bail out if current tile does not match depth
    if (current_tile.depth != current_depth) {
        return 0;
    }

    // Once final tile is reached, add new trail
    if (current_tile.depth == 9) {
        if (trails) |trail_set| {
            const trail = Trail{ .start = start, .end = current };
            try trail_set.add(trail);
        }

        return 1;
    }

    // Galculate tile positions around current tile
    const north = helpers.Coords{ .x = current.x, .y = current.y - 1 };
    const east = helpers.Coords{ .x = current.x + 1, .y = current.y };
    const south = helpers.Coords{ .x = current.x, .y = current.y + 1 };
    const west = helpers.Coords{ .x = current.x - 1, .y = current.y };

    // Check all surrounding tiles with depth+1 for a valid path
    var paths: u64 = 0;
    paths += try findTrails(map, trails, start, north, current_tile.depth + 1);
    paths += try findTrails(map, trails, start, east, current_tile.depth + 1);
    paths += try findTrails(map, trails, start, south, current_tile.depth + 1);
    paths += try findTrails(map, trails, start, west, current_tile.depth + 1);

    return paths;
}

const Map = helpers.Map(Tile);
const TrailSet = helpers.Set(Trail);

const Trail = struct {
    start: helpers.Coords,
    end: helpers.Coords,
};

const Tile = struct {
    depth: u8,

    const Self = @This();

    pub fn from(c: u8) !Self {
        if (c >= '0' and c <= '9') {
            return .{ .depth = c - '0' };
        } else {
            return error.InvalidTile;
        }
    }
};

const example_input =
    \\89010123
    \\78121874
    \\87430965
    \\96549874
    \\45678903
    \\32019012
    \\01329801
    \\10456732
;

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(36, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(81, problem.part2());
}
