#!/usr/bin/env bash

radarr() {
  # https://radarr.video/#downloads-macos
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
  mkdir -p /tmp/prowlarr
  curl -L -o /tmp/prowlarr/latest-arm64.zip "https://prowlarr.servarr.com/v1/update/master/updatefile?os=osx&runtime=netcore&arch=arm64&installer=true"
  unzip /tmp/prowlarr/latest-arm64.zip -d /tmp/prowlarr

  mv /tmp/prowlarr/Prowlarr.app /Applications/Prowlarr.app
  codesign --force --deep -s - /Applications/Prowlarr.app
  xattr -rd com.apple.quarantine /Applications/Prowlarr.app
  rm -rf /tmp/prowlarr
}

seerr() {
  # https://docs.seerr.dev/getting-started/buildfromsource
  which pnpm || (curl -fsSL https://get.pnpm.io/install.sh | sh - && source ~/.zshrc)
  which node || HOMEBREW_NO_AUTO_UPDATE=1 brew install node@22
  mkdir -p /tmp/seerr
  pushd /tmp/seerr || return
  git clone https://github.com/seerr-team/seerr.git .
  git checkout main
  CYPRESS_INSTALL_BINARY=0 pnpm install --frozen-lockfile
  pnpm build
  popd || return
  sudo mv --force /tmp/seerr /opt
}

nginx() {
  which nginx || HOMEBREW_NO_AUTO_UPDATE=1 brew install nginx
  mkdir -p ./nginx/certs
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./nginx/certs/local.key -out ./nginx/certs/local.crt -subj "/CN=localhost"
  sudo ln -s "$PWD/nginx" /usr/local/etc/nginx
  sudo ln -sf "$PWD/nginx/nginx.conf" /opt/homebrew/etc/nginx/nginx.conf
}

dns() {
  cat ./hosts | sudo tee -a /etc/hosts
}
