Sequel.migration do
  change do
    create_table :entries do
      primary_key :id
      String :description, null: false

      DateTime :imported_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table :entries_lexemes do
      foreign_key :entry_id, :entries, null: false
      foreign_key :lexeme_id, :lexemes, null: false
    end
  end
end
