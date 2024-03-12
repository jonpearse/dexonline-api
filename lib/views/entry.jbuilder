json.id @entry.id
json.description @entry.description

# definitions
json.definitions @entry.definitions.each do |defn|
  formatted_text, footnotes = Formatter::htmlise(defn.text, source: defn.source)

  json.text formatted_text
  json.user defn.user_name

  json.footnotes footnotes if footnotes.any?

  source = defn.source
  json.source do
    json.short_name source.short_name
    json.name source.name
    json.author source.author
    json.publisher source.publisher
    json.year source.year
  end
end

# links out to lexemes
json.lexems @entry.lexemes.each do |lexeme|
  json.id lexeme.id
  json.word lexeme.word
  json.categorie lexeme.categorie
  json.gen lexeme.gen if lexeme.gen

  # let’s add a URL to be nice (:
  json.ref to_api_url("lexem/#{lexeme.id}")
end
