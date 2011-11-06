require 'ffi-rzmq'

class Connection
  attr_reader :app_id, :sub_addr, :pub_addr
  
  def initialize(app_id, zmq_sub_pub_addr=["tcp://127.0.0.1", 9999, "tcp://127.0.0.1", 9998])
    @app_id = app_id
    @sub_addr = zmq_sub_pub_addr[0..1].join(":")
    @pub_addr = zmq_sub_pub_addr[2..3].join(":")
    
    @request_sock = @response_sock = nil
  end
  
  def connect
    context = ZMQ::Context.new 1
    @request_sock = context.socket ZMQ::PULL
    @request_sock.connect @sub_addr
    
    @response_sock = context.socket ZMQ::PUB
    @response_sock.setsockopt ZMQ::IDENTITY, @app_id
    @response_sock.connect @pub_addr
  end
  
  #raw recv
  def recv
    msg = ""
    @request_sock.recv_string msg
    return msg
  end
  
  #parse the request, this is the best way to get stuff back, as a Hash
  def receive
    return parse(self.recv)
  end
  
  def send(uuid, conn_id, msg)
    header = "%s %d:%s" % [uuid, conn_id.join(' ').length, conn_id.join(' ')]
    string =  header + ', ' + msg 
    #puts "\t\treplying to #{conn_id} with: ", string
    @response_sock.send_string string
    return
  end
  
  def reply(request, message)
    self.send(request[:uuid], [request[:id]], message)
  end

  def reply_http(req, body, code=200, headers={})
    self.reply(req, http_response(body, code, headers))
  end
  
  private
  def http_response(body, code, headers)
    headers['Content-Length'] = body.size
    headers_s = headers.map{|k, v| "%s: %s" % [k,v]}.join("\r\n")

    "HTTP/1.1 #{code} #{StatusMessage[code.to_i]}\r\n#{headers_s}\r\n\r\n#{body}"
  end
  
  def parse(msg)
    if(msg.empty?)
      return nil
    end
    
    uuid, id, path, header_size, headers, body_size, body = msg.match(/^(.{36}) (\d+) (.*?) (\d+):(.*?),(\d+):(.*?),$/).to_a[1..-1]
  
    return {:uuid => uuid, :id => id, :path => path, :header_size => header_size, :headers => headers, :body_size => body_size, :body => body}
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
