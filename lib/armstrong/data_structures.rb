AddRoute = Struct.new :route, :method
AddRoutes = Struct.new :routes
ShowRoutes = Struct.new :this
Request = Struct.new :data
ConnectionInformation = Struct.new :connection
Reply = Struct.new :data, :body, :code, :headers
