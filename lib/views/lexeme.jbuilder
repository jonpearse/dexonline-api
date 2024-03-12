json.id @lexeme.id
json.word @lexeme.word
json.categorie @lexeme.categorie
json.gen @lexeme.gen if @lexeme.gen

json.inflections @lexeme.inflections do |inflection|
  form = inflection.form

  json.word inflection.word
  json.emphasis Formatter::emphasise(inflection.emphasised)
  json.order inflection.order

  json.form do
    json.categorie form.categorie
    json.caz form.caz if form.caz
    json.gen form.gen if form.gen && form.categorie != "substantiv"
    json.mod form.mod if form.mod
    json.timp form.timp if form.timp
    json.persoana form.persoana if form.persoana
    json.plural form.plural unless form.plural.nil?
    json.articulat form.articulat unless form.articulat.nil?
  end
end
