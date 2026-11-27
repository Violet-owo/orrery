#!/usr/bin/env bash
# README pictures, in English, in a neutral home (/home/demo): tests/demo.sh  -> docs/*.jpg
# Nothing of yours shows: a "demo" user, Orrery's wallpapers, an isolated D-Bus for the lock screen.
# The GIPHY picture uses your key (~/.config/orrery/giphy.json), copied only into the temporary home.
set -u
here=$(readlink -f "$(dirname "$(readlink -f "$0")")/.."); tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
out=$tmp/raw; mkdir -p "$out"

# A copy of the app whose shell.qml runs a script of steps: ORRERY_PROMO=file.js, one statement per tick
cp -r "$here" "$tmp/app"
python3 -I - "$tmp/app/ui/shell.qml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("ShellRoot {", '''ShellRoot {
    Timer {
        property int n: 0
        property var steps: Quickshell.env("ORRERY_PROMO_STEPS") ? Quickshell.env("ORRERY_PROMO_STEPS").split(";;") : []
        interval: 1000; repeat: true; running: Backend.ready && steps.length > 0
        onTriggered: { if (n < steps.length) eval(steps[n]); n++; }
    }''', 1)
open(p, "w").write(s)
PY

for m in night dawn; do
  h=$tmp/$m; mkdir -p "$h"/{.config/{caelestia,hypr,orrery},.local/state/caelestia/wallpaper,Pictures/Wallpapers}
  touch "$h/.config/hypr/hyprland.lua" "$h/.config/caelestia/hypr-user.lua"
  cp "$here"/wallpapers/*.png "$h/Pictures/Wallpapers/"
  [ -f ~/.config/orrery/giphy.json ] && install -m600 ~/.config/orrery/giphy.json "$h/.config/orrery/giphy.json"
  mode=dark; [ $m = dawn ] && mode=light
  python3 -I - "$here/wallpapers/orrery-$m.png" "$h/.local/state/caelestia/scheme.json" $mode <<'PY'
import json, subprocess, sys
d = json.loads(subprocess.run(["caelestia", "wallpaper", "-p", sys.argv[1]], capture_output=True, text=True, check=True).stdout)
d["mode"] = sys.argv[3] if d.get("mode") is None else d["mode"]
json.dump(d, open(sys.argv[2], "w"))
PY
  echo "/home/demo/Pictures/Wallpapers/orrery-$m.png" > "$h/.local/state/caelestia/wallpaper/path.txt"
  echo '{"appearance":{"transparency":{"enabled":false}},"services":{"weatherLocation":"London"}}' > "$h/.config/caelestia/shell.json"
done

# mode page area scroll wait name steps
shot() {
  bwrap --dev-bind / / --tmpfs /home --bind "$tmp/$1" /home/demo --ro-bind "$tmp/app" /home/demo/.orrery --bind "$tmp" /tmp/shots --setenv HOME /home/demo \
    --unsetenv XDG_CONFIG_HOME --unsetenv XDG_STATE_HOME --unsetenv XDG_DATA_HOME --unsetenv XDG_CACHE_HOME --unsetenv HYPRLAND_INSTANCE_SIGNATURE --unsetenv DBUS_SESSION_BUS_ADDRESS \
    --setenv LANG en_US.UTF-8 --setenv ORRERY_DRY 1 --setenv ORRERY_NET 1 --setenv ORRERY_PAGE "$2" --setenv ORRERY_AREA "$3" --setenv ORRERY_SCROLL "$4" \
    --setenv ORRERY_PROMO_STEPS "${7:-}" --setenv WLR_BACKENDS headless --setenv WLR_LIBINPUT_NO_DEVICES 1 --chdir /home/demo \
    timeout 60 cage -- bash -c "/home/demo/.orrery/bin/orrery >/tmp/shots/$6.log 2>&1 & sleep $5; grim /tmp/shots/$6.png; kill %1" >/dev/null 2>&1 || true
  cp "$tmp/$6.png" "$out/" 2>/dev/null || echo "no shot: $6"
}

SEARCH='Ui.gifPicker.show("Media", p => {})'
GIPHY='Ui.gifPicker.setTab("giphy")'
QUERY='(function f(i) { if (i.cursorPosition !== undefined && i.maximumLength === 50) { i.text = "cute cat"; return true; } for (const c of i.children) if (f(c)) return true; return false; })(Ui.gifPicker)'
GO='Ui.gifPicker.search("cute cat", false)'
PRE='Ui.gifPicker.giphyQuery = "cute cat"'
shot night 1 0 0 22 gif-search "$PRE;;$SEARCH;;$GIPHY"
shot night 1 0 700 6 gif-places
AREA='Backend.mutate(c => { const a = c.areas[1]; a.enabled = true; a.spaces[0].apps.push({ name: "Telegram", class: "org.telegram.desktop", command: "telegram-desktop", autostart: true }); a.spaces.push({ id: "teamspeak", apps: [{ name: "TeamSpeak", class: "TeamSpeak", command: "teamspeak", autostart: false }] }); });;; Backend.savedJson = JSON.stringify(Backend.cfg)'
shot dawn 5 1 0 7 areas "$AREA"
shot night 2 0 0 6 bar
shot dawn 8 0 0 6 power

# Login: Caelestia's lock screen built by Orrery's greeter builder, for a "demo" user
g=$tmp/greeter; mkdir -p "$g"
bwrap --dev-bind / / --tmpfs /home --bind "$tmp/night" "/home/$(id -un)" --bind "$tmp" /tmp/shots \
  python3 -I "$tmp/app/helper/orrery-greeter-build" "$(id -un)" --data "$tmp/app/helper/greeter" --dest "$g/orrery" >/dev/null || echo "greeter build failed"
sed -i "s#/home/demo/Pictures/Wallpapers#$tmp/night/Pictures/Wallpapers#" "$g/orrery/state/state/caelestia/wallpaper/path.txt" 2>/dev/null
env -i PATH="$PATH" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" LANG=en_US.UTF-8 WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
  HOME="$g/orrery/state" XDG_CONFIG_HOME="$g/orrery/state/config" XDG_STATE_HOME="$g/orrery/state/state" XDG_CACHE_HOME="$tmp/cache" \
  QML_IMPORT_PATH=/usr/share/quickshell-greetd/core QML2_IMPORT_PATH=/usr/share/quickshell-greetd/core \
  QT_SCALE_FACTOR=0.667 QSGREET_THEME=orrery QSGREET_THEME_ROOT="$g" QSGREET_SURFACE=modules/lock/LockSurface.qml QSGREET_COMPOSITOR=cage QSGREET_POWER_ENABLED=1 \
  QSGREET_USER=demo QSGREET_USERS_JSON='[{"name":"demo","displayName":"Demo","uid":1000,"home":"/home/demo","avatar":""}]' QSGREET_SESSIONS_JSON='[{"name":"Hyprland","exec":"Hyprland"}]' \
  timeout 50 dbus-run-session -- cage -- bash -c "quickshell -n -p '$g/orrery/shell/_qsgreet-entry.qml' >'$tmp/lock.log' 2>&1 & sleep 16; grim '$tmp/lock.png'; kill %1" >/dev/null 2>&1
cp "$tmp/lock.png" "$out/" 2>/dev/null || echo "no shot: lock"
grep -hE 'ERROR|TypeError' "$tmp"/*.log | sed 's/\x1b\[[0-9;]*m//g' | sort | uniq -c | head -15
python3 -I "$here/tests/demo_frame.py" "$out" "$here/wallpapers" "$here/docs"
