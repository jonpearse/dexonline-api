require "models/definition"
require "models/lexeme"

class Entry < Sequel::Model
  many_to_many :definitions
  many_to_many :lexemes
end
