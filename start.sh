#!/usr/bin/env bash

main() {
    launchctl list | awk '/com\.homelab\./ {print $3}' | while read -r service; do
        launchctl start "$service"
    done
}

main "$@"