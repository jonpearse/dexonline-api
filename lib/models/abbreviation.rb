require "models/source"

class Abbreviation < Sequel::Model
  many_to_one :source
end
