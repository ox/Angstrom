module Aleph
  class Base
    class << self
      attr_accessor :replier, :request_handler, :supervisor
      attr_accessor :replier_proc, :request_handler_proc, :supervisor_proc, :container_proc
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

# super modular replier proc.
# they're now one-off actors. They're really just spawned to reply to a thing.
# I still wanna keep this actor-based since the replier can fail, without
# the container necessarily failing.
Aleph::Base.replier_proc = Proc.new do   
  @name = "replier"
  #puts "started (#{@name})"
  Actor.receive do |msg|
    msg.when(Reply) do |m|
      begin
        $armstrong_conn.reply_http(m.env, m.body, m.code, m.headers)
      rescue Exception => e
        puts "[replier]: I messed up with exception: #{e.message}"
      end
    end
  end

end

# this nifty mess helps us just to use the output of the Procs that handle
# the request instead of making the user manually catch messages and send 
# them out to the replier. 
Aleph::Base.container_proc = Proc.new do
  data = Actor.receive
  env, proccess = data.env, data.proccess
  response = proccess.call(env)
  if response.is_a? Array
    #just like Rack: env, code, headers, body. HINT HINT ( can't work because it's all async )
    Actor.spawn(&Aleph::Base.replier_proc) << Reply.new(env, response[0], response[1], response[2])
  else
    Actor.spawn(&Aleph::Base.replier_proc) << Reply.new(env, 200, {"Content-Type", "text/html;charset=utf-8", "Connection", "keep-alive", "Server", "Armstrong", "X-Frame-Options", "sameorigin", "X-XSS_Protection", "1; mode=block"}, response)
  end
end

Aleph::Base.request_handler_proc = Proc.new do
  @name = "request_handler"
  num = 0
  puts "started (#{@name})"
  Actor.trap_exit = true
  
  routes = {}
  loop do
    Actor.receive do |f|
      f.when(Num) do |n|
        #puts "[request_handler] I am num: #{n.index}"
        num = n.index
      end
      
      f.when(AddRoutes) do |r|
        routes = r.routes
        #puts "[request_handler:#{num}] routes added"
      end

      f.when(Request) do |r|
        #puts "[request_handler:#{num}] got request"
        failure = true
        verb = r.env[:headers]["METHOD"]
        routes[verb].each do |route|
          if route.route[0].match(r.env[:path])
            #puts "[request_handler:#{@num}] route match!"
            r.env[:params] = process_route(r.env[:path], route.route[0], route.route[1])
            Actor.spawn(&Aleph::Base.container_proc) << MessageAndProc.new(r.env, route.method)
            failure = false
            break
          end
        end
        Aleph::Base.replier << Reply.new(r.env, 404, {'Content-type'=>'text/html'}, "<h1>404</h1>") if failure
      end

      f.when(Actor::DeadActorError) do |exit|
        puts "#{exit.actor} died with reason: [#{exit.reason}]"
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
  
  handlers = []
  handler_turn = 0
      
  loop do
    Actor.receive do |f|
      f.when(AddRoutes) do |r|
        #puts "Adding routes"
        handlers.each { |h| h << r }
      end
      
      f.when(SpawnRequestHandlers) do |r|
        #puts "trying to spawn #{r.num} request_handlers"
        r.num.times do
          n = handlers.size
          #puts "spawning a request_handler in handlers[#{n}]"
          handlers << (Actor.spawn_link(&Aleph::Base.request_handler_proc) << Num.new(n))
        end
      end
      
      f.when(Request) do |req|
        puts "[supervisor] firing handler #{handler_turn}"
        handlers[handler_turn] << req
        if(handler_turn == handlers.size-1)
          handler_turn = 0
        else
          handler_turn += 1
        end
      end
      
      f.when(Actor::DeadActorError) do |exit|
        "#{exit.actor.name} died with reason: #{exit.reason}"
        case exit.actor.name
        when "request_handler"
          # lets replace that failed request_handler with a new one. NO DOWN TIME
          handler[exit.actor.num] = (Actor.spawn_link(&@request_handler_proc) << Num.new(exit.actor.num))
        when "replier"
          Actor.spawn_link(&@replier_proc)          
        end
      end
    end
  end
end
