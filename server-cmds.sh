#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./server-cmds.sh IMAGE [DOCKER_HUB_USERNAME]
# If a username is supplied, provide the registry token on standard input.

export IMAGE="${1:?Usage: server-cmds.sh IMAGE [DOCKER_HUB_USERNAME]}"
registry_user="${2:-}"

if [[ "$IMAGE" == -* || "$IMAGE" =~ [[:space:]] ]]; then
  printf 'Invalid image reference.\n' >&2
  exit 1
fi

export APP_BIND_ADDRESS="${APP_BIND_ADDRESS:-0.0.0.0}"
export APP_PORT="${APP_PORT:-8080}"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-complete-cicd-with-terraform}"

pull_image="${PULL_IMAGE:-true}"

case "$pull_image" in
  true|false) ;;
  *)
    printf 'PULL_IMAGE must be true or false.\n' >&2
    exit 1
    ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")"

registry_config=""
response_file="$(mktemp)"

cleanup() {
  rm -f "$response_file"
  if [ -n "$registry_config" ]; then
    rm -rf "$registry_config"
  fi
}
trap cleanup EXIT

docker info >/dev/null
docker compose version
docker compose -f docker-compose.yaml config --quiet

if [ -n "$registry_user" ]; then
  registry_config="$(mktemp -d)"
  chmod 700 "$registry_config"
  export DOCKER_CONFIG="$registry_config"

  docker login \
    --username "$registry_user" \
    --password-stdin
fi

if [ "$pull_image" = "true" ]; then
  docker compose -f docker-compose.yaml pull java-maven-app
else
  # Local verification only: the image must already exist.
  docker image inspect "$IMAGE" >/dev/null
fi

docker compose -f docker-compose.yaml up -d --no-build

verify_method="${VERIFY_METHOD:-host}"

case "$verify_method" in
  host|container) ;;
  *)
    printf 'VERIFY_METHOD must be host or container.\n' >&2
    exit 1
    ;;
esac

probe_container="$(
  docker compose -f docker-compose.yaml ps -q java-maven-app
)"
test -n "$probe_container"

fetch_homepage() {
  if [ "$verify_method" = "container" ]; then
    docker exec "$probe_container" \
      /bin/busybox wget -q -T 5 -O - \
      http://127.0.0.1:8080/ > "$response_file"
  else
    curl --fail --silent \
      --connect-timeout 2 \
      --max-time 5 \
      "http://127.0.0.1:${APP_PORT}/" \
      -o "$response_file"
  fi
}

ready=false

for attempt in {1..30}; do
  if fetch_homepage; then

    if grep -Fq \
      '<h1>Welcome to Java Maven Application</h1>' \
      "$response_file"; then
      ready=true
      break
    fi
  fi

  sleep 2
done

if [ "$ready" != "true" ]; then
  printf 'FAILED: application readiness verification.\n' >&2
  docker compose -f docker-compose.yaml ps
  docker compose -f docker-compose.yaml logs --tail 100 --no-color
  exit 1
fi

container_id="$(
  docker compose -f docker-compose.yaml ps -q java-maven-app
)"
test -n "$container_id"

actual_image="$(
  docker inspect --format '{{.Config.Image}}' "$container_id"
)"
test "$actual_image" = "$IMAGE"

test "$(
  docker inspect --format '{{.State.Running}}' "$container_id"
)" = "true"

docker compose -f docker-compose.yaml ps

printf 'PASS: %s is running and serves the expected homepage.\n' "$IMAGE"
