require 'actor'

require './lib/armstrong/connection'
require './lib/armstrong/data_structures'
require './lib/armstrong/main_actors'

require 'lazy'

def get_request
  return Actor.receive
end

def reply(request, value)
  Actor[:replier] << Reply.new(request, value)
end

def reply_string(value)
  Actor[:replier] << Reply.new(Actor.receive,value)
end
  
module Aleph
  class Base
    class << self
      attr_accessor :conn, :routes, :pairs
      
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
      
      def get(path, &block)
        (@pairs ||= []) << AddRoute.new(path, block)
      end
    end
  end
  
  class Armstrong < Base  
    def self.run!
      uuid = new_uuid
      puts "starting Armstrong as mongrel2 service #{uuid}"
      @conn = Connection.new uuid
      @conn.connect
      
      done = Lazy::demand(Lazy::Promise.new do |done|
        Actor.spawn(&Aleph::Base.supervisor)
        Actor.spawn(&Aleph::Base.replier)
        Actor.spawn(&Aleph::Base.request_handler)
        done = true
      end)
      
      Actor[:replier] << ConnectionInformation.new(@conn) if done
      
      Lazy::demand(Lazy::Promise.new do |done|
        Actor[:request_handler] << AddRoutes.new(@pairs)
        done = true
      end)

      puts "","="*56,"Armstrong has launched on #{Time.now}","="*56, ""
      # main loop
      loop do
        req = @conn.receive
        Actor[:request_handler] << Request.new(req) if !req.nil?
      end
    end
  end
  
  # thank you sinatra!
  # Sinatra delegation mixin. Mixing this module into an object causes all
  # methods to be delegated to the Aleph::Armstrong class. Used primarily
  # at the top-level.
  module Delegator
    def self.delegate(*methods)
      methods.each do |method_name|
        define_method(method_name) do |*args, &block|
          return super(*args, &block) if respond_to? method_name
          Delegator.target.send(method_name, *args, &block)
        end
        private method_name
      end
    end

    delegate :get

    class << self
      attr_accessor :target
    end

    self.target = Armstrong
  end
  
  at_exit { Armstrong.run! }
end

include Aleph::Delegator

