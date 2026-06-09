# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

Customized OWASP Juice Shop CTF setup for the BWI Developer Conference. 6 teams each attack their own isolated Juice Shop instance on a Kali Linux VM. A central server runs CTFd for scoreboard and flag submission. The shop is themed as "LockHeedGünter" — a fictional military equipment store.

## Key constraint: CTF_KEY

`CTF_KEY` must be **identical** across all 6 Juice Shop instances and the challenge CSV export. It is set once in `ctfd/.env` and sourced automatically by all scripts via `scripts/lib/common.sh`. One wrong character = all flags rejected across the entire event.

## Scripts (run in order)

All scripts are run from the project root. They source `ctfd/.env` automatically.

```bash
bash scripts/01-build-juice-shop.sh   # Build custom Docker image (bwi-juice-shop:latest)
bash scripts/02-export-challenges.sh  # Generate challenge-export/ctfd_challenges.csv
bash scripts/03-save-image.sh         # Save image as bwi-juice-shop.tar for VM transfer
CTF_KEY='<key>' bash scripts/04-vm-setup.sh  # Run inside each Kali VM
```

**Rebuild image required after:** any change to `juice-shop/config/bwi.yml`, `juice-shop/Dockerfile`, or files under `assets/`. After rebuilding, re-export challenges and regenerate the tar.

## CTFd stack

```bash
cd ctfd && docker compose up -d   # Start CTFd + MariaDB + Redis + Nginx on port 80
```

Secrets live in `ctfd/.env` (not in git). Template is `ctfd/.env.example`.

## Architecture

```
juice-shop/Dockerfile         Extends bkimminich/juice-shop:v20.0.0, bakes in config + assets
juice-shop/config/bwi.yml     Shop name, products, CTF mode — NODE_ENV=bwi activates this
assets/                       Logo, favicon, product images, geo-EXIF images, blueprint PDF
challenge-export/ctf.config.yml  juice-shop-ctf-cli config (supported fields: ctfFramework,
                                 juiceShopUrl, ctfKey, insertHints only — v12 schema)
scripts/02-export-challenges.sh  Runs juice-shop-ctf-cli then hides DoS challenges via Python
ctfd/custom/                  CTFd HTML/CSS customization files (military dark theme)
```

The Docker build context must be the project root (not `juice-shop/`) because the Dockerfile copies from `assets/` and `juice-shop/config/`.

## CTFd customization

All three files in `ctfd/custom/` are pasted manually into the CTFd admin panel — they are not mounted or deployed automatically:

| File | Where to paste |
|---|---|
| `theme-header.html` | Admin → Config → Appearance → Theme → Header |
| `landing.html` | Admin → Pages → New Page, route `/`, format `html` |
| `prizes.html` | Admin → Pages → New Page, route `/prizes`, format `html` |

`theme-header.html` contains all CSS (global dark theme + landing + prizes page styles) and the active-nav-link JS. `landing.html` and `prizes.html` contain only HTML — no `<style>` tags.

## Challenge curation

`scripts/02-export-challenges.sh` applies curation automatically after each export. Currently: 108 visible, 3 hidden (DoS/crash only). The curation logic is a Python block at the end of the script — edit `HIDE_DOS_CRASH` there to change which challenges are hidden.

## Assets that are challenge-critical

- `assets/memories/kaserne-sommer.png` — GPS EXIF set to Köln (Meta Geo Stalking)
- `assets/memories/uebung-winter.png` — GPS EXIF set to Frankfurt (Visual Geo Stalking)
- `assets/bwi_nvg7_specs.pdf` — served at `/assets/bwi_nvg7_specs.pdf` (Retrieve Blueprint)

Do not strip EXIF data from the geo images or replace the PDF without updating the challenge hints.