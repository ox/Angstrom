require './lib/armstrong'

class HelloHandler < WebMessageHandler
  def process(req)
    output("Hello world")
  end
end

app = Armstrong.new [[/\//, HelloHandler]]
app.run!