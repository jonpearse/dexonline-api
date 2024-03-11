require "models/inflection"
require "models/mixins/has_word"

class Lexeme < Sequel::Model
  include HasWord

  one_to_many :inflections
end
