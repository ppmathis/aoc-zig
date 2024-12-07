const std = @import("std");
const helpers = @import("helpers");
const Problem = @This();

const Page = u8;
const PageList = std.ArrayList(Page);
const PageGraph = helpers.Graph(Page);

input: []const u8,
allocator: std.mem.Allocator,

pub fn part1(this: *const Problem) !?u64 {
    var data = try Data.parse(this.allocator, this.input);
    defer data.deinit();

    var result: u64 = 0;
    for (data.page_lists.items) |page_list| {
        // Use topological sort to determine correct page order
        const ordered_pages = try data.graph.topologicalSort(page_list.items);
        defer ordered_pages.deinit();

        // If update was correctly ordered, determine middle page and sum to result
        if (std.mem.eql(Page, ordered_pages.items, page_list.items)) {
            const middle_page = determineMiddlePage(page_list.items);
            result += middle_page;
        }
    }

    return result;
}

pub fn part2(this: *const Problem) !?u64 {
    var data = try Data.parse(this.allocator, this.input);
    defer data.deinit();

    var result: u64 = 0;
    for (data.page_lists.items) |page_list| {
        // Use topological sort to determine correct page order
        const ordered_pages = try data.graph.topologicalSort(page_list.items);
        defer ordered_pages.deinit();

        // If update was incorrectly ordered, determine middle page of reordered list and sum to result
        if (!std.mem.eql(Page, ordered_pages.items, page_list.items)) {
            const middle_page = determineMiddlePage(ordered_pages.items);
            result += middle_page;
        }
    }

    return result;
}

fn determineMiddlePage(pages: []Page) Page {
    const middle_index = pages.len / 2;
    return pages[middle_index];
}

const Data = struct {
    graph: PageGraph,
    page_lists: std.ArrayList(PageList),

    const Self = @This();

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Self {
        var blocks = std.mem.tokenizeSequence(u8, input, "\n\n");
        const first_block = blocks.next().?;
        const second_block = blocks.next().?;

        return .{
            .graph = try Self.buildPageGraph(allocator, first_block),
            .page_lists = try Self.buildPageLists(allocator, second_block),
        };
    }

    fn buildPageGraph(allocator: std.mem.Allocator, input: []const u8) !PageGraph {
        // Initialize empty graph for storing page ordering rules
        var graph = PageGraph.init(allocator);

        // Build graph of page ordering rules from first block of input
        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        while (lines.next()) |line| {
            // Parse page ordering rule in format "A|B" where A must be read before B
            var parts = std.mem.tokenizeScalar(u8, line, '|');
            const from = try std.fmt.parseInt(Page, parts.next().?, 10);
            const to = try std.fmt.parseInt(Page, parts.next().?, 10);

            // Add edge from 'from' to 'to'
            try graph.addEdge(from, to);
        }

        return graph;
    }

    fn buildPageLists(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(PageList) {
        // Initialize empty array list for storing page lists
        var page_lists = std.ArrayList(PageList).init(allocator);

        // Build array list of page lists from second block of input
        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        while (lines.next()) |line| {
            // Initialize new page list for current line
            var page_list = PageList.init(allocator);

            // Parse comma-separated pages from current line
            var page_tokens = std.mem.tokenizeScalar(u8, line, ',');
            while (page_tokens.next()) |page_str| {
                const page = try std.fmt.parseInt(Page, page_str, 10);
                _ = try page_list.append(page);
            }

            // Add current page list to page lists
            _ = try page_lists.append(page_list);
        }

        return page_lists;
    }

    pub fn deinit(self: *Data) void {
        for (self.page_lists.items) |page_list| {
            page_list.deinit();
        }
        self.page_lists.deinit();
        self.graph.deinit();
    }
};

const example_input =
    \\47|53
    \\97|13
    \\97|61
    \\97|47
    \\75|29
    \\61|13
    \\75|53
    \\29|13
    \\97|29
    \\53|29
    \\61|53
    \\97|53
    \\61|29
    \\47|13
    \\75|47
    \\97|75
    \\47|61
    \\75|61
    \\47|29
    \\75|13
    \\53|13
    \\
    \\75,47,61,53,29
    \\97,61,53,29,13
    \\75,29,13
    \\75,97,47,61,53
    \\61,13,29
    \\97,13,75,29,47
;

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(143, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(123, problem.part2());
}
