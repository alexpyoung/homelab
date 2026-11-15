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

## Uncommitted work in progress (main checkout)

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

### 2. Land the `.lab` / dnsmasq work as focused commits
- [ ] `feat(dns): rename local domains .local -> .lab` (hosts + conf.d server_names). Also update README if it mentions `.local`.
- [ ] `feat(nginx): listen on IPv6`
- [ ] `feat(dns): dnsmasq for LAN resolution`. Decide where it lives (`dnsmasq/dnsmasq.conf` to match `nginx/` rather than a root-owned `opt/homebrew/etc/` mirror). Enable the `address=/.lab/<ip>` wildcard. Add an `init.sh dnsmasq()` (brew install, symlink config, `sudo brew services start dnsmasq` since it needs port 53). Document pointing the router or Tailscale split-DNS at it.
- [ ] `feat(plex): launch via wrapper script` + `feat(plex): public hostname`
- [ ] Restore `init.sh main` before committing.

### 3. Bugs and gaps found during review
- [ ] `init.sh seerr`: `sudo mv --force` fails on macOS (BSD `mv` has no long flags) → use `-f`. `source ~/.zshrc` inside a bash script is ineffective/odd.
- [ ] `init.sh dns`: appends to `/etc/hosts` on every run. After the rename, re-running it leaves the stale `.local` block alongside the new `.lab` one. Make it replace the `# Begin homelab`…`# End homelab` block instead.
- [ ] `init.sh nginx`: `ln -s` without `-f`/existence check isn't idempotent; the cert is regenerated on every run.
- [ ] `hosts` has no `flaresolverr` entry even though there's an nginx vhost for it.
- [ ] `com.homelab.nginx.plist`: nginx daemonizes by default, so launchd loses track of it. Add `-g 'daemon off;'` to `ProgramArguments` (or `daemon off;` in `nginx.conf`) so `kickstart -k` / `bootout` actually control it.
- [ ] Inconsistent logging: radarr, plex, qbittorrent plists have no `StandardOutPath`/`StandardErrorPath`.
- [ ] `stop.sh` discovers jobs via `launchctl list | awk`, while `start.sh` reads plist Labels. Align them (iterate plists in both).
- [ ] No `init.sh` functions for Plex/qBittorrent install, or for installing Docker/FlareSolverr.
- [ ] The 443 blocks use a self-signed cert only to 301 to HTTP, and public hosts are HTTP-only at nginx. Confirm TLS terminates upstream (Cloudflare? Tailscale Funnel?) and document it.

### 4. Nice to have
- [ ] README: setup steps (`init.sh` → `start.sh`), port table, how public DNS reaches the box.
- [ ] `shellcheck` all scripts; `plutil -lint` plists; `nginx -t` as a pre-commit check.
- [ ] Templating for conf.d (they are 95% identical).

## Open questions
- How does public traffic reach the Mac (port-forward, Cloudflare Tunnel, Tailscale Funnel)? The README says "CNAME → homelab" but doesn't say what's behind it.
- Is the second public Seerr hostname meant to be permanent (shared with someone else)?
- What prompted the Plex wrapper script — Full Disk Access/TCC, or the path with spaces?
