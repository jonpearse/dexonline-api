json.query @qry
json.results @results do |entry, lexemes|
  json.id entry.id
  json.description entry.description

  # links out to lexemes (so we can get to them without having to load the
  # full entry…)
  json.lexems lexemes.each do |lexeme|
    json.id lexeme.id
    json.word lexeme.word
    json.categorie lexeme.categorie
    json.gen lexeme.gen if lexeme.gen

    # let’s add a URL to be nice (:
    json.ref to_api_url("lexem/#{lexeme.id}")
  end

  # let’s add a URL to be nice (:
  json.ref to_api_url("entry/#{entry.id}")
end
