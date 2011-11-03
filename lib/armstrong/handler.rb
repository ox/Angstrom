require 'actor'

class WebMessageHandler
  
  def initialize
    @routes = []
  end
  
  
  
  def output(value)
    Actor[:replier] << Reply.new(value)
  end
end