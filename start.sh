#!/usr/bin/env bash

main() {
    docker start flaresolverr || docker run -d --name flaresolverr -e LOG_LEVEL=info -p 8191:8191 --restart unless-stopped ghcr.io/flaresolverr/flaresolverr:latest
    launchctl list | awk '/com\.homelab\./ {print $3}' | while read -r service; do
        launchctl start "$service"
    done
}

main "$@"