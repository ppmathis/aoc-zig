const std = @import("std");
const helpers = @import("helpers");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    return try calculateFenceCost(this.allocator, this.input, false);
}

pub fn part2(this: *const Problem) !?u64 {
    return try calculateFenceCost(this.allocator, this.input, true);
}

fn calculateFenceCost(allocator: std.mem.Allocator, input: []const u8, discount: bool) !u64 {
    // Parse map of garden plots from input
    var map = try PlotMap.parse(allocator, input);
    defer map.deinit();

    // Initialize set for storing visited plots
    var visited = helpers.CoordsSet.init(allocator);
    defer visited.deinit();

    // Loop through each tile entry and calculate total fencing costs
    var total_costs: u64 = 0;
    var entry_iter = map.iterate();
    while (entry_iter.next()) |entry| {
        // Skip if plot has already been visited
        if (visited.contains(entry.coords)) {
            continue;
        }

        // Find region of plot and calculate fencing costs
        const info = try findPlotRegion(entry.coords, allocator, &map, &visited);
        if (discount) {
            total_costs += info.area * info.sides;
        } else {
            total_costs += info.area * info.perimeter;
        }
    }

    return total_costs;
}

fn findPlotRegion(start: helpers.Coords, allocator: std.mem.Allocator, map: *PlotMap, visited: *helpers.CoordsSet) !PlotRegion {
    var result = PlotRegion{ .area = 0, .perimeter = 0, .sides = 0 };

    // Initialize stack for storing plots to visit
    var stack = helpers.CoordsList.init(allocator);
    defer stack.deinit();

    // Clear stack and add start plot
    stack.clearRetainingCapacity();
    try stack.append(start);
    try visited.add(start);

    // Loop while stack contains coordinates to visit
    while (stack.popOrNull()) |coords| {
        // Get current plot and increment area
        const plot = map.get(coords).?;
        result.area += 1;

        // Determine surrounding coordinates
        const north = helpers.Coords{ .x = coords.x, .y = coords.y - 1 };
        const north_east = helpers.Coords{ .x = coords.x + 1, .y = coords.y - 1 };
        const east = helpers.Coords{ .x = coords.x + 1, .y = coords.y };
        const south_east = helpers.Coords{ .x = coords.x + 1, .y = coords.y + 1 };
        const south = helpers.Coords{ .x = coords.x, .y = coords.y + 1 };
        const south_west = helpers.Coords{ .x = coords.x - 1, .y = coords.y + 1 };
        const west = helpers.Coords{ .x = coords.x - 1, .y = coords.y };
        const north_west = helpers.Coords{ .x = coords.x - 1, .y = coords.y - 1 };

        // Initialize array for storing if neighbors are equal
        var neighbors = [8]bool{ false, false, false, false, false, false, false, false };

        // Process each neighboring plot
        const neighbor_coords = [8]helpers.Coords{ north, north_east, east, south_east, south, south_west, west, north_west };
        for (neighbor_coords, 0..) |neighbor_coord, i| {
            const neighbor = map.get(neighbor_coord);
            const is_diagonal = i % 2 != 0;

            // Skip if neighbor is out of bounds or not equal
            if (neighbor == null or !plot.eql(neighbor.?)) {
                if (!is_diagonal) result.perimeter += 1;
                continue;
            }

            // Mark neighbor as equal to current plot, used for corner detection
            neighbors[i] = true;

            // Add non-diagonal neighbors to stack if not visited before
            if (!is_diagonal and !visited.contains(neighbor_coord)) {
                try stack.append(neighbor_coord);
                try visited.add(neighbor_coord);
            }
        }

        // Increment sides whenever there is an inner or outer corner
        if ((neighbors[0] == neighbors[2]) and (!neighbors[0] or !neighbors[1])) result.sides += 1;
        if ((neighbors[2] == neighbors[4]) and (!neighbors[2] or !neighbors[3])) result.sides += 1;
        if ((neighbors[4] == neighbors[6]) and (!neighbors[4] or !neighbors[5])) result.sides += 1;
        if ((neighbors[6] == neighbors[0]) and (!neighbors[6] or !neighbors[7])) result.sides += 1;
    }

    return result;
}

const PlotMap = helpers.Map(Plot);

const PlotRegion = struct {
    area: u64,
    perimeter: u64,
    sides: u64,
};

const Plot = struct {
    plant: u8,

    const Self = @This();

    pub fn from(c: u8) !Self {
        return .{ .plant = c };
    }

    pub inline fn eql(self: Self, other: Self) bool {
        return self.plant == other.plant;
    }
};

const example_input_little =
    \\AAAA
    \\BBCD
    \\BBCC
    \\EEEC
;

const example_input_big =
    \\RRRRIICCFF
    \\RRRRIICCCF
    \\VVRRRCCFFF
    \\VVRCCCJFFF
    \\VVVVCJJCFE
    \\VVIVCCJJEE
    \\VVIIICJJEE
    \\MIIIIIJJEE
    \\MIIISIJEEE
    \\MMMISSJEEE
;

test "part 1: little example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input_little,
        .allocator = allocator,
    };

    try std.testing.expectEqual(140, problem.part1());
}

test "part 1: big example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input_big,
        .allocator = allocator,
    };

    try std.testing.expectEqual(1930, problem.part1());
}

test "part 2: little example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input_little,
        .allocator = allocator,
    };

    try std.testing.expectEqual(80, problem.part2());
}

test "part 2: big example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input_big,
        .allocator = allocator,
    };

    try std.testing.expectEqual(1206, problem.part2());
}
