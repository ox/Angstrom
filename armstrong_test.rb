require './lib/armstrong'

HelloProc = Proc.new do
  output "hello world"
end

app = Armstrong.new [[/\//, HelloProc]]
app.run!