require "models/entry"
require "models/source"

class Definition < Sequel::Model
  many_to_many :entries
  many_to_one :source
end
