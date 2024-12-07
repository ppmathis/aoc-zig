const std = @import("std");

var opt_aoc_year: u32 = undefined;
var opt_aoc_day: u32 = undefined;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Options
    opt_aoc_year = b.option(
        u32,
        "year",
        "Year of AoC puzzle to run",
    ) orelse fatal("Missing required option: --year\n", .{});

    opt_aoc_day = b.option(
        u32,
        "day",
        "Day of AoC puzzle to run",
    ) orelse fatal("Missing required option: --day\n", .{});

    // Problem and Input
    const problem_file = try std.fmt.allocPrint(b.allocator, "src/{d}/day{d}.zig", .{ opt_aoc_year, opt_aoc_day });
    const problem_path = b.path(problem_file);

    const input_file = try std.fmt.allocPrint(b.allocator, "data/{d}/day{d}.txt", .{ opt_aoc_year, opt_aoc_day });
    const input_path = b.path(input_file);

    // Prepare
    const prepare_step = b.step("prepare", "Prepare the AoC puzzle");
    prepare_step.makeFn = prepareStep;

    // Helpers Module
    const helpers_mod = b.createModule(.{
        .root_source_file = b.path("src/helpers.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Problem Module
    const problem_mod = b.createModule(.{
        .root_source_file = problem_path,
        .target = target,
        .optimize = optimize,
    });
    problem_mod.addImport("helpers", helpers_mod);

    // Executable
    const exe_name = try std.fmt.allocPrint(b.allocator, "aoc{d}-day{d}", .{ opt_aoc_year, opt_aoc_day });
    defer b.allocator.free(exe_name);

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("helpers", helpers_mod);
    exe.root_module.addImport("problem", problem_mod);
    exe.root_module.addAnonymousImport("input", .{ .root_source_file = input_path });
    exe.step.dependOn(prepare_step);

    // Install
    b.installArtifact(exe);

    // Run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the AoC puzzle");
    run_step.dependOn(&run_cmd.step);

    // Test
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("helpers", helpers_mod);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    run_exe_unit_tests.step.dependOn(prepare_step);

    const problem_unit_tests = b.addTest(.{
        .root_source_file = problem_path,
        .target = target,
        .optimize = optimize,
    });
    problem_unit_tests.root_module.addImport("helpers", helpers_mod);

    const run_problem_unit_tests = b.addRunArtifact(problem_unit_tests);
    run_problem_unit_tests.step.dependOn(prepare_step);

    const test_step = b.step("test", "Test the AoC puzzle");
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_problem_unit_tests.step);

    // Clean
    const clean_cmd = b.addRemoveDirTree(b.install_path);
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&clean_cmd.step);
}

fn prepareStep(_: *std.Build.Step, _: std.Progress.Node) !void {
    const allocator = std.heap.page_allocator;

    // Determine relevant paths
    const problem_path = try std.fmt.allocPrint(allocator, "src/{d}/day{d}.zig", .{ opt_aoc_year, opt_aoc_day });
    defer allocator.free(problem_path);

    const input_path = try std.fmt.allocPrint(allocator, "data/{d}/day{d}.txt", .{ opt_aoc_year, opt_aoc_day });
    defer allocator.free(input_path);

    // Ensure current AoC day is ready for execution
    try fetchInputFile(allocator, opt_aoc_year, opt_aoc_day, input_path);
    try createProblemFile(problem_path);
}

fn createProblemFile(problem_path: []const u8) !void {
    // If problem file already exists, do nothing
    if (std.fs.cwd().access(problem_path, .{})) |_| {
        return;
    } else |_| {}

    // Define template for new problem file
    const template =
        \\const std = @import("std");
        \\const Problem = @This();
        \\
        \\input: []const u8,
        \\allocator: std.mem.Allocator,
        \\
        \\pub fn part1(this: *const Problem) !?i64 {
        \\    _ = this;
        \\    return null;
        \\}
        \\
        \\pub fn part2(this: *const Problem) !?i64 {
        \\    _ = this;
        \\    return null;
        \\}
        \\
    ;

    // Write new problem file to disk
    const problem_dir_name = std.fs.path.dirname(problem_path).?;
    const problem_dir = try std.fs.cwd().makeOpenPath(problem_dir_name, .{});

    const problem_file_name = std.fs.path.basename(problem_path);
    const problem_file = try problem_dir.createFile(problem_file_name, .{});
    defer problem_file.close();

    try problem_file.writeAll(template);
}

fn fetchInputFile(allocator: std.mem.Allocator, year: u32, day: u32, input_path: []const u8) !void {
    // If input file already exists, do nothing
    if (std.fs.cwd().access(input_path, .{})) |_| {
        return;
    } else |_| {}

    // Prepare string for Cookie header
    const token = try std.process.getEnvVarOwned(allocator, "AOC_TOKEN");
    const token_cookie = try std.fmt.allocPrint(allocator, "session={s}", .{token});
    defer allocator.free(token_cookie);

    // Build request URL to obtain specific day
    const request_url = try std.fmt.allocPrint(allocator, "https://adventofcode.com/{d}/day/{d}/input", .{ year, day });
    defer allocator.free(request_url);

    // Initialize HTTP client and response buffer
    var http_client = std.http.Client{ .allocator = allocator };
    defer http_client.deinit();
    var response_buffer = std.ArrayList(u8).init(allocator);
    defer response_buffer.deinit();

    // Fetch input file via HTTP client
    const response = try http_client.fetch(.{
        .method = .GET,
        .location = .{ .url = request_url },
        .extra_headers = &[_]std.http.Header{
            .{ .name = "Cookie", .value = token_cookie },
        },
        .response_storage = .{ .dynamic = &response_buffer },
    });

    // Ensure response status is OK
    if (response.status != .ok) {
        return error.@"Failed to fetch input file";
    }

    // Write gathered input file to disk
    const input_dir_name = std.fs.path.dirname(input_path).?;
    const input_dir = try std.fs.cwd().makeOpenPath(input_dir_name, .{});

    const input_file_name = std.fs.path.basename(input_path);
    const input_file = try input_dir.createFile(input_file_name, .{});
    defer input_file.close();

    try input_file.writeAll(response_buffer.items);
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}
