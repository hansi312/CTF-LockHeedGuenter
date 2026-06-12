#!/usr/bin/env bash
# Run once from inside the ctfd/ directory on a fresh server to bootstrap TLS.
# Prerequisite: .env is filled in, DOMAIN points to this server's public IP.
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f .env ]; then
    echo "ERROR: .env not found. Run: cp .env.example .env  and fill in all values." >&2
    exit 1
fi

set -a; source .env; set +a

if [ -z "${DOMAIN:-}" ] || [ -z "${CERTBOT_EMAIL:-}" ]; then
    echo "ERROR: DOMAIN and CERTBOT_EMAIL must be set in .env" >&2
    exit 1
fi

LIVE_DIR=".data/letsencrypt/live/${DOMAIN}"

# Step 1: Bootstrap with a temporary self-signed cert so nginx can start.
# Without a cert file on disk the 443 server block causes nginx to refuse startup.
if [ ! -f "${LIVE_DIR}/fullchain.pem" ]; then
    echo "[1/5] Generating temporary self-signed certificate for ${DOMAIN}..."
    mkdir -p "${LIVE_DIR}"
    openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
        -keyout "${LIVE_DIR}/privkey.pem" \
        -out    "${LIVE_DIR}/fullchain.pem" \
        -subj   "/CN=${DOMAIN}" 2>/dev/null
    cp "${LIVE_DIR}/fullchain.pem" "${LIVE_DIR}/chain.pem"
else
    echo "[1/5] Certificate directory already exists, skipping self-signed bootstrap."
fi

# Step 2: Start nginx (and only nginx) so it can serve the ACME HTTP-01 challenge.
echo "[2/5] Starting nginx..."
docker compose up -d nginx
sleep 4

# Step 3: Obtain the real certificate from Let's Encrypt.
# Remove the bootstrap cert — certbot refuses to run if the live dir exists
# without a matching renewal conf, which the self-signed bootstrap doesn't have.
rm -rf "${LIVE_DIR}"

# DOMAIN_ALT is optional; if set, it is added as a SAN to the same certificate.
CERTBOT_DOMAINS="-d ${DOMAIN}"
if [ -n "${DOMAIN_ALT:-}" ]; then
    CERTBOT_DOMAINS="${CERTBOT_DOMAINS} -d ${DOMAIN_ALT}"
    echo "[3/5] Requesting Let's Encrypt certificate for ${DOMAIN} + ${DOMAIN_ALT}..."
else
    echo "[3/5] Requesting Let's Encrypt certificate for ${DOMAIN}..."
fi

docker compose run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    --email "${CERTBOT_EMAIL}" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    ${STAGING:+--staging} \
    ${CERTBOT_DOMAINS}

# Step 4: Reload nginx so it picks up the real cert (replaces the self-signed one).
echo "[4/5] Reloading nginx with real certificate..."
docker compose exec nginx nginx -s reload

# Step 5: Bring up the full stack.
echo "[5/5] Starting full CTFd stack..."
docker compose up -d

echo ""
echo "Done! CTFd is running at https://${DOMAIN}/"
echo ""
echo "Add this line to the root crontab (crontab -e) for automatic renewal:"
echo "  0 3 * * * cd $(pwd) && bash renew-certs.sh >> /var/log/certbot-renew.log 2>&1"
