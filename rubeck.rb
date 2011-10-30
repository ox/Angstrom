require './m2'

class HelloHandler < WebMessageHandler
  def get
    self.set_body "hello world"
    return self.render
  end
end

urls = [[/\//, HelloHandler]]
mongrel2_pair = ["tcp://localhost:9999", "tcp://localhost:9998"]

app = Rubeck(mongrel2_pair, urls)
app.run
