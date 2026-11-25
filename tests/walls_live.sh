#!/usr/bin/env bash
# Starts a real Caelestia shell off-screen with a throw-away home and checks that a folder
# created AFTER the shell started shows up without restarting it.
set -u
here=$(readlink -f "$(dirname "$(readlink -f "$0")")/.."); work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
export HOME=$work XDG_CONFIG_HOME=$work/.config XDG_STATE_HOME=$work/.local/state XDG_CACHE_HOME=$work/.cache XDG_DATA_HOME=$work/.local/share XDG_RUNTIME_DIR=$work/run
mkdir -p "$XDG_CONFIG_HOME/caelestia" "$XDG_STATE_HOME/caelestia" "$work/run" "$work/bin"; chmod 700 "$work/run"
echo '{"lock":{"useWallpaper":true}}' > "$XDG_CONFIG_HOME/caelestia/shell.json"
unset HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
printf '#!/bin/sh\nshift\nexec qs -c caelestia ipc call "$@"\n' > "$work/bin/caelestia"; chmod +x "$work/bin/caelestia"
WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 timeout 55 dbus-run-session -- cage -- bash -c '
  export PATH='"$work"'/bin:$PATH
  qs -c caelestia -n > '"$work"'/qs.log 2>&1 & sleep 8
  echo "before:   [$(caelestia shell wallpaper list 2>&1 | head -2)]"
  mkdir -p $HOME/Immagini/Wallpapers; cp '"$here"'/wallpapers/orrery-dawn.png $HOME/Immagini/Wallpapers/; sleep 2
  echo "by hand:  [$(caelestia shell wallpaper list 2>&1 | head -2)]"
  echo "{\"dir\":\"$HOME/Immagini/Wallpapers\"}" | python3 -I '"$here"'/lib/orreryctl.py wallpapers; echo
  echo "after:    [$(caelestia shell wallpaper list 2>&1 | tr "\n" " ")]"
  pgrep -c -f "qs -c caelestia -n" >/dev/null; kill %1' 2>/dev/null
