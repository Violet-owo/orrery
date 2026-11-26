#!/usr/bin/env bash
# Real key presses and clicks (QtTest) on the real UI, off-screen: tests/input.sh OUTDIR
set -u
out=$1; here=$(readlink -f "$(dirname "$(readlink -f "$0")")/.."); mkdir -p "$out"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cp -r "$here/ui" "$here/lib" "$here/lua" "$here/wallpapers" "$work/"
conf="$work/conf"; mkdir -p "$conf/caelestia" "$conf/hypr"; touch "$conf/hypr/hyprland.lua" "$conf/caelestia/hypr-user.lua"
python3 -I - "$work/ui/shell.qml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("import Quickshell\n", "import Quickshell\nimport QtTest\n", 1)
s = s.replace("            Help { id: help }", '''            TestCase {
                id: t
                name: "input"
                when: false
                property int bad: 0
                function check(what: string, ok: bool): void { if (!ok) bad++; console.log("INPUT", ok ? "ok  " : "FAIL", what); }
                function key(k: int, m: int): void { keyClick(k, m ?? 0); wait(120); }
                function label(): string { let i = Nav.current; while (i && !i.label && !i.placeholder) i = i.parent; return i?.label ?? ""; }
                function go(): void {
                    wait(700);
                    key(Qt.Key_Down); check("first arrow goes to the menu", Nav.inside(Nav.current, side));
                    key(Qt.Key_Down); check("down changes page", Ui.page >= 1);
                    key(Qt.Key_5, Qt.ControlModifier); check("ctrl+5 opens keyboard", Ui.page === 4); wait(900);
                    key(Qt.Key_Right); check("right enters the page", label() === I18n.tr("Manage the keyboard with Orrery"));
                    key(Qt.Key_Space); check("space toggles", Backend.cfg.keyboard.managed === true);
                    key(Qt.Key_Z, Qt.ControlModifier); check("ctrl+z", Backend.cfg.keyboard.managed === false);
                    key(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier); check("ctrl+shift+z", Backend.cfg.keyboard.managed === true);
                    let n = 0; while (label() !== I18n.tr("Repeat rate") && n++ < 20) key(Qt.Key_Down);
                    check("down reaches the slider", label() === I18n.tr("Repeat rate"));
                    wait(700); { const b = Nav.box(Nav.current); check("focused slider is on screen", b.y > 0 && b.y + b.height < bg.height); }
                    const rate = Backend.cfg.keyboard.repeatRate;
                    key(Qt.Key_Right); key(Qt.Key_Right); check("arrows move the slider", Backend.cfg.keyboard.repeatRate === rate + 2);
                    key(Qt.Key_Home); check("home", Backend.cfg.keyboard.repeatRate === 1);
                    n = 0; while (label() !== I18n.tr("Switch layout") && n++ < 8) key(Qt.Key_Up);
                    check("up reaches the shortcut", label() === I18n.tr("Switch layout"));
                    n = 0; while (!("cursorPosition" in Nav.current) && n++ < 6) key(Qt.Key_Right);
                    key(Qt.Key_A, Qt.ControlModifier); key(Qt.Key_K); key(Qt.Key_Return);
                    check("typing a shortcut: " + Backend.cfg.keyboard.switchKey, Backend.cfg.keyboard.switchKey.endsWith("+ K"));
                    key(Qt.Key_Escape); check("esc goes back to the menu", Nav.inside(Nav.current, side));
                    key(Qt.Key_6, Qt.ControlModifier); wait(900); check("ctrl+6 opens areas", Ui.page === 5);
                    key(Qt.Key_Right, Qt.AltModifier); check("alt+right changes area", Ui.area === 1);
                    n = 0; key(Qt.Key_Right); while (label() !== I18n.tr("Add an app") && n++ < 20) key(Qt.Key_Down);
                    const apps = Backend.cfg.areas[1].spaces[0].apps.length;
                    console.log("INPUT info at", label()); key(Qt.Key_Return); check("enter opens the picker", picker.open); wait(400); console.log("INPUT info focus", Nav.current, search.input, "shown", picker.shown.length);
                    key(Qt.Key_Down); key(Qt.Key_Return); wait(700);
                    check("picker adds an app", !picker.open && Backend.cfg.areas[1].spaces[0].apps.length === apps + 1);
                    key(Qt.Key_Up); check("focus survives the rebuilt list", Nav.current?.navigable === true);
                    n = 0; while (!(Nav.current?.onDelete) && n++ < 6) key(Qt.Key_Down);
                    if (!Nav.current?.onDelete) { n = 0; while (!(Nav.current?.onDelete) && n++ < 8) key(Qt.Key_Up); }
                    key(Qt.Key_Delete); wait(600); check("delete removes it", Backend.cfg.areas[1].spaces[0].apps.length === apps);
                    console.log("INPUT info open", picker.open, help.open); key(Qt.Key_F, Qt.ControlModifier); check("ctrl+f focuses search", Nav.current === search.input);
                    for (const c of I18n.tr("Num Lock at startup").slice(0, 8)) keyClick(c);
                    wait(300); check("search finds", search.hits.length > 0); key(Qt.Key_Return); wait(1500);
                    check("enter lands on the result", Ui.page === 4 && label() === I18n.tr("Num Lock at startup"));
                    key(Qt.Key_F1); check("f1 opens the guide", help.open); key(Qt.Key_Escape); check("esc closes it", !help.open);
                    key(Qt.Key_S, Qt.ControlModifier); wait(2500); check("ctrl+s applies: " + Backend.message, !Backend.dirty && Backend.st.saved);
                    // mouse
                    Ui.go(4); wait(900); const tile = stack.currentItem.findTile(I18n.tr("Num Lock at startup"), null), was = Backend.cfg.keyboard.numlock;
                    stack.currentItem.reveal(tile); wait(900); mouseClick(tile, 60, 20); wait(300); check("click toggles", Backend.cfg.keyboard.numlock !== was);
                    check("no ring with the mouse", !Nav.keys);
                    const close = windowButtons.children[1]; mouseClick(close, 20, 20); wait(600); check("X asks when there are changes", picker.open);
                    key(Qt.Key_Escape); wait(500); check("esc keeps editing", !picker.open);
                    key(Qt.Key_Z, Qt.ControlModifier); wait(200); check("nothing left to save", !Backend.dirty);
                    Ui.go(8); wait(1100); key(Qt.Key_Escape); key(Qt.Key_Right); check("power: first option", label() === I18n.tr("Lock"));
                    key(Qt.Key_Return); wait(400); key(Qt.Key_Down); key(Qt.Key_Return); wait(600); check("power: picking a time: " + Backend.cfg.power.lock, Backend.cfg.power.lock === 300);
                    stack.currentItem.setBattery(3600); check("power: charging follows battery", Backend.cfg.power.ac === 3600);
                    stack.currentItem.setAc(600); check("power: battery follows charging", Backend.cfg.power.battery === 600);
                    stack.currentItem.setAc(0); check("power: never while charging", Backend.cfg.power.battery === 600 && Backend.cfg.power.ac === 0);
                    stack.currentItem.addWarning(); check("power: add a battery warning", Backend.cfg.shell.battery.warnLevels.length === 4 && Backend.cfg.shell.battery.warnLevels[3].level === 15);
                    Backend.discard(); wait(200); check("power: discard", !Backend.dirty);
                    key(Qt.Key_3, Qt.ControlModifier); wait(1100); check("ctrl+3 opens the bar", Ui.page === 2);
                    stack.currentItem.move(0, 1); check("bar: move a block", Backend.cfg.shell.bar.entries[1].id === "logo");
                    stack.currentItem.setShown("X-1", false); check("bar: hide on a screen", Backend.cfg.shell.bar.excludedScreens.includes("X-1"));
                    Backend.discard(); wait(200); check("bar: discard", !Backend.dirty);
                    key(Qt.Key_0, Qt.ControlModifier); check("ctrl+0 opens health", Ui.page === 9);
                    for (let i = 0; i < Ui.nav.length; i++) { Ui.go(i); wait(1100); key(Qt.Key_Escape); key(Qt.Key_Right); check("page " + i + " reachable by keyboard", i === 9 || Nav.current?.navigable === true && !Nav.inside(Nav.current, side)); }
                    console.log("INPUT DONE failures=" + bad);
                    last.start(); // outside the nested test event loop
                }
            }
            Timer { running: Backend.ready; interval: 500; onTriggered: t.go() }
            Timer { id: last; interval: 300; onTriggered: { late.start(); t.mouseClick(windowButtons.children[1], 20, 20); } }
            Timer { id: late; interval: 1500; onTriggered: { console.log("INPUT FAIL X did not close"); Qt.quit(); } }

            Help { id: help }''', 1)
open(p, "w").write(s)
PY
export XDG_CONFIG_HOME=$conf ORRERY_DRY=1 ORRERY_SHARE=$work ORRERY_CTL=$work/lib/orreryctl.py WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
timeout 90 cage -- bash -c "quickshell -p '$work/ui/shell.qml' >'$out/input.log' 2>&1" >/dev/null 2>&1
sed 's/\x1b\[[0-9;]*m//g' "$out/input.log" | grep -E 'INPUT|ERROR|WARN.*(scene|qml)' | sed 's/.*INPUT/INPUT/' | cut -c1-200; grep -qi crash "$out/input.log" && echo 'INPUT FAIL crash on close' || echo 'INPUT ok   closed cleanly'
