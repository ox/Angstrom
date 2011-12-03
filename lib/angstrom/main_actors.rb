module Aleph
  class Base
    class << self
      attr_accessor :supervisor, :routes
      attr_accessor :message_receiver_proc, :request_handler_proc, :supervisor_proc, :container_proc
    end
  end
end

# take the route and pattern and keys and this function will match the keyworded params in
# the url with the pattern. Example:
# 
#   url: /user/2/view/345
#   pattern: /user/:id/view/:comment
#
# returns:
#
#   params = {id: 2, comment: 345}
#
def process_route(route, pattern, keys, values = [])
  return unless match = pattern.match(route)
  values += match.captures.map { |v| URI.decode(v) if v }
  params = {}
  
  if values.any?
    keys.zip(values) { |k,v| (params[k] ||= '') << v if v }
  end
  params
end

# uuid generator. There's a pretty low chance of collision.
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
  "%04x%04x-%04x-%04x-%04x%06x%06x" % values
end







# this nifty mess helps us just to use the output of the Procs that handle
# the request instead of making the user manually catch messages and send 
# them out to the replier. 
Aleph::Base.container_proc = Proc.new do
  @name = "{container}"
  data = Actor.receive
  env, proccess = data.env, data.proccess
  response = proccess.call(env)
  
  if response.is_a? Array
    #just like Rack: env, code, headers, body. HINT HINT ( can't work because it's all async )
    env[:conn].reply_http(env, response[1], response[2], response[0])
  else
    #puts "[container] sending http_reply"
    env[:conn].reply_http(env, response, 200, {"Content-Type" => "text/html;charset=utf-8", "Connection" => "keep-alive", "Server" => "Angstrom", "X-Frame-Options" => "sameorigin", "X-XSS_Protection" => "1; mode=block"})
  end
end

Aleph::Base.message_receiver_proc = Proc.new do
  @name = "message_receiver"
  @num = 0
  puts "started (#{@name})"

  uuid = new_uuid
  conn = Connection.new(uuid)
  conn.connect
  puts "replying as mongrel2 service #{uuid}"

  Actor.receive do |f|
    f.when(Num) do |n|
      @num = n.index
    end
  end
    
  while !conn.nil?
    env = conn.receive
    env[:conn] = conn
    #puts "[message_receiver:#{@num}] got message"
    Actor[:supervisor] << Request.new(env) if !env.nil?
  end
end



Aleph::Base.request_handler_proc = Proc.new do
  @name = "request_handler"
  @num = 0
  puts "started (#{@name})"
  Actor.trap_exit = true

  loop do
    Actor.receive do |f|
      f.when(Num) do |n|
        @num = n.index
      end

      f.when(Request) do |r|
        failure = true
        verb = r.env[:headers]["METHOD"]
        $routes[verb].each do |route|
          if route.route[0].match(r.env[:path])
            #puts "[request_handler:#{@num}] route matched! Making container..."
            r.env[:params] = process_route(r.env[:path], route.route[0], route.route[1])
            Actor.spawn_link(&Aleph::Base.container_proc) << MessageAndProc.new(r.env, route.method)
            failure = false
            break
          end
        end
        env[:conn].reply_http(r.env, "<h1>404</h1>", 404, {'Content-type'=>'text/html'} ) if failure
      end

      f.when(Actor::DeadActorError) do |exit|
        puts "[request_handler] #{exit.actor} died with reason: [#{exit.reason}]"
      end
    end
  end
end

#if this dies, all hell will break loose
Aleph::Base.supervisor_proc = Proc.new do
  Actor.register(:supervisor, Actor.current)
  Aleph::Base.supervisor = Actor.current
  Actor.trap_exit = true
  puts "started (supervisor)"
  
  @handlers = []
  @receivers = []
  @handler_turn = 0
  @receiver_turn = 0
      
  loop do
    Actor.receive do |f|      
      f.when(SpawnRequestHandlers) do |r|
        puts "[supervisor] adding #{r.num} handlers. #{@handlers.size + r.num} will be available"
        r.num.times do
          #puts "spawning a request_handler in handlers[#{handlers.size}]"
          @handlers << (Actor.spawn_link(&Aleph::Base.request_handler_proc) << Num.new(@handlers.size))
        end
      end
      
      f.when(Request) do |req|
        puts "[supervisor] routing request to handlers[#{@handler_turn}]"
        @handlers[@handler_turn] << req
        if(@handler_turn == @handlers.size - 1)
          @handler_turn = 0
        else
          @handler_turn += 1
        end
      end
      
      f.when(SpawnReceivers) do |r|
        puts "[supervisor] adding #{r.num} receivers. #{@receivers.size + r.num} will be available"
        r.num.times do
          #puts "spawning a receiver in receivers[#{receivers.size}]"
          @receivers << (Actor.spawn_link(&Aleph::Base.message_receiver_proc) << Num.new(@receivers.size))
        end
      end

      f.when(RemoveReceivers) do |r|
        puts "[supervisor] removing #{r.num} receivers. #{@receivers.size-r.num} remaining"
        @receivers = @receivers[0..@receivers.size-1-r.num]
        @receiver_turn = 0
      end

      f.when(RemoveRequestHandlers) do |r|
        puts "[supervisor] removing #{r.num} handlers. #{@handlers.size-r.num} remaining"
        @handlers = @handlers[0..@receivers.size-1-r.num]
        @handler_turn = 0
      end
      
      f.when(Actor::DeadActorError) do |exit|
        "[supervisor] #{exit.actor} died with reason: [#{exit.reason}]"
        puts "!!!! \e[32m[supervisor]\e[0m death:", exit.inspect, exit.actor.inspect
        # case exit.actor.name
        # when "request_handler"
        #   # lets replace that failed request_handler with a new one. NO DOWN TIME
        #   handlers[exit.actor.num] = (Actor.spawn_link(&Aleph::Base.request_handler_proc) << Num.new(exit.actor.num))
        # when "message_receiver"
        #   repliers[exit.actor.num] = (Actor.spawn_link(&Aleph::Base.message_receiver_proc) << Num.new(exit.actor.num))     
        # end
      end
    end
  end
end
