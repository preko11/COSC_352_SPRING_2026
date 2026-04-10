pub mod traits;
pub mod numeric;
pub mod categorical;

use crate::utils::DataType;
use numeric::NumericProfiler;
use categorical::CategoricalProfiler;
pub use traits::ColumnProfiler;

pub fn create_profiler(dtype: DataType) -> Box<dyn ColumnProfiler> {
    match dtype {
        DataType::Integer | DataType::Float => Box::new(NumericProfiler::new()),
        _ => Box::new(CategoricalProfiler::new()),
    }
}
