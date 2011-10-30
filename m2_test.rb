require './Mongrel2Commodore'
comm = Mongrel2Commodore.new "251249FF-14F2-442F-84C2-BE4B49720A75"
comm.connect

require './experiments/fiber_test'

class HelloHandler < WebMessageHandler
  def process
    output("Hello world")
  end
end

puts "START"

while true
  req = comm.receive
  req[:response] = HelloHandler.new.resume
  comm.reply(req)
end

puts "END"
