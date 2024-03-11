require "models/definition"

class Source < Sequel::Model
  one_to_many :definitions
end
