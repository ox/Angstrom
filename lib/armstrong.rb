require 'actor'
require 'rubygems'
require 'lazy'
require 'open-uri'
require 'json'

libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require "armstrong/connection"
require 'armstrong/data_structures'
require 'armstrong/main_actors'
  
module Aleph
  class Base
    class << self
      attr_accessor :conn, :routes
      
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
      
      def get(path, &block) route "GET", path, &block end
      def put(path, &block)  route "PUT",  path, &block end
      def post(path, &block) route "POST", path, &block end
      def head(path, &block) route "HEAD", path, &block end
      def delete(path, &block) route "DELETE", path, &block end
      def patch(path, &block) route "PATCH", path, &block end
      
      def route(verb, path, &block)
        @routes ||= {}
        (@routes[verb] ||= []) << AddRoute.new(compile(path), block)
      end
      
      private
        def compile(path)
          keys = []
          if path.respond_to? :to_str
            pattern = path.to_str.gsub(/[^\?\%\\\/\:\*\w]/) { |c| encoded(c) }
            pattern.gsub!(/((:\w+)|\*)/) do |match|
              if match == "*"
                keys << 'splat'
                "(.*?)"
              else
                keys << $2[1..-1]
                "([^/?#]+)"
              end
            end
            [/^#{pattern}$/, keys]
          elsif path.respond_to?(:keys) && path.respond_to?(:match)
            [path, path.keys]
          elsif path.respond_to?(:names) && path.respond_to?(:match)
            [path, path.names]
          elsif path.respond_to? :match
            [path, keys]
          else
            raise TypeError, path
          end
        end

        def encoded(char)
          enc = URI.encode(char)
          enc = "(?:#{Regexp.escape enc}|#{URI.encode char, /./})" if enc == char
          enc = "(?:#{enc}|#{encoded('+')})" if char == " "
          enc
        end
    end
  end
  
  class Armstrong < Base  
    def self.run!
      uuid = new_uuid
      puts "starting Armstrong as mongrel2 service #{uuid}"
      @conn = Connection.new uuid
      @conn.connect
      
      #ensure that all actors are launched. Yea.
      done = Lazy::demand(Lazy::promise do |done|
        Actor.spawn(&Aleph::Base.replier_proc)
        done = Lazy::demand(Lazy::promise do |done|
          Actor.spawn(&Aleph::Base.request_handler_proc)
          done = Lazy::demand(Lazy::promise do |done|
            Actor.spawn(&Aleph::Base.supervisor_proc)
            done = true
          end)
        end)
      end)
      
      Aleph::Base.replier << ConnectionInformation.new(@conn) if done
      
      done = Lazy::demand(Lazy::Promise.new do |done|
        Aleph::Base.request_handler << AddRoutes.new(@routes)
        done = true
      end)

      if Aleph::Base.supervisor && Aleph::Base.request_handler && Aleph::Base.replier && done
        puts "","="*56,"Armstrong has launched on #{Time.now}","="*56, ""
      end
      
      # main loop
      loop do
        req = @conn.receive
        Aleph::Base.request_handler << Request.new(req) if !req.nil?
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

    delegate :get, :post, :put, :patch, :delete, :head

    class << self
      attr_accessor :target
    end

    self.target = Armstrong
  end
  
  at_exit { Armstrong.run! }
end

include Aleph::Delegator

