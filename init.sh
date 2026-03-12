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
