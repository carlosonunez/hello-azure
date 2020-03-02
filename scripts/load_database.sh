#!/usr/bin/env sh
SESSION_DB_USER=${SESSION_DB_USER}
SESSION_DB_PASSWORD=${SESSION_DB_PASSWORD}
SESSION_DB_HOST=${SESSION_DB_HOST}
SESSION_DB_PORT=${SESSION_DB_PORT}
export PGPASSWORD=$SESSION_DB_PASSWORD

psql --username "${SESSION_DB_USER}" \
  --port "$SESSION_DB_PORT" \
  --dbname sessions \
  --host "$SESSION_DB_HOST" \
  -c "$(cat <<-SQL
CREATE TABLE click_data (
  id text,
  click_count int
)
SQL
)" || true
