# CLAUDE.md

Personal media homelab running natively on a single Apple Silicon Mac. No containers except FlareSolverr; everything else is a macOS app/binary supervised by `launchd` and fronted by an nginx reverse proxy. The repo is the declarative-ish source of truth: install scripts, launchd plists, nginx vhosts, and DNS entries.

## Stack

| Service      | Role                          | Runs as                                   | Port  |
|--------------|-------------------------------|-------------------------------------------|-------|
| nginx        | Reverse proxy (vhosts)        | launchd → `/opt/homebrew/bin/nginx`       | 80/443|
| Seerr        | Request UI (public)           | launchd → node@22 `/opt/seerr/dist/index.js` | 5055 |
| Plex         | Media server (public WIP)     | launchd → Plex Media Server.app           | 32400 |
| Radarr       | Movies                        | launchd → `/Applications/Radarr.app`      | 7878  |
| Sonarr       | TV                            | launchd → `/Applications/Sonarr.app`      | 8989  |
| Prowlarr     | Indexer manager               | launchd → `/Applications/Prowlarr.app`    | 9696  |
| qBittorrent  | Download client               | launchd → `/Applications/qBittorrent.app` | 8080  |
| FlareSolverr | Cloudflare challenge solver   | Docker container `flaresolverr`           | 8191  |

Flow: Seerr → Radarr/Sonarr ↔ Prowlarr → qBittorrent → filesystem ← Plex. See the mermaid diagram in `README.md`. Access is over a Tailscale tailnet (private DNS) plus public DNS (CNAME) for Seerr.

## Layout

- `init.sh` — one-time machine setup. One bash function per service (`radarr`, `sonarr`, `prowlarr`, `seerr`, `nginx`, `dns`), called from `main`. Downloads arm64 builds to `/tmp`, moves to `/Applications`, ad-hoc codesigns and strips quarantine. Seerr is built from source into `/opt/seerr`. Plex and qBittorrent are installed manually (no init function yet).
- `start.sh` / `stop.sh` — start/stop everything. `start.sh` iterates `launchctl/*.plist`, reads each `Label` via `plutil`, and `kickstart -k`s if loaded or `bootstrap`s if not (idempotent). `stop.sh` `bootout`s every loaded `com.homelab.*` job. Both also start/stop the FlareSolverr container. Run from the repo root (paths are relative).
- `launchctl/com.homelab.<service>.plist` — LaunchAgents in the `gui/$(id -u)` domain. Logs (where configured) go to `/usr/local/var/log/homelab.<service>[.error].log`.
- `nginx/nginx.conf` — minimal; includes `/usr/local/etc/nginx/conf.d/*.conf`. `init.sh` symlinks `nginx/` → `/usr/local/etc/nginx` and `nginx.conf` → `/opt/homebrew/etc/nginx/nginx.conf`, so edits in the repo are live after an nginx reload.
- `nginx/conf.d/<service>.conf` — one file per service: a `443 ssl` block (self-signed cert from `nginx/certs/`, gitignored) that 301s to HTTP, and a `:80` block that `proxy_pass`es to `localhost:<port>`. Public hostnames get an extra `:80` server block in the same file.
- `hosts` — block appended to `/etc/hosts` by `init.sh dns`, delimited by `# Begin homelab` / `# End homelab`.

## Conventions

- **Commits:** Conventional Commits, scope = service or component: `feat(sonarr): run bin via launchctl`, `fix(launchctl): makes scripts idempotent`, `doc(README): ...`. The author uses `git commit --fixup` + autosquash; don't push `fixup ...` commits — squash them first.
- **Adding a service** touches, in order: an `init.sh` function (+ call in `main`), `launchctl/com.homelab.<svc>.plist`, `nginx/conf.d/<svc>.conf` (copy an existing one, change `server_name` and port), and a `hosts` (and dnsmasq, once landed) entry.
- **Shell:** bash, `main() { ... }; main "$@"`, `local` vars, 2-space indent in `init.sh`, 4-space in `start.sh`/`stop.sh`. Target is macOS: BSD userland (`mv`, `sed`, etc. — no GNU long flags), `launchctl`, `plutil`, Homebrew at `/opt/homebrew`.
- **launchd:** use the modern `bootstrap` / `bootout` / `kickstart` / `print` subcommands with `gui/$(id -u)/<label>`, not `load`/`start`/`stop`.

## Working here

- These scripts mutate the host (`sudo`, `/etc/hosts`, `/Applications`, `/opt`, launchd). Don't run `init.sh`, `start.sh`, `stop.sh`, or `sudo` commands without asking. Read-only checks are fine: `nginx -t`, `plutil -lint launchctl/*.plist`, `launchctl print gui/$(id -u)/com.homelab.<svc>`, `bash -n *.sh`, `shellcheck`.
- After editing nginx config: `nginx -t` then `nginx -s reload` (ask before reloading).
- Logs: `tail -f /usr/local/var/log/homelab.<svc>.error.log`; the *arr apps also log under `~/Library/Application Support/<App>/logs/`.
- Public hostnames and LAN IPs live in nginx/dnsmasq configs; treat them as private and don't send them to outside services.
- Current in-progress work and known issues: see `PLAN.md`.
