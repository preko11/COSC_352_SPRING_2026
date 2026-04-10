mod profiler;
mod utils;

use clap::Parser;
use csv::Reader;
use profiler::{create_profiler, ColumnProfiler};
use utils::infer_type;

#[derive(Parser)]
#[command(name = "csvprof")]
struct Args {
    /// Path to CSV file (use - for stdin later if you extend)
    file: String,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    let mut rdr = Reader::from_path(&args.file)?;
    let headers = rdr.headers()?.clone();

    // Sample rows for type inference
    let mut samples: Vec<Vec<String>> = vec![Vec::new(); headers.len()];

    for result in rdr.records().take(100) {
        let record = result?;
        for (i, field) in record.iter().enumerate() {
            samples[i].push(field.to_string());
        }
    }

    // Create profilers
    let mut profilers: Vec<Box<dyn ColumnProfiler>> = samples
        .iter()
        .map(|col| create_profiler(infer_type(col)))
        .collect();

    // Re-read for full streaming pass
    let mut rdr = Reader::from_path(&args.file)?;

    for result in rdr.records() {
        let record = result?;
        for (i, field) in record.iter().enumerate() {
            profilers[i].update(field);
        }
    }

    // Output report
    for (i, profiler) in profilers.iter_mut().enumerate() {
        profiler.finalize();

        println!("Column: {}", &headers[i]);
        println!("{}", profiler.report());
        println!("----------------------------------");
    }

    Ok(())
}
