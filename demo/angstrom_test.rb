require File.join(File.dirname(__FILE__), "..", "lib/angstrom")

set("request_handlers", 8)
set("receivers", 10)

get "/" do
  "hello world"
end

post "/" do |env|
  puts "post: ", env[:post].inspect
  "hello POST world"
end

get "/:id" do |env|
  "id: #{env[:params]["id"]}"
end

get "/:id/do" do |env|
  "do: #{env[:params]["id"]}"
end
