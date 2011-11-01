require 'rubygems'
require 'ffi-rzmq'
require 'json'
require 'benchmark'

sender_id = "251449FF-14F2-442F-84C2-BE4B49720A75"

context = ZMQ::Context.new 1
@req = context.socket ZMQ::PULL
@req.connect "tcp://127.0.0.1:9999"

@res = context.socket ZMQ::PUB
@res.setsockopt ZMQ::IDENTITY, sender_id
@res.connect "tcp://127.0.0.1:9998"


def parse(msg)
  uuid, id, path, header_size, headers, body_size, body = msg.match(/^(.{36}) (\d+) (.*?) (\d+):(.*?),(\d+):(.*?),$/).to_a[1..-1]

  return {:uuid => uuid, :id => id, :path => path, :body_size => body_size, :body => body}
end

def send(uuid, conn_id, msg)
  header = "%s %d:%s" % [uuid, conn_id.join(' ').length, conn_id.join(' ')]
  string =  header + ', ' + msg 
  puts "'send'ing string: ", string
  @res.send_string string, ZMQ::NOBLOCK
end

def reply(request, message)
  send(request[:uuid], [request[:id]], message)
end

def reply_http(req, body, code=200, headers={})
  headers["Content-Type"] = "text/html"
  reply(req, http_response(body, code, headers))
end

def http_response(body, code, headers)
  headers['Content-Length'] = body.size
  headers_s = headers.map{|k, v| "%s: %s" % [k,v]}.join("\r\n")

  "HTTP/1.1 #{code} #{StatusMessage[code.to_i]}\r\n#{headers_s}\r\n\r\n#{body}"
end

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


msg = ""

while true
  @req.recv_string msg
  puts Benchmark.measure {
  data = parse(msg)
  reply_http(data, "hello world\0")
  }
end

context.terminate