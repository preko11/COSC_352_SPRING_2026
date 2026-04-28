use foo::{get_reader, CategoryProfiler, ColumnAnalyzer};
use std::env;

fn main() -> anyhow::Result<()> {
    let args: Vec<String> = env::args().collect();
    
    // Check if path is provided to avoid panic
    let path = match args.get(1) {
        Some(p) => p,
        None => {
            println!("Usage: cargo run --bin csvprof <path>");
            return Ok(());
        }
    };

    let mut reader = get_reader(path)?;
    let mut profiler = CategoryProfiler { counts: std::collections::HashMap::new() };

    for result in reader.records() {
        let record = result?;
        // Use index 0 for the first column (Neighborhood)
        if let Some(val) = record.get(0) {
            profiler.observe(val);
        }
    }

    println!("{}", profiler.report());
    Ok(())
}
