require "values"
require "yaml"

module InflectionForm
  @@loaded = nil

  KEYS = %i{ id description categorie gen caz mod timp persoana plural articulat }

  Form = Value.new(*KEYS)

  def self.all
    self.load unless @@loaded

    @@loaded
  end

  def self.find(id)
    self.load unless @@loaded

    raise "Could not find inflection #{id}" unless @@loaded.key?(id)

    @@loaded[id]
  end

  def self.[](id)
    self.find(id)
  end

  def self.load
    File.open($ROOT_PATH.join("data", "inflection_forms.yaml"), "r") do |f|
      @@loaded = YAML.load(f.read, symbolize_names: true).map do |f|
        vals = KEYS.map { |k| [k, nil] }.to_h.merge(f)

        [
          f.fetch(:id),
          Form.with(vals).freeze,
        ]
      end.to_h
    end
  end
end
