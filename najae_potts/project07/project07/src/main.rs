mod profile;

use anyhow::Context;
use clap::{Parser, ValueEnum};
use profile::{profile_csv, print_json_report, print_text_report, ProfileConfig};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Input CSV file path
    input: std::path::PathBuf,

    /// Field delimiter, e.g. ',' or ';'
    #[arg(short, long, default_value = ",")]
    delimiter: char,

    /// Output format
    #[arg(short, long, default_value = "text")]
    format: OutputFormat,

    /// Treat file as having no header row
    #[arg(long)]
    no_headers: bool,

    /// Number of rows used for type inference
    #[arg(long, default_value_t = 1000)]
    sample_size: usize,
}

#[derive(ValueEnum, Clone, Debug)]
enum OutputFormat {
    Text,
    Json,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    let config = ProfileConfig {
        delimiter: args.delimiter as u8,
        has_headers: !args.no_headers,
        sample_size: args.sample_size,
    };

    let report = profile_csv(&args.input, config)
        .with_context(|| format!("failed to profile {}", args.input.display()))?;

    match args.format {
        OutputFormat::Text => print_text_report(&report),
        OutputFormat::Json => print_json_report(&report)?,
    }

    Ok(())
}
