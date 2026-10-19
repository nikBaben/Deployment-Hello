#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export DEPLOY_ROOT="$HOME/hello-demo"
STATE="$DEPLOY_ROOT/state"
mkdir -p "$STATE"
exec 9> "$DEPLOY_ROOT/deploy.lock"
flock -w 300 9
compose() { docker compose --env-file image.env --env-file catalog.env -f compose.yaml "$@"; }

printf 'Containers before deployment:\n'
compose ps --format json

infrastructure_changed=false
for file in compose.yaml nginx.conf deploy.sh; do
  if ! cmp -s "$file" "$STATE/$file"; then
    infrastructure_changed=true
  fi
done

if "$infrastructure_changed"; then
  echo "Shared configuration changed: apply api, catalog and nginx"
  mkdir -p "$DEPLOY_ROOT/config"
  cp nginx.conf "$DEPLOY_ROOT/config/nginx.conf"
  chmod 644 "$DEPLOY_ROOT/config/nginx.conf"
  compose pull api catalog nginx
  compose up -d --no-deps api catalog
  compose up -d --no-deps --force-recreate nginx
  cp compose.yaml nginx.conf deploy.sh image.env catalog.env "$STATE/"
else
  services=()
  if ! cmp -s image.env "$STATE/image.env"; then services+=(api); fi
  if ! cmp -s catalog.env "$STATE/catalog.env"; then services+=(catalog); fi
  if ((${#services[@]} == 0)); then
    echo "No service versions changed; nothing to apply"
  else
    printf 'Changed services: %s\n' "${services[*]}"
    compose pull "${services[@]}"
    compose up -d --no-deps "${services[@]}"
    cp image.env catalog.env "$STATE/"
  fi
fi

ln -sfn "$PWD" "$DEPLOY_ROOT/current"
printf 'Containers after deployment:\n'
compose ps --format json
printf 'Deployment applied: %s\n' "$PWD"
