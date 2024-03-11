require "models/entry"
require "models/inflection"
require "models/mixins/has_word"

class Lexeme < Sequel::Model
  include HasWord

  many_to_many :entries
  one_to_many :inflections
end
