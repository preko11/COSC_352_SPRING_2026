use foo::{ColumnAnalyzer}; 
use foo::get_reader;
use std::collections::HashMap;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut stats: HashMap<String, (i32, i32)> = HashMap::new();

    // 1. Process Liquor Licenses grouped by zip
    let mut rdr1 = get_reader("data/Liquor_Licenses.csv")?;
    for result in rdr1.records() {
        let record = result?;
        if let Some(zip) = record.get(19) {  // AddrZip column
            stats.entry(zip.to_string()).or_insert((0, 0)).0 += 1;
        }
    }

    // 2. Process Vacant Building Rehabs by neighborhood
    let mut rdr2 = get_reader("data/Vacant_Building_Rehabs.csv")?;
    for result in rdr2.records() {
        let record = result?;
        if let Some(neighborhood) = record.get(13) {
            stats.entry(neighborhood.to_string()).or_insert((0, 0)).1 += 1;
        }
    }

    // 3. Print Output
    println!("Location | Licenses | Rehabs");
    for (loc, (lic, rehab)) in stats {
        println!("{}: {} licenses, {} rehabs", loc, lic, rehab);
    }

    Ok(())
}