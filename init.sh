#!/usr/bin/env bash

packages() {
  command -v brew >/dev/null || { echo "Homebrew is required: https://brew.sh"; exit 1; }
  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file Brewfile
}

plex() {
  # https://www.plex.tv/media-server-downloads/ (universal build; URL and checksum come from plex.tv's download API)
  # Installed apps self-update by hand only; never replace an existing install.
  if [[ ! -d "/Applications/Plex Media Server.app" ]]; then
    local release url sha1
    release=$(curl -fsSL https://plex.tv/api/downloads/5.json)
    url=$(plutil -extract computer.MacOS.releases.0.url raw -o - - <<<"$release")
    sha1=$(plutil -extract computer.MacOS.releases.0.checksum raw -o - - <<<"$release")
    mkdir -p /tmp/plex
    curl -fL -o /tmp/plex/plex.zip "$url"
    [[ $(shasum -a 1 /tmp/plex/plex.zip | cut -d' ' -f1) == "$sha1" ]] || { echo "plex: checksum mismatch"; exit 1; }
    unzip -q /tmp/plex/plex.zip -d /tmp/plex
    mv "/tmp/plex/Plex Media Server.app" "/Applications/Plex Media Server.app"
    rm -rf /tmp/plex
  fi
  # Self-updates relaunch Plex outside launchd (no restart on crash); update by hand instead.
  # Same as Settings > General > Server version updates: "Ask me".
  defaults write com.plexapp.plexmediaserver ButlerTaskUpdateServer askme
}

radarr() {
  # https://radarr.video/#downloads-macos
  # Installed apps self-update; re-running mv would nest a second bundle inside.
  [[ -d /Applications/Radarr.app ]] && { echo "radarr already installed, skipping"; return; }
  mkdir -p /tmp/radarr
  curl -L -o /tmp/radarr/latest-arm64.zip "https://radarr.servarr.com/v1/update/master/updatefile?os=osx&runtime=netcore&arch=arm64&installer=true"
  unzip /tmp/radarr/latest-arm64.zip -d /tmp/radarr

  mv /tmp/radarr/Radarr.app /Applications/Radarr.app
  codesign --force --deep -s - /Applications/Radarr.app
  xattr -rd com.apple.quarantine /Applications/Radarr.app
  rm -rf /tmp/radarr
}

sonarr() {
  # https://sonarr.tv/#downloads-macos
  # Installed apps self-update; re-running mv would nest a second bundle inside.
  [[ -d /Applications/Sonarr.app ]] && { echo "sonarr already installed, skipping"; return; }
  mkdir -p /tmp/sonarr
  curl -L -o /tmp/sonarr/latest-arm64.zip "https://services.sonarr.tv/v1/download/main/latest?version=4&os=macos&arch=arm64&installer=true"
  unzip /tmp/sonarr/latest-arm64.zip -d /tmp/sonarr

  mv /tmp/sonarr/Sonarr.app /Applications/Sonarr.app
  codesign --force --deep -s - /Applications/Sonarr.app
  xattr -rd com.apple.quarantine /Applications/Sonarr.app
  rm -rf /tmp/sonarr
}

prowlarr() {
  # https://prowlarr.com/#downloads-v3-macos
  # Installed apps self-update; re-running mv would nest a second bundle inside.
  [[ -d /Applications/Prowlarr.app ]] && { echo "prowlarr already installed, skipping"; return; }
  mkdir -p /tmp/prowlarr
  curl -L -o /tmp/prowlarr/latest-arm64.zip "https://prowlarr.servarr.com/v1/update/master/updatefile?os=osx&runtime=netcore&arch=arm64&installer=true"
  unzip /tmp/prowlarr/latest-arm64.zip -d /tmp/prowlarr

  mv /tmp/prowlarr/Prowlarr.app /Applications/Prowlarr.app
  codesign --force --deep -s - /Applications/Prowlarr.app
  xattr -rd com.apple.quarantine /Applications/Prowlarr.app
  rm -rf /tmp/prowlarr
}

qbittorrent() {
  # Not from Homebrew (its cask is disabled); the dmg is from the official SourceForge qbittorrent-mac folder.
  # Run it as an agent app (no Dock icon or menu bar); use the Web UI on :8080.
  # Replacing the app drops the LSUIElement flag, so this re-applies it: bump `version`, delete the app, re-run.
  local -r version=5.2.3
  local -r app=/Applications/qBittorrent.app
  if [[ ! -d $app ]]; then
    mkdir -p /tmp/qbittorrent/mnt
    curl -fL -o /tmp/qbittorrent/qbittorrent.dmg "https://sourceforge.net/projects/qbittorrent/files/qbittorrent-mac/qbittorrent-$version/qbittorrent-$version.dmg/download"
    hdiutil attach -nobrowse -readonly -mountpoint /tmp/qbittorrent/mnt /tmp/qbittorrent/qbittorrent.dmg >/dev/null
    cp -R /tmp/qbittorrent/mnt/qbittorrent.app "$app"
    hdiutil detach /tmp/qbittorrent/mnt >/dev/null
    rm -rf /tmp/qbittorrent
    xattr -rd com.apple.quarantine "$app" 2>/dev/null
  fi
  /usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$app/Contents/Info.plist" >/dev/null 2>&1 && return
  /usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$app/Contents/Info.plist"
  codesign --force --deep -s - "$app"
}

seerr() {
  # https://docs.seerr.dev/getting-started/buildfromsource
  # /opt/seerr/config holds Seerr's settings and database: never replace an existing install.
  [[ -d /opt/seerr ]] && { echo "seerr already installed, skipping"; return; }
  # Release tag to build (https://github.com/seerr-team/seerr/releases); upgrade steps are in README.md.
  local -r version=v3.5.2
  local -r node_bin=/opt/homebrew/opt/node@22/bin
  export PATH="$node_bin:$PATH"
  if ! command -v pnpm >/dev/null; then
    curl -fsSL https://get.pnpm.io/install.sh | sh -
    export PNPM_HOME="$HOME/Library/pnpm"
    export PATH="$PNPM_HOME:$PATH"
  fi
  rm -rf /tmp/seerr
  git clone --branch "$version" https://github.com/seerr-team/seerr.git /tmp/seerr
  pushd /tmp/seerr || return
  CYPRESS_INSTALL_BINARY=0 pnpm install --frozen-lockfile
  pnpm build
  popd || return
  sudo mv /tmp/seerr /opt/seerr
}

nginx() {
  sudo mkdir -p /usr/local/etc
  sudo ln -sfn "$PWD/nginx" /usr/local/etc/nginx
  sudo ln -sf "$PWD/nginx/nginx.conf" /opt/homebrew/etc/nginx/nginx.conf
}

tls() {
  # https://go-acme.github.io/lego/ (certs are issued/renewed by launchctl/com.homelab.lego.plist)
  mkdir -p /usr/local/var/lego "$HOME/.config/homelab"
  [[ -f "$HOME/.config/homelab/cloudflare.env" ]] || echo "tls: add CF_DNS_API_TOKEN to ~/.config/homelab/cloudflare.env (mode 600)"
}

launchagents() {
  # Jobs bootstrapped from the repo path are forgotten at reboot; launchd loads ~/Library/LaunchAgents at every login.
  mkdir -p "$HOME/Library/LaunchAgents"
  ln -sf "$PWD"/launchctl/*.plist "$HOME/Library/LaunchAgents/"
}

logs() {
  sudo mkdir -p /usr/local/var/log
  sudo chown "$USER" /usr/local/var/log
  sed "s/@USER@/$USER/" newsyslog/homelab.conf | sudo tee /etc/newsyslog.d/homelab.conf >/dev/null
}

main() {
  cd "$(dirname "$0")" || exit 1
  logs
  packages

  plex
  radarr
  sonarr
  prowlarr
  qbittorrent
  seerr

  tls
  nginx
  launchagents
}

main "$@"
