# homelab
Dashboard: https://lab.alexyoung.io (tailnet only). Each service is at `https://<service>.lab.alexyoung.io`.

## Setup
```
$ ./init.sh   # install apps, link configs (uses sudo)
$ cp .env.example .env   # fill in Homepage widget keys
$ $EDITOR ~/.config/homelab/cloudflare.env   # CF_DNS_API_TOKEN=... (Zone:DNS:Edit + Zone:Read on alexyoung.io), chmod 600
$ ./start.sh
```
## Helpful Commands
### Tail Logs
```
$ tail -f ~/Library/Application\ Support/Radarr/logs/radarr.debug.txt
```
### Test DNS
```
$ dig +short seerr.lab.alexyoung.io   # expect the homelab's Tailscale IP
```
### Restart a service
```
$ launchctl kickstart -k gui/$(id -u)/com.homelab.<service>
```
### Update Plex
Auto-update is off (it relaunches Plex outside launchd). Install the new version over the old one, then restart `com.homelab.plex`.
### Update Seerr
Bump `version` in `init.sh`'s `seerr()`, then:
```
$ cp -Rp /opt/seerr/config ~/seerr-config-backup
$ cd /opt/seerr && git fetch --tags && git checkout vX.Y.Z
$ CYPRESS_INSTALL_BINARY=0 pnpm install --frozen-lockfile && pnpm build
$ launchctl kickstart -k gui/$(id -u)/com.homelab.seerr
```
## Architecture
```mermaid
flowchart
    subgraph tailnet
        subgraph homelab
            nginx{nginx}
            nginx-->homepage
            nginx-->seerr
            nginx-->plex
            seerr-->radarr
            seerr-->sonarr
            seerr-->plex
            radarr<-->prowlarr
            sonarr<-->prowlarr
            prowlarr-->qbittorrent
            fs[(filesystem)]
            qbittorrent-->fs
            plex-->fs
        end
        Device01--"*.lab.alexyoung.io"-->nginx
        Device02--"*.lab.alexyoung.io"-->nginx
    end
```
