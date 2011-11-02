#we need Rubinius for this.

require 'rubygems'
require 'actor'

require 'ffi-rzmq'

require './lib/armstrong/connection'
sender_id = "251449FF-14F2-442F-84C2-BE4B49720A75"
@conn = Connection.new sender_id
@conn.connect

AddRoute = Struct.new :route
ShowRoutes = Struct.new :this
Route = Struct.new :route
Request = Struct.new :data, :connection

@supervisor = Actor.spawn do
  supervisor = Actor.current
  Actor.trap_exit = true
  
  work_loop = Proc.new do
    dc = Actor.receive
    dc[1].reply_http(dc[0], "hello world")
  end

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
        puts r.inspect
        routes.each do |route|
          puts "trying route #{route} for path #{r.data[:path]} => #{route.match(r.data[:path]) != nil}"
          if route.match(r.data[:path]) != nil
            Actor.spawn_link(&work_loop) << [r.data, r.connection] 
          end
        end
      end
    end
  end
end

@supervisor << AddRoute.new("/")
@supervisor << ShowRoutes.new()

while true
  msg = @conn.receive
  @supervisor << Request.new(msg, @conn)
end