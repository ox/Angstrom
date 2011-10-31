class WebMessageHandler
  def initialize
    @fiber_delegate = Fiber.new do |req|
      process(req)
    end
  end
  
  def resume(req)
    @fiber_delegate.resume(req)
  end
  
  def process(req)
    handle_value(req)
  end
  
  #dummy 
  def handle_value(value)
    output(value)
  end
  
  def output(value)
    Fiber.yield(value)
  end
end