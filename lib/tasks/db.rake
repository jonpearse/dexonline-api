namespace :db do
  desc "Run all migrations"
  task :migrate do
    new_version = Database::migrate

    if new_version
      puts "Migrated database to schema version #{new_version}"
    else
      puts "No migrations were run"
    end
  end

  desc "Roll back the last migration"
  task :rollback do
    new_version = Database::rollback

    if new_version
      puts "Rolled database back to schema version #{new_version}"
    else
      puts "No rollback was performed"
    end
  end
end
