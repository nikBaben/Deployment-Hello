#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec 9> "$HOME/hello-demo/deploy.lock"
flock -w 300 9
compose() { docker compose --env-file image.env -f compose.yaml "$@"; }
compose config --quiet
compose pull
if ! compose up -d --wait --wait-timeout 120; then
  compose ps
  compose logs --no-color --tail 80
  exit 1
fi
STATUS=$(curl --fail --silent --show-error --retry 12 --retry-connrefused --retry-delay 2 --output response.txt --write-out '%{http_code}' http://127.0.0.1/)
test "$STATUS" = '200'
ln -sfn "$PWD" "$HOME/hello-demo/current"
compose ps
printf 'Deployment succeeded: %s\n' "$(cat image.env)"
