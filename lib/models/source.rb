require "models/abbreviation"
require "models/definition"

class Source < Sequel::Model
  one_to_many :abbreviations
  one_to_many :definitions
end
