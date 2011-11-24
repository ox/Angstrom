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

Aleph::Base.replier_proc = Proc.new do   
  @name = "replier"
  puts "started (#{@name})"
  Actor.register(:replier, Actor.current)
  Aleph::Base.replier = Actor.current
  Actor.trap_exit = true
  conn = nil
  
  loop do
    Actor.receive do |msg|
      msg.when(ConnectionInformation) do |c|
        conn = c.connection
      end
      msg.when(Reply) do |m|
        begin
          conn.reply_http(m.env, m.body, m.code, m.headers)
        rescue Exception => e
          puts "Actor[:replier]: I messed up with exception: #{e.message}"
        end
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
    #just like Rack: env, code, headers, body. HINT HINT
    Aleph::Base.replier << Reply.new(env, response[0], response[1], response[2])
  else
    Aleph::Base.replier << Reply.new(env, 200, {"Content-Type", "text/html;charset=utf-8", "Connection", "keep-alive", "Server", "Armstrong", "X-Frame-Options", "sameorigin", "X-XSS_Protection", "1; mode=block"}, response)
  end
end

Aleph::Base.request_handler_proc = Proc.new do
  @name = "request_handler"
  puts "started (#{@name})"
  Actor.register(:request_handler, Actor.current)
  Aleph::Base.request_handler = Actor.current
  Actor.trap_exit = true
  
  routes = {}
  loop do
    Actor.receive do |f|
      f.when(AddRoutes) do |r|
        routes = r.routes
      end

      f.when(Request) do |r|
        failure = true
        verb = r.env[:headers]["METHOD"]
        routes[verb].each do |route|
          if route.route[0].match(r.env[:path])
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
  puts "started (supervisor)"
  Actor.register(:supervisor, Actor.current)
  Aleph::Base.supervisor = Actor.current
  Actor.trap_exit = true
  
  handler = []
  handler_turn = 0
  
  Actor.spawn_link(&Aleph::Base.replier_proc)
  
  loop do
    Actor.receive do |f|
      f.when(AddRoutes) do |r|
        handlers.each do |h|
          h << r
        end
      end
      
      f.when(SpawnRequestHandlers) do |r|
        handler << Actor.spawn_link(&Aleph::Base.request_handler_proc)
      end
      
      f.when(Request) do |req|
        handler[handler_turn] << req
        if(handler_turn == handler.length)
          handler_turn = 0
        else
          handler_turn += 1
        end
      end
      
      f.when(Actor::DeadActorError) do |exit|
        "#{exit.actor.name} died with reason: #{exit.reason}"
        case exit.actor.name
        when "request_handler"
          Actor.spawn_link(&@request_handler_proc)
        when "replier"
          Actor.spawn_link(&@replier_proc)          
        end
      end
    end
  end
end
