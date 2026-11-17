#!/usr/bin/env bash
# Back up or restore the app state that lives outside the repo: app databases and settings, API keys, tokens.
#   ./state.sh backup DIR     writes DIR/homelab-state-<timestamp>.tar.gz
#   ./state.sh restore FILE   unpacks it; run after init.sh and before start.sh, with everything stopped
# The archive holds API keys and the Plex and Cloudflare tokens: keep it somewhere private.
# Plex artwork and thumbnails (Metadata, Media) are skipped because Plex rebuilds them; PLEX_FULL=1 keeps them.
# Not saved: media (it lives on /Volumes/Lucy), the lego cert (lego reissues it) and caches, logs and cover art.

readonly APP_SUPPORT="$HOME/Library/Application Support"
readonly PLEX_PLIST=com.plexapp.plexmediaserver

# name|directory
readonly DIRS=(
    "radarr|$APP_SUPPORT/Radarr"
    "sonarr|$HOME/.config/Sonarr"
    "prowlarr|$APP_SUPPORT/Prowlarr"
    "qbittorrent|$APP_SUPPORT/qBittorrent"
    "qbittorrent-config|$HOME/.config/qBittorrent"
    "plex|$APP_SUPPORT/Plex Media Server"
    "seerr|/opt/seerr/config"
    "secrets|$HOME/.config/homelab"
)

readonly EXCLUDES=(
    --exclude=logs --exclude=Logs --exclude='logs.db*' --exclude=MediaCover --exclude=Sentry --exclude=asp
    --exclude='*.pid' --exclude=Backups/update
    --exclude=Cache --exclude=Caches --exclude=Codecs --exclude=Drivers --exclude=Diagnostics
    --exclude='Crash Reports' --exclude=Updates --exclude='*.db-20*'
    # Databases are copied separately with sqlite3, which is safe while the app runs.
    --exclude='*-wal' --exclude='*-shm' --exclude='*-journal'
)

backup() {
    local -r dest=${1:?usage: state.sh backup DIR}
    local -r stage=$(mktemp -d)
    trap 'rm -rf "$stage"' EXIT
    local excludes=("${EXCLUDES[@]}")
    [[ ${PLEX_FULL:-} ]] || excludes+=(--exclude=/Metadata --exclude=/Media)

    local entry name dir db rel
    for entry in "${DIRS[@]}"; do
        name=${entry%%|*}
        dir=${entry#*|}
        [[ -d $dir ]] || { echo "skipping $name: $dir not found"; continue; }
        mkdir -p "$stage/$name"
        rsync -a "${excludes[@]}" "$dir/" "$stage/$name/"
        while IFS= read -r -d '' db; do
            rel=${db#"$stage/$name/"}
            rm "$db"
            sqlite3 "$dir/$rel" ".backup '$db'" || echo "WARNING: could not back up $dir/$rel" >&2
        done < <(find "$stage/$name" \( -name '*.db' -o -name '*.sqlite3' \) -print0)
        find "$stage/$name" \( -name '*-wal' -o -name '*-shm' \) -delete
        echo "saved $name"
    done
    [[ -f .env ]] && cp .env "$stage/env"
    defaults export "$PLEX_PLIST" "$stage/plex-prefs.plist" 2>/dev/null

    mkdir -p "$dest"
    local -r archive="$dest/homelab-state-$(date +%Y%m%d-%H%M%S).tar.gz"
    (umask 077 && tar -C "$stage" -czf "$archive" .)
    echo "wrote $archive"
}

restore() {
    local -r archive=${1:?usage: state.sh restore FILE}
    if launchctl list | grep -q com.homelab || pgrep -x 'Plex Media Server|Radarr|Sonarr|Prowlarr|qBittorrent' >/dev/null; then
        echo "stop everything first (./stop.sh; quit Plex if it is still running)"
        exit 1
    fi
    local -r stage=$(mktemp -d)
    trap 'rm -rf "$stage"' EXIT
    tar -C "$stage" -xzf "$archive"

    local entry name dir
    for entry in "${DIRS[@]}"; do
        name=${entry%%|*}
        dir=${entry#*|}
        [[ -d $stage/$name ]] || continue
        mkdir -p "$dir" 2>/dev/null || { echo "skipping $name: cannot create $dir (run init.sh first)"; continue; }
        # Stale journal files would not match the restored databases.
        find "$dir" \( -name '*-wal' -o -name '*-shm' -o -name '*-journal' \) -delete
        rsync -a "$stage/$name/" "$dir/"
        echo "restored $name"
    done
    [[ -f $stage/env ]] && cp "$stage/env" .env
    [[ -f $stage/plex-prefs.plist ]] && defaults import "$PLEX_PLIST" "$stage/plex-prefs.plist"
    chmod 700 "$HOME/.config/homelab" 2>/dev/null
    chmod 600 "$HOME/.config/homelab"/* .env 2>/dev/null
    echo "done: run ./start.sh"
}

main() {
    cd "$(dirname "$0")" || exit 1
    case ${1:-} in
        backup) shift; backup "$@" ;;
        restore) shift; restore "$@" ;;
        *) echo "usage: state.sh backup DIR | restore FILE"; exit 1 ;;
    esac
}

main "$@"
