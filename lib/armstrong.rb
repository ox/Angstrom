require 'actor'
require './lib/armstrong/connection'

AddRoute = Struct.new :route, :actor
ShowRoutes = Struct.new :this
Request = Struct.new :data
ConnectionInformation = Struct.new :connection
Reply = Struct.new :data, :message

class Armstrong
  def initialize(urls)
    @conn = Connection.new "251249FF-14F2-442F-84C2-BE4B49720A75"
    @conn.connect
    
    @replier = Actor.spawn do
      Actor.register(:replier, Actor.current)
      conn = nil
      loop do
        Actor.receive do |msg|
          msg.when(ConnectionInformation) do |c|
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