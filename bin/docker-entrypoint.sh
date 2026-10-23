#!/bin/sh
set -e

# Only prepare the database when starting the web server, not for test runs.
if [ "$1" = "bin/rails" ] && [ "$2" = "server" ]; then
  rm -f tmp/pids/server.pid
  bin/rails db:mongoid:create_indexes
  bin/rails db:seed
fi

exec "$@"
