#!/usr/bin/env bash
# Captures mid-animation frames off-screen, 4x slower: tests/motion.sh OUTDIR
set -u
out=$1; here=$(readlink -f "$(dirname "$(readlink -f "$0")")/.."); mkdir -p "$out"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cp -r "$here/ui" "$here/lib" "$here/lua" "$here/wallpapers" "$work/"
conf="$work/conf"; mkdir -p "$conf/caelestia" "$conf/hypr"; touch "$conf/hypr/hyprland.lua" "$conf/caelestia/hypr-user.lua"
echo '{"appearance":{"anim":{"durations":{"scale":4}}}}' > "$conf/caelestia/shell.json"
python3 -I - "$work/ui/shell.qml" "$out" <<'PY'
import sys
p, out = sys.argv[1:]; s = open(p).read()
s = s.replace("ShellRoot {", '''ShellRoot {
    Timer {
        property int n: 0
        property var steps: [
            ["none", () => {}], ["cascade", () => Ui.go(4)], ["pill", () => Ui.go(7)], ["back", () => Ui.go(5)],
            ["area", () => Ui.area = 3], ["add", () => { Ui.markAdded("space-1"); Backend.mutate(c => c.areas[3].spaces.push({ id: "zz", apps: [] })); }],
            ["toggle", () => Backend.mutate(c => c.areas[3].enabled = true)], ["picker", () => Ui.pick("Pick", Backend.st.apps.map(a => ({ value: a.id, label: a.name, sub: a.command })), "", v => {})],
            ["close", () => Ui.picker.close()], ["error", () => Backend.say("Music: SUPER + M is already used", true)]]
        interval: 3000; repeat: true; running: Backend.ready
        onTriggered: {
            if (n >= steps.length) return Qt.quit();
            const [name, fn] = steps[n++];
            fn();
            Quickshell.execDetached(["bash", "-c", `for i in 1 2 3; do sleep 0.22; grim -s 0.6 "OUT/${String(n).padStart(2, "0")}-${name}-$i.png"; done`]);
        }
    }
'''.replace("OUT", out), 1)
open(p, "w").write(s)
PY
export XDG_CONFIG_HOME=$conf ORRERY_DRY=1 ORRERY_SHARE=$work ORRERY_CTL=$work/lib/orreryctl.py WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
timeout 60 cage -- bash -c "quickshell -p '$work/ui/shell.qml' >'$out/motion.log' 2>&1" >/dev/null 2>&1
sed 's/\x1b\[[0-9;]*m//g' "$out/motion.log" | grep -E 'ERROR|WARN.*(scene|qml)' | sort | uniq -c
