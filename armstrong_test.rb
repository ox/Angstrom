require './lib/armstrong'

HelloProc = Proc.new do
  data = Actor.receive
  Actor[:replier] << Reply.new(data, "Hello World\0")
end

app = Armstrong.new [[/\//, HelloProc]]
app.run!