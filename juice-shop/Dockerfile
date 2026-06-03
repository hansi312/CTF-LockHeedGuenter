# Custom Juice Shop image for BWI Developer Conference CTF
# Build context must be the project root:
#   docker build -f juice-shop/Dockerfile -t bwi-juice-shop:latest .
#
# Pin JUICE_SHOP_VERSION to a specific tag (e.g. v17.1.1) before the event
# to ensure the build is reproducible. Use "latest" only during development.

ARG JUICE_SHOP_VERSION=latest
FROM bkimminich/juice-shop:${JUICE_SHOP_VERSION}

# Custom configuration
COPY juice-shop/config/bwi.yml /juice-shop/config/bwi.yml

# Custom logo — place assets/logo.png in the repo before building.
# The filename here must match application.logo in bwi.yml.
COPY assets/logo.png \
     /juice-shop/frontend/dist/frontend/assets/public/images/logo.png

# Blueprint PDF for the "Retrieve Blueprint" challenge.
# Without this file the challenge returns 404 and cannot be solved.
COPY assets/bwi_nvg7_specs.pdf \
     /juice-shop/frontend/dist/frontend/assets/bwi_nvg7_specs.pdf

# Activate the custom config by default
ENV NODE_ENV=bwi

# CTF_KEY is NOT hardcoded here — inject at runtime via docker-compose / .env
# so that the shared secret is not baked into the image layer.

EXPOSE 3000
