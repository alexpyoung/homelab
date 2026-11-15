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
- [x] `.local` → `.lab` rename, IPv6 listen, Plex wrapper script, public Plex hostname (2026-11-15). `init.sh main` restored, with `plex` added.
- [ ] **dnsmasq — blocked on decisions.** The WIP config is still uncommitted in the main checkout at `opt/homebrew/etc/dnsmasq.conf` (root-owned dir). Findings:
  - The LAN IP drifts: the WIP config uses `192.168.1.10`, `en0` is currently `192.168.1.161`, and a hand-added `/etc/hosts` line uses `.180`. Pick a DHCP reservation or use the Tailscale IP (`100.68.47.46`, stable).
  - The live `/opt/homebrew/etc/dnsmasq.conf` is a different March config (`port=5354`, `tv.alexyoung.io` → Tailscale IP), running as a *user* brew service. Its log shows `Permission denied` binding :53 as non-root, which is why it uses 5354. Router DHCP DNS and Tailscale split DNS both need :53, so it has to run as root (`sudo brew services start dnsmasq`).
  - dnsmasq serves `/etc/hosts` by default, which would hand LAN clients `127.0.0.1` for `*.lab` → needs `no-hosts`.
  - To do: move the config to `dnsmasq/dnsmasq.conf`, use the wildcard `address=/lab/<ip>`, add `init.sh dnsmasq()` (symlink + root service), and document the router / Tailscale split-DNS setup.

### 3. Bugs and gaps found during review
- [x] `init.sh seerr`: BSD `mv --force`, non-empty `/tmp/seerr` / `/opt/seerr`, `source ~/.zshrc` from bash, `which node` vs keg-only node@22.
- [x] `init.sh dns`: now replaces the `# Begin homelab`…`# End homelab` block instead of appending. Re-run it once to clean the existing `/etc/hosts`.
- [x] `init.sh nginx`: `ln -sfn`; the cert is only generated if missing.
- [x] `init.sh` runs from its own directory and creates `/usr/local/var/log`.
- [x] `hosts`: added `flaresolverr.lab`.
- [x] `com.homelab.nginx.plist`: `-g 'daemon off;'`. This was the cause of the `bind() ... Address already in use` loop in `homelab.nginx.error.log`. **Before the first start with the new plist, stop any stray daemonized nginx (`nginx -s stop`).**
- [x] Log paths added for the radarr, plex and qbittorrent plists.
- [x] `stop.sh` iterates plist Labels like `start.sh`; both `cd` to their own directory; shellcheck clean.
- [ ] No `init.sh` functions for Plex/qBittorrent install (`brew install --cask plex-media-server qbittorrent`?), or for installing Docker/FlareSolverr.
- [ ] The 443 blocks use a self-signed cert only to 301 to HTTP, and public hosts are HTTP-only at nginx. Confirm TLS terminates upstream (Cloudflare? Tailscale Funnel?) and document it.
- [ ] Not verified on the host: none of the changes have been run (`init.sh`, `start.sh`). As of 2026-11-15, no `com.homelab.*` jobs are loaded; only the FlareSolverr container and the old user-level dnsmasq are running.

### 4. Nice to have
- [ ] README: setup steps (`init.sh` → `start.sh`), port table, how public DNS reaches the box.
- [ ] `shellcheck` all scripts; `plutil -lint` plists; `nginx -t` as a pre-commit check.
- [ ] Templating for conf.d (they are 95% identical).

## Open questions
- How does public traffic reach the Mac (port-forward, Cloudflare Tunnel, Tailscale Funnel)? The README says "CNAME → homelab" but doesn't say what's behind it.
- Is the second public Seerr hostname meant to be permanent (shared with someone else)?
- What prompted the Plex wrapper script — Full Disk Access/TCC, or the path with spaces?
