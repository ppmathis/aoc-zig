const std = @import("std");

const Problem = @import("problem");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const problem = Problem{
        .input = @embedFile("input"),
        .allocator = allocator,
    };

    if (try problem.part1()) |solution| {
        try stdout.print(switch (@TypeOf(solution)) {
            []const u8 => "{s}",
            else => "{any}",
        } ++ "\n", .{solution});
    }

    if (try problem.part2()) |solution| {
        try stdout.print(switch (@TypeOf(solution)) {
            []const u8 => "{s}",
            else => "{any}",
        } ++ "\n", .{solution});
    }
}
