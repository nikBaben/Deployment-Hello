#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec 9> "$HOME/hello-demo/deploy.lock"
flock -w 300 9
compose() { docker compose --env-file image.env -f compose.yaml "$@"; }
compose pull
compose up -d
ln -sfn "$PWD" "$HOME/hello-demo/current"
compose ps
printf 'Deployment succeeded: %s\n' "$(cat image.env)"
