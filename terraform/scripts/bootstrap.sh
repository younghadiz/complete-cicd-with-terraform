#!/usr/bin/env bash
set -euo pipefail

exec > >(tee -a /var/log/capstone-bootstrap.log) 2>&1

printf 'Starting capstone server bootstrap\n'

mkdir -p /var/lib/capstone
rm -f /var/lib/capstone/bootstrap-ready

test "$(uname -m)" = "x86_64"

dnf install -y docker

mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON

# Pin Compose rather than downloading an unspecified latest release.
compose_version="v2.39.4"
compose_asset="docker-compose-linux-x86_64"
compose_url="https://github.com/docker/compose/releases/download/${compose_version}"

bootstrap_tmp="$(mktemp -d)"
trap 'rm -rf "$bootstrap_tmp"' EXIT

curl --fail --location \
  --retry 5 --retry-delay 3 \
  --connect-timeout 15 --max-time 180 \
  "${compose_url}/${compose_asset}" \
  -o "${bootstrap_tmp}/${compose_asset}"

curl --fail --location \
  --retry 5 --retry-delay 3 \
  --connect-timeout 15 --max-time 60 \
  "${compose_url}/${compose_asset}.sha256" \
  -o "${bootstrap_tmp}/${compose_asset}.sha256"

expected_sha="$(
  awk 'NR == 1 {print $1}' \
    "${bootstrap_tmp}/${compose_asset}.sha256"
)"

[[ "$expected_sha" =~ ^[0-9a-fA-F]{64}$ ]]

printf '%s  %s\n' \
  "$expected_sha" \
  "${bootstrap_tmp}/${compose_asset}" |
  sha256sum --check -

install -d -m 0755 /usr/local/lib/docker/cli-plugins

install -m 0755 \
  "${bootstrap_tmp}/${compose_asset}" \
  /usr/local/lib/docker/cli-plugins/docker-compose

usermod -aG docker ec2-user

install -d \
  -o ec2-user \
  -g ec2-user \
  -m 0750 \
  /opt/complete-cicd-with-terraform

systemctl enable --now docker

docker info >/dev/null
docker compose version

touch /var/lib/capstone/bootstrap-ready

printf 'Capstone server bootstrap completed\n'
