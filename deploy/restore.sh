#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: restore.sh /backups/<timestamp>" >&2
  exit 2
fi

source_dir="$1"
test -f "$source_dir/database.dump"
test -f "$source_dir/media.tar.gz"
(cd "$source_dir" && sha256sum -c SHA256SUMS)
pg_restore --clean --if-exists --no-owner --dbname="$DATABASE_URL" "$source_dir/database.dump"
mkdir -p /data/media
tar -C /data -xzf "$source_dir/media.tar.gz"
echo "Restore completed from: $source_dir"

