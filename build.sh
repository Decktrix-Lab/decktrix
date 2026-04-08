#!/bin/bash
set -e

docker compose run --remove-orphans build "$@"
sudo chown -R "$(id -u):$(id -g)" deploy/
