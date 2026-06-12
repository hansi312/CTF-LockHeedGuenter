#!/usr/bin/env bash
# Renew Let's Encrypt certificates and reload nginx.
#
# Add to root crontab (crontab -e):
#   0 3 * * * cd /path/to/ctfd && bash renew-certs.sh >> /var/log/certbot-renew.log 2>&1
set -euo pipefail

cd "$(dirname "$0")"

echo "[$(date -Iseconds)] Running certificate renewal..."
docker compose run --rm certbot renew --webroot -w /var/www/certbot --quiet

echo "[$(date -Iseconds)] Reloading nginx..."
docker compose exec -T nginx nginx -s reload

echo "[$(date -Iseconds)] Done."
