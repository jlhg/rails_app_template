# Benchmark IPS - Performance Testing
# https://github.com/evanphx/benchmark-ips
#
# Benchmark IPS (Iterations Per Second) provides statistically significant
# performance measurements for Ruby code.
#
# Features:
# - Measures iterations per second (not just elapsed time)
# - Statistical significance testing
# - Comparison between different implementations
# - Warmup phase to eliminate JIT compilation effects
#
# Usage:
#   require "benchmark/ips"
#   Benchmark.ips do |x|
#     x.report("method_a") { method_a }
#     x.report("method_b") { method_b }
#     x.compare!
#   end

gem "benchmark-ips"
