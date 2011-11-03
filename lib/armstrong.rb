require 'actor'
require './lib/armstrong/connection'

AddRoute = Struct.new :route, :actor
ShowRoutes = Struct.new :this
Request = Struct.new :data
ConnectionInformation = Struct.new :connection
Reply = Struct.new :data, :message

def output(value)
  Actor[:replier] << Reply.new(Actor.receive,value)
end
  
class Armstrong
  def new_uuid
    values = [
      rand(0x0010000),
      rand(0x0010000),
      rand(0x0010000),
      rand(0x0010000),
      rand(0x0010000),
      rand(0x1000000),
      rand(0x1000000),
    ]
    #"251249FF-14F2-442F-84C2-BE4B49720A75"
    "%04x%04x-%04x-%04x-%04x%06x%06x" % values
  end
  
  def initialize(urls)
    uuid = new_uuid
    puts "using #{uuid}"
    @conn = Connection.new uuid
    @conn.connect
  
    @replier = Actor.spawn do      
      Actor.register(:replier, Actor.current)
      conn = nil
      loop do
        Actor.receive do |msg|
          msg.when(ConnectionInformation) { |c| conn = c.connection }
          msg.when(Reply) do |m|
            begin
              conn.reply_http(m.data, m.message, 200, {"Content-type" => "text/html"})
            rescue Exception => e
              puts "@replier: I fucked up with exception: #{e.message}"
            end
          end
        end
      end
    end
    
    @request_overlord = Actor.spawn do
      Actor.register :overlord, Actor.current
      Actor.trap_exit = true
      loop do
        Actor.receive do |msg|
          msg.when(Actor::DeadActorError) do |exit|
            puts "A request actor died parsing the input.\nactor: #{exit.actor.name}\nreason: #{exit.reason}"
            exit = nil
          end
        end
      end
    end

    @replier << ConnectionInformation.new(@conn)

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
            routes.each do |route|
              if route[0].match(r.data[:path]) != nil
                Actor.spawn_link(&route[1]) << r.data
              end
            end
          end

          f.when(Actor::DeadActorError) do |exit|
            puts "#{exit.actor} died with reason: [#{exit.reason}]"
            exit = nil
          end
        end
      end
    end
    
    @routes = {}
    urls.each { |u| add_route(u[0], u[1]) }    
  end
  
  def add_route(path, handler) 
    @supervisor << AddRoute.new(path, handler)
  end
  
  def run!    
    while true
      req = @conn.receive
      @supervisor << Request.new(req)
    end
  end
end