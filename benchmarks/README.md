# CrShader Performance Benchmarks

This directory contains standalone and automated performance benchmarks for the CrShader toolchain. Benchmarks measure native Crystal execution latency, track historical performance across releases and tags, and detect compiler/transpiler regressions.

## Available Benchmarks

- `compiler/`: Measures CrShader DSL parsing and AST transformation throughput.
- `transpiler/`: Measures multi-stage pipeline transpilation throughput across spatial, canvas_item, particles, and sky shader types.
- `vector_math/`: Measures high-throughput vector math routines, matrix operations, and color interpolation.

## Running Benchmarks

### Direct Execution via Lapis CLI

```bash
# Run all discovered benchmarks in this directory
lapis benchmarks

# Run benchmarks and generate interactive HTML report and SVG latency chart
lapis benchmarks run html

# Compare benchmarks against previous release tag
lapis benchmarks compare html --tag=v1.1.0 --previous-tag=v1.0.0
```

### Direct Execution via Make

```bash
# Run benchmarks and update reports
make benchmark
```
