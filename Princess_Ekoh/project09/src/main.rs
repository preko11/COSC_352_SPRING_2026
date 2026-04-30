use std::collections::HashMap;
use std::error::Error;
use csv::{ReaderBuilder, StringRecord};
use plotters::prelude::*;

fn main() -> Result<(), Box<dyn Error>> {
    // Read 311 data
    let mut rdr_311 = ReaderBuilder::new().flexible(true).from_path("../project08/data/311.csv")?;
    let mut neighborhood_311: HashMap<String, u32> = HashMap::new();
    for result in rdr_311.records() {
        let record: StringRecord = result?;
        if record.len() > 15 {
            if let Some(neigh) = record.get(15) {
                if !neigh.is_empty() {
                    *neighborhood_311.entry(neigh.to_string()).or_insert(0) += 1;
                }
            }
        }
    }

    // Read vacant data
    let mut rdr_vacant = ReaderBuilder::new().flexible(true).from_path("../project08/data/vacant.csv")?;
    let mut neighborhood_vacant: HashMap<String, u32> = HashMap::new();
    for result in rdr_vacant.records() {
        let record: StringRecord = result?;
        if record.len() > 13 {
            if let Some(neigh) = record.get(13) {
                if !neigh.is_empty() {
                    *neighborhood_vacant.entry(neigh.to_string()).or_insert(0) += 1;
                }
            }
        }
    }

    // Collect correlated data
    let mut data_points: Vec<(u32, u32)> = Vec::new();
    for (neigh, vacant_count) in &neighborhood_vacant {
        if let Some(incident_count) = neighborhood_311.get(neigh) {
            data_points.push((*vacant_count, *incident_count));
        }
    }

    // Statistics
    let total_311 = neighborhood_311.values().sum::<u32>();
    let total_vacant = neighborhood_vacant.values().sum::<u32>();
    println!("Total 311 requests: {}", total_311);
    println!("Total vacant buildings: {}", total_vacant);
    println!("Neighborhoods with data: {}", data_points.len());

    // Top neighborhoods for 311
    let mut top_311: Vec<_> = neighborhood_311.iter().collect();
    top_311.sort_by(|a, b| b.1.cmp(a.1));
    println!("\nTop 5 neighborhoods by 311 requests:");
    for (neigh, count) in top_311.iter().take(5) {
        println!("{}: {}", neigh, count);
    }

    // Top neighborhoods for vacant
    let mut top_vacant: Vec<_> = neighborhood_vacant.iter().collect();
    top_vacant.sort_by(|a, b| b.1.cmp(a.1));
    println!("\nTop 5 neighborhoods by vacant buildings:");
    for (neigh, count) in top_vacant.iter().take(5) {
        println!("{}: {}", neigh, count);
    }

    if data_points.is_empty() {
        println!("No correlated data found.");
        return Ok(());
    }

    // Find max for axes
    let max_vacant = data_points.iter().map(|(x, _)| *x).max().unwrap_or(50);
    let max_311 = data_points.iter().map(|(_, y)| *y).max().unwrap_or(200);

    // Create scatter plot
    let root = SVGBackend::new("correlation_plot.svg", (800, 600)).into_drawing_area();
    root.fill(&WHITE)?;

    let mut chart = ChartBuilder::on(&root)
        .caption("Correlation between Vacant Buildings and 311 Requests by Neighborhood", ("sans-serif", 20))
        .x_label_area_size(40)
        .y_label_area_size(40)
        .build_cartesian_2d(0u32..max_vacant + 10, 0u32..max_311 + 20)?;

    chart.configure_mesh().x_desc("Number of Vacant Buildings").y_desc("Number of 311 Requests").draw()?;

    chart.draw_series(
        data_points.iter().map(|&(x, y)| Circle::new((x, y), 5, BLUE.filled())),
    )?;

    root.present()?;

    println!("Plot saved to correlation_plot.svg");

    Ok(())
}