# homelab
Dashboard: http://lab.alexyoung.io (tailnet only). Each service is at `http://<service>.lab.alexyoung.io`.

## Setup
```
$ ./init.sh   # install apps, link configs (uses sudo)
$ cp .env.example .env   # fill in Homepage widget keys
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
