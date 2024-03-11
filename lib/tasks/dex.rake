# gems
require "colorize"
require "digest"
require "excon"
require "nokogiri"
require "ruby-progressbar"
require "zlib"

namespace :dex do
  DEX_UPDATE_URI = "https://dexonline.ro/update5.php"
  CACHE_PATH = $ROOT_PATH.join("tmp")
  CACHE_EXPIRY = 24 * 60 * 60 # 24 hours

  desc "Updates the database"
  task :update do
    DB = Database::connect

    # local files
    require "models/inflection_form"
    require "models/inflection"
    require "models/lexeme"
    require "models/source"

    # find the last time we updated
    last_update = DB[:dictionary_updates].order(Sequel.desc(:update_date)).last
      &.fetch(:update_date)&.to_s || "0"

    xml = load_xml("#{DEX_UPDATE_URI}?last=#{last_update}", "latest data", gzip: false)
    current_version = xml.xpath("/Files/Full/@date").first.value
    if current_version == last_update
      puts "No updates found: exiting"
      exit
    end

    puts "\nImporting update #{current_version.bold}"

    # Load full information
    sync_sources(xtext(xml, "//Full/Sources"))
    sync_abbrevations(xtext(xml, "//Full/Abbrevs"))
    load_lexemes(xtext(xml, "//Full/Lexems"))
    load_entries(xtext(xml, "//Full/Entries"))
    load_definitions(xtext(xml, "//Full/Definitions"))

    # Mapping of entries to lexemes and definitions
    map_entries_lexemes(xtext(xml, "//Full/EntryLexemMap"))
    map_entries_definitions(xtext(xml, "//Full/EntryDefinitionMap"))

    # TODO: diffs

    # record the update
    DB[:dictionary_updates].insert(update_date: current_version)
  end

  def sync_sources(uri)
    Source.unrestrict_primary_key

    xml = load_xml(uri, "sources")
    with_progress(xml.xpath("//Source"), "Sources") do |node|
      id = node["id"]

      source = Source[id] || Source.new(id: id)

      source.update(
        short_name: xtext(node, "ShortName"),
        name: xtext(node, "Name"),
        author: xtext(node, "Author"),
        publisher: xtext(node, "Publisher"),
        year: xtext(node, "Year").to_i,
      )
    end
  end

  def sync_abbrevations(uri)
    xml = load_xml(uri, "abbreviations")
    with_progress(xml.xpath("//Abbrev"), "Abbreviations") do |node|
      params = {
        source_id: node.parent["id"].to_i,
        short: node["short"].strip,
      }

      abbreviation = Abbreviation.where(params).first || Abbreviation.new(params)
      abbreviation.update(text: get_text(node).unicode_normalize)
    end
  end

  def load_lexemes(uri)
    xml = load_xml(uri, "lexemes")
    with_progress(xml.xpath("//Lexem"), "Lexemes") do |node|
      # get the inflection form for the lexeme
      form = node.xpath("InflectedForm")
        .map { |n| InflectionForm[get_text(n).to_i] }
        .uniq { |f| f.categorie }
        .first

      DB.transaction do
        Lexeme.import(xtext(node, "Form"), {
          id: node["id"],
          categorie: form.categorie,
          gen: form.gen,
        })

        order = 0
        last_form_id = nil
        node.xpath("InflectedForm").each do |inflection|
          form_id = xtext(inflection, "InflectionId")

          # if we have multiple of the same form, store a sequence
          order = form_id == last_form_id ? order + 1 : 0
          last_form_id = form_id

          Inflection.import(xtext(inflection, "Form"), {
            lexeme_id: node["id"],
            form_id: form_id,
            order: order,
          })
        end
      end
    end
  end

  def load_entries(uri)
    xml = load_xml(uri, "entries")
    with_progress(xml.xpath("//Entry"), "Entries") do |node|
      Entry.insert(
        id: node["id"],
        description: xtext(node, "Description"),
      )
    end
  end

  def load_definitions(uri)
    xml = load_xml(uri, "definitions")
    with_progress(xml.xpath("//Definition"), "Definitions") do |node|
      Definition.insert(
        id: node["id"],
        source_id: xtext(node, "SourceId").to_i,
        user_name: xtext(node, "UserName"),
        text: xtext(node, "Text"),
      )
    end
  end

  def map_entries_lexemes(uri)
    xml = load_xml(uri, "entry–lexeme map")

    # unmap anything that needs removing
    with_progress(xml.xpath("//Unmap"), "Pruning E–L map") do |node|
      DB[
        "DELETE FROM entries_lexemes WHERE entry_id = ? AND lexeme_id = ?",
        node["entryId"],
        node["lexemId"]
      ].delete
    end

    # Insert new links
    with_progress(xml.xpath("//Map"), "Adding E–L map") do |node|
      DB[
        "INSERT INTO entries_lexemes (entry_id, lexeme_id) VALUES (?, ?)",
        node["entryId"],
        node["lexemId"]
      ].insert
    end
  end

  def map_entries_definitions(uri)
    xml = load_xml(uri, "entry–definition map")

    # unmap anything that needs removing
    with_progress(xml.xpath("//Unmap"), "Pruning E–D map") do |node|
      DB[
        "DELETE FROM definitions_entries WHERE entry_id = ? AND definition_id = ?",
        node["entryId"],
        node["definitionId"]
      ].delete
    end

    # Insert new links
    with_progress(xml.xpath("//Map"), "Adding E–D map") do |node|
      DB[
        "INSERT INTO definitions_entries (entry_id, definition_id) VALUES (?, ?)",
        node["entryId"],
        node["definitionId"]
      ].insert
    end
  end

  # Internal API calls

  def load_xml(uri, label, gzip: true)
    xml = with_cache(uri, label)
    xml = Zlib::gunzip(xml) if gzip

    Nokogiri::XML(xml)
  end

  def with_cache(uri, label)
    Dir::mkdir(CACHE_PATH) unless Dir.exist?(CACHE_PATH)

    print "Downloading #{label}… "

    cache_filename = CACHE_PATH.join(Digest::MD5.hexdigest(uri))
    if File.exist?(cache_filename) && File.mtime(cache_filename) > (Time.now - CACHE_EXPIRY)
      puts "[cache]".bold.green

      return File.read(cache_filename)
    end

    # it’s not in the cache, so yank it from the server
    response = Excon.get(uri)
    unless response.status == 200
      puts "[failed]".bold.red
      puts "\tReceived status #{response.status}".bold
      exit response.status
    end

    # save it in the cache
    File.open(cache_filename, "wb") { |f| f.write(response.body) }
    puts "[ok]".bold.green
    response.body
  end

  def with_progress(to_iterate, label, &blk)
    return unless to_iterate.any?

    pb = ProgressBar.create(
      title: label,
      total: to_iterate.length,
      format: "%t: [%B] [ %c/%C | +%r ]",
      remainder_mark: "-",
      progress_mark: "#",
      throttle_rate: 0.1,
    )

    to_iterate.each do |item|
      pb.increment
      yield item
    end

    pb.finish
  end

  def get_text(node)
    node = [node] unless node.is_a?(Array)

    node.map { |n| n.text.strip }.join
  end

  def xtext(node, selector)
    get_text(node.xpath(selector))
  end
end
