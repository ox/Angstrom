require './lib/rubeck/connection'

conn = Connection.new "71875A6A-314A-4061-B97B-64D4AF32498D"
conn.connect

puts "starting..."
while true
  req = conn.receive
  conn.reply(req, "hello world")
end
