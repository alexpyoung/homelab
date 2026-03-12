#!/usr/bin/env bash

main() {
    docker stop flaresolverr
    launchctl list | awk '/com\.homelab\./ {print $3}' | while read -r service; do
        launchctl stop "$service"
    done
}

main "$@"