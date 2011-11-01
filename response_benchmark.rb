require 'open-uri'
require 'benchmark'

puts Benchmark.measure {
  open("http://localhost:6767").read
}