#!/usr/bin/env bash

plex() {
  sudo ln -sf "$PWD/plex.sh" /usr/local/bin/plex.sh
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
  # Installed manually. Run it as an agent app (no Dock icon or menu bar); use the Web UI on :8080.
  # Replacing the app drops the flag, so this re-applies it.
  local -r app=/Applications/qBittorrent.app
  [[ -d $app ]] || { echo "qbittorrent not installed, skipping"; return; }
  /usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$app/Contents/Info.plist" >/dev/null 2>&1 && return
  /usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$app/Contents/Info.plist"
  codesign --force --deep -s - "$app"
}

seerr() {
  # https://docs.seerr.dev/getting-started/buildfromsource
  # /opt/seerr/config holds Seerr's settings and database: never replace an existing install.
  [[ -d /opt/seerr ]] && { echo "seerr already installed, skipping"; return; }
  local -r node_bin=/opt/homebrew/opt/node@22/bin
  [[ -x "$node_bin/node" ]] || HOMEBREW_NO_AUTO_UPDATE=1 brew install node@22
  export PATH="$node_bin:$PATH"
  if ! command -v pnpm >/dev/null; then
    curl -fsSL https://get.pnpm.io/install.sh | sh -
    export PNPM_HOME="$HOME/Library/pnpm"
    export PATH="$PNPM_HOME:$PATH"
  fi
  rm -rf /tmp/seerr
  git clone --branch main https://github.com/seerr-team/seerr.git /tmp/seerr
  pushd /tmp/seerr || return
  CYPRESS_INSTALL_BINARY=0 pnpm install --frozen-lockfile
  pnpm build
  popd || return
  sudo mv /tmp/seerr /opt/seerr
}

nginx() {
  command -v nginx >/dev/null || HOMEBREW_NO_AUTO_UPDATE=1 brew install nginx
  sudo mkdir -p /usr/local/etc
  sudo ln -sfn "$PWD/nginx" /usr/local/etc/nginx
  sudo ln -sf "$PWD/nginx/nginx.conf" /opt/homebrew/etc/nginx/nginx.conf
}

logs() {
  sudo mkdir -p /usr/local/var/log
  sudo chown "$USER" /usr/local/var/log
}

main() {
  cd "$(dirname "$0")" || exit 1
  logs

  plex
  radarr
  sonarr
  prowlarr
  qbittorrent
  seerr

  nginx
}

main "$@"
