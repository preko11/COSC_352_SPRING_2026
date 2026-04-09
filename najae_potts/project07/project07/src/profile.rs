use anyhow::Context;
use chrono::NaiveDate;
use serde::Serialize;
use std::{
    collections::{HashMap, HashSet},
    fs::File,
    io::BufReader,
    path::{Path, PathBuf},
};

pub struct ProfileConfig {
    pub delimiter: u8,
    pub has_headers: bool,
    pub sample_size: usize,
}

#[derive(Debug, Serialize)]
pub enum ColumnType {
    Integer,
    Float,
    Boolean,
    Date,
    Categorical,
    Text,
}

#[derive(Debug, Serialize)]
pub struct ColumnReport {
    pub name: String,
    pub inferred_type: ColumnType,
    pub total_count: usize,
    pub missing_count: usize,
    pub unique_count: usize,
    pub sample_count: usize,
    pub min: Option<String>,
    pub max: Option<String>,
    pub mean: Option<f64>,
    pub stddev: Option<f64>,
    pub top_values: Vec<(String, usize)>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct DatasetReport {
    pub row_count: usize,
    pub column_count: usize,
    pub columns: Vec<ColumnReport>,
}

pub trait ColumnProfiler {
    fn ingest(&mut self, value: &str);
    fn finalize(self) -> ColumnReport;
}

struct ColumnInferenceState {
    name: String,
    total_count: usize,
    missing_count: usize,
    sample_count: usize,
    unique_values: HashSet<String>,
    top_counts: HashMap<String, usize>,

    integer_count: usize,
    float_count: usize,
    boolean_count: usize,
    date_count: usize,
    text_count: usize,
    mixed_type: bool,
    observed_types: HashSet<TypeHint>,

    numeric_min: Option<f64>,
    numeric_max: Option<f64>,
    numeric_sum: f64,
    numeric_sum_sq: f64,
    string_min: Option<String>,
    string_max: Option<String>,
    date_min: Option<NaiveDate>,
    date_max: Option<NaiveDate>,
}

#[derive(Debug, Hash, PartialEq, Eq)]
enum TypeHint {
    Integer,
    Float,
    Boolean,
    Date,
    Text,
}

impl ColumnInferenceState {
    fn new(name: String) -> Self {
        Self {
            name,
            total_count: 0,
            missing_count: 0,
            sample_count: 0,
            unique_values: HashSet::new(),
            top_counts: HashMap::new(),
            integer_count: 0,
            float_count: 0,
            boolean_count: 0,
            date_count: 0,
            text_count: 0,
            mixed_type: false,
            observed_types: HashSet::new(),
            numeric_min: None,
            numeric_max: None,
            numeric_sum: 0.0,
            numeric_sum_sq: 0.0,
            string_min: None,
            string_max: None,
            date_min: None,
            date_max: None,
        }
    }

    fn infer_type(&self) -> ColumnType {
        let non_missing = self.total_count.saturating_sub(self.missing_count);
        let numeric_votes = self.integer_count + self.float_count;
        if non_missing == 0 {
            return ColumnType::Text;
        }

        if self.boolean_count == non_missing {
            return ColumnType::Boolean;
        }

        if self.date_count >= (non_missing * 8 / 10) && self.date_count > 0 {
            return ColumnType::Date;
        }

        if numeric_votes == non_missing {
            if self.float_count > 0 {
                return ColumnType::Float;
            }
            return ColumnType::Integer;
        }

        if self.unique_values.len() <= 20 {
            return ColumnType::Categorical;
        }

        if self.unique_values.len() <= non_missing / 5 {
            return ColumnType::Categorical;
        }

        ColumnType::Text
    }

    fn compute_mean(&self) -> Option<f64> {
        let n = self.integer_count + self.float_count;
        if n == 0 {
            return None;
        }
        Some(self.numeric_sum / n as f64)
    }

    fn compute_stddev(&self) -> Option<f64> {
        let n = self.integer_count + self.float_count;
        if n < 2 {
            return None;
        }
        let mean = self.numeric_sum / n as f64;
        let variance = (self.numeric_sum_sq / n as f64) - (mean * mean);
        Some(variance.max(0.0).sqrt())
    }

    fn top_values(&self, limit: usize) -> Vec<(String, usize)> {
        let mut items: Vec<_> = self.top_counts.iter().map(|(value, count)| (value.clone(), *count)).collect();
        items.sort_unstable_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
        items.into_iter().take(limit).collect()
    }
}

impl ColumnProfiler for ColumnInferenceState {
    fn ingest(&mut self, value: &str) {
        self.total_count += 1;
        let trimmed = value.trim();

        if trimmed.is_empty() {
            self.missing_count += 1;
            return;
        }

        self.sample_count += 1;
        self.unique_values.insert(trimmed.to_string());
        *self.top_counts.entry(trimmed.to_string()).or_default() += 1;

        let hint = classify_value(trimmed);
        if !self.observed_types.insert(hint.clone()) {
            // already seen this hint
        }
        if self.observed_types.len() > 1 {
            self.mixed_type = true;
        }

        match hint {
            TypeHint::Integer => {
                self.integer_count += 1;
                if let Ok(value) = trimmed.parse::<f64>() {
                    self.add_numeric(value);
                }
            }
            TypeHint::Float => {
                self.float_count += 1;
                if let Ok(value) = trimmed.parse::<f64>() {
                    self.add_numeric(value);
                }
            }
            TypeHint::Boolean => {
                self.boolean_count += 1;
            }
            TypeHint::Date => {
                self.date_count += 1;
                if let Some(date) = parse_date(trimmed) {
                    update_min_max_date(&mut self.date_min, &mut self.date_max, date);
                }
            }
            TypeHint::Text => {
                self.text_count += 1;
            }
        }

        update_min_max_string(&mut self.string_min, &mut self.string_max, trimmed);
    }

    fn finalize(self) -> ColumnReport {
        let inferred_type = self.infer_type();
        let mean = self.compute_mean();
        let stddev = self.compute_stddev();
        let mut warnings = Vec::new();

        if self.missing_count > 0 {
            warnings.push(format!(
                "{} missing values ({:.1}%)",
                self.missing_count,
                100.0 * self.missing_count as f64 / self.total_count as f64
            ));
        }

        if self.mixed_type {
            warnings.push("mixed inferred types detected".to_string());
        }

        if (self.unique_values.len() as f64) < (self.total_count as f64 * 0.1) {
            warnings.push("low cardinality detected".to_string());
        }

        if let Some(mean) = mean {
            if let Some(stddev) = stddev {
                if stddev > 0.0 {
                    if let Some(min) = self.numeric_min {
                        if (mean - min).abs() > 3.0 * stddev {
                            warnings.push("numeric outlier suspected at min".to_string());
                        }
                    }
                    if let Some(max) = self.numeric_max {
                        if (max - mean).abs() > 3.0 * stddev {
                            warnings.push("numeric outlier suspected at max".to_string());
                        }
                    }
                }
            }
        }

        ColumnReport {
            name: self.name,
            inferred_type,
            total_count: self.total_count,
            missing_count: self.missing_count,
            unique_count: self.unique_values.len(),
            sample_count: self.sample_count,
            min: self.string_min,
            max: self.string_max,
            mean,
            stddev,
            top_values: self.top_values(5),
            warnings,
        }
    }
}

fn classify_value(value: &str) -> TypeHint {
    if value.eq_ignore_ascii_case("true") || value.eq_ignore_ascii_case("false") {
        return TypeHint::Boolean;
    }

    if value.parse::<i64>().is_ok() {
        return TypeHint::Integer;
    }

    if value.parse::<f64>().is_ok() {
        return TypeHint::Float;
    }

    if parse_date(value).is_some() {
        return TypeHint::Date;
    }

    TypeHint::Text
}

fn parse_date(value: &str) -> Option<NaiveDate> {
    let candidates = ["%Y-%m-%d", "%m/%d/%Y", "%d-%b-%Y", "%Y/%m/%d"];
    for fmt in candidates {
        if let Ok(date) = NaiveDate::parse_from_str(value, fmt) {
            return Some(date);
        }
    }
    None
}

fn add_numeric_to_bounds(state: &mut ColumnInferenceState, value: f64) {
    if state.numeric_min.map_or(true, |min| value < min) {
        state.numeric_min = Some(value);
    }
    if state.numeric_max.map_or(true, |max| value > max) {
        state.numeric_max = Some(value);
    }
}

impl ColumnInferenceState {
    fn add_numeric(&mut self, value: f64) {
        self.numeric_sum += value;
        self.numeric_sum_sq += value * value;
        if self.numeric_min.map_or(true, |min| value < min) {
            self.numeric_min = Some(value);
        }
        if self.numeric_max.map_or(true, |max| value > max) {
            self.numeric_max = Some(value);
        }
    }
}

fn update_min_max_string(min_value: &mut Option<String>, max_value: &mut Option<String>, value: &str) {
    if min_value.as_ref().map_or(true, |current| value < current) {
        *min_value = Some(value.to_string());
    }
    if max_value.as_ref().map_or(true, |current| value > current) {
        *max_value = Some(value.to_string());
    }
}

fn update_min_max_date(min_value: &mut Option<NaiveDate>, max_value: &mut Option<NaiveDate>, value: NaiveDate) {
    if min_value.as_ref().map_or(true, |current| value < *current) {
        *min_value = Some(value);
    }
    if max_value.as_ref().map_or(true, |current| value > *current) {
        *max_value = Some(value);
    }
}

pub fn profile_csv(path: &Path, config: ProfileConfig) -> anyhow::Result<DatasetReport> {
    let file = File::open(path).with_context(|| format!("could not open {}", path.display()))?;
    let mut reader = csv::ReaderBuilder::new()
        .delimiter(config.delimiter)
        .has_headers(config.has_headers)
        .from_reader(BufReader::new(file));

    let headers = if config.has_headers {
        reader
            .headers()
            .context("could not read CSV headers")?
            .iter()
            .map(|h| h.to_string())
            .collect()
    } else {
        let first_record = reader
            .records()
            .next()
            .transpose()
            .context("could not read first record")?;
        let num_columns = first_record
            .as_ref()
            .map(|r| r.len())
            .unwrap_or(0);
        (0..num_columns)
            .map(|i| format!("column_{}", i + 1))
            .collect()
    };

    let mut columns: Vec<ColumnInferenceState> =
        headers.into_iter().map(ColumnInferenceState::new).collect();

    let mut row_count = 0;
    for result in reader.records() {
        let record = result.context("failed to parse CSV record")?;
        row_count += 1;

        if record.len() != columns.len() {
            return Err(anyhow::anyhow!(
                "record length {} does not match header length {}",
                record.len(),
                columns.len()
            ));
        }

        for (col, value) in columns.iter_mut().zip(record.iter()) {
            col.ingest(value);
        }
    }

    let reports = columns.into_iter().map(|state| state.finalize()).collect();

    Ok(DatasetReport {
        row_count,
        column_count: reports.len(),
        columns: reports,
    })
}

pub fn print_text_report(report: &DatasetReport) {
    println!("Dataset report");
    println!("Rows: {}", report.row_count);
    println!("Columns: {}", report.column_count);
    println!();

    for column in &report.columns {
        println!("Column: {}", column.name);
        println!("  Type: {:?}", column.inferred_type);
        println!("  Count: {}", column.total_count);
        println!("  Missing: {}", column.missing_count);
        println!("  Unique: {}", column.unique_count);

        if let Some(min) = &column.min {
            println!("  Min: {}", min);
        }
        if let Some(max) = &column.max {
            println!("  Max: {}", max);
        }
        if let Some(mean) = column.mean {
            println!("  Mean: {:.4}", mean);
        }
        if let Some(stddev) = column.stddev {
            println!("  Stddev: {:.4}", stddev);
        }

        if !column.top_values.is_empty() {
            println!("  Top values:");
            for (value, count) in &column.top_values {
                println!("    {}: {}", value, count);
            }
        }

        if !column.warnings.is_empty() {
            println!("  Warnings:");
            for warning in &column.warnings {
                println!("    - {}", warning);
            }
        }

        println!();
    }
}

pub fn print_json_report(report: &DatasetReport) -> anyhow::Result<()> {
    let json = serde_json::to_string_pretty(report)?;
    println!("{json}");
    Ok(())
}

