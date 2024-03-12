require "models/entry"
require "models/inflection"
require "models/mixins/has_word"

class Lexeme < Sequel::Model
  include HasWord

  many_to_many :entries
  one_to_many :inflections

  def self.search_inflections(query)
    qry = query.dup

    # this is ugly, but Sequel doesn’t like join queries…
    qry[Sequel.lit("inflections.normalised")] = qry.delete(:normalised)
    association_join(:inflections).where(qry).select(Sequel.lit("lexemes.*"))
  end
end
