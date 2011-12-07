require 'actor'
require 'rubygems'
require 'lazy'

libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require "angstrom/connection"
require 'angstrom/data_structures'
require 'angstrom/main_actors'
require 'angstrom/nucleus'
  
module Aleph
  class Base
    class << self
      attr_accessor :options
      
      def get(path, &block) route "GET", path, &block end
      def put(path, &block)  route "PUT",  path, &block end
      def post(path, &block) route "POST", path, &block end
      def head(path, &block) route "HEAD", path, &block end
      def delete(path, &block) route "DELETE", path, &block end
      def patch(path, &block) route "PATCH", path, &block end
      
      def set(option, value)
        @options ||= {}
        @options[option] = value
      end
      
      def route(verb, path, &block)
        $routes ||= {}
        ($routes[verb] ||= []) << AddRoute.new(compile(path), block)
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
  
  class Angstrom < Base
    # the kicker. It all gets launched from here.
    # this function makes a new connection object to handle the communication,
    # promises to start the replier, request handler, and their supervisor,
    # gives the replier the connection information, tells the request_handler
    # what routes it should be able to match, then checks that all of the services
    # are running correctly, gives us a launch time, then jumps into our main loop
    # that waits for an incoming message, parses it, and sends it off to be
    # operated on by the request handler. Boom.
    def self.run!
      @options ||= {}
      set("receivers", 2) if !@options["receivers"]
      set("request_handlers", 4) if !@options["request_handlers"]

      #ensure that all actors are launched. Yea.
      done = Lazy::demand(Lazy::promise do |done|
        Actor.spawn(&Aleph::Base.supervisor_proc)
        done = true
      end)
      
      if done
        done2 = Lazy::demand(Lazy::Promise.new do |done2|
          Actor[:supervisor] << SpawnRequestHandlers.new(options["request_handlers"])
          Actor[:supervisor] << SpawnReceivers.new(options["receivers"])
          done2 = true
        end)
      end
      
      if Aleph::Base.supervisor && done2
        puts "","="*56,"Angstrom has launched on #{Time.now}","="*56, ""
      end
      
      # main loop
      loop do
        print "> "
        Aleph::Nucleus.bond(gets.chomp)
      end
    end
  end
  
  # thank you sinatra!
  # Sinatra delegation mixin. Mixing this module into an object causes all
  # methods to be delegated to the Aleph::Angstrom class. Used primarily
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

    delegate :get, :post, :put, :patch, :delete, :head, :set

    class << self
      attr_accessor :target
    end

    self.target = Angstrom
  end
  
  # Sinatras secret sauce.
  at_exit { Angstrom.run! }
end

include Aleph::Delegator
