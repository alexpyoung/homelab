#!/usr/bin/env bash

main() {
    docker stop flaresolverr
    local domain="gui/$(id -u)"
    launchctl list | awk '/com\.homelab\./ {print $3}' | while read -r service; do
        launchctl bootout "$domain/$service" && echo "Stopping $service"
    done
}

main "$@"