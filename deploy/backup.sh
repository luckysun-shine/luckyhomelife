#!/bin/sh
set -eu

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
target="/backups/$timestamp"
mkdir -p "$target"
pg_dump --format=custom --no-owner --dbname="$DATABASE_URL" --file="$target/database.dump"
tar -C /data -czf "$target/media.tar.gz" media
sha256sum "$target/database.dump" "$target/media.tar.gz" > "$target/SHA256SUMS"
find /backups -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf -- {} +
echo "Backup completed: $target"

