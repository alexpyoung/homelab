#!/usr/bin/env bash

main() {
    cd "$(dirname "$0")" || exit 1
    docker stop flaresolverr
    local -r domain="gui/$(id -u)"
    for plist in ./launchctl/*.plist; do
        local service
        service=$(plutil -extract Label raw -o - "$plist")
        local job="$domain/$service"
        if launchctl print "$job" &>/dev/null; then
            launchctl bootout "$job" && echo "Stopping $service"
        fi
    done
}

main "$@"
