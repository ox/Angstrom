class Request < Hash
  def method_missing(name, *args, &block)
    try
      return self.["#{name}"]
    rescue
      super(name, args, block)
    end
  end
end
