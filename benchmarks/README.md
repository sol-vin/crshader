# CrShader Performance Benchmarks

This directory contains standalone and automated performance benchmarks for the CrShader toolchain.

## Available Benchmarks

- `compiler/`: Measures CrShader DSL parsing and GDShader code emission speed vs Godot's native engine GDShader compilation.
- `transpiler/`: Measures multi-stage pipeline transpilation (spatial, canvas_item, particles, sky) vs Godot multi-shader resource compilation.
- `vector_math/`: Measures high-throughput vector projections, basis rotations, and color linear interpolation in Crystal vs GDScript.

## Running Benchmarks

### Direct Execution via Lapis CLI

```bash
# Run all discovered benchmarks in this directory
lapis benchmarks

# Run benchmarks and generate interactive HTML report and SVG speedup chart
lapis benchmarks run html

# Compare benchmarks against previous version
lapis benchmarks compare html
```

### Direct Execution via Make

```bash
# Run benchmarks and update reports
make benchmark
```
