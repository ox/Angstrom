require './lib/rubeck'

class HelloHandler < WebMessageHandler
  def process(req)
    puts req
    output("Hello world")
  end
end

app = Rubeck.new
app.add_route(/\//, HelloHandler)

app.run!