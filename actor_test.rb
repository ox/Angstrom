#we need Rubinius for this.

require 'rubygems'
require 'actor'

require 'ffi-rzmq'

require './lib/armstrong/connection'
sender_id = "251449FF-14F2-442F-84C2-BE4B49720A75"
@conn = Connection.new sender_id
@conn.connect

AddRoute = Struct.new :route, :actor
ShowRoutes = Struct.new :this
Route = Struct.new :route, :process
Request = Struct.new :data
Connection = Struct.new :connection
Reply = Struct.new :data, :message

@replier = Actor.spawn do
  conn = nil
  loop do
    Actor.receive do |msg|
      msg.when(Connection) do |c|
        conn = c.connection
        #puts "@replier: got a new connection"
      end
    
      msg.when(Reply) do |m|
        #puts "@replier: got a Reply: #{m.message}"
        begin
          conn.reply_http(m.data, m.message, 200, {"Content-type" => "text/html"})
        rescue Exception => e
          puts "@replier: I fucked up with exception: #{e.message}"
        end
      end
    end
  end
end

@replier << Connection.new(@conn)

@supervisor = Actor.spawn do
  supervisor = Actor.current
  Actor.trap_exit = true
  Actor.link(@replier)
  routes = []
  loop do
    Actor.receive do |f|
      f.when(AddRoute) do |r|
        routes << [r.route, r.actor]
      end
      f.when(ShowRoutes) do |r|
        routes.each {|s| puts s}
      end
      f.when(Request) do |r|
        #puts "@supervisor got Request"
        routes.each do |route|
          if route[0].match(r.data[:path]) != nil
            #puts "starting actor"
            actor = Actor.spawn_link(&route[1])
            actor << r.data
            actor = nil
          end
        end
      end
      
      f.when(Actor::DeadActorError) do |exit|
        puts "actor died with reason: #{exit}"
      end
    end
  end
end

HelloProc = lambda {
  data = Actor.receive
  @replier << Reply.new(data, "Hello World\0")
}

@supervisor << AddRoute.new("/", HelloProc)
@supervisor << ShowRoutes.new()

while true
  msg = @conn.receive
  @supervisor << Request.new(msg)
end