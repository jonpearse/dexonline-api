require "dotenv/load"
require "pathname"

# Work out some paths
$ROOT_PATH = Pathname.new(File.expand_path("..", __dir__))
$LOAD_PATH.unshift($ROOT_PATH.join("lib").to_s)

# we’ll probably always want a database…
require "database"
