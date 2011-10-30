require 'json'
require 'zmq'

class Mongrel2Commodore
  
  attr_reader :app_id, :sub_addr, :pub_addr
  
  def initialize(app_id, zmq_sub_pub_addr=["tcp://localhost", 9999, "tcp://localhost", 9998])
    @app_id = app_id
    @sub_addr = zmq_sub_pub_addr[0..1].join(":")
    @pub_addr = zmq_sub_pub_addr[2..3].join(":")
    
    @request_sock = @response_sock = nil
  end
  
  def connect
    context = ZMQ::Context.new 1
    @request_sock = context.socket ZMQ::PULL
    @request_sock.setsockopt ZMQ::LINGER, 0
    @request_sock.connect @sub_addr
    
    @response_sock = context.socket ZMQ::PUB
    @response_sock.setsockopt ZMQ::IDENTITY, @app_id
    @response_sock.setsockopt ZMQ::LINGER, 0
    @response_sock.connect @pub_addr
  end
  
  def recv
    data = @request_sock.recv
    return data
  end
  
  def receive
    data = self.recv
    return parse(data)
  end
  
  def send(uuid, conn_id, msg)
    header = "%s %d:%s" % [uuid, conn_id.length, conn_id.join(' ')]
    
    puts header + ', ' + msg + "\0"
    
    @response_sock.send header + ', ' + msg
  end
  
  def reply(request)
    puts request
    self.send(request[:uuid], [request[:id]], request[:response])
  end

  def parse(msg)
    uuid, id, path, header_size, headers, body_size, body = msg.match(/^(.{36}) (\d+) (.*?) (\d+):(.*?),(\d+):(.*?),$/).to_a[1..-1]
  
    return {uuid: uuid, id: id, path: path, header_size: header_size, headers: JSON.parse(headers), body_size: body_size, body: body}
  end
end
