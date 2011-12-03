# nucleus 

# command your servers

# SpawnRequestHandlers = Struct.new :num
# SpawnReceivers = Struct.new :num
# RemoveRequestHandlers = Struct.new :num
# RemoveReceivers = Struct.new :num

require 'actor'
require 'angstrom/data_structures'

module Aleph
  class Nucleus
    def self.bond(command)
      m = command.scan(/(\w+) (\d+) (\w+)$/)
      op, quantity, what = m[0][0].to_s, m[0][1].to_i, m[0][2].to_s
      puts m.inspect
      puts "{%s, %s, %s}" % [op, quantity, what]

      case op
      when "add"
        case what
        when "handlers"
          puts 'ehre'
          Actor[:supervisor] << SpawnRequestHandlers.new(quantity)
        when "receivers"
          Actor[:supervisor] << SpawnReceivers.new(quantity)
        else
          puts "either 'handlers' or 'receivers'"
        end
      when "remove"
        case what
        when "handlers"
          Actor[:supervisor] << RemoveRequestHandlers.new(quantity)
        when "receivers"
          Actor[:supervisor] << RemoveReceivers.new(quantity)
        else
          puts "either 'handlers' or 'receivers'"
        end
      else
        puts "either 'add' or 'remove'"
      end
    end
  end
end