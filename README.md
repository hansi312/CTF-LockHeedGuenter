# BWI Developer Conference CTF — OWASP Juice Shop Setup

Customized OWASP Juice Shop for an internal CTF event. 6 teams each attack their own Juice Shop instance running in a Kali Linux VM. A central server runs CTFd for scoreboard and flag submission.

```
Central Server
  └── CTFd (port 80) ──────────── Teams submit flags here

Notebook 1..6 (each)
  └── VirtualBox → Kali Linux
        └── Docker → bwi-juice-shop:latest (port 3000)
              └── Teams attack http://localhost:3000
```

---

## Prerequisites

| Tool | Where |
|---|---|
| Docker + docker compose | Dev machine and Kali VMs |
| openssl | Dev machine |
| VirtualBox | Each notebook |
| ~2 GB free disk | Dev machine (for image tar) |

---

## Operator Checklist

### Step 0 — Customize before building

1. **Shop name**: Already set to `LockHeedGünter` in `juice-shop/config/bwi.yml`.
2. **Logo**: Replace `assets/logo.png` with the real logo (PNG, ~200×200 px, transparent background recommended). Update `application.logo` in `bwi.yml` to match the filename.
3. **Juice Shop version**: Pinned to `v20.0.0` in `juice-shop/Dockerfile`.

### Step 1 — Generate secrets (once)

```bash
openssl rand -hex 64    # → SECRET_KEY
openssl rand -hex 32    # → CTF_KEY  (same for all VMs + challenge export)
openssl rand -hex 16    # → MARIADB_PASSWORD
openssl rand -hex 16    # → MARIADB_ROOT_PASSWORD
```

Copy the template and fill in:

```bash
cp ctfd/.env.example ctfd/.env
# Edit ctfd/.env and replace all CHANGE_ME_ values
```

### Step 2 — Build the custom image

```bash
bash scripts/01-build-juice-shop.sh
```

This uses `ctfd/.env` to load `CTF_KEY`. The image `bwi-juice-shop:latest` is created locally.

> **Rebuild required after any change to:** `juice-shop/config/bwi.yml`, `juice-shop/Dockerfile`, or any file under `assets/`. The config and assets are baked into the image. After rebuilding, repeat Step 3.

### Step 3 — Export challenges to CTFd

```bash
bash scripts/02-export-challenges.sh
```

Starts a temporary Juice Shop container, runs `juice-shop-ctf-cli`, writes `challenge-export/ctfd_challenges.csv`, and automatically applies the challenge curation (96 visible / 16 hidden). The container is stopped automatically.

> **Re-export required after:** rebuilding the image (Step 2) or changing `CTF_KEY`.

### Step 4 — Set up CTFd (central server)

```bash
cd ctfd
docker compose up -d
```

Wait ~30 seconds for MariaDB to initialize, then open `http://<server-ip>/setup`:

- **Event name**: your CTF name
- **Mode**: Teams (recommended — one team per notebook)
- **Team size limit**: number of participants per table
- **Registration**: Open or Invite-only

Import challenges:
> Admin Panel → Config → Backup → Import → select `challenge-export/ctfd_challenges.csv`

The CSV already contains the curated set (96 visible, 16 hidden). See the **Challenge Curation** section for details.

Pre-create 6 teams and distribute credentials to each table.

**Test flag submission** (do this before the event):

```bash
# Start a local Juice Shop with the same CTF_KEY
docker run -d -e NODE_ENV=bwi -e CTF_KEY=$(grep CTF_KEY ctfd/.env | cut -d= -f2) \
  -p 3000:3000 bwi-juice-shop:latest
# Open http://localhost:3000, solve "DOM XSS", copy the flag code
# Submit to CTFd and verify it is accepted
```

### Step 5 — Prepare each Kali VM

Save the image to a tar file:

```bash
bash scripts/03-save-image.sh
# Output: bwi-juice-shop.tar (~500 MB–1 GB)
```

Transfer `bwi-juice-shop.tar` and `scripts/04-vm-setup.sh` to each VM (USB stick or scp).

Inside each Kali VM:

```bash
CTF_KEY='<actual-key-from-ctfd-env>' bash 04-vm-setup.sh
```

Verify the shop name and products appear correctly, then:

> **VirtualBox → Machine → Take Snapshot → "CTF Ready — Do Not Delete"**
>
> Take the snapshot while the container is **running**.

Repeat for all 6 VMs.

---

## Event Day

1. Start CTFd: `cd ctfd && docker compose up -d`
2. Restore all 6 VMs from the "CTF Ready" snapshot
3. Confirm Juice Shop is accessible at `http://localhost:3000` on each VM
4. Confirm CTFd is accessible at `http://<server-ip>/`
5. Distribute team credentials

**Between rounds** (optional score reset):

```
CTFd Admin Panel → Config → Reset → Reset Scores Only
```

Then restore all 6 VMs from snapshot.

---

## Architecture — Key Points

- `CTF_KEY` must be **identical** across all 6 Juice Shop instances and the challenge CSV export. One wrong character = all flags rejected.
- Each Juice Shop instance is **stateless per-session** (SQLite in-memory). Snapshot restore is a clean reset.
- The container runs with `restart: unless-stopped`, so it comes back automatically after snapshot restore.

---

## Challenge Curation

The curated challenge set is in `challenge-export/ctfd_challenges.csv`.
**108 of 111 Juice Shop challenges are visible; 3 are hidden (DoS only).**

### Visible challenges by difficulty

| Stars | Points | Count |
|---|---|---|
| ★ | 100 | 13 |
| ★★ | 250 | 18 |
| ★★★ | 450 | 25 |
| ★★★★ | 700 | 24 |
| ★★★★★ | 1000 | 16 |
| ★★★★★★ | 1350 | 12 |
| **Total** | | **108** |

### Hidden challenges

#### DoS / Crash (4) — can bring down a team's own Juice Shop instance
| Challenge | Points |
|---|---|
| NoSQL DoS | 700 |
| Blocked RCE DoS | 1000 |
| Memory Bomb | 1000 |
| XXE DoS | 1000 |

#### 6★ — enabled (12)
| Challenge | Points | Notes |
|---|---|---|
| Arbitrary File Write | 1350 | Also Danger Zone |
| Forged Coupon | 1350 | |
| Forged Signed JWT | 1350 | |
| Imaginary Challenge | 1350 | Intentionally unsolvable easter egg |
| Login Support Team | 1350 | |
| Multiple Likes | 1350 | |
| Premium Paywall | 1350 | |
| SSRF | 1350 | |
| SSTi | 1350 | Also Danger Zone |
| Successful RCE DoS | 1350 | Also Danger Zone + Crash |
| Video XSS | 1350 | Also Danger Zone |
| Wallet Depletion | 1350 | |

### Notes on specific challenges

| Challenge | Status | Notes |
|---|---|---|
| Meta Geo Stalking | ✅ Works | `kaserne-sommer.png` has GPS EXIF → Köln |
| Visual Geo Stalking | ✅ Works | `uebung-winter.png` has GPS EXIF → Frankfurt |
| Retrieve Blueprint | ✅ Works | `bwi_nvg7_specs.pdf` included in image |
| Christmas Special | ✅ Works | `useForChristmasSpecialChallenge` set on Adventskalender product |
| Pastebin Data Leak | ✅ Works (requires internet) | Needs outbound access to pastebin.com; solvable when internet is available |

---

## File Reference

```
juice-shop/config/bwi.yml     Custom Juice Shop configuration (name, products, CTF mode)
juice-shop/Dockerfile         Custom Docker image definition
juice-shop/docker-compose.vm.yml  Deployed to each Kali VM
assets/logo.png               Shop logo (replace with real file)
assets/bwi_nvg7_specs.pdf     Blueprint PDF for Retrieve Blueprint challenge
ctfd/docker-compose.yml       CTFd stack (CTFd + MariaDB + Redis + Nginx)
ctfd/.env.example             Secret template — copy to .env and fill in
ctfd/.env                     [NOT in git] Real secrets
challenge-export/ctf.config.yml  juice-shop-ctf-cli config
scripts/01-build-juice-shop.sh  Build custom Docker image
scripts/02-export-challenges.sh  Generate CTFd challenge CSV
scripts/03-save-image.sh      Save image as tar for offline transfer
scripts/04-vm-setup.sh        Setup script to run inside each Kali VM
```
