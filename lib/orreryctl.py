#!/usr/bin/python3 -I
"""Orrery backend: reads and writes the user's settings. Never runs as root."""
import configparser, copy, datetime, json, os, re, shutil, subprocess, sys
from pathlib import Path

HOME = Path.home()
CONF = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
DATA_DIRS = [Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")] + [
    Path(p) for p in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if p]
CAEL, OWN = CONF / "caelestia", CONF / "orrery"
CONFIG, BACKUPS, LUADIR = OWN / "config.json", OWN / "backups", CAEL / "orrery"
USER_LUA, MIMEAPPS = CAEL / "hypr-user.lua", CONF / "mimeapps.list"
SHARE = Path(os.environ.get("ORRERY_SHARE") or Path(__file__).resolve().parent.parent)
DRY = os.environ.get("ORRERY_DRY") == "1"
BEGIN, END = "-- >>> orrery >>>", "-- <<< orrery <<<"
HYPRMOD = re.compile(r'^.*require\("hyprland-gui"\)', re.M)
LED = next(iter(sorted(Path("/sys/class/leds").glob("*::kbd_backlight"))), None)

# Caelestia variable holding the shortcut, for every default app we manage
ROLES = {"browser": "kbBrowser", "terminal": "kbTerminal", "editor": "kbEditor", "files": "kbFileExplorer"}
MIME = {
    "browser": ["x-scheme-handler/http", "x-scheme-handler/https", "x-scheme-handler/about",
                "x-scheme-handler/unknown", "text/html", "application/xhtml+xml"],
    "editor": ["text/plain"], "files": ["inode/directory"],
    "images": ["image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp", "image/svg+xml"],
    "video": ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime"],
    "music": ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav"],
    "pdf": ["application/pdf"], "mail": ["x-scheme-handler/mailto"],
}
ALL_ROLES = ["browser", "terminal", "editor", "files", "images", "video", "music", "pdf", "mail"]
OPEN_ANIM, SWITCH_ANIM = ("vertical", "horizontal", "fade", "none"), ("horizontal", "vertical", "fade", "none")
LAYOUT_RE, VARIANT_RE = re.compile(r"[a-z]{2,12}$"), re.compile(r"[A-Za-z0-9_-]{0,32}$")
KEY_RE = re.compile(r"(?:(?:SUPER|CTRL|ALT|SHIFT) \+ )+[A-Za-z0-9_]+$")

DEFAULT = {
    "version": 1,
    "apps": {r: "" for r in ALL_ROLES},
    "keyboard": {"managed": False, "layouts": [{"layout": "us", "variant": ""}], "switchKey": "SUPER + Space",
                 "numlock": False, "repeatRate": 35, "repeatDelay": 250},
    "areas": [],
}

def _app(name, cls, command, autostart=True):
    return {"name": name, "class": cls, "command": command, "autostart": autostart}


def _area(name, key_, *spaces):
    return {"name": name, "enabled": False, "key": key_, "arrows": True, "wrap": True, "bringBack": True,
            "openAnimation": "vertical", "openSpeed": 4, "switchAnimation": "horizontal", "switchSpeed": 5,
            "spaces": [{"id": i, "apps": list(a)} for i, a in spaces]}


# Caelestia's own special workspaces. Disabled = Caelestia's behaviour is left alone.
def presets(installed):
    def have(*a):
        return [x for x in a if not x["command"] or shutil.which(x["command"].split()[0])]
    return [
        _area("Special", "SUPER + S", ("special", [])),
        _area("Messages", "SUPER + D", ("communication", have(_app("Discord", "discord", "discord")))),
        _area("Music", "SUPER + M", ("music", have(_app("Spotify", "Spotify", "spotify"), _app("Feishin", "feishin", "feishin")))),
        _area("To-do", "SUPER + R", ("todo", have(_app("Todoist", "todoist", "todoist")))),
        _area("System monitor", "CTRL + SHIFT + Escape", ("sysmon", have(_app("btop", "btop", "foot -a btop -T btop btop")))),
    ]


class Bad(Exception):
    pass


def run(*cmd, **kw):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=20, **kw)
    except (OSError, subprocess.TimeoutExpired) as e:
        return subprocess.CompletedProcess(cmd, 127, "", str(e))


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    target = path.resolve() if path.is_symlink() else path
    tmp = target.with_name(target.name + ".orrery-tmp")
    tmp.write_text(text)
    if target.exists():
        shutil.copymode(target, tmp)
    os.replace(tmp, target)


# --- desktop entries -------------------------------------------------------------
def desktop_apps():
    lang = (os.environ.get("LANG") or "en").split("_")[0]
    apps = {}
    for base in DATA_DIRS:
        root = base / "applications"
        for f in sorted(root.rglob("*.desktop")) if root.is_dir() else []:
            app_id = str(f.relative_to(root)).replace("/", "-")
            if app_id in apps:
                continue
            cp = configparser.RawConfigParser(strict=False, interpolation=None)
            cp.optionxform = str
            try:
                cp.read(f, encoding="utf-8")
                e = cp["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError, OSError):
                continue
            if e.get("Type") != "Application" or e.get("Hidden") == "true" or not e.get("Exec"):
                apps[app_id] = None
                continue
            command = re.sub(r"\s+", " ", re.sub(r"%[a-zA-Z]", "", e["Exec"]).replace("%%", "%")).strip()
            command = re.sub(r"\s+--\s*$", "", command)
            apps[app_id] = {
                "id": app_id, "name": e.get(f"Name[{lang}]") or e.get("Name", app_id), "command": command,
                "icon": e.get("Icon", ""), "class": e.get("StartupWMClass") or app_id.removesuffix(".desktop"),
                "wmclass": e.get("StartupWMClass", ""),
                "mime": [m for m in e.get("MimeType", "").split(";") if m],
                "categories": [c for c in e.get("Categories", "").split(";") if c],
                "hidden": e.get("NoDisplay") == "true"}
    return {k: v for k, v in apps.items() if v}


def roles_for(apps):
    out = {}
    for role in ALL_ROLES:
        if role == "terminal":
            ok = [a for a in apps.values() if "TerminalEmulator" in a["categories"]]
        elif role == "editor":
            ok = [a for a in apps.values() if "text/plain" in a["mime"] or "TextEditor" in a["categories"]]
        elif role == "browser":
            ok = [a for a in apps.values() if "x-scheme-handler/https" in a["mime"]]
        else:
            ok = [a for a in apps.values() if set(MIME[role][:2]) & set(a["mime"])]
        out[role] = sorted((a["id"] for a in ok if not a["hidden"]), key=lambda i: apps[i]["name"].lower())
    return out


def system_default(role):
    if role not in MIME:
        return ""
    return run("xdg-mime", "query", "default", MIME[role][1] if role == "browser" else MIME[role][0]).stdout.strip()


def xkb_layouts():
    names, variants, section = {}, {}, ""
    for p in ("/usr/share/X11/xkb/rules/base.lst", "/usr/share/xkeyboard-config-2/rules/base.lst"):
        if os.path.exists(p):
            for line in Path(p).read_text(errors="replace").splitlines():
                if line.startswith("! "):
                    section = line[2:].strip()
                elif line.strip() and section == "layout":
                    k, v = line.split(None, 1)
                    names[k] = v
                elif line.strip() and section == "variant":
                    m = re.match(r"\s*(\S+)\s+(\S+):\s*(.*)", line)
                    if m:
                        variants.setdefault(m[2], []).append({"id": m[1], "name": m[3]})
            break
    return [{"id": k, "name": v, "variants": variants.get(k, [])}
            for k, v in sorted(names.items(), key=lambda i: i[1]) if k != "custom"]


# --- config ------------------------------------------------------------------------
def load():
    cfg = copy.deepcopy(DEFAULT)
    try:
        data = json.loads(CONFIG.read_text())
    except (OSError, ValueError):
        return cfg, False
    for k in cfg:
        if isinstance(cfg[k], dict) and isinstance(data.get(k), dict):
            cfg[k].update(data[k])
        elif k in data:
            cfg[k] = data[k]
    return cfg, True


def line(s, what, limit=300, empty=True):
    if not isinstance(s, str) or len(s) > limit or any(ord(c) < 32 or ord(c) == 127 for c in s):
        raise Bad(f"{what}: invalid text")
    if not empty and not s.strip():
        raise Bad(f"{what}: empty")
    return s.strip()


def number(v, lo, hi, what):
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not lo <= v <= hi:
        raise Bad(f"{what}: must be between {lo} and {hi}")
    return v


def key(v, what):
    v = line(v, what, 60)
    if v and not KEY_RE.match(v):
        raise Bad(f"{what}: '{v}' is not a valid shortcut")
    return v


def validate(cfg):
    out = copy.deepcopy(DEFAULT)
    apps = desktop_apps()
    for role in ALL_ROLES:
        v = line((cfg.get("apps") or {}).get(role, ""), role)
        if v and v not in apps:
            raise Bad(f"{role}: {v} is not installed")
        out["apps"][role] = v

    kb, k = cfg.get("keyboard") or {}, out["keyboard"]
    k["managed"], k["numlock"] = bool(kb.get("managed")), bool(kb.get("numlock"))
    k["layouts"] = []
    for l in kb.get("layouts") or []:
        lay, var = str(l.get("layout", "")), str(l.get("variant", ""))
        if not LAYOUT_RE.match(lay) or not VARIANT_RE.match(var):
            raise Bad("keyboard: invalid layout")
        k["layouts"].append({"layout": lay, "variant": var})
    if not 1 <= len(k["layouts"]) <= 4:
        raise Bad("keyboard: choose between 1 and 4 layouts")
    k["switchKey"] = key(kb.get("switchKey", ""), "keyboard shortcut")
    k["repeatRate"] = int(number(kb.get("repeatRate", 35), 1, 100, "repeat rate"))
    k["repeatDelay"] = int(number(kb.get("repeatDelay", 250), 100, 2000, "repeat delay"))

    names, keys, classes = set(), {k["switchKey"]: "keyboard"} if k["managed"] and k["switchKey"] else {}, {}
    for n, a in enumerate(cfg.get("areas") or []):
        title = line(a.get("name", ""), "area name", 40, empty=False)
        area = {"id": f"area{n + 1}", "name": title, "enabled": bool(a.get("enabled", True)),
                "key": key(a.get("key", ""), title),
                "arrows": bool(a.get("arrows", True)), "wrap": bool(a.get("wrap", True)),
                "bringBack": bool(a.get("bringBack", True)),
                "openAnimation": a.get("openAnimation") if a.get("openAnimation") in OPEN_ANIM else "vertical",
                "openSpeed": number(a.get("openSpeed", 4), 1, 20, f"{title}: speed"),
                "switchAnimation": a.get("switchAnimation") if a.get("switchAnimation") in SWITCH_ANIM else "horizontal",
                "switchSpeed": number(a.get("switchSpeed", 5), 1, 20, f"{title}: speed"), "spaces": []}
        if area["enabled"] and not area["key"]:
            raise Bad(f"{title}: choose a shortcut")
        if area["enabled"]:
            if area["key"].upper() in {x.upper() for x in keys}:
                raise Bad(f"{title}: {area['key']} is already used")
            keys[area["key"]] = title
        for s in a.get("spaces") or []:
            sid = re.sub(r"[^a-z0-9_-]", "", str(s.get("id", "")).lower())[:32]
            if not sid:
                sid = f"orrery-{n + 1}-{len(area['spaces']) + 1}"
            if sid in names:
                raise Bad(f"{title}: workspace '{sid}' is used twice")
            names.add(sid)
            space = {"id": sid, "apps": []}
            for p in s.get("apps") or []:
                cls = line(p.get("class", ""), f"{title}: window class", 120, empty=False)
                if area["enabled"]:
                    if cls in classes:
                        raise Bad(f"{title}: {cls} is already in {classes[cls]}")
                    classes[cls] = title
                space["apps"].append({"class": cls, "command": line(p.get("command", ""), f"{title}: command"),
                                      "name": line(p.get("name", "") or cls, "app name", 80),
                                      "autostart": bool(p.get("autostart", True))})
            area["spaces"].append(space)
        if not 1 <= len(area["spaces"]) <= 8:
            raise Bad(f"{title}: needs between 1 and 8 workspaces")
        out["areas"].append(area)
    if len(out["areas"]) > 12:
        raise Bad("too many areas")
    return out


# --- lua ----------------------------------------------------------------------------
def lua(v, ind=0):
    pad = "    " * (ind + 1)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"' + "".join(c if 32 <= ord(c) != 127 and c not in '"\\' else f"\\{ord(c):03d}" for c in v) + '"'
    if isinstance(v, list):
        return "{}" if not v else "{\n" + "".join(f"{pad}{lua(i, ind + 1)},\n" for i in v) + "    " * ind + "}"
    if isinstance(v, dict):
        return "{}" if not v else "{\n" + "".join(f"{pad}{k} = {lua(i, ind + 1)},\n" for k, i in v.items() if i is not None) + "    " * ind + "}"
    raise TypeError(type(v))


def re2(names):
    quoted = [re.sub(r"([\\.^$|?*+()\[\]{}])", r"\\\1", s) for s in names]
    return f"(?i)^{quoted[0]}$" if len(quoted) == 1 else "(?i)^(" + "|".join(quoted) + ")$"


def every_class(cls, apps, taken):
    """Wayland windows often use the desktop id, X11 ones StartupWMClass: accept both, unless another app claims it."""
    out = [cls]
    for a in apps.values():
        names = [n for n in (a["wmclass"], a["id"].removesuffix(".desktop")) if n]
        if cls.lower() in [n.lower() for n in names]:
            out += [n for n in names if n.lower() not in [o.lower() for o in out] and n.lower() not in taken]
    return out[:6]


def settings_lua(cfg, apps):
    out = {}
    k = cfg["keyboard"]
    if k["managed"]:
        out["keyboard"] = {"layout": ",".join(l["layout"] for l in k["layouts"]),
                           "variant": ",".join(l["variant"] for l in k["layouts"]), "numlock": k["numlock"],
                           "repeat_rate": k["repeatRate"], "repeat_delay": k["repeatDelay"],
                           "switch_key": k["switchKey"] if k["switchKey"] and len(k["layouts"]) > 1 else None}
    out["apps"] = {var: apps[cfg["apps"][role]]["command"] for role, var in ROLES.items() if cfg["apps"][role]}
    taken = {p["class"].lower() for a in cfg["areas"] for s in a["spaces"] for p in s["apps"]}
    out["areas"] = [{
        "id": a["id"], "key": a["key"], "arrows": a["arrows"], "wrap": a["wrap"], "bring_back": a["bringBack"],
        "open_animation": a["openAnimation"], "open_speed": a["openSpeed"],
        "switch_animation": a["switchAnimation"], "switch_speed": a["switchSpeed"],
        "spaces": [{"name": "special:" + s["id"],
                    "apps": [{"class": p["class"], "classes": every_class(p["class"], apps, taken),
                              "class_regex": re2(every_class(p["class"], apps, taken)), "command": p["command"],
                              "autostart": p["autostart"]} for p in s["apps"]]} for s in a["spaces"]],
    } for a in cfg["areas"] if a["enabled"]]
    return "-- Generated by Orrery: do not edit, changes are overwritten.\nreturn " + lua(out) + "\n"


def strip_hook(text):
    return re.sub(r"\n?" + re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "\n", text, flags=re.S)


def with_hook(text):
    text = strip_hook(text).rstrip("\n") + "\n"
    block = f'{BEGIN}\nrequire("orrery.engine")\n{END}\n'
    m = HYPRMOD.search(text)          # HyprMod must stay last
    if not m:
        return text + "\n" + block
    start = m.start()
    head = text[:start].rstrip("\n").split("\n")
    while head and head[-1].lstrip().startswith("--"):
        start -= len(head.pop()) + 1
    start = max(start, 0)
    return text[:start].rstrip("\n") + "\n\n" + block + "\n" + text[start:].lstrip("\n")


# --- backup / apply ---------------------------------------------------------------------
TRACKED = {"hypr-user.lua": USER_LUA, "engine.lua": LUADIR / "engine.lua", "settings.lua": LUADIR / "settings.lua",
           "mimeapps.list": MIMEAPPS, "config.json": CONFIG}


def backup():
    d = BACKUPS / datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    d.mkdir(parents=True)
    for name, path in TRACKED.items():
        if path.exists():
            shutil.copy2(path, d / name)
    for old in sorted(BACKUPS.iterdir())[:-20]:
        shutil.rmtree(old, ignore_errors=True)
    return d


def restore(d):
    for name, path in TRACKED.items():
        if (d / name).exists():
            write(path, (d / name).read_text())
        elif path.exists():
            path.unlink()


def hypr_errors():
    if DRY or not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return ""
    run("hyprctl", "reload")
    import time
    time.sleep(1.2)
    e = run("hyprctl", "configerrors").stdout.strip()
    return "" if e.lower() in ("", "no errors", "ok") else e


def apply(cfg):
    cfg = validate(cfg)
    apps = desktop_apps()
    if not (CONF / "hypr/hyprland.lua").exists() and not DRY:
        raise Bad("Caelestia's Hyprland config was not found")
    before = hypr_errors()
    d = backup()
    try:
        write(LUADIR / "engine.lua", (SHARE / "lua/engine.lua").read_text())
        write(LUADIR / "settings.lua", settings_lua(cfg, apps))
        write(USER_LUA, with_hook(USER_LUA.read_text() if USER_LUA.exists() else ""))
        write(CONFIG, json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
        if not DRY:
            for role, mimes in MIME.items():
                if cfg["apps"][role]:
                    run("xdg-mime", "default", cfg["apps"][role], *mimes)
        errors = hypr_errors()
    except BaseException:
        restore(d)
        hypr_errors()
        raise
    if errors and errors != before:
        restore(d)
        hypr_errors()
        raise Bad("Hyprland rejected the changes, previous settings restored: " + errors[:400])
    return {"ok": True, "config": cfg, "backup": d.name}


def undo():
    all_ = sorted(BACKUPS.iterdir()) if BACKUPS.is_dir() else []
    if not all_:
        raise Bad("nothing to undo")
    restore(all_[-1])
    shutil.rmtree(all_[-1])
    hypr_errors()
    return {"ok": True}


def disable():
    backup()
    if USER_LUA.exists():
        write(USER_LUA, strip_hook(USER_LUA.read_text()).rstrip("\n") + "\n")
    hypr_errors()
    return {"ok": True}


PREFS = {"language": "auto", "follow": True, "transparent": True, "base": 0.85, "layers": 0.4, "speed": 1.0, "rounding": 1.0}


def prefs(new):
    """Look of the app itself: saved at once, never touches Hyprland."""
    out = dict(PREFS)
    path = OWN / "ui.json"
    try:
        old = json.loads(path.read_text())
        out.update({k: old[k] for k in PREFS if k in old})
    except (OSError, ValueError):
        pass
    out.update({k: v for k, v in new.items() if k in PREFS})
    if out["language"] not in ("auto", "en", "it"):
        raise Bad("language: unknown")
    for k in ("follow", "transparent"):
        out[k] = bool(out[k])
    for k, lo, hi in (("base", 0.1, 1), ("layers", 0.05, 1), ("speed", 0.05, 4), ("rounding", 0, 2)):
        out[k] = round(float(number(out[k], lo, hi, k)), 3)
    write(path, json.dumps(out, indent=2) + "\n")
    return {"ok": True}


# --- wallpapers ----------------------------------------------------------------------
WALLS = {"dawn": ("orrery-dawn.png", "light"), "night": ("orrery-night.png", "dark")}


def shell_json():
    try:
        d = json.loads((CAEL / "shell.json").read_text())
    except FileNotFoundError:
        return {}
    if not isinstance(d, dict):
        raise Bad("shell.json is not an object")
    return d          # broken JSON raises ValueError: never overwrite it


def walls_dir():
    """Where Caelestia looks (its default is ~/Pictures/Wallpapers, whatever the system language)."""
    p = (shell_json().get("paths") or {}).get("wallpaperDir")
    if p:
        return Path(re.sub(r"^(~|\$HOME|\$\{HOME\})(?=/|$)", str(HOME), str(p)))
    return HOME / "Pictures/Wallpapers"


def pictures_dir():
    p = run("xdg-user-dir", "PICTURES").stdout.strip()
    return Path(p) if p and Path(p) != HOME else HOME / "Pictures"


def wall_list():
    r = run("caelestia", "shell", "wallpaper", "list")
    return [l for l in r.stdout.splitlines() if l.startswith("/")] if r.returncode == 0 else None


def point_shell(path):
    """Writes paths.wallpaperDir. Caelestia reloads shell.json live, so no restart is needed."""
    d = shell_json()
    d.setdefault("paths", {})["wallpaperDir"] = str(path)
    write(CAEL / "shell.json", json.dumps(d, indent=4, ensure_ascii=False) + "\n")


def wall_state():
    try:
        cur = walls_dir()
        want = pictures_dir() / "Wallpapers"
    except (Bad, ValueError):
        return {"error": "shell.json"}
    listed = None if DRY else wall_list()
    have = [p for p in cur.iterdir() if p.is_file()] if cur.is_dir() else []
    return {"dir": str(cur), "exists": cur.is_dir(), "suggested": str(want), "files": len(have),
            "installed": all((cur / f).exists() for f, _ in WALLS.values()), "seen": listed is not None and (len(listed) > 0 or not have),
            "running": listed is not None, "previews": {k: str(SHARE / "wallpapers" / f) for k, (f, _) in WALLS.items()}}


def refresh(target):
    """Makes a running shell notice the folder: its watcher ignores folders created after it started."""
    import time
    before = shell_json()
    names = {f for f, _ in WALLS.values()}
    # Changing the path (even to an equivalent one) makes Caelestia scan it again
    point_shell(f"{target}/.")
    time.sleep(0.9)
    point_shell(target)
    if DRY:
        return True
    for _ in range(12):
        time.sleep(0.4)
        listed = wall_list()
        if listed is None:
            return False
        if any(Path(p).name in names for p in listed) or (listed and not any((Path(target) / n).exists() for n in names)):
            return True
    return False


def wallpapers(opts):
    target = Path(opts.get("dir") or pictures_dir() / "Wallpapers").expanduser()
    if not target.is_absolute() or HOME not in (target / "x").resolve().parents:
        raise Bad("the folder must be inside your home")
    shell_json()      # stop early if it is broken
    target.mkdir(parents=True, exist_ok=True)
    added = []
    for f, _ in WALLS.values():
        if not (target / f).exists():
            shutil.copyfile(SHARE / "wallpapers" / f, target / f)
            added.append(f)
    live = refresh(target)
    return {"ok": True, "dir": str(target), "added": added, "live": live}


def use_wallpaper(opts):
    name = opts.get("name")
    if name not in WALLS:
        raise Bad("unknown wallpaper")
    f, mode = WALLS[name]
    path = walls_dir() / f
    if not path.exists():
        raise Bad("set up the wallpapers first")
    if not DRY:
        for cmd in (["caelestia", "scheme", "set", "-n", "dynamic"], ["caelestia", "scheme", "set", "-m", mode],
                    ["caelestia", "wallpaper", "-N", "-f", str(path)]):
            r = run(*cmd)
            if r.returncode != 0:
                raise Bad((r.stderr or r.stdout).strip()[-300:] or " ".join(cmd))
    return {"ok": True}


# --- state -----------------------------------------------------------------------------
def windows():
    try:
        clients = json.loads(run("hyprctl", "clients", "-j").stdout)
    except ValueError:
        return []
    seen = {}
    for c in clients:
        if c.get("class") and c["class"] not in seen:
            seen[c["class"]] = {"class": c["class"], "title": c.get("title", "")[:60]}
    return list(seen.values())


def option(name):
    try:
        d = json.loads(run("hyprctl", "getoption", name, "-j").stdout)
    except ValueError:
        return None
    return next((d[k] for k in ("str", "int", "float", "bool") if k in d), None)


def conflicts():
    """Hand-made snippets that would fight with Orrery."""
    text = strip_hook(USER_LUA.read_text()) if USER_LUA.exists() else ""
    code = "\n".join(l.split("--", 1)[0] for l in text.splitlines())
    found = []
    if re.search(r'require\(\s*["\']comms["\']', code):
        found.append("comms")
    if "switchxkblayout" in code:
        found.append("switchkey")
    if "kb_layout" in code:
        found.append("kb_layout")
    return found


def state():
    cfg, saved = load()
    apps = desktop_apps()
    if not saved:     # first run: nothing is changed unless chosen
        layouts = str(option("input:kb_layout") or "us").split(",")
        variants = str(option("input:kb_variant") or "").split(",")
        variants += [""] * len(layouts)
        ok = [{"layout": l.strip(), "variant": v.strip()} for l, v in zip(layouts, variants) if LAYOUT_RE.match(l.strip())]
        cfg["keyboard"]["layouts"] = ok[:4] or cfg["keyboard"]["layouts"]
        cfg["keyboard"]["numlock"] = bool(option("input:numlock_by_default"))
        cfg["areas"] = presets(apps)
    helper = "/usr/lib/orrery/orrery-helper"
    walls = wall_state()
    greeter = ""
    try:
        m = re.search(r'^\s*command\s*=\s*"([^"]+)"', Path("/etc/greetd/config.toml").read_text(), re.M)
        greeter = m[1] if m else ""
    except OSError:
        pass
    return {
        "config": cfg, "saved": saved, "apps": sorted(apps.values(), key=lambda a: a["name"].lower()),
        "roles": roles_for(apps), "defaults": {r: system_default(r) for r in ALL_ROLES}, "layouts": xkb_layouts(), "windows": windows(), "conflicts": conflicts(),
        "active": USER_LUA.exists() and BEGIN in USER_LUA.read_text(),
        "walls": walls,
        "canUndo": BACKUPS.is_dir() and any(BACKUPS.iterdir()),
        "system": {
            "helper": os.path.exists(helper), "caelestia": (CONF / "hypr/hyprland.lua").exists(),
            "backlight": {"present": LED is not None,
                          "max": int((LED / "max_brightness").read_text()) if LED else 0,
                          "unit": next((u for u in ("orrery-kbd-backlight.service", "kbd-backlight-on.service")
                                        if os.path.exists(f"/etc/systemd/system/{u}")), "")},
            "login": {"greetd": os.path.exists("/etc/greetd/config.toml"), "command": greeter,
                      "packages": {p: shutil.which(b) is not None for p, b in
                                   (("cage", "cage"), ("quickshell-greetd", "quickshell-greetd-launcher"))}}}}


def check():
    out = []
    def add(i, ok, detail=""):
        out.append({"id": i, "ok": ok, "detail": detail})
    qs = run("quickshell", "--private-check-compat")
    add("quickshell", shutil.which("quickshell") is not None and not re.search("built against|rebuil", qs.stdout + qs.stderr))
    add("noctaliaqs", run("pacman", "-Qq", "noctalia-qs").returncode != 0)
    e = run("hyprctl", "configerrors").stdout.strip()
    add("hyprland", e.lower() in ("", "no errors"), e[:300])
    add("shell", "/quickshell/caelestia/shell.qml" in run("qs", "list", "--all").stdout)
    add("hook", USER_LUA.exists() and BEGIN in USER_LUA.read_text())
    add("conflicts", not conflicts(), ", ".join(conflicts()))
    return {"checks": out}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "state"
    try:
        takes = {"apply": apply, "prefs": prefs, "wallpapers": wallpapers, "use-wallpaper": use_wallpaper}
        if cmd in takes:
            res = takes[cmd](json.load(sys.stdin))
        else:
            res = {"state": state, "undo": undo, "disable": disable, "check": check, "walls": wall_state,
                   "windows": lambda: {"windows": windows()}}[cmd]()
    except Bad as e:
        res = {"ok": False, "error": str(e)}
    except KeyError:
        res = {"ok": False, "error": f"unknown command {cmd}"}
    except (ValueError, OSError) as e:
        res = {"ok": False, "error": f"{type(e).__name__}: {e}"}
    json.dump(res, sys.stdout, ensure_ascii=False)
    sys.exit(0 if res.get("ok", True) else 1)


if __name__ == "__main__":
    main()
