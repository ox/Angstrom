require 'ffi'
require 'ffi-rzmq'
require 'json'
require 'cgi'

class Connection
  attr_reader :app_id, :sub_addr, :pub_addr, :request_sock, :response_sock, :context
  
  def initialize(app_id, zmq_sub_pub_addr=["tcp://127.0.0.1", 9999, "tcp://127.0.0.1", 9998])
    @app_id = app_id
    @sub_addr = zmq_sub_pub_addr[0..1].join(":")
    @pub_addr = zmq_sub_pub_addr[2..3].join(":")
    
    @request_sock = @response_sock = nil
  end
  
  def connect
    @context = ZMQ::Context.new 1
    @request_sock = @context.socket ZMQ::PULL
    @request_sock.connect @sub_addr
    
    @response_sock = @context.socket ZMQ::PUB
    @response_sock.setsockopt ZMQ::IDENTITY, @app_id
    @response_sock.connect @pub_addr
  end
  
  #raw recv, unparsed message
  def recv
    msg = ""
    rc = @request_sock.recv_string(msg)
    puts "errno [#{ZMQ::Util.errno}] with description [#{ZMQ::Util.error_string}]" unless ZMQ::Util.resultcode_ok?(rc)
    msg
  end
  
  #parse the request, this is the best way to get stuff back, as a Hash
  def receive
    parse(recv)
  end
  
  # sends the message off, formatted for Mongrel2 to understand
  def send(uuid, conn_id, msg)
    header = "%s %d:%s" % [uuid, conn_id.join(' ').length, conn_id.join(' ')]
    string =  header + ', ' + msg 
    #puts "\t\treplying to #{conn_id} with: ", string
    rc = @response_sock.send_string string, ZMQ::NOBLOCK
    puts "errno [#{ZMQ::Util.errno}] with description [#{ZMQ::Util.error_string}]" unless ZMQ::Util.resultcode_ok?(rc)
  end
  
  # reply to an env with `message` string
  def reply(env, message)
    self.send(env[:sender], [env[:conn_id]], message)
  end

  # reply to a req with a valid http header
  def reply_http(env, body, code=200, headers={"Content-type" => "text/html"})
    self.reply(env, http_response(body, code, headers))
  end
  
  private
  def http_response(body, code, headers)
    headers['Content-Length'] = body.size
    headers_s = headers.map{|k, v| "%s: %s" % [k,v]}.join("\r\n")
    
    "HTTP/1.1 #{code} #{StatusMessage[code.to_i]}\r\n#{headers_s}\r\n\r\n#{body}"
  end
  
  def parse_netstring(ns)
    len, rest = ns.split(':', 2)
    len = len.to_i
    raise "Netstring did not end in ','" unless rest[len].chr == ','
    [ rest[0...len], rest[(len+1)..-1] ]
  end
  
  def parse(msg)
    if msg.nil? || msg.empty?
      return nil
    end
    
    env = {}
    env[:sender], env[:conn_id], env[:path], rest = msg.split(' ', 4)
    env[:headers], head_rest = parse_netstring(rest)
    env[:body], _ = parse_netstring(head_rest)

    env[:headers] = JSON.parse(env[:headers])
    if(env[:headers]["METHOD"] == "POST")
      env[:post] = parse_params(env)
    end
    
    return env
  end
  
  def parse_params(env)
    r = {}
    m = env[:body].scan(/(\w+)=(.*?)(?:&|$)/)
    m.each { |k| r[CGI::unescape(k[0].to_s)] = CGI::unescape(k[1]) }
    return r
  end
  
  # From WEBrick: thanks dawg.
  StatusMessage = {
    100 => 'Continue',
    101 => 'Switching Protocols',
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',
    203 => 'Non-Authoritative Information',
    204 => 'No Content',
    205 => 'Reset Content',
    206 => 'Partial Content',
    300 => 'Multiple Choices',
    301 => 'Moved Permanently',
    302 => 'Found',
    303 => 'See Other',
    304 => 'Not Modified',
    305 => 'Use Proxy',
    307 => 'Temporary Redirect',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    402 => 'Payment Required',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    407 => 'Proxy Authentication Required',
    408 => 'Request Timeout',
    409 => 'Conflict',
    410 => 'Gone',
    411 => 'Length Required',
    412 => 'Precondition Failed',
    413 => 'Request Entity Too Large',
    414 => 'Request-URI Too Large',
    415 => 'Unsupported Media Type',
    416 => 'Request Range Not Satisfiable',
    417 => 'Expectation Failed',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported'
  }
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

uuid = new_uuid
puts "replying as mongrel2 service #{uuid}"
$armstrong_conn = Connection.new uuid
$armstrong_conn.connect
