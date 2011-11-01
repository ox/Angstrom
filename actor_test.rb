#we need Rubinius for this.

require 'rubygems'
require 'actor'

require 'ffi-rzmq'

sender_id = "251449FF-14F2-442F-84C2-BE4B49720A75"

context = ZMQ::Context.new 1
req = context.socket ZMQ::PULL
req.connect "tcp://127.0.0.1:9999"

res = context.socket ZMQ::PUB
res.setsockopt ZMQ::IDENTITY, sender_id
res.connect "tcp://127.0.0.1:9998"

def send(uuid, conn_id, msg)
  header = "%s %d:%s" % [uuid, conn_id.join(' ').length, conn_id.join(' ')]
  string =  header + ', ' + msg 
  puts "'send'ing string: ", string
  res.send(ZMQ::Message.new(string), 0)
  return
end

def reply(request, message)
  #puts request
  send(request[:uuid], [request[:id]], message)
end

def parse(msg)
  uuid, id, path, header_size, headers, body_size, body = msg.match(/^(.{36}) (\d+) (.*?) (\d+):(.*?),(\d+):(.*?),$/).to_a[1..-1]

  return {:uuid => uuid, :id => id, :path => path, :header_size => header_size, :headers => JSON.parse(headers), :body_size => body_size, :body => body}
end

AddRoute = Struct.new :route
ShowRoutes = Struct.new :this
Route = Struct.new :route
Request = Struct.new :data

@supervisor = Actor.spawn do
 supervisor = Actor.current
 Actor.trap_exit = true
 
 pool = []
 routes = []
 loop do
   Actor.receive do |f|
     f.when(AddRoute) do |r|
       routes << r.route
     end
     f.when(ShowRoutes) do |r|
       routes.each {|s| puts s}
     end
     f.when(Request) do |r|
       puts r.route
       routes.each do |k|
         if k.match r.data[:path]
           reply(data, "hello world")
         end
       end
     end
   end
 end
end

@supervisor << AddRoute.new("/")
@supervisor << ShowRoutes.new()

while true
  message = ZMQ::Message.new
  data = parse(res.recv(message, 0))
  puts data
  reply(data, "HELLO")
  #@supervisor << Request.new(data)
end