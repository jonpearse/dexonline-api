require "roda"
require "tilt/jbuilder"

# load entry + let everything spiral out from there…
require "models/entry"
require "util/formatter"

class App < Roda
  plugin :json

  plugin :render,
    engine: :jbuilder,
    views: $ROOT_PATH.join("lib", "views")

  CATEGORIES = %w[
    adjectiv
    forma_unica
    invariabil
    pronume
    substantiv_propriu
    substantiv
    verb
  ]

  route do |r|
    r.on "v1" do
      response["Content-Type"] = "application/json"

      # Simple access routes
      r.get "entry", Integer do |id|
        @entry = Entry[id]

        render(:entry)
      end

      r.get "lexem", Integer do |id|
        @lexeme = Lexeme[id]

        render(:lexeme)
      end

      # More complex search routes
      r.get "search", String, String do |category, query|
        category.downcase!

        unless CATEGORIES.include?(category)
          response.status = 404
          return
        end

        perform_search(query, category: category)
      end

      r.get "search", String do |query|
        perform_search(query)
      end
    end
  end

  private def to_api_url(path)
    "#{ENV.fetch("APP_URL")}/v1/#{path}"
  end

  private def perform_search(query, category: nil)
    @qry = {
      normalised: CGI.unescape(query).unicode_normalize(:nfd).gsub(/[^\x00-\x7F]/, ""),
    }
    @qry[:categorie] = category if category

    # perform the search
    lexemes = Lexeme.where(@qry)

    # If we have no results + the user has asked us to perform a full search…
    if lexemes.empty? && request.params.key?("full")
      # because this needs to know more about how lexemes work, we’ll ask the
      # Lexeme class to do it for us
      lexemes = Lexeme.search_inflections(@qry)

      # for the benefit of the output
      @qry[:expanded] = true
    end

    # return the corresponding entries + render
    # Note that we want to render lexemes (to avoid the user having to make
    # more queries than required), and these lexemes should probably be filtered
    # by a category is required, therefore…
    @results = lexemes.map(&:entries).flatten.uniq { |e| e.id }.map do |entry|
      lexemes = if category
          entry.lexemes_dataset.where(categorie: category).all
        else
          entry.lexemes
        end

      [entry, lexemes]
    end
    render(:search)
  end
end
