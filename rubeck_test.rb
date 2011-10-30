require './lib/rubeck'

class HelloHandler < WebMessageHandler
  def process(req)
    output("Hello world")
  end
end

app = Rubeck.new [[/\//, HelloHandler]]
app.run!