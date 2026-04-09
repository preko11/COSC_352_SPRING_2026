# CSV Data Profiler

A command-line data profiling tool written in Rust that ingests any CSV file and produces a structured report describing the shape, quality, and statistical characteristics of each column.

The profiler is built as a demonstration of idiomatic Rust design — traits, ownership, error handling, and zero-cost abstractions — while remaining fast enough to handle large files without loading them entirely into memory.

## Dependencies

This project uses the following Cargo crates:

- `anyhow` for ergonomic error handling
- `chrono` for date parsing and handling
- `clap` for command-line argument parsing
- `csv` for streaming CSV reading and parsing
- `serde` and `serde_json` for report serialization

## Build

From `project07/project07`:

```bash
cargo build
```

## Run

From `project07/project07`:

```bash
cargo run -- path/to/data.csv --format text
```

Example with flags:

```bash
cargo run -- path/to/data.csv --delimiter , --format json --no-headers
```

## CLI Options

- `input` — path to the CSV file
- `--delimiter <char>` — optional field delimiter (default: `,`)
- `--format <text|json>` — output format (default: `text`)
- `--no-headers` — treat the CSV as having no header row
- `--sample-size <usize>` — number of rows used for type inference (default: `1000`)

## Notes

- The profiler streams rows rather than loading the full file into memory.
- It infers column data types such as integer, float, boolean, date, categorical, and text.
- It reports missing values, unique counts, numeric statistics, top values, and warnings for data quality issues.

