# PLAN.md

Snapshot as of 2026-11-15. Last commit 2026-06-09; the repo has been idle ~5 months.

## History

| Date       | Phase | What landed |
|------------|-------|-------------|
| 2026-03-12 | Bootstrap the *arr stack | `init.sh` installers, launchd plists for Radarr, Sonarr, Prowlarr, Seerr; `start.sh`/`stop.sh`; FlareSolverr via Docker |
| 2026-04-08 | Reverse proxy + DNS | nginx via launchd, per-service vhosts on `*.local`, `/etc/hosts` block, public `tv.alexyoung.io` → Seerr, `init.sh main`, README with arch diagram |
| 2026-04-08 | (pushed only) | `7962843 wip` on `origin/main`: second public hostname for Seerr. **Not on local `main`.** |
| 2026-05-23 | Launchd hardening | Idempotent start/stop; plists for Plex and qBittorrent |
| 2026-06-09 | Fixup | `b5e7296 fixup 032e530`: `start.sh` reworked to bootstrap-or-kickstart from plist Labels |

## Branch state

- Was: local `main` 4 ahead / 1 behind `origin/main`, with an unsquashed fixup.
- 2026-11-15: rebased onto `origin/main` (fixup squashed into `fix(launchctl): makes scripts idempotent`) and fast-forward pushed. `7962843 wip` keeps its message since it was already public.

## Work in progress found on 2026-11-15 (main checkout, uncommitted)

All of this is now committed except dnsmasq (see Next steps §2).

Theme: **move local DNS from `*.local` to `*.lab` and make it work for other LAN devices**, plus expose Plex publicly.

1. **`.local` → `.lab` rename** across `hosts` and every `nginx/conf.d/*.conf` (`.local` is reserved for mDNS/Bonjour on macOS and resolves poorly).
2. **IPv6:** `listen [::]:80;` added to every service's local `:80` block.
3. **dnsmasq** (`opt/homebrew/etc/dnsmasq.conf`, staged, new): listens on `127.0.0.1` and the server's LAN IP, answers `seerr.lab` only; the `.lab` wildcard and `plex.lab` lines are commented out; upstream 1.1.1.1 / 8.8.8.8. The repo `opt/` directory is root-owned — it was probably created with `sudo`.
4. **Plex wrapper:** new `plex.sh` (`exec`s Plex Media Server); `init.sh plex()` symlinks it to `/usr/local/bin/plex.sh`; the plist now runs the wrapper. Not wired into `init.sh main`.
5. **Public Plex:** `watch.alexyoung.io` server block in `plex.conf` (`proxy_buffering off`).
6. **Second public Seerr host** in `seerr.conf` (same as `origin/main`'s `wip`).
7. **`init.sh main`:** every step except `dns` is commented out. This looks like a temporary edit to re-run only `dns`, and it should not be committed.

## Next steps

### 1. Reconcile git
- [x] Rebase local commits onto `origin/main`, squash the fixup, push.

### 2. Land the WIP as focused commits
- [x] `.local` → `.lab` rename, IPv6 listen, Plex wrapper script, public Plex hostname.
- [x] dnsmasq **retired** (2026-11-15): brew service stopped and uninstalled. Superseded by public DNS → Tailscale IP (§3).

### 3. Access model (2026-11-15)
Goal: easy, resilient access to every service from the host and the tailnet; limited public access later.
- [x] Names: `<service>.lab.alexyoung.io`, plus `lab.alexyoung.io` → Homepage. Subdomains, not paths: Plex and Seerr don't support a base path (Seerr's docs: "Base URLs cannot be configured").
- [x] Dropped `.lab`, the `hosts` file and `/etc/hosts` management, and the self-signed TLS redirect blocks.
- [x] Homepage v2.8.0 (Docker, compose) with widgets for Plex, Seerr, Radarr, Sonarr, Prowlarr and qBittorrent. FlareSolverr moved into the same `compose.yaml`, pinned to v3.5.2.
- [x] **DNS records (at Namecheap):** `lab` A `100.68.47.46` and `*.lab` A `100.68.47.46`. Use A records, not a CNAME to `*.ts.net`; the CNAME broke when the machine was renamed from `alexs-macbook-pro` to `alexs-homelab`.
- [x] Fill `.env` from `.env.example`. qBittorrent has no Web UI login, so its two vars stay empty.
- [x] Host cleanup: `/etc/hosts` homelab block, the root-owned `opt/` dir and `nginx/certs/` removed from the main checkout.
- [x] First start (2026-11-15): nginx reloaded on the new vhosts, pre-compose `flaresolverr` container removed, `docker compose up -d` from the main checkout. Every `*.lab.alexyoung.io` name answers, and all Homepage widgets show live data.
- [x] Public hostnames removed (2026-11-16): `tv.alexyoung.io`, `watch.alexyoung.io` and `tv.vasvikejriwal.com` vhosts dropped; their DNS records were already gone. Public Seerr is next.

### 4. TLS — evaluation (2026-11-15)
**Constraint:** the names resolve to a Tailscale CGNAT IP, so Let's Encrypt can't reach the server. The HTTP-01 and TLS-ALPN-01 challenges are out; **DNS-01 is the only option**, which needs API access to the DNS zone. DNS-01 also allows a wildcard cert (`*.lab.alexyoung.io` + `lab.alexyoung.io`): one cert for every service, with no per-service changes when services are added.

| Option | Verdict |
|---|---|
| **Move DNS to Cloudflare (free; Namecheap stays the registrar) + `lego` DNS-01** | **Recommended.** Cloudflare imports existing records, and an API token can be scoped to DNS edits on one zone. `lego` is a single Go binary (`brew install lego`) with first-class Cloudflare support. Renewal is `lego renew` in a daily launchd job that reloads nginx after renewing. The same zone also sets up Cloudflare Tunnel for public access later. |
| Namecheap API + lego/acme.sh | Fragile. Namecheap's API needs account eligibility (a balance/spend/domain-count threshold) and a **whitelisted static source IP**, which a home connection doesn't have. |
| `_acme-challenge` CNAME delegation to acme-dns / deSEC | Works and keeps Namecheap, but adds another service and account to keep alive. More moving parts than moving DNS. |
| certbot + `certbot-dns-cloudflare` | Works, but on macOS the plugin means pip-installing into Homebrew's certbot environment, which is brittle across upgrades. lego covers the same ground with one binary. |
| Caddy instead of nginx | Built-in automatic HTTPS, but DNS-01 needs a custom build with a Cloudflare module (not the stock brew formula), and it would replace a working nginx setup. Not worth it now. |
| Tailscale certs (`tailscale cert` / `serve`) | Only issues certs for `*.ts.net` names, not `lab.alexyoung.io`. |
| Manual DNS-01 | Not resilient: Let's Encrypt lifetimes are shrinking (90 → 45 days), so this would be a recurring chore. |

**Implemented (2026-11-16):**
- [x] DNS moved to Cloudflare (Namecheap stays registrar); all records DNS-only (grey cloud): GitHub Pages apex/www, Fastmail MX/SPF/DKIM, `lab` / `*.lab`.
- [x] API token with `Zone:DNS:Edit` + `Zone:Zone:Read` on `alexyoung.io`, in `~/.config/homelab/cloudflare.env` (mode 600).
- [x] `launchctl/com.homelab.lego.plist`: `lego run` (v5 issues and renews in one command, renewing only when due) at load and daily at 04:17, deploy hook `nginx -s reload`. Propagation is checked against `1.1.1.1` because the local resolver caches the challenge TXT record. Account and certs in `/usr/local/var/lego` — back it up.
- [x] nginx: shared `ssl_certificate` in `nginx.conf`, every lab vhost on `listen 443 ssl`, `:80` → 301 to https, `X-Forwarded-Proto` passed; Homepage `href`s on https.

### 5. Remaining gaps
- [x] 2026-11-17: `init.sh` installs Plex, qBittorrent (pinned dmg; the cask was disabled 2026-09-01 for failing Gatekeeper), Docker Desktop and Tailscale (via `Brewfile`). `state.sh` backs up and restores app state; the new-machine runbook is in `README.md`. The restore path has only been tested against scratch directories, not on a clean Mac.
- [ ] launchd jobs were bootstrapped from the repo's `launchctl/` directory, so they didn't come back after a reboot. `init.sh` now symlinks the plists into `~/Library/LaunchAgents` (a symlinked plist bootstraps fine). Re-run `init.sh` on this Mac, then confirm after the next reboot that all `com.homelab.*` jobs are loaded without `./start.sh`.
- [x] `init.sh` re-run safety: an earlier version wiped `/opt/seerr/config` (restored from a local APFS snapshot on 2026-11-15). It now skips existing installs, and the stray nested bundles from old runs were deleted 2026-11-16 (apps re-signed ad hoc).
- [x] nginx has no `default_server`: unknown hosts fall through to the first vhost (FlareSolverr). Add a catch-all returning 444. Done 2026-11-16 (`return 444` + `ssl_reject_handshake`).
- [x] `homepage.conf` proxies to `localhost:3000`, which nginx tries as `[::1]` first; Homepage only binds `127.0.0.1`, so every request logs a refused connection before falling back. Use `127.0.0.1:3000`. Done 2026-11-16.
- [x] 2026-11-16: blank Plex Web page over https. nginx temp dirs were owned by `nobody` (from a root-run nginx in March), so large responses were truncated and failed the page's integrity checks. Removed the empty dirs; nginx recreated them as the user.

- [x] 2026-11-17 hardening: launchd `KeepAlive` on crash; Plex self-update off (it had relaunched outside launchd); nginx passes WebSockets and sets proxy headers once; Seerr pinned to `v3.5.2`; qBittorrent Web UI on localhost; *arr login skipped for tailnet clients.

### 6. Deferred options (2026-11-16)
Researched, not started. Pick up from here.

**Public Seerr**
- **Recommended: Cloudflare Tunnel.** `cloudflared` as a launchd job dials out to Cloudflare; no open ports, home IP stays hidden, works behind CGNAT, free. Token stored outside the repo like the DNS token; public hostname → `http://localhost:5055` (skip nginx).
- Hostname must be one level deep (`seerr.alexyoung.io`, `requests.alexyoung.io`): the free Universal SSL cert covers `*.alexyoung.io`, not `seerr.lab.alexyoung.io` (that needs Advanced Certificate Manager, ~$10/mo). `seerr.lab` keeps working on the tailnet unchanged.
- Optional Cloudflare Access in front (email code / Google); Seerr already has its own Plex login.
- Rejected: Tailscale Funnel (only `*.ts.net` names), router port forward (exposes home IP), VPS proxy (another machine).
- Plex stays private; if ever needed, use Plex Remote Access (Cloudflare's terms forbid video streaming through a tunnel).

**`*.lab.alexyoung.io` on home Wi-Fi (off the tailnet)**
- The names resolve to the Tailscale IP, so they fail off-tailnet. Devices need `192.168.1.161` instead (reserve it via DHCP); nginx and the wildcard cert work unchanged.
- **Recommended: router DNS override** for `lab.alexyoung.io` + `*.lab.alexyoung.io` → `192.168.1.161`, if the router supports wildcards.
- Otherwise: a local DNS server (dnsmasq / AdGuard Home / Pi-hole; brings back what was retired and becomes a single point of failure for home DNS), or Tailscale for household members / node sharing for friends.
- Rejected: separate public names like `*.home.alexyoung.io` → private IP (two names per service; some routers block private IPs in public DNS answers).
- Devices with their own DNS (VPNs, iCloud Private Relay, browser DNS-over-HTTPS) ignore a router override. This Mac uses `10.2.0.1` (likely a VPN's DNS).

**LAN exposure of app ports**
- 2026-11-17: qBittorrent, Radarr, Sonarr and Prowlarr bind `127.0.0.1` (only via nginx and Homepage; verified unreachable on `192.168.1.161`). Still on all interfaces: Plex (expected for local clients) and Seerr (`:5055`, has its own login). FlareSolverr publishes `8191` on all interfaces via compose.
- Fix: block incoming connections per app in the macOS firewall, or bind each app to localhost where it supports that. Plex on the LAN is expected (local clients discover it).

## Open questions
- None. The Plex wrapper script (`plex.sh`) was removed 2026-11-17; the plist runs the app binary directly. If Plex loses access to `/Volumes/Lucy` after a reload, suspect TCC (external volume access) and restore the wrapper or grant Full Disk Access.
