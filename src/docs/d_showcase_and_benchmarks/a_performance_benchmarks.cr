# ==============================================================================
# Auto-generated from docs_src by Lapis::Docs::Generator
# DO NOT EDIT MANUALLY - Edit corresponding YAML in docs_src/ instead
# ==============================================================================

{% unless flag?(:release) %}
module CrShader
  module Docs
    module D_SHOWCASE_AND_BENCHMARKS
      # # Compiler Performance & Throughput Benchmarks
      #
      # CRShader includes a comprehensive compiler benchmark suite measuring lexical parsing, AST construction,
      # and code generation throughput across both small spatial shaders and large post-processing suites.
      #
      # ### Executive Summary & Key Topics
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Topic</th>
      #       <th>Method / Anchor</th>
      #       <th>Description</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Compilation Throughput & Latency</strong></td>
      #       <td><code>.topic_01_throughput_metrics</code></td>
      #       <td>Benchmark results showing &gt;100,000 LOC/sec throughput and sub-millisecond compilation.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Running Compiler Benchmarks</strong></td>
      #       <td><code>.topic_02_running_benchmarks</code></td>
      #       <td>Commands to run local benchmark sweeps and inspect latency statistics.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - bin/crshader/benchmarks/compiler_bench.cr
      # - bin/crshader/Makefile
      #
      module A_PERFORMANCE_BENCHMARKS
        # **Compilation Throughput & Latency**: Benchmark results showing >100,000 LOC/sec throughput and sub-millisecond compilation.
        #
        # Benchmarking on standard developer hardware demonstrates the high efficiency of CRShader's
        # Crystal-based compiler:
        #
        # <table>
        #   <thead>
        #     <tr>
        #       <th>Benchmark Target</th>
        #       <th>Source Lines (LOC)</th>
        #       <th>Transpile Time</th>
        #       <th>Throughput</th>
        #       <th>Memory Overhead</th>
        #     </tr>
        #   </thead>
        #   <tbody>
        #     <tr>
        #       <td><strong>Spatial 3D Procedural Plasma</strong></td>
        #       <td>480 LOC</td>
        #       <td>~0.41 ms</td>
        #       <td>&gt; 117,000 LOC/sec</td>
        #       <td>&lt; 2.1 MB</td>
        #     </tr>
        #     <tr>
        #       <td><strong>Kuwahara Multi-Pass Filter</strong></td>
        #       <td>890 LOC</td>
        #       <td>~0.78 ms</td>
        #       <td>&gt; 114,000 LOC/sec</td>
        #       <td>&lt; 2.8 MB</td>
        #     </tr>
        #     <tr>
        #       <td><strong>Complex Post-Processing Suite</strong></td>
        #       <td>1,250 LOC</td>
        #       <td>~1.12 ms</td>
        #       <td>&gt; 110,000 LOC/sec</td>
        #       <td>&lt; 3.2 MB</td>
        #     </tr>
        #   </tbody>
        # </table>
        #
        def self.topic_01_throughput_metrics : Nil
        end

        # **Running Compiler Benchmarks**: Commands to run local benchmark sweeps and inspect latency statistics.
        #
        # Run the benchmark suite using `make benchmark` or Crystal directly:
        #
        # #### Working Examples
        #
        # ```bash
        # # Run benchmarks via Makefile
        # make benchmark
        #
        # # Or run the benchmark harness directly
        # crystal run benchmarks/compiler_bench.cr --release
        # ```
        #
        def self.topic_02_running_benchmarks : Nil
        end
      end
    end
  end
end
{% end %}
