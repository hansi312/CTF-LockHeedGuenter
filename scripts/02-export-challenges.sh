#!/usr/bin/env bash
# Generate a CTFd-importable challenge CSV from the running Juice Shop image.
# Starts a temporary Juice Shop container, runs juice-shop-ctf-cli, then cleans up.
# Requires: Docker, CTF_KEY set in ctfd/.env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

EXPORT_DIR="${PROJECT_ROOT}/challenge-export"
OUTPUT_FILE="ctfd_challenges.csv"
RESOLVED_CONFIG="${EXPORT_DIR}/ctf.config.resolved.yml"

echo "==> Starting temporary Juice Shop container for challenge export..."

CONTAINER_ID=$(docker run --detach \
  --rm \
  --publish 3000:3000 \
  --env "NODE_ENV=bwi" \
  --env "CTF_KEY=${CTF_KEY}" \
  "${IMAGE_NAME}:${IMAGE_TAG}")

echo "    Container: ${CONTAINER_ID:0:12}"

# Poll until ready (max 90s)
echo -n "    Waiting for Juice Shop to become ready"
for i in $(seq 1 45); do
  if curl --silent --fail http://localhost:3000/rest/admin/application-version > /dev/null 2>&1; then
    echo " ready."
    break
  fi
  if [[ $i -eq 45 ]]; then
    echo ""
    echo "ERROR: Juice Shop did not become ready within 90 seconds."
    docker stop "${CONTAINER_ID}" > /dev/null
    exit 1
  fi
  echo -n "."
  sleep 2
done

# Write a resolved config with the actual CTF_KEY substituted
# (the committed config uses a placeholder to avoid storing secrets in git)
sed "s/CHANGE_ME_same_as_CTF_KEY_in_ctfd_env/${CTF_KEY}/" \
  "${EXPORT_DIR}/ctf.config.yml" > "${RESOLVED_CONFIG}"

echo "==> Running juice-shop-ctf-cli..."

docker run --rm \
  --network host \
  --volume "${EXPORT_DIR}:/data" \
  bkimminich/juice-shop-ctf:v12.0.0 \
  --config "/data/$(basename "${RESOLVED_CONFIG}")" \
  --output "/data/${OUTPUT_FILE}"

echo "==> Stopping temporary Juice Shop container..."
docker stop "${CONTAINER_ID}" > /dev/null

# Remove resolved config — it contains the real CTF_KEY
rm -f "${RESOLVED_CONFIG}"

# ---------------------------------------------------------------------------
# Curate challenges: hide DoS/crash challenges only.
# 6★ (1350 pt) challenges are intentionally left visible.
# See README "Challenge Curation" section for rationale.
# ---------------------------------------------------------------------------
echo "==> Applying challenge curation..."

python3 - "${EXPORT_DIR}/${OUTPUT_FILE}" << 'PYTHON'
import csv, sys

INPUT = sys.argv[1]

# Challenges that can crash or DoS the Juice Shop container
HIDE_DOS_CRASH = {
    "NoSQL DoS",
    "Blocked RCE DoS",
    "Memory Bomb",
    "XXE DoS",
}

with open(INPUT, newline='') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    rows = list(reader)

hidden = []
for r in rows:
    if r['name'] in HIDE_DOS_CRASH:
        r['state'] = 'hidden'
        hidden.append(r['name'])

with open(INPUT, 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

visible = sum(1 for r in rows if r['state'] == 'visible')
print(f"    Visible: {visible}  |  Hidden: {len(hidden)}")
for name in sorted(hidden):
    print(f"      - {name}")
PYTHON

echo ""
echo "==> Challenge export complete: ${EXPORT_DIR}/${OUTPUT_FILE}"
echo ""
echo "Import into CTFd:"
echo "  Admin Panel → Config → Backup → Import → select ${OUTPUT_FILE}"
