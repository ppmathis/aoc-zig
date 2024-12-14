const std = @import("std");

pub const CoordsSet = Set(Coords);
pub const CoordsList = std.ArrayList(Coords);

pub fn Vec2(comptime T: type) type {
    return struct {
        x: T,
        y: T,

        const Self = @This();

        pub inline fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y;
        }
    };
}

pub const Coords = Vec2(isize);

pub fn Map(comptime Tile: type) type {
    return struct {
        rows: isize,
        cols: isize,
        tiles: std.ArrayList(Tile),

        const Self = @This();

        pub const Entry = struct {
            index: isize,
            coords: Coords,
            tile: *Tile,
        };

        pub const Iterator = struct {
            map: *const Self,
            index: isize,

            pub fn next(self: *Iterator) ?Entry {
                self.index += 1;
                if (self.index >= self.map.tiles.items.len) {
                    return null;
                }

                return .{
                    .index = self.index,
                    .coords = self.map.indexToCoords(@intCast(self.index)).?,
                    .tile = &self.map.tiles.items[@intCast(self.index)],
                };
            }
        };

        pub fn init(allocator: std.mem.Allocator, cols: isize, rows: isize, default: Tile) !Self {
            // Calculate total map size and allocate tile array
            const size: usize = @intCast(rows * cols);
            var tiles = try std.ArrayList(Tile).initCapacity(allocator, size);

            // Fill all tiles with default value
            for (0..size) |_| {
                _ = try tiles.append(default);
            }

            // Return initialized map
            return .{
                .rows = rows,
                .cols = cols,
                .tiles = tiles,
            };
        }

        pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Self {
            var rows: isize = 0;
            var cols: isize = 0;
            var tiles = std.ArrayList(Tile).init(allocator);
            errdefer tiles.deinit();

            var lines = std.mem.tokenizeScalar(u8, input, '\n');
            while (lines.next()) |line| {
                // Increment rows and determine columns if not set
                rows += 1;
                if (cols == 0) {
                    cols = @intCast(line.len);
                }

                // Ensure each line has the same number of columns
                if (line.len != cols) {
                    std.debug.print("line has {d} columns, expected {d}\n", .{ line.len, cols });
                    std.debug.print("line: {s}\n", .{line});
                    return error.ColumnMismatch;
                }

                // Parse each character as tile
                for (line) |c| {
                    const tile: Tile = try Tile.from(c);
                    _ = try tiles.append(tile);
                }
            }

            return .{
                .rows = rows,
                .cols = cols,
                .tiles = tiles,
            };
        }

        pub fn clear(self: *Self, default: Tile) void {
            for (self.tiles.items) |*tile| {
                tile.* = default;
            }
        }

        pub fn iterate(self: *const Self) Iterator {
            return .{
                .map = self,
                .index = -1,
            };
        }

        pub fn checkBounds(self: *const Self, coords: Coords) bool {
            return coords.x >= 0 and coords.y >= 0 and coords.x < self.cols and coords.y < self.rows;
        }

        pub fn get(self: *const Self, coords: Coords) ?Tile {
            if (self.coordsToIndex(coords)) |index| {
                return self.tiles.items[@intCast(index)];
            }

            return null;
        }

        pub fn set(self: *Self, coords: Coords, tile: Tile) void {
            if (self.coordsToIndex(coords)) |index| {
                self.tiles.items[@intCast(index)] = tile;
            }
        }

        pub fn deinit(self: *Self) void {
            self.tiles.deinit();
        }

        pub inline fn coordsToIndex(self: *const Self, coords: Coords) ?isize {
            if (coords.x < 0 or coords.y < 0 or coords.x >= self.cols or coords.y >= self.rows) {
                return null;
            }

            return coords.y * self.cols + coords.x;
        }

        pub inline fn indexToCoords(self: *const Self, index: isize) ?Coords {
            if (index < 0 or index >= self.tiles.items.len) {
                return null;
            }

            return .{
                .x = @mod(index, self.cols),
                .y = @divFloor(index, self.cols),
            };
        }
    };
}

pub fn Set(comptime T: type) type {
    return struct {
        data: HashMapSet,

        const HashMapSet = std.AutoHashMap(T, void);
        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .data = HashMapSet.init(allocator) };
        }

        pub fn fromArray(allocator: std.mem.Allocator, values: []T) !Self {
            var set = Self.init(allocator);
            for (values) |value| {
                _ = try set.add(value);
            }
            return set;
        }

        pub fn add(self: *Self, value: T) !void {
            _ = try self.data.getOrPut(value);
        }

        pub fn contains(self: *const Self, value: T) bool {
            return self.data.contains(value);
        }

        pub fn count(self: *const Self) usize {
            return self.data.count();
        }

        pub fn clear(self: *Self) void {
            self.data.clearAndFree();
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }
    };
}

pub fn Graph(comptime N: type) type {
    return struct {
        allocator: std.mem.Allocator,
        edges: std.AutoHashMap(N, Set(N)),
        in_degree: std.AutoHashMap(N, usize),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .edges = std.AutoHashMap(N, Set(N)).init(allocator),
                .in_degree = std.AutoHashMap(N, usize).init(allocator),
            };
        }

        pub fn addEdge(self: *Self, from: N, to: N) !void {
            // Add edge from 'from' to 'to'
            if (!self.edges.contains(from)) {
                try self.edges.put(from, Set(N).init(self.allocator));
            }

            var edge_set = self.edges.getPtr(from) orelse unreachable;
            try edge_set.add(to);

            // Set default in-degrees of 0 for 'from' node
            _ = try self.in_degree.getOrPutValue(from, 0);

            // Increment in-degrees for 'to' node
            const to_degree = self.in_degree.get(to) orelse 0;
            try self.in_degree.put(to, to_degree + 1);
        }

        pub fn createSubGraph(self: *Self, nodes: []N) !Self {
            // Transform nodes array into set for faster lookups
            var node_set = try Set(N).fromArray(self.allocator, nodes);
            defer node_set.deinit();

            // Initialize new graph for storing sub-graph
            var sub_graph = Self.init(self.allocator);

            // Iterate over all nodes in the parent graph to build sub-graph
            for (nodes) |node| {
                // Obtain iterator over parent graph edges for current node
                const parent_edge_set = self.edges.getPtr(node) orelse continue;
                var parent_edge_iter = parent_edge_set.data.keyIterator();

                // Copy all edges from parent graph, if both nodes are in the sub-graph
                while (parent_edge_iter.next()) |parent_edge_ptr| {
                    const parent_edge = parent_edge_ptr.*;
                    if (node_set.contains(parent_edge)) {
                        _ = try sub_graph.addEdge(node, parent_edge);
                    }
                }
            }

            return sub_graph;
        }

        pub fn topologicalSort(self: *Self, nodes: []N) !std.ArrayList(N) {
            // Build sub-graph for specified nodes
            var sub_graph = try self.createSubGraph(nodes);
            defer sub_graph.deinit();

            // Initialize node queue for topological sort
            var queue = std.ArrayList(N).init(self.allocator);
            defer queue.deinit();

            // Add all nodes with in-degree of 0 to queue
            for (nodes) |node| {
                if (sub_graph.in_degree.get(node) == 0) {
                    _ = try queue.append(node);
                }
            }

            // Initialize ordered list for topological sort
            var ordered = std.ArrayList(N).init(self.allocator);

            // Perform topological sort on sub-graph until queue is empty
            while (queue.items.len > 0) {
                // Remove first element from queue and add to ordered list
                const current = queue.orderedRemove(0);
                _ = try ordered.append(current);

                // Get pointer to edge set from sub-graph and skip if not found
                const edge_set = sub_graph.edges.getPtr(current) orelse continue;
                var edge_iter = edge_set.data.keyIterator();

                // Iterate over all edges from current node
                while (edge_iter.next()) |edge_ptr| {
                    const edge = edge_ptr.*;

                    // Get current edge and decrement in-degree
                    var degree = sub_graph.in_degree.get(edge) orelse unreachable;
                    degree -= 1;

                    // If in-degree is 0, add to queue
                    if (degree == 0) {
                        _ = try queue.append(edge);
                    }

                    // Update in-degree for current edge
                    _ = try sub_graph.in_degree.put(edge, degree);
                }
            }

            // Return ordered list of nodes
            return ordered;
        }

        pub fn deinit(self: *Self) void {
            var edge_set = self.edges.valueIterator();
            while (edge_set.next()) |edge| {
                edge.deinit();
            }
            self.edges.deinit();
            self.in_degree.deinit();
        }
    };
}
