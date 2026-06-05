#!/usr/bin/env bash
# Kali Linux VM setup script for BWI Developer Conference CTF.
# Run this INSIDE the Kali VM as a user with Docker access (kali user is fine).
#
# Prerequisites:
#   - bwi-juice-shop.tar copied to the same directory as this script
#   - Docker installed and running on the VM
#   - CTF_KEY set as an environment variable
#
# Usage:
#   CTF_KEY='<shared-secret>' bash 04-vm-setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="${SCRIPT_DIR}/bwi-juice-shop.tar"
IMAGE_NAME="bwi-juice-shop"
COMPOSE_DIR="${HOME}/ctf"
ENV_FILE="${COMPOSE_DIR}/.env"

# --- Validate CTF_KEY ---
if [[ -z "${CTF_KEY:-}" ]]; then
  echo "ERROR: CTF_KEY is not set."
  echo "Usage: CTF_KEY='<shared-secret>' bash $(basename "$0")"
  exit 1
fi

# --- Validate image file ---
if [[ ! -f "${IMAGE_FILE}" ]]; then
  echo "ERROR: Image file not found: ${IMAGE_FILE}"
  echo "       Copy bwi-juice-shop.tar to the same directory as this script."
  exit 1
fi

# --- Ensure Docker is running ---
if ! docker info > /dev/null 2>&1; then
  echo "==> Docker is not running. Starting Docker daemon..."
  sudo systemctl start docker
  sleep 5
  if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Could not start Docker. Check: sudo systemctl status docker"
    exit 1
  fi
fi

# --- Load Docker image ---
echo "==> Loading Docker image from ${IMAGE_FILE}..."
docker load --input "${IMAGE_FILE}"
echo "    Image loaded: ${IMAGE_NAME}:latest"

# --- Create working directory ---
mkdir -p "${COMPOSE_DIR}"

# --- Write .env file (readable only by owner) ---
cat > "${ENV_FILE}" <<EOF
CTF_KEY=${CTF_KEY}
EOF
chmod 600 "${ENV_FILE}"
echo "==> Created ${ENV_FILE}"

# --- Write docker-compose.yml ---
# Single-quoted HEREDOC delimiter prevents bash from expanding ${CTF_KEY} here;
# docker compose reads it from .env at runtime.
cat > "${COMPOSE_DIR}/docker-compose.yml" <<'COMPOSE_EOF'
version: '3.8'

services:
  juice-shop:
    image: bwi-juice-shop:latest
    container_name: juice-shop
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=bwi
      - CTF_KEY=${CTF_KEY}
COMPOSE_EOF
echo "==> Created ${COMPOSE_DIR}/docker-compose.yml"

# --- Start the container ---
echo "==> Starting Juice Shop..."
cd "${COMPOSE_DIR}"
docker compose --env-file "${ENV_FILE}" up --detach

# --- Poll for readiness ---
echo -n "    Waiting for Juice Shop to become ready (up to 90s)"
for i in $(seq 1 45); do
  if curl --silent --fail http://localhost:3000/rest/admin/application-version > /dev/null 2>&1; then
    echo " ready."
    break
  fi
  if [[ $i -eq 45 ]]; then
    echo ""
    echo "ERROR: Juice Shop did not become ready."
    echo "       Check logs: docker logs juice-shop"
    exit 1
  fi
  echo -n "."
  sleep 2
done

# --- Sanity checks ---
echo ""
echo "==> Sanity checks..."

if curl --silent --fail http://localhost:3000 | grep --quiet "LockHeedGünter"; then
  echo "    [OK] Custom shop name found"
else
  echo "    [WARN] Custom shop name not found — verify NODE_ENV=bwi and bwi.yml application.name"
fi

if curl --silent --fail http://localhost:3000/api/Products | grep --quiet "Eisenfaust"; then
  echo "    [OK] Military-themed products loaded"
else
  echo "    [WARN] Custom products not found — NODE_ENV may not be set correctly"
fi

echo ""
echo "======================================================="
echo " Setup complete!"
echo " Juice Shop: http://localhost:3000"
echo ""
echo " ACTION REQUIRED:"
echo "   Open a browser, verify the shop looks correct, then"
echo "   take a VirtualBox snapshot while the container is RUNNING:"
echo "   VirtualBox → Machine → Take Snapshot"
echo "   Name: CTF Ready — Do Not Delete"
echo "======================================================="
