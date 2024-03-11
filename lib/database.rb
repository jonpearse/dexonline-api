require "sequel"

Sequel.extension :migration

class Database
  MIGRATION_DIR = $ROOT_PATH.join("db", "migrations")

  def self.connect(with_migrations = true)
    db = Sequel.connect(ENV.fetch("DATABASE_URL"), encoding: "utf8mb4")

    # check_current raises if it’s not current
    Sequel::Migrator.check_current(db, MIGRATION_DIR) if with_migrations

    return db
  end

  def self.migrate
    migrator = self::migrator(self::connect(false))
    return nil if migrator.is_current?

    migrator.run
    migrator.current
  end

  def self.rollback
    db = self::connect(false)
    migrator = self::migrator(db)
    current_version = migrator.current

    # we can’t do anything if the version is zero
    return nil if current_version == 0

    # this is tiresome…
    Sequel::Migrator.run(db, MIGRATION_DIR, target: current_version - 1)
    return current_version - 1
  end

  def self.migrator(db)
    Sequel::Migrator.migrator_class(MIGRATION_DIR).new(db, MIGRATION_DIR)
  end
end
