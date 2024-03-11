require "models/inflection_form"
require "models/lexeme"
require "models/mixins/has_word"

class Inflection < Sequel::Model
  include HasWord

  many_to_one :lexeme

  def form
    InflectionForm[form_id]
  end
end
