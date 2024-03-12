module Formatter
  def self.htmlise(str, source:)
    str.gsub!(/▶(.*?)◀/m, "") # remove unwanted parts of the definition
    str.gsub!(/(?<!\\\\)"(.*?)"/, "<q>\\1</q>") # quoted sections (this differs from Dex)

    # Footnotes!
    footnotes = []
    str.gsub!(/(?<!\\\\)\{\{(.*?)(?<![+])\}\}/) do |_|
      # Dex specifically ignores nested footnotes (‘so help us god’), and while
      # I’m a good Pratchett (GNU) fan that’d normally consider such things
      # necessary, I’m going to follow Dex’s lead in this case.
      # If nothing else, supporting nesting with regex would very much invoke
      # xkcd #1171…
      #
      # Also to note that Dex associates footnotes with their author, but as
      # don’t have access to that information, we’re just going to strip it out.
      footnotes << self::htmlise($1.split("/").first, source: source).first

      # note: 1-indexing footnotes, per dex.
      "[#{footnotes.length}]"
    end

    str.gsub!(/(?<!\\\\)\{-(.*?)-\}/m, "<del>\\1</del>") # deletions
    str.gsub!(/(?<!\\\\)\{+(.*?)+\}/m, "<ins>\\1</ins>") # insertions

    str.gsub!(/(?<!\\\\)@(.*?)(?<!\\\\)@/m, "<b>\\1</b>") # bold text
    str.gsub!(/(?<!\\\\)\$(.*?)(?<!\\\\)\$/m, "<i>\\1</i>") # italic
    str.gsub!(/(?<!\\\\)__(.*?)__/, "<em>\\1</em>") # emphasis
    str.gsub!(/(?<!\\\\)\^(\d)/, '<sup>\\1</sup>') # superscript
    str.gsub!(/(?<!\\\\)\^\{(.*?)\}/, '<sup>\\1</sup>') # more superscript
    str.gsub!(/(?<!\\\\)_(\d)/, '<sub>\\1</sub>') # subscript
    str.gsub!(/(?<!\\\\)_\{(.*?)\}/, '<sub>\\1</sub>') # more subscript

    # Deliberate decision: we’re not going to handle ‘spaced’ text, as this is
    # pure formatting and we’re an API…
    str.gsub!(/(?<!\\\\)%(.*?)(?<!\\\\)%/m, '\\1')

    # Abbreviations are fun!
    str.gsub!(/(?<!\\\\)##(.*?)(?<!\\\\)##/m, '\\1') # not an abbreviation…
    str.gsub!(/\{#(.*?)#\}/m, '\\1') # abbreviations for review: somewhat irrelavent here
    str.gsub!(/(?<!\\\\)#(.*?)(?<!\\\\)#/m) do |_| # actual abbreviations, which require a lookup
      abbr = source.abbreviations_dataset.where(short: $1).first

      if abbr
        "<abbr title=\"#{abbr.text}\">#{abbr.short}</abbr>"
      else
        $1
      end
    end

    # handle accents via the emphasiser
    str = self::emphasise(str)

    # Finally, remove any remaining escaping characters (that aren’t,
    # themselves, escaped)
    str.gsub!(/(?<!\\\\)\\\\/, "")

    [str, footnotes]
  end

  def self.emphasise(str)
    # Handle emphasis via unicode combining low lines. Dex does this via CSS
    # classes, but as we’re an API, this is maybe better?
    str.gsub!(/(?<!\\\\|\')'(\p{L})/, "\\1\u0332")
    str.gsub!(/(?<!\\\\)''(\p{L})/, "\\1\u0333")

    str
  end
end
