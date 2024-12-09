const std = @import("std");
const Problem = @This();

input: []const u8,
allocator: std.mem.Allocator,

const debug = false;

pub fn part1(this: *const Problem) !?u64 {
    // Parse disk from input
    var disk = try Disk.parse(this.allocator, this.input);
    defer disk.deinit();

    // Defragment disk by moving used blocks from the end to the left-most free spots
    var forward: usize = 0;
    var reverse: usize = disk.blocks.items.len - 1;
    while (forward < disk.blocks.items.len) {
        // Skip block if already in use
        const block = disk.blocks.items[forward];
        if (block != null) {
            forward += 1;
            continue;
        }

        // Search for right-most block that is used
        while (reverse > forward and disk.blocks.items[reverse] == null) {
            reverse -= 1;
        }

        // Stop once reverse index is less than forward index
        if (reverse <= forward) {
            break;
        }

        // Move used block to the left-most free spot
        disk.blocks.items[forward] = disk.blocks.items[reverse];
        disk.blocks.items[reverse] = null;

        // Proceed to next block
        forward += 1;
    }

    return disk.checksum();
}

pub fn part2(this: *const Problem) !?u64 {
    // Parse disk from input
    var disk = try Disk.parse(this.allocator, this.input);
    defer disk.deinit();

    // Visualize blocks before defragmentation
    if (debug) {
        disk.visualize();
    }

    // Defragment disk by attempting to move files into free spots
    var file_index = disk.files.items.len;
    while (file_index > 0) {
        // Find current file entry for gathering more information
        file_index -= 1;
        var file = &disk.files.items[file_index];

        // Search for free chunks before current position to relocate file
        var block_index: usize = 0;
        while (block_index < file.start) {
            // Skip if block is already in use
            const block = disk.blocks.items[block_index];
            if (block != null) {
                block_index += 1;
                continue;
            }

            // Check if there are enough free blocks to fit the file
            var free_blocks: usize = 1;
            while (block_index + free_blocks < disk.blocks.items.len and disk.blocks.items[block_index + free_blocks] == null) {
                free_blocks += 1;
            }

            // If there are not enough free blocks, skip to next block
            if (free_blocks < file.blocks) {
                if (debug) {
                    std.debug.print("skipping {d} blocks at index {d}, need {d} blocks\n", .{ free_blocks, block_index, file.blocks });
                }
                block_index += free_blocks;
                continue;
            }

            // Otherwise move file blocks to new spot
            for (0..file.blocks) |i| {
                disk.blocks.items[block_index + i] = disk.blocks.items[file.start + i];
                disk.blocks.items[file.start + i] = null;
            }

            // Relocate file to point to new start index
            if (debug) {
                std.debug.print("relocated file #{d} from {d} to {d}\n", .{ file.id, file.start, block_index });
            }
            file.start = block_index;

            // Break out of loop after successfully relocating file
            break;
        }
    }

    // Visualize blocks after defragmentation
    if (debug) {
        disk.visualize();
    }

    return disk.checksum();
}

const Disk = struct {
    blocks: std.ArrayList(?Block),
    files: std.ArrayList(File),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .blocks = std.ArrayList(?Block).init(allocator),
            .files = std.ArrayList(File).init(allocator),
        };
    }

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Self {
        var blocks = std.ArrayList(?Block).init(allocator);
        var files = std.ArrayList(File).init(allocator);
        errdefer blocks.deinit();
        errdefer files.deinit();

        var block_id: u64 = 0;
        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        while (lines.next()) |line| {
            var i: usize = 0;
            while (i < line.len) {
                // Read first digit to determine how many blocks are used
                const used_blocks = line[i] - '0';

                // Allocate X blocks and mark them as used, then add file entry
                const first_block = blocks.items.len;
                for (0..used_blocks) |_| {
                    try blocks.append(Block{ .id = block_id });
                }
                try files.append(File{
                    .id = block_id,
                    .start = first_block,
                    .blocks = used_blocks,
                });

                // Increment block ID for next iteration
                block_id += 1;

                // Bail out if i+1 is out of bounds
                if (i + 1 >= line.len) {
                    break;
                }

                // Read second digit and mark X blocks as free
                const free_blocks = line[i + 1] - '0';
                for (0..free_blocks) |_| {
                    try blocks.append(null);
                }

                // Increment index by 2 to skip to next pair of digits
                i += 2;
            }
        }

        return .{
            .blocks = blocks,
            .files = files,
        };
    }

    pub fn visualize(this: *Self) void {
        for (this.blocks.items) |block| {
            if (block) |b| {
                std.debug.print("{d}", .{b.id});
            } else {
                std.debug.print(".", .{});
            }
        }

        std.debug.print("\n", .{});
    }

    pub fn checksum(this: *Self) u64 {
        var result: u64 = 0;
        for (this.blocks.items, 0..) |block, index| {
            if (block) |b| {
                result += index * b.id;
            }
        }

        return result;
    }

    pub fn deinit(this: *Self) void {
        this.blocks.deinit();
        this.files.deinit();
    }
};

const Block = struct { id: u64 };

const File = struct {
    id: u64,
    start: u64,
    blocks: u64,
};

const example_input =
    \\2333133121414131402
;

test "part 1: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(1928, problem.part1());
}

test "part 2: example" {
    const allocator = std.testing.allocator;

    const problem = Problem{
        .input = example_input,
        .allocator = allocator,
    };

    try std.testing.expectEqual(2858, problem.part2());
}
