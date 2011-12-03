AddRoute = Struct.new :route, :method
AddRoutes = Struct.new :routes
Request = Struct.new :env
ConnectionInformation = Struct.new :connection
Reply = Struct.new :env, :code, :headers, :body
MessageAndProc = Struct.new :env, :proccess

SpawnRequestHandlers = Struct.new :num
SpawnReceivers = Struct.new :num
RemoveRequestHandlers = Struct.new :num
RemoveReceivers = Struct.new :num
Num = Struct.new :index
