require 'zmq'

ctx = ZMQ::Context.new 1
s = ctx.socket ZMQ::PULL
s.connect "tcp://127.0.0.1:9999"

while true
  msg = s.recv
  puts msg
end