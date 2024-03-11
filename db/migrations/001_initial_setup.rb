Sequel.migration do
  change do
    # Store dictionary updates
    create_table :dictionary_updates do
      Date :update_date, null: false, unique: true
      DateTime :imported_at, default: Sequel::CURRENT_TIMESTAMP
    end

    # Basic lexeme structure
    create_table :lexemes do
      primary_key :id

      String :word, null: false
      String :normalised, null: false, index: true
      String :emphasised, null: false

      # denormalise category + gender for ease of lookup
      String :categorie, size: 24, null: false
      String :gen, size: 12

      DateTime :imported_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table :inflections do
      primary_key :id

      foreign_key :lexeme_id, :lexemes
      Integer :form_id

      String :word, null: false
      String :normalised, null: false, index: true
      String :emphasised, null: false

      Integer :order, limit: 1, null: false

      DateTime :imported_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
