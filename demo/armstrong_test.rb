require '../lib/armstrong'

get "/" do
  reply_string "hello world"
end

get "/:id" do
  req = get_request
  reply req, "id: #{req[:params]["id"]}"
end

get "/:id/do" do
  req = get_request
  reply req, "do: #{req[:params]["id"]}"
end