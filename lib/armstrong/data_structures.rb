AddRoute = Struct.new :route, :method
AddRoutes = Struct.new :routes
Request = Struct.new :env
ConnectionInformation = Struct.new :connection
Reply = Struct.new :env, :code, :headers, :body
MessageAndProc = Struct.new :env, :proccess
