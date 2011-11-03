require 'open-uri'
require 'benchmark'

d = 0

puts Benchmark.measure {
  100.times do
    begin
      open("http://localhost:6000/")
    rescue Exception => e
      puts e.message
      d += 1
      next
    end
  end
}

puts "failed: #{d}"
