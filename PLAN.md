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
- [ ] **DNS records (manual, at Namecheap):** `lab` A `100.68.47.46` and `*.lab` A `100.68.47.46`. Use A records, not a CNAME to `*.ts.net`; the CNAME broke when the machine was renamed from `alexs-macbook-pro` to `alexs-homelab`.
- [ ] Fill `.env` from `.env.example`.
- [ ] Host cleanup (manual, needs sudo): remove the `# Begin homelab`…`# End homelab` block from `/etc/hosts`; delete the root-owned `opt/` dir and `nginx/certs/` in the main checkout.
- [ ] First start with the new setup: `nginx -s stop` (to clear any daemonized nginx), `docker rm -f flaresolverr` (to clear the pre-compose container), then `./init.sh` and `./start.sh`.
- [ ] **Deferred: public access.** `tv.alexyoung.io` / `watch.alexyoung.io` still CNAME to the stale `alexs-macbook-pro` name, so they're broken. Until then, either repoint them as A → `100.68.47.46` (tailnet-only) or remove them. Option to evaluate later: Cloudflare Tunnel for Seerr (custom domain, optional Cloudflare Access login), and Plex's built-in Remote Access for Plex (Cloudflare's terms forbid video streaming through the tunnel).

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

**Proposed implementation (after the DNS move):**
- [ ] Cloudflare: add the zone, verify the imported records, switch nameservers at Namecheap. Keep `lab` / `*.lab` **DNS-only (grey cloud)**: proxied records can't reach a `100.x` IP.
- [ ] API token scoped to `Zone:DNS:Edit` on `alexyoung.io`, stored outside the repo (e.g. `~/.config/homelab/cloudflare.env`, mode 600).
- [ ] `init.sh tls()`: `brew install lego`, then the first issue for `lab.alexyoung.io` + `*.lab.alexyoung.io` into a cert dir outside the repo.
- [ ] `launchctl/com.homelab.lego-renew.plist`: daily `StartCalendarInterval` running `lego renew --days 30 --renew-hook "nginx -s reload"`.
- [ ] nginx: one shared `ssl` snippet included by every vhost; `listen 443 ssl`; `:80` → 301 to https; switch Homepage `href`s to https.

### 5. Remaining gaps
- [ ] No `init.sh` functions for Plex/qBittorrent install (`brew install --cask plex-media-server qbittorrent`?), or for Docker Desktop.
- [ ] Not verified on the host: `init.sh` and `start.sh` haven't been run since these changes. As of 2026-11-15, no `com.homelab.*` jobs are loaded.

## Open questions
- Is `tv.vasvikejriwal.com` meant to stay? It probably has the same stale CNAME.
- What prompted the Plex wrapper script — Full Disk Access/TCC, or the path with spaces?
