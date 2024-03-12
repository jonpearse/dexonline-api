require_relative "lib/bootstrap"

DB = Database.connect

require "app"

run App.freeze.app
