# CrShader Performance Benchmarks

This directory contains standalone and automated performance benchmarks for the CrShader toolchain.

## Available Benchmarks

- `compiler_bench.cr`: Measures CrShader DSL parsing, AST transformations, and GDShader emission speed over N iterations.
- `compiler/compiler.cr`: Lapis CLI discovery target for automated CI regression tracking (`lapis benchmarks run`).
- `example_bench.cr`: Microbenchmark measuring vector math and engine binding performance.

## Running Benchmarks

### Direct Execution via Crystal

```bash
# Run compiler benchmark (50 iterations)
crystal run benchmarks/compiler_bench.cr -- 50

# Run microbenchmark (5000 iterations)
crystal run benchmarks/example_bench.cr -- 5000
```

### Automated Suite & HTML Reports via Lapis CLI

```bash
# Run all discovered benchmarks in this directory
lapis benchmarks

# Run benchmarks and generate HTML comparison report
lapis benchmarks run html
```
