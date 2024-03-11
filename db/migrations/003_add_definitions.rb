Sequel.migration do
  change do
    create_table :sources do
      primary_key :id

      String :short_name, null: false
      String :name, null: false
      String :author, null: false
      String :publisher, null: false
      Integer :year, null: false

      DateTime :imported_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table :definitions do
      primary_key :id

      foreign_key :source_id, :sources, null: false
      Text :text
      String :user_name

      DateTime :imported_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table :definitions_entries do
      foreign_key :definition_id, :definitions, null: false
      foreign_key :entry_id, :entries, null: false
    end
  end
end
