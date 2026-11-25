#!/usr/bin/env bash
# README pictures in a neutral environment (/home/demo): tests/demo.sh   -> docs/*.png, docs/demo.gif
set -eu
here=$(readlink -f "$(dirname "$(readlink -f "$0")")/.."); out=$here/docs; mkdir -p "$out"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
for m in night dawn; do
  h=$tmp/$m; mkdir -p "$h"/{.config/{caelestia,hypr,orrery},.local/state/caelestia,Pictures/Wallpapers}
  touch "$h/.config/hypr/hyprland.lua" "$h/.config/caelestia/hypr-user.lua"
  cp "$here"/wallpapers/*.png "$h/Pictures/Wallpapers/"
  mode=dark; [ $m = dawn ] && mode=light
  python3 -I - "$here/wallpapers/orrery-$m.png" "$h/.local/state/caelestia/scheme.json" $mode <<'PY'
import json, subprocess, sys
d = json.loads(subprocess.run(["caelestia", "wallpaper", "-p", sys.argv[1]], capture_output=True, text=True, check=True).stdout)
d["mode"] = sys.argv[3] if d.get("mode") is None else d["mode"]
json.dump(d, open(sys.argv[2], "w"))
PY
  echo '{"appearance":{"transparency":{"enabled":false},"anim":{"durations":{"scale":SCALE}}}}' | sed "s/SCALE/${SPEED:-1}/" > "$h/.config/caelestia/shell.json"
done
run() { # mode page area scroll command
  bwrap --dev-bind / / --tmpfs /home --bind "$tmp/$1" /home/demo --ro-bind "$here" /home/demo/.orrery --bind "$tmp" /tmp/shots --setenv HOME /home/demo \
    --unsetenv XDG_CONFIG_HOME --unsetenv XDG_STATE_HOME --unsetenv XDG_DATA_HOME --unsetenv XDG_CACHE_HOME --unsetenv HYPRLAND_INSTANCE_SIGNATURE --unsetenv DBUS_SESSION_BUS_ADDRESS \
    --setenv LANG en_US.UTF-8 --setenv ORRERY_DRY 1 --setenv ORRERY_PAGE "$2" --setenv ORRERY_AREA "$3" --setenv ORRERY_SCROLL "$4" --setenv WLR_BACKENDS headless --setenv WLR_LIBINPUT_NO_DEVICES 1 --chdir /home/demo \
    timeout 30 cage -- bash -c "/home/demo/.orrery/bin/orrery >/tmp/shots/log 2>&1 & $5; kill %1" >/dev/null 2>&1 || true
}
shot() { run "$1" "$2" "$3" "$4" "sleep 5; grim /tmp/shots/$5.png"; cp "$tmp/$5.png" "$out/"; }
shot night 0 0 0 appearance; shot night 4 1 0 areas; shot night 3 0 0 keyboard; shot dawn 1 0 0 wallpapers; shot night 2 0 0 apps
ls -la "$out"
