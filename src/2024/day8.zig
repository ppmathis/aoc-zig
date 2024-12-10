const std = @import("std");
const helpers = @import("helpers");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    // Parse input as antenna map, containing antennas with varying frequencies
    var map = try AntennaMap.parse(this.allocator, this.input);
    defer map.deinit();

    // Initialize set for storing antinodes
    var antinodes = helpers.Set(helpers.Coords).init(this.allocator);
    defer antinodes.deinit();

    // Check all pairs of antennas with same frequency for antinodes
    var pairs_a = map.iterate();
    while (pairs_a.next()) |pair_a| {
        // Skip tiles with no antenna, where frequency is null
        if (pair_a.tile.frequency == null) {
            continue;
        }

        // Check all other antennas with same frequency
        var pairs_b = map.iterate();
        while (pairs_b.next()) |pair_b| {
            // Skip if antennas are the same
            if (pair_a.coords.eql(pair_b.coords)) {
                continue;
            }

            // Skip if antennas have different frequencies
            if (pair_a.tile.frequency != pair_b.tile.frequency) {
                continue;
            }

            // Calculate X/Y distance between antennas
            const dx = pair_b.coords.x - pair_a.coords.x;
            const dy = pair_b.coords.y - pair_a.coords.y;

            // Calculate position of antinode
            const node_a = helpers.Coords{ .x = pair_a.coords.x - dx, .y = pair_a.coords.y - dy };
            const node_b = helpers.Coords{ .x = pair_b.coords.x + dx, .y = pair_b.coords.y + dy };

            // Add antinodes to set if within bounds
            if (map.checkBounds(node_a)) try antinodes.add(node_a);
            if (map.checkBounds(node_b)) try antinodes.add(node_b);
        }
    }

    // Visualize map with antinodes
    if (false)
        visualizeMap(&map, &antinodes);

    return antinodes.count();
}

pub fn part2(this: *const Problem) !?u64 {
    // Parse input as antenna map, containing antennas with varying frequencies
    var map = try AntennaMap.parse(this.allocator, this.input);
    defer map.deinit();

    // Initialize set for storing antinodes
    var antinodes = helpers.Set(helpers.Coords).init(this.allocator);
    defer antinodes.deinit();

    // Check all pairs of antennas with same frequency for antinodes
    var pairs_a = map.iterate();
    while (pairs_a.next()) |pair_a| {
        // Skip tiles with no antenna, where frequency is null
        if (pair_a.tile.frequency == null) {
            continue;
        }

        // Check all other antennas with same frequency
        var pairs_b = map.iterate();
        while (pairs_b.next()) |pair_b| {
            // Skip if antennas are the same
            if (pair_a.coords.eql(pair_b.coords)) {
                continue;
            }

            // Skip if antennas have different frequencies
            if (pair_a.tile.frequency != pair_b.tile.frequency) {
                continue;
            }

            // Calculate X/Y distance between antennas
            const dx = pair_b.coords.x - pair_a.coords.x;
            const dy = pair_b.coords.y - pair_a.coords.y;

            // Spawn antinodes on antennas themselves
            try antinodes.add(pair_a.coords);
            try antinodes.add(pair_b.coords);

            // Spawn antinodes backwards from pair A
            var node = helpers.Coords{ .x = pair_a.coords.x - dx, .y = pair_a.coords.y - dy };
            while (map.checkBounds(node)) {
                try antinodes.add(node);
                node.x -= dx;
                node.y -= dy;
            }

            // Spawn antinodes forwards from pair B
            node = helpers.Coords{ .x = pair_b.coords.x + dx, .y = pair_b.coords.y + dy };
            while (map.checkBounds(node)) {
                try antinodes.add(node);
                node.x += dx;
                node.y += dy;
            }
        }
    }

    // Visualize map with antinodes
    if (false)
        visualizeMap(&map, &antinodes);

    return antinodes.count();
}

fn visualizeMap(map: *const AntennaMap, antinodes: *const helpers.Set(helpers.Coords)) void {
    var iter = map.iterate();
    while (iter.next()) |entry| {
        const c = entry.tile.frequency orelse '.';
        if (antinodes.contains(entry.coords)) {
            std.debug.print("#", .{});
        } else {
            std.debug.print("{c}", .{c});
        }

        if (entry.coords.x == map.cols - 1) {
            std.debug.print("\n", .{});
        }
    }
}

const AntennaMap = helpers.Map(Antenna);

const Antenna = struct {
    frequency: ?u8,

    const Self = @This();

    pub fn from(c: u8) !Self {
        return switch (c) {
            '.' => .{ .frequency = null },
            else => .{ .frequency = c },
        };
    }
};

const example_input =
    \\............
    \\........0...
    \\.....0......
    \\.......0....
    \\....0.......
    \\......A.....
    \\............
    \\............
    \\........A...
    \\.........A..
    \\............
    \\............
;

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(14, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(34, problem.part2());
}
