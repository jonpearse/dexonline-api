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

    xml = load_xml("#{DEX_UPDATE_URI}?last=#{last_update}", "updates since last run", gzip: false)

    # check we have a full node, otherwise we are unable to work out what the
    # current state should be
    full_node = xml.xpath("//Full").first
    unless full_node
      puts "#{"Error:".bold.red} update file does not contain a <Full> node!"
      exit 1
    end

    # if there are no updates, bail out
    if full_node["date"] == last_update
      puts "Already up-to-date!"
      exit
    end

    # sources and abbrevations are always present in every update + should
    # probably be synched
    print_header("Importing full data from #{full_node["date"].bold}")
    sync_sources(xtext(full_node, "Sources"))
    sync_abbrevations(xtext(full_node, "Abbrevs"))

    # Load the remainder of the Full node, if present
    install_update(full_node)

    # Now iterate through diffs
    xml.xpath("//Diffs/Diff").each do |diff_node|
      print_header("Importing diff from #{diff_node["date"].bold}")
      install_update(diff_node)
    end

    # record the update + done
    DB[:dictionary_updates].insert(update_date: full_node["date"])
  end

  def install_update(node)
    # data
    xtext(node, "Lexems") { |uri| load_lexemes(uri) }
    xtext(node, "Entries") { |uri| load_entries(uri) }
    xtext(node, "Definitions") { |uri| load_definitions(uri) }

    # mapping
    xtext(node, "EntryLexemMap") { |uri| map_entries_lexemes(uri) }
    xtext(node, "EntryDefinitionMap") { |uri| map_entries_definitions(uri) }
  end

  def sync_sources(uri)
    Source.unrestrict_primary_key

    xml = load_xml(uri, "sources")
    with_progress(xml.xpath("//Source"), "Inserting") do |node|
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
    with_progress(xml.xpath("//Abbrev"), "Inserting") do |node|
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
    with_progress(xml.xpath("//Lexem"), "Inserting") do |node|
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
    with_progress(xml.xpath("//Entry"), "Inserting") do |node|
      Entry.insert(
        id: node["id"],
        description: xtext(node, "Description"),
      )
    end
  end

  def load_definitions(uri)
    xml = load_xml(uri, "definitions")
    with_progress(xml.xpath("//Definition"), "Inserting") do |node|
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
    with_progress(xml.xpath("//Unmap"), "Pruning") do |node|
      DB[
        "DELETE FROM entries_lexemes WHERE entry_id = ? AND lexeme_id = ?",
        node["entryId"],
        node["lexemId"]
      ].delete
    end

    # Insert new links
    with_progress(xml.xpath("//Map"), "Inserting") do |node|
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
    with_progress(xml.xpath("//Unmap"), "Pruning") do |node|
      DB[
        "DELETE FROM definitions_entries WHERE entry_id = ? AND definition_id = ?",
        node["entryId"],
        node["definitionId"]
      ].delete
    end

    # Insert new links
    with_progress(xml.xpath("//Map"), "Inserting") do |node|
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
    puts
  end

  def get_text(node)
    node = [node] unless node.is_a?(Array)

    node.map { |n| n.text.strip }.join
  end

  def xtext(node, selector)
    found = node.xpath(selector)
    return nil unless found.any?

    text = get_text(found)

    yield text if block_given?
    text
  end

  def print_header(str)
    padding = "=" * (str.uncolorize.length + 2)

    puts
    puts padding
    puts " #{str}"
    puts padding
    puts
  end
end
