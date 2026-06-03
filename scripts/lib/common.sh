#!/usr/bin/env bash
# Shared variables and helpers sourced by all scripts in scripts/

IMAGE_NAME="bwi-juice-shop"
IMAGE_TAG="latest"
IMAGE_FILE="bwi-juice-shop.tar"

# Project root = two levels above this file (scripts/lib/ → scripts/ → project root)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load CTF_KEY and other secrets from ctfd/.env if it exists
ENV_FILE="${PROJECT_ROOT}/ctfd/.env"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  set -a
  source "${ENV_FILE}"
  set +a
fi

if [[ -z "${CTF_KEY:-}" ]]; then
  echo "ERROR: CTF_KEY is not set." >&2
  echo "       Either source ctfd/.env or: export CTF_KEY='<your-key>'" >&2
  exit 1
fi
