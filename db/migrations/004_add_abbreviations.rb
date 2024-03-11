Sequel.migration do
  change do
    create_table :abbreviations do
      primary_key :id
      foreign_key :source_id, :sources, null: false
      String :short, null: false
      Text :text
    end
  end
end
