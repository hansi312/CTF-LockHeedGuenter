#!/usr/bin/env bash
# Build the custom Juice Shop Docker image.
# Run from anywhere; the script resolves paths automatically.
# Requires: Docker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "==> Building custom Juice Shop image: ${IMAGE_NAME}:${IMAGE_TAG}"

# Create a minimal PNG placeholder if logo is missing
if [[ ! -f "${PROJECT_ROOT}/assets/logo.png" ]]; then
  echo "    WARNING: assets/logo.png not found — generating 1×1 pixel placeholder."
  echo "    Replace it with the real logo before the event."
  # Minimal valid PNG (1×1 white pixel) encoded as raw bytes
  printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' \
    > "${PROJECT_ROOT}/assets/logo.png"
fi

# Create a minimal PDF placeholder if blueprint file is missing
if [[ ! -f "${PROJECT_ROOT}/assets/bwi_nvg7_specs.pdf" ]]; then
  echo "    WARNING: assets/bwi_nvg7_specs.pdf not found — generating placeholder PDF."
  echo "    The Retrieve Blueprint challenge will work but the file content is meaningless."
  printf '%%PDF-1.4\n1 0 obj<</Type /Catalog /Pages 2 0 R>>endobj\n2 0 obj<</Type /Pages /Kids [3 0 R] /Count 1>>endobj\n3 0 obj<</Type /Page /MediaBox [0 0 612 792] /Parent 2 0 R>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4 /Root 1 0 R>>\nstartxref\n193\n%%%%EOF\n' \
    > "${PROJECT_ROOT}/assets/bwi_nvg7_specs.pdf"
fi

# Build from project root so Dockerfile can COPY from assets/ and juice-shop/
docker build \
  --file "${PROJECT_ROOT}/juice-shop/Dockerfile" \
  --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
  "${PROJECT_ROOT}"

IMAGE_SIZE=$(docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Size}}' | awk '{printf "%.0f MB", $1/1024/1024}')
echo "==> Build complete: ${IMAGE_NAME}:${IMAGE_TAG} (${IMAGE_SIZE})"
echo ""
echo "Next steps:"
echo "  Verify:           docker run -e NODE_ENV=bwi -e CTF_KEY=test -p 3000:3000 ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Export challenges: bash scripts/02-export-challenges.sh"
echo "  Save for VMs:      bash scripts/03-save-image.sh"
