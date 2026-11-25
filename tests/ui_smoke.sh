#!/usr/bin/env bash
# Drives the real UI against a throw-away configuration: tests/ui_smoke.sh OUTDIR
set -u
out=$1; here=$(readlink -f "$(dirname "$(readlink -f "$0")")/.."); mkdir -p "$out"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cp -r "$here/ui" "$here/lib" "$here/lua" "$here/wallpapers" "$work/"
conf="$work/conf"; mkdir -p "$conf/caelestia" "$conf/hypr"; touch "$conf/hypr/hyprland.lua"
printf 'require("hyprland-gui")\n' > "$conf/caelestia/hypr-user.lua"
python3 -I - "$work/ui/shell.qml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("ShellRoot {", '''ShellRoot {
    Timer {
        property int n: 0
        interval: 900; repeat: true; running: Backend.ready
        onTriggered: {
            n++;
            if (n === 1) { Ui.go(4); Ui.area = 1; }
            if (n === 2) Backend.mutate(c => { c.areas[1].enabled = true; c.areas[1].name = "Chat"; c.areas[1].spaces.push({ id: "smoke", apps: [{ name: "Foo", class: "foo", command: "foo --x", autostart: true }] }); c.keyboard.managed = true; });
            if (n === 3) console.log("SMOKE dirty", Backend.dirty);
            if (n === 4) Ui.pick("Pick", Backend.st.apps.map(a => ({ value: a.id, label: a.name, sub: a.command })), "", v => {});
            if (n === 6) { Ui.picker.close(); Backend.apply(); }
            if (n === 9) console.log("SMOKE applied dirty=" + Backend.dirty + " saved=" + Backend.st.saved + " active=" + Backend.st.active + " err=" + Backend.messageIsError + " msg=" + Backend.message);
            if (n === 10) Backend.mutate(c => c.areas[1].key = "SUPER + M") ;
            if (n === 11) Backend.mutate(c => c.areas[2].enabled = true);
            if (n === 12) Backend.apply();
            if (n === 15) console.log("SMOKE clash err=" + Backend.messageIsError + " msg=" + Backend.message);
            if (n === 16) Backend.discard();
            if (n === 17) Backend.simple("undo", "ok");
            if (n === 20) { console.log("SMOKE undone saved=" + Backend.st.saved + " active=" + Backend.st.active); Qt.quit(); }
        }
    }
''', 1)
open(p, "w").write(s)
PY
export XDG_CONFIG_HOME=$conf ORRERY_DRY=1 ORRERY_SHARE=$work ORRERY_CTL=$work/lib/orreryctl.py WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
timeout 60 cage -- bash -c "quickshell -p '$work/ui/shell.qml' >'$out/smoke.log' 2>&1 & sleep 5.2; grim '$out/smoke-area.png'; sleep 1.4; grim '$out/smoke-picker.png'; wait" >/dev/null 2>&1
sed 's/\x1b\[[0-9;]*m//g' "$out/smoke.log" | grep -E 'SMOKE|ERROR|WARN.*(scene|qml)' | cut -c1-260
echo "hypr-user after undo: $(cat "$conf/caelestia/hypr-user.lua")"
