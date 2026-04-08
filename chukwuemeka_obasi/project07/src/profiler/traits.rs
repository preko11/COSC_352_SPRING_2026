pub trait ColumnProfiler {
    fn update(&mut self, value: &str);
    fn finalize(&mut self);
    fn report(&self) -> String;
}