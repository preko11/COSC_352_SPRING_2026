//! csvprof - A production-quality CSV data profiling tool.
//!
//! This is the main entry point that orchestrates the entire profiling pipeline:
//! 1. Parse CLI arguments
//! 2. Open the CSV file (or stdin)
//! 3. Infer column types (first pass with sampling)
//! 4. Create profilers for each inferred type
//! 5. Stream through the CSV (second pass) feeding values to profilers
//! 6. Render the final report

mod cli;
mod error;
mod infer;
mod output;
mod profiler;
mod report;

use anyhow::Result;
use clap::Parser;
use csv::ReaderBuilder;
use infer::TypeInferrer;
use profiler::create_profiler;
use report::CsvReport;
use std::fs::File;
use std::io::{Read, Write};

/// Configuration for profiling operations.
struct ProfileConfig {
    delimiter: u8,
    no_header: bool,
    max_unique: usize,
    percentiles: bool,
    top_n: usize,
    hist: bool,
}

/// The main application entry point.
fn main() -> Result<()> {
    let args = cli::Args::parse();

    // Validate delimiter
    let delimiter = if args.delimiter.len() != 1 {
        return Err(anyhow::anyhow!("Invalid delimiter: {}", args.delimiter));
    } else {
        args.delimiter.chars().next().unwrap() as u8
    };

    // Open input (file or stdin) and buffer if needed
    let input_desc = if args.file == "-" {
        "stdin".to_string()
    } else {
        args.file.clone()
    };

    // Read file content into memory (necessary for two-pass processing with stdin)
    let file_content = read_input(&args.file)?;

    let config = ProfileConfig {
        delimiter,
        no_header: args.no_header,
        max_unique: args.max_unique,
        percentiles: args.percentiles,
        top_n: args.top_n,
        hist: args.hist,
    };

    // First pass: infer types by sampling
    let (headers, inferred_types) = infer_column_types(&file_content, &config)?;

    // Second pass: profile each column
    let column_reports = profile_columns(&file_content, &headers, &inferred_types, &config)?;

    // Build final report
    let report = CsvReport {
        file: input_desc,
        rows: column_reports
            .first()
            .map(|r| r.row_count)
            .unwrap_or(0),
        columns: headers.len(),
        column_reports,
    };

    // Output
    let mut output: Box<dyn Write> = if let Some(output_path) = args.output {
        Box::new(File::create(&output_path)?)
    } else {
        Box::new(std::io::stdout())
    };

    if args.json {
        output::render_json(&report, &mut *output)?;
    } else {
        output::render_terminal(&report, &mut *output)?;
    }

    Ok(())
}

/// Read input from file or stdin into a string buffer.
fn read_input(file_path: &str) -> Result<String> {
    let mut content = String::new();
    if file_path == "-" {
        std::io::stdin().read_to_string(&mut content)?;
    } else {
        let mut file = File::open(file_path)?;
        file.read_to_string(&mut content)?;
    }
    Ok(content)
}

/// First pass: infer column types by sampling.
fn infer_column_types(
    content: &str,
    config: &ProfileConfig,
) -> Result<(Vec<String>, Vec<infer::InferredType>)> {
    let reader = ReaderBuilder::new()
        .delimiter(config.delimiter)
        .has_headers(!config.no_header)
        .from_reader(content.as_bytes());

    let mut headers = Vec::new();
    let mut sample_rows = Vec::new();
    let sample_size = 1000; // Sample up to 1000 rows

    // Read headers and sample values
    {
        let mut reader = reader;
        if !config.no_header {
            match reader.headers() {
                Ok(record) => {
                    headers = record.iter().map(|s| s.to_string()).collect();
                }
                Err(_) => {
                    // No headers, will use index-based names
                }
            }
        }

        // Sample values for type inference
        for (i, result) in reader.records().enumerate() {
            if i >= sample_size {
                break;
            }
            let record = result?;
            sample_rows.push(record.iter().map(|s| s.to_string()).collect::<Vec<_>>());
        }
    }

    // If no headers, use column indices
    if headers.is_empty() && !sample_rows.is_empty() {
        headers = (0..sample_rows[0].len())
            .map(|i| format!("Column_{}", i))
            .collect();
    }

    // Infer types
    let inferrer = TypeInferrer::new(config.max_unique, sample_size);
    let inferred_types = if !sample_rows.is_empty() {
        (0..headers.len())
            .map(|col_idx| {
                let values: Vec<&str> = sample_rows
                    .iter()
                    .filter_map(|row| {
                        row.get(col_idx).map(|s| s.as_str()).filter(|s| !s.is_empty())
                    })
                    .collect();
                inferrer.infer(&values)
            })
            .collect()
    } else {
        vec![infer::InferredType::Text; headers.len()]
    };

    Ok((headers, inferred_types))
}

/// Second pass: profile all columns.
fn profile_columns(
    content: &str,
    headers: &[String],
    inferred_types: &[infer::InferredType],
    config: &ProfileConfig,
) -> Result<Vec<report::ColumnReport>> {
    let reader = ReaderBuilder::new()
        .delimiter(config.delimiter)
        .has_headers(!config.no_header)
        .from_reader(content.as_bytes());

    let mut reader = reader;

    // Create profilers
    let mut profilers: Vec<Box<dyn profiler::ColumnProfiler>> = headers
        .iter()
        .enumerate()
        .map(|(i, name)| {
            create_profiler(
                name.clone(),
                inferred_types[i],
                config.percentiles,
                config.top_n,
                config.hist,
            )
        })
        .collect();

    // Stream through CSV
    for result in reader.records() {
        let record = result?;
        for (col_idx, profiler) in profilers.iter_mut().enumerate() {
            let value = record.get(col_idx);
            let value_ref = value.filter(|v| !v.is_empty()); // Treat empty strings as null
            profiler.feed(value_ref);
        }
    }

    // Generate reports
    let reports = profilers.iter().map(|p| p.report()).collect();

    Ok(reports)
}
