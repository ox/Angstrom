require 'open-uri'
require 'benchmark'

d = 0
x = (ARGV[0].nil? ? 100 : ARGV[0].to_i)

bench = Benchmark.measure {
  x.times do
    begin
      open("http://localhost:6767/")
    rescue Exception => e
      puts e.message
      d += 1
      next
    end
  end
}

puts "succeeded: #{x-d}", "failed: #{d}", "reqs/sec: #{(x-d)/bench.real}", "time elapsed: %.6f" % bench.real
