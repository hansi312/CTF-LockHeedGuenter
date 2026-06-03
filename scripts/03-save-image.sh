#!/usr/bin/env bash
# Save the custom Juice Shop Docker image to a tar file for offline VM deployment.
# The resulting .tar is excluded from git (see .gitignore).
# Requires: Docker, built image (run 01-build-juice-shop.sh first)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

OUTPUT_PATH="${PROJECT_ROOT}/${IMAGE_FILE}"

echo "==> Saving Docker image to tar..."
echo "    Image : ${IMAGE_NAME}:${IMAGE_TAG}"
echo "    Output: ${OUTPUT_PATH}"

docker save "${IMAGE_NAME}:${IMAGE_TAG}" --output "${OUTPUT_PATH}"

SIZE=$(du -sh "${OUTPUT_PATH}" | cut -f1)
echo "==> Saved successfully (${SIZE})"
echo ""
echo "Transfer to each Kali VM:"
echo "  USB stick:            copy ${IMAGE_FILE} and scripts/04-vm-setup.sh"
echo "  scp:                  scp ${OUTPUT_PATH} kali@<VM_IP>:/home/kali/"
echo "  VirtualBox shared folder: mount the folder and copy from /media/sf_<name>/"
echo ""
echo "On each VM, run:"
echo "  CTF_KEY='<actual-key>' bash 04-vm-setup.sh"
