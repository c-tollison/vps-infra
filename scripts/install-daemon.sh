#!/usr/bin/env sh
# Install daemon.json into /etc/docker and restart Docker. Run with sudo.
set -eu
cd "$(dirname "$0")/.."
install -m 644 daemon.json /etc/docker/daemon.json
systemctl restart docker
docker info --format 'log driver: {{.LoggingDriver}}'
