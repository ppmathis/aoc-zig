# Advent of Code in Zig

This repository contains my personal solutions for [Advent of Code](https://adventofcode.com/), all written in Zig.

## Usage

To simplify running and testing puzzles, the build script will automatically fetch puzzle inputs via REST API from AoC servers. All puzzle inputs will be locally stored in the `data` directory, whose contents are ignored from version control in accordance with the official AoC guidelines. Please make sure to define the environment variable `AOC_TOKEN` with your session token to let the build script fetch the inputs. If you specify a puzzle that is not covered by this repository, it will be automatically created with a barebones template.

### Running a Specific AoC Puzzle

Use the `run` step and specify the year and day as build options, e.g.:

```sh
zig build -Dyear=2024 -Dday=6 run
```

### Testing a Specific AoC Puzzle

Use the `test` step and specify the year and day as build options, e.g.:

```sh
zig build -Dyear=2024 -Dday=6 test
```

### Environment Setup

Ensure you have the environment variable set:

- `AOC_TOKEN`: Your session token for Advent of Code.

## Directory Structure

- `src/`: Contains the source code for each day's puzzle.
- `data/`: Stores the fetched puzzle inputs (ignored by version control).

## License

This project is licensed under the MIT License. See the [LICENSE.txt](LICENSE.txt) file for details.
