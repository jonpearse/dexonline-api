module HasWord
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def import(word, other = {})
      word = word.unicode_normalize
      unemphasised = word.gsub("'", "")

      insert(other.merge(
        word: unemphasised,
        normalised: unemphasised.unicode_normalize(:nfd).gsub(/[^\x00-\x7F]/, ""),
        emphasised: word,
      ))
    end
  end
end
