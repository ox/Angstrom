module Aleph
  class Base
    class << self
      attr_accessor :replier, :request_handler, :supervisor
    end
  end
end

Aleph::Base.replier = Proc.new do   
  @name = "replier"
  puts "started (#{@name})"
  Actor.register(:replier, Actor.current)
  conn = nil
  
  loop do
    Actor.receive do |msg|
      msg.when(ConnectionInformation) do |c|
        #puts "replier: got connection information #{c.inspect}"
        conn = c.connection
      end
      msg.when(Reply) do |m|
        begin
          conn.reply_http(m.data, m.message, 200, {"Content-type" => "text/html"})
        rescue Exception => e
          puts "Actor[:replier]: I messed up with exception: #{e.message}"
        end
      end
    end
  end
end

Aleph::Base.request_handler = Proc.new do
  @name = "request_handler"
  puts "started (#{@name})"
  Actor.register(:request_handler, Actor.current)
  Actor.trap_exit = true
  
  routes = []
  loop do
    Actor.receive do |f|
      f.when(AddRoute) do |r|
        routes << [r.route, r.method]
      end
      
      f.when(AddRoutes) do |r|
        r.routes.each do |k|
          routes << [k.route, k.method]
        end
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
      end
    end
  end
end

#if this dies, all hell will break loose
Aleph::Base.supervisor = Proc.new do
  puts "started (supervisor)"
  Actor.register(:supervisor, Actor.current)
  Actor.trap_exit = true
  
  Actor.link(Actor[:replier])
  Actor.link(Actor[:request_handler])

  loop do
    Actor.receive do |f|
      f.when(Actor::DeadActorError) do |exit|
        "#{exit.actor.name} died with reason: #{exit.reason}"
        case exit.actor.name
        when "request_handler"
          Actor.spawn_link(&@request_handler)
        when "replier"
          Actor.spawn_link(&@replier)          
        end
      end
    end
  end
end
