require '../lib/armstrong'

get "/" do
  "hello world"
end

get "/:id" do |env|
  "id: #{env[:params]["id"]}"
end

get "/:id/do" do |env|
  "do: #{env[:params]["id"]}"
end