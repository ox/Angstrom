#!ruby19
# encoding: utf-8

require 'open-uri'
require 'benchmark'


∂ = 0

puts Benchmark.measure {
  200.times do
    begin
      open("http://localhost:6767").read
    rescue Exception => e
      puts e.message
      ∂ += 1
      next
    end
  end
}

puts "failed: " + ∂.to_s
