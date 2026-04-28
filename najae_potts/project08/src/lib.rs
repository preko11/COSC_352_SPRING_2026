use std::collections::HashMap;
use serde::Serialize;

pub trait ColumnAnalyzer {
    fn observe(&mut self, value: &str);
    fn report(&self) -> String;
}

#[derive(Serialize)]
pub struct CategoryProfiler {
    pub counts: HashMap<String, usize>,
}

impl ColumnAnalyzer for CategoryProfiler {
    fn observe(&mut self, value: &str) {
        if !value.trim().is_empty() {
            *self.counts.entry(value.to_string()).or_insert(0) += 1;
        }
    }
    fn report(&self) -> String {
        serde_json::to_string_pretty(&self.counts).unwrap_or_default()
    }
}

pub fn get_reader(path: &str) -> anyhow::Result<csv::Reader<std::fs::File>> {
    let rdr = csv::ReaderBuilder::new()
        .has_headers(true)
        .from_path(path)?;
    Ok(rdr)
}
