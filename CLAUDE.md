# CLAUDE.md

Personal media homelab running natively on a single Apple Silicon Mac. FlareSolverr and Homepage run in Docker (`compose.yaml`); everything else is a macOS app/binary supervised by `launchd`, all fronted by an nginx reverse proxy. The repo is the declarative-ish source of truth: install scripts, launchd plists, compose file, nginx vhosts.

## Principles

- For every new feature, pick the most reliable, best-suited tool for the job (official install method, pinned versions, supported config over workarounds).
- When planning, favor the simplest implementation that works; remove moving parts rather than add them.
- Keep commits small and atomic: one logical change per commit.

## Stack

| Service      | Role                          | Runs as                                   | Port  |
|--------------|-------------------------------|-------------------------------------------|-------|
| nginx        | Reverse proxy (vhosts), TLS   | launchd → `/opt/homebrew/bin/nginx`       | 80, 443 |
| lego         | Let's Encrypt cert (daily)   | launchd → `/opt/homebrew/bin/lego`        | —     |
| Homepage     | Dashboard at `lab.alexyoung.io` | Docker (compose), bound to 127.0.0.1    | 3000  |
| Seerr        | Request UI                    | launchd → node@22 `/opt/seerr/dist/index.js` | 5055 |
| Plex         | Media server                  | launchd → Plex Media Server.app           | 32400 |
| Radarr       | Movies                        | launchd → `/Applications/Radarr.app`      | 7878  |
| Sonarr       | TV                            | launchd → `/Applications/Sonarr.app`      | 8989  |
| Prowlarr     | Indexer manager               | launchd → `/Applications/Prowlarr.app`    | 9696  |
| qBittorrent  | Download client (Web UI only) | launchd → `/Applications/qBittorrent.app` (agent app, no Dock icon) | 8080  |
| FlareSolverr | Cloudflare challenge solver   | Docker (compose)                          | 8191  |

Flow: Seerr → Radarr/Sonarr ↔ Prowlarr → qBittorrent → filesystem ← Plex. See the mermaid diagram in `README.md`. Access: every service is `<service>.lab.alexyoung.io`, plus `lab.alexyoung.io` for Homepage. Public DNS has `lab` and `*.lab` A records pointing at the homelab's Tailscale IP, so the names work on the host and anywhere on the tailnet, and nowhere else. Public internet access is deferred (see `PLAN.md`).

## Layout

- `init.sh` — machine setup, meant to be safe to re-run. One bash function per service (`logs`, `plex`, `radarr`, `sonarr`, `prowlarr`, `qbittorrent`, `seerr`, `nginx`), called from `main`. Downloads arm64 builds to `/tmp`, moves to `/Applications`, ad-hoc codesigns and strips quarantine. Seerr is built from source into `/opt/seerr`. Plex and qBittorrent are installed manually (Homebrew's qBittorrent cask is disabled; get the dmg from the official SourceForge `qbittorrent-mac` folder). `qbittorrent()` only sets `LSUIElement` and re-signs the app so it runs without a Dock icon; re-run `init.sh` after replacing the app.
- `start.sh` / `stop.sh` — start/stop everything. `start.sh` iterates `launchctl/*.plist`, reads each `Label` via `plutil`, and `kickstart -k`s if loaded or `bootstrap`s if not (idempotent). `stop.sh` `bootout`s every loaded `com.homelab.*` job. Both also run `docker compose up -d` / `stop` for the containers. All three scripts `cd` to their own directory first.
- `plex.sh` — wrapper that `exec`s Plex Media Server; symlinked to `/usr/local/bin/plex.sh` and used by the Plex plist.
- `launchctl/com.homelab.<service>.plist` — LaunchAgents in the `gui/$(id -u)` domain. Logs (where configured) go to `/usr/local/var/log/homelab.<service>[.error].log`.
- `nginx/nginx.conf` — sets the shared `ssl_certificate` (lego's `/usr/local/var/lego/certificates/lab.alexyoung.io.{crt,key}`) and a `:80` server that 301s every lab name to https; includes `/usr/local/etc/nginx/conf.d/*.conf`. `init.sh` symlinks `nginx/` → `/usr/local/etc/nginx` and `nginx.conf` → `/opt/homebrew/etc/nginx/nginx.conf`, so edits in the repo are live after an nginx reload.
- `nginx/conf.d/<service>.conf` — one file per service: a `listen 443 ssl` server block for `<service>.lab.alexyoung.io` that `proxy_pass`es to `localhost:<port>` (the cert is inherited from `nginx.conf`). Proxy headers (Host, X-Forwarded-*, WebSocket Upgrade) are also set once in `nginx.conf`; don't add `proxy_set_header` in a vhost, or it stops inheriting all of them.
- `compose.yaml` — FlareSolverr and Homepage, with pinned image tags.
- `homepage/config/*.yaml` — Homepage config. Widget secrets are `{{HOMEPAGE_VAR_*}}` placeholders filled from a gitignored `.env` (template: `.env.example`). Widgets reach host services via `host.docker.internal`.
- `nginx/nginx.conf` also has a `default_server` that closes connections (444, TLS handshake rejected) for any name without a vhost.
- nginx runs in the foreground (`-g 'daemon off;'` in its plist) so launchd can supervise it. Don't remove that. Never run nginx with `sudo`: root-run nginx recreates `/opt/homebrew/var/run/nginx/*_temp` owned by `nobody`, and the user-run nginx then truncates large proxied responses (blank Plex Web page). Fix: `rmdir` those empty dirs and reload.
- TLS: `launchctl/com.homelab.lego.plist` runs `lego run` at load and daily; it proves control via Cloudflare DNS-01 (token in `~/.config/homelab/cloudflare.env`, outside the repo), renews only when due and reloads nginx. One wildcard cert covers every `*.lab` service.

## Conventions

- **Commits:** Conventional Commits, scope = service or component: `feat(sonarr): run bin via launchctl`, `fix(launchctl): makes scripts idempotent`, `doc(README): ...`. The author uses `git commit --fixup` + autosquash; don't push `fixup ...` commits — squash them first.
- **Adding a service** touches, in order: an `init.sh` function (+ call in `main`), `launchctl/com.homelab.<svc>.plist`, `nginx/conf.d/<svc>.conf` (copy an existing one, change `server_name` and port), and a tile in `homepage/config/services.yaml`. DNS and TLS are covered by the wildcard record and cert.
- **Shell:** bash, `main() { ... }; main "$@"`, `local` vars, 2-space indent in `init.sh`, 4-space in `start.sh`/`stop.sh`. Target is macOS: BSD userland (`mv`, `sed`, etc. — no GNU long flags), `launchctl`, `plutil`, Homebrew at `/opt/homebrew`.
- **launchd:** use the modern `bootstrap` / `bootout` / `kickstart` / `print` subcommands with `gui/$(id -u)/<label>`, not `load`/`start`/`stop`.

- **App settings outside the repo** (set in each app's UI or API; re-apply after a reinstall):
  - Plex: Server version updates = "Ask me" (`init.sh` sets it).
  - Radarr/Sonarr/Prowlarr: Bind Address `127.0.0.1` (reachable only via nginx and Homepage); Authentication Required = "Disabled for Local Addresses" (they count private LAN IPs as local, so this is only safe while bound to localhost). nginx omits `X-Forwarded-For` for them so tailnet clients count as local.
  - qBittorrent: Web UI bound to `127.0.0.1` (reachable only via nginx), "Bypass authentication for clients on localhost" on.
- launchd jobs use `KeepAlive` → `SuccessfulExit=false`: restart on crash, not after a clean exit (apps quit to self-update). Plist edits need `bootout` + `bootstrap` (kickstart keeps the old definition); a `bootstrap` right after `bootout` can fail with error 5 while the old job unloads: wait and retry. Quit Plex with `osascript -e 'tell application id "com.plexapp.plexmediaserver" to quit'` before a `bootout`; it ignores SIGTERM.

## Working here

- These scripts mutate the host (`sudo`, `/Applications`, `/opt`, launchd, Docker). Don't run `init.sh`, `start.sh`, `stop.sh`, or `sudo` commands without asking. Read-only checks are fine: `nginx -t`, `plutil -lint launchctl/*.plist`, `launchctl print gui/$(id -u)/com.homelab.<svc>`, `bash -n *.sh`, `shellcheck`.
- After editing nginx config: `nginx -t` then `nginx -s reload` (ask before reloading).
- Logs: `tail -f /usr/local/var/log/homelab.<svc>.error.log`; the *arr apps also log under `~/Library/Application Support/<App>/logs/`.
- Public hostnames and the Tailscale IP live in these configs; treat them as private and don't send them to outside services.
- Current in-progress work and known issues: see `PLAN.md`.
