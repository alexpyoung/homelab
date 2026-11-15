#!/usr/bin/env bash

main() {
    cd "$(dirname "$0")" || exit 1
    docker start flaresolverr || docker run -d --name flaresolverr -e LOG_LEVEL=info -p 8191:8191 --restart unless-stopped ghcr.io/flaresolverr/flaresolverr:latest
    local -r domain="gui/$(id -u)"
    for plist in ./launchctl/*.plist; do
        local service=$(plutil -extract Label raw -o - "$plist")
        local job="$domain/$service"
        if launchctl print "$job" &>/dev/null; then
            launchctl kickstart -k "$job" && echo "Restarting $service"
        else
            launchctl bootstrap "$domain" "$plist" && echo "Starting $service"
        fi
    done
}

main "$@"