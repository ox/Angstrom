require 'json'

require './lib/amstrong/connection'
require './lib/amstrong/fiber_pool'
require './lib/amstrong/handler'

class Amstrong
  attr_reader :conn, :routes, :pool
  
  def initialize(urls)
    @conn = Connection.new "251249FF-14F2-442F-84C2-BE4B49720A75"
    @conn.connect
    
    @routes = {}
    urls.each { |u| add_route(u[0], u[1]) }
    
    @pool = FiberPool.new
  end
  
  def add_route(regex, handler)
    @routes[Regexp.new regex] = handler
  end
  
  def route(req)
    @routes.each do |r, handler|
      if req[:path].match r
        return @conn.reply_http(req, handler.new.resume(req[:body]), 200, {"Content-type"=> "text/html"})
      end
    end
    
    return @conn.reply(req, "404 Not Found")
  end
  
  def run!
    while true
      req = @conn.receive
      self.route(req)
    end
  end
end