#!/usr/bin/python3 -I
"""Orrery backend: reads and writes the user's settings. Never runs as root."""
import configparser, copy, datetime, json, os, re, shlex, shutil, subprocess, sys, time
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
    # our other apps: Specola, the gallery, on a key of its own when it is installed
    "gallery": {"enabled": True, "key": "SUPER + G"},
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


def mimeapps_defaults():
    """[Default Applications] of every mimeapps.list, in the order the XDG spec reads them (first wins)."""
    desktops = [d.lower() for d in (os.environ.get("XDG_CURRENT_DESKTOP") or "").split(":") if d]
    dirs = [CONF] + [Path(p) for p in (os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg").split(":") if p]
    dirs += [d / "applications" for d in DATA_DIRS]
    out = {}
    for d in dirs:
        for name in [f"{x}-mimeapps.list" for x in desktops] + ["mimeapps.list"]:
            cp = configparser.RawConfigParser(strict=False, interpolation=None, delimiters=("=",))
            cp.optionxform = str
            try:
                cp.read(d / name, encoding="utf-8")
            except (configparser.Error, UnicodeDecodeError):
                continue
            if cp.has_section("Default Applications"):
                for mime, apps in cp.items("Default Applications"):
                    out.setdefault(mime, [a for a in apps.split(";") if a.strip()])
    # No choice made: xdg-mime then takes the first app that declares the type (mimeinfo.cache)
    for d in DATA_DIRS:
        for name, sec in (("defaults.list", "Default Applications"), ("mimeinfo.cache", "MIME Cache")):
            cp = configparser.RawConfigParser(strict=False, interpolation=None, delimiters=("=",))
            cp.optionxform = str
            try:
                cp.read(d / "applications" / name, encoding="utf-8")
            except (configparser.Error, UnicodeDecodeError):
                continue
            if cp.has_section(sec):
                for mime, apps in cp.items(sec):
                    out.setdefault(mime, [a for a in apps.split(";") if a.strip()])
    return out


def system_default(role, apps=None, table=None):
    """Like xdg-mime query default, without starting a shell script per type (9 of them took a quarter of a second)."""
    if role not in MIME:
        return ""
    mime = MIME[role][1] if role == "browser" else MIME[role][0]
    for a in (table if table is not None else mimeapps_defaults()).get(mime, []):
        if apps is None or a.strip() in apps:
            return a.strip()
    return run("xdg-mime", "query", "default", mime).stdout.strip()


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

    g = cfg.get("gallery") or {}
    out["gallery"]["enabled"] = bool(g.get("enabled", True))
    key_ = str(g.get("key") or "SUPER + G").strip().upper()
    if not KEY_RE.match(key_):
        raise Bad("gallery: invalid shortcut")
    out["gallery"]["key"] = key_

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
    g = cfg.get("gallery") or {}
    if g.get("enabled", True) and shutil.which("specola"):
        out["binds"] = [{"key": g.get("key") or "SUPER + G", "command": "specola"}]
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


# --- power -------------------------------------------------------------------------
# Lives in Caelestia's shell.json (general.idle), which stays the only source of truth: nothing is copied in config.json.
# A user list replaces Caelestia's defaults entirely (2.5.0), so the rows are always written together.
IDLE_ROWS = [{"timeout": 180, "idleAction": "lock"},
             {"timeout": 300, "idleAction": "dpms off", "returnAction": "dpms on"},
             {"timeout": 600, "idleAction": ["suspendThenHibernate"]}]
IDLE_FLAGS = {"lockBefore": ("lockBeforeSleep", True), "audio": ("inhibitWhenAudio", True), "charging": ("inhibitWhenCharging", False)}
IDLE_TIMES = ("lock", "screen", "battery", "ac")
SLEEP = {"suspend": "suspend", "hibernate": "suspendThenHibernate"}


def row_kind(row):
    """lock / screen / suspend / hibernate; None for the user's own rows, which are never touched."""
    a = row.get("idleAction") if isinstance(row, dict) else None
    if isinstance(a, str):
        return {"lock": "lock", "dpms off": "screen"}.get(a)
    if not isinstance(a, list) or not a or not all(isinstance(x, str) for x in a):
        return None
    words = [re.sub(r"[-_]", "", x).lower() for x in a]
    if len(words) == 2 and words[0] in ("systemctl", "loginctl"):
        words = words[1:]
    return {("suspend",): "suspend", ("suspendthenhibernate",): "hibernate", ("locksession",): "lock"}.get(tuple(words))


def idle_json():
    general = shell_json().get("general", {})
    idle = general.get("idle", {}) if isinstance(general, dict) else None
    if not isinstance(idle, dict) or not isinstance(idle.get("timeouts", []), list):
        raise Bad("shell.json: general.idle is not valid")
    return idle


def idle_rows(idle):
    """All the rows, and the ones Orrery handles: the first of each kind."""
    rows, mine = copy.deepcopy(idle.get("timeouts", IDLE_ROWS)), {}
    for n, r in enumerate(rows):
        k = row_kind(r)
        if k in SLEEP:
            k = "battery" if r.get("inhibitWhenCharging") is True else "ac"
        if k:
            mine.setdefault(k, n)
    return rows, mine


def seconds(row):
    t = row.get("timeout", 300)
    return int(t) if row.get("enabled", True) is not False and isinstance(t, (int, float)) and t > 0 else 0


def read_power(idle=None):
    idle = idle_json() if idle is None else idle
    rows, mine = idle_rows(idle)
    out = {k: seconds(rows[mine[k]]) if k in mine else 0 for k in IDLE_TIMES}
    # The row without conditions also works on battery: the shorter one wins
    out["battery"] = min([t for t in (out["battery"], out["ac"]) if t], default=0)
    kinds = [row_kind(rows[mine[k]]) for k in ("ac", "battery") if k in mine]
    out["action"] = kinds[0] if kinds else "hibernate"
    for k, (name, default) in IDLE_FLAGS.items():
        v = idle.get(name, default)
        out[k] = v if isinstance(v, bool) else default
    return out


def check_power(p):
    out = {}
    for k, name in (("lock", "lock"), ("screen", "screen off"), ("battery", "suspend on battery"), ("ac", "suspend while charging")):
        v = p.get(k)
        out[k] = int(number(v, 10, 86400, name)) if v != 0 or isinstance(v, bool) else 0
    if out["ac"] and not 0 < out["battery"] <= out["ac"]:
        raise Bad("suspend: the time on battery cannot be longer than the one while charging")
    if p.get("action") not in SLEEP:
        raise Bad("suspend: unknown action")
    out["action"] = p["action"]
    for k in IDLE_FLAGS:
        out[k] = bool(p.get(k))
    return out


def with_power(idle, new):
    """general.idle with the new values, leaving everything else in it alone."""
    old, idle = read_power(idle), copy.deepcopy(idle)
    for k, (name, default) in IDLE_FLAGS.items():
        if new[k] != old[k]:
            idle[name] = new[k]
            if new[k] == default:
                del idle[name]
    if all(new[k] == old[k] for k in (*IDLE_TIMES, "action")):
        return idle
    rows, mine = idle_rows(idle)
    want = {"lock": new["lock"], "screen": new["screen"], "ac": new["ac"],
            "battery": new["battery"] if new["battery"] != new["ac"] else 0}
    sleep = copy.deepcopy(rows[mine["ac"]] if "ac" in mine else rows[mine["battery"]] if "battery" in mine else IDLE_ROWS[2])
    sleep.pop("inhibitWhenCharging", None)
    fresh = {"lock": IDLE_ROWS[0], "screen": IDLE_ROWS[1], "battery": {**sleep, "inhibitWhenCharging": True}, "ac": sleep}
    for k in ("lock", "screen", "battery", "ac"):
        if k not in mine:
            if not want[k]:
                continue
            mine[k] = len(rows)
            rows.append(copy.deepcopy(fresh[k]))
        row = rows[mine[k]]
        if want[k]:
            row["timeout"] = want[k]
            row.pop("enabled", None)
        else:
            row["enabled"] = False
        if k in ("battery", "ac") and row_kind(row) != new["action"]:
            row["idleAction"] = [SLEEP[new["action"]]]
    if rows == IDLE_ROWS:
        idle.pop("timeouts", None)      # back to Caelestia's defaults
    else:
        idle["timeouts"] = rows
    return idle


def put_idle(idle):
    """Replaces general.idle only (an empty one is removed)."""
    put_shell({"general.idle": idle or MISSING})


# --- shell settings ---------------------------------------------------------------------
# Battery warnings, on-screen indicators and the bar, also straight in shell.json. A key equal to Caelestia's
# default is removed, so updates to Caelestia's defaults still reach you. Lists replace the defaults whole.
WARN_LEVELS = [
    {"level": 20, "title": "Low battery", "message": "You might want to plug in a charger", "icon": "battery_android_frame_2"},
    {"level": 10, "title": "Did you see the previous message?", "message": "You should probably plug in a charger <b>now</b>",
     "icon": "battery_android_frame_1"},
    {"level": 5, "title": "Critical battery level", "message": "PLUG THE CHARGER RIGHT NOW!!", "icon": "battery_android_alert",
     "critical": True}]
BATTERY = {"warnLevels": WARN_LEVELS, "criticalLevel": 3}
OSD = {"enabled": True, "hideDelay": 2000, "enableBrightness": True, "enableMicrophone": False}
# The pictures Caelestia shows: path in shell.json, default. The notification ones are still images, drawn as a silhouette.
GIFS = {"media": ("paths.mediaGif", "root:/assets/bongocat.gif"), "session": ("paths.sessionGif", "root:/assets/kurukuru.gif"),
        "notifs": ("paths.noNotifsPic", "root:/assets/dino.png"), "lock": ("paths.lockNoNotifsPic", "root:/assets/dino.png")}
SPEEDS = {"mediaSpeed": ("general.mediaGifSpeedAdjustment", 300, 30, 3000), "sessionSpeed": ("general.sessionGifSpeed", 0.7, 0.1, 5)}
IMG_EXT = (".gif", ".webp", ".png", ".jpg", ".jpeg", ".svg")
# Plain options: key -> (path in shell.json, Caelestia's default, range | choices | "text" | None for a switch)
CLOCK_AT = [f"{v}-{h}" for v in ("top", "middle", "bottom") for h in ("left", "center", "right")]
DC, VIS = "background.desktopClock", "background.visualiser"
SIMPLE = {
    "desktop": {"clock": (f"{DC}.enabled", False, None), "clockPosition": (f"{DC}.position", "bottom-right", CLOCK_AT),
                "clockScale": (f"{DC}.scale", 1.0, (0.25, 4)), "clockInvert": (f"{DC}.invertColors", False, None),
                "clockBg": (f"{DC}.background.enabled", False, None), "clockBgOpacity": (f"{DC}.background.opacity", 0.7, (0, 1)),
                "clockBgBlur": (f"{DC}.background.blur", True, None), "clockShadow": (f"{DC}.shadow.enabled", True, None),
                "clockShadowOpacity": (f"{DC}.shadow.opacity", 0.7, (0, 1)), "clockShadowBlur": (f"{DC}.shadow.blur", 0.4, (0, 1)),
                "vis": (f"{VIS}.enabled", False, None), "visAutoHide": (f"{VIS}.autoHide", True, None),
                "visBlur": (f"{VIS}.blur", False, None), "visRounding": (f"{VIS}.rounding", 1.0, (0, 2)),
                "visSpacing": (f"{VIS}.spacing", 1.0, (0, 4))},
    "panels": {"weather": ("services.weatherLocation", "", "text"), "notifClick": ("notifs.actionOnClick", False, None),
               "notifFullscreen": ("notifs.fullscreenExpireTimeout", 2000, (500, 60000))},
}
# The third button of the shut down menu: Hibernate does nothing on a computer that cannot hibernate
SESSION_BUTTON = {"hibernate": (["hibernate"], "downloading"), "suspend": (["suspend"], "bedtime"),
                  "lock": (["loginctl", "lock-session"], "lock")}


def simple_ok(default, spec):
    if isinstance(default, bool):
        return lambda x: isinstance(x, bool)
    if isinstance(default, (int, float)):
        return lambda x: isinstance(x, (int, float)) and not isinstance(x, bool)
    return lambda x: isinstance(x, str)
BAR_IDS = ("logo", "workspaces", "spacer", "activeWindow", "tray", "clock", "statusIcons", "power")
BAR_ENTRIES = [{"id": i, "enabled": True} for i in
               ("logo", "workspaces", "spacer", "activeWindow", "spacer", "tray", "clock", "statusIcons", "power")]
ID_RE, ICON_RE = re.compile(r"[A-Za-z0-9_]{1,40}$"), re.compile(r"[a-z0-9_]{0,64}$")
MISSING = object()


def get_path(d, path):
    for k in path.split("."):
        if not isinstance(d, dict) or k not in d:
            return MISSING
        d = d[k]
    return d


def set_path(d, path, v):
    """Sets or (MISSING) removes a key, dropping parents left empty. Refuses to replace a value that is not an object."""
    *parents, last = path.split(".")
    chain = [d]
    for k in parents:
        nxt = chain[-1].get(k, MISSING)
        if nxt is MISSING:
            if v is MISSING:
                return
            nxt = chain[-1][k] = {}
        if not isinstance(nxt, dict):
            raise Bad(f"shell.json: {k} is not valid")
        chain.append(nxt)
    if v is MISSING:
        chain[-1].pop(last, None)
        for k, parent in zip(reversed(parents), reversed(chain[:-1])):
            if parent[k]:
                break
            del parent[k]
    else:
        chain[-1][last] = copy.deepcopy(v)


def read_shell(d=None):
    """What Caelestia uses: the value in shell.json when it is usable, otherwise its default."""
    d = shell_json() if d is None else d
    def pick(path, default, ok):
        v = get_path(d, path)
        return copy.deepcopy(v if v is not MISSING and ok(v) else default)
    out = {"battery": {"warnLevels": pick("general.battery.warnLevels", WARN_LEVELS,
                                          lambda v: isinstance(v, list) and all(isinstance(x, dict) for x in v)),
                       "criticalLevel": pick("general.battery.criticalLevel", 3, lambda v: isinstance(v, int) and not isinstance(v, bool))},
           "osd": {k: pick(f"osd.{k}", v, lambda x, v=v: type(x) is type(v)) for k, v in OSD.items()},
           "bar": {"entries": pick("bar.entries", BAR_ENTRIES,
                                   lambda v: isinstance(v, list) and all(isinstance(x, dict) and isinstance(x.get("id"), str) for x in v)),
                   "excludedScreens": pick("bar.excludedScreens", [], lambda v: isinstance(v, list) and all(isinstance(x, str) for x in v))},
           "gifs": {**{k: pick(path, v, lambda x: isinstance(x, str) and x != "") for k, (path, v) in GIFS.items()},
                    **{k: pick(path, v, lambda x: isinstance(x, (int, float)) and not isinstance(x, bool)) for k, (path, v, *_) in SPEEDS.items()}}}
    for sec, opts in SIMPLE.items():
        out[sec] = {k: pick(path, v, simple_ok(v, spec)) for k, (path, v, spec) in opts.items()}
    cmd = get_path(d, "session.commands.hibernate")
    out["panels"]["sessionButton"] = "hibernate" if cmd is MISSING else next(
        (k for k, (c, _) in SESSION_BUTTON.items() if c == cmd), "custom")
    return out


def extra(src, known, what):
    """Keys of a list entry Orrery does not edit, kept as they are when they are plain values."""
    out = {}
    for k, v in src.items():
        if k in known or not isinstance(k, str) or len(k) > 40:
            continue
        if isinstance(v, str):
            v = line(v, what)
        elif v is not None and not isinstance(v, (bool, int, float)):
            continue
        out[k] = v
    return out


def check_shell(s, old):
    """A section left as it was is not checked again: a strange hand-made value never blocks the rest."""
    out = {}
    b = s.get("battery") or {}
    if b == old["battery"]:
        out["battery"] = old["battery"]
    else:
        levels = []
        for w in b.get("warnLevels") or []:
            if not isinstance(w, dict):
                raise Bad("battery warning: invalid")
            x = {**extra(w, ("level", "title", "message", "icon", "critical"), "battery warning"),
                 "level": int(number(w.get("level"), 1, 99, "battery warning"))}
            for k in ("title", "message"):
                if k in w:
                    x[k] = line(w[k], f"battery warning: {k}")
            if "icon" in w:
                if not isinstance(w["icon"], str) or not ICON_RE.match(w["icon"]):
                    raise Bad("battery warning: invalid icon")
                x["icon"] = w["icon"]
            if "critical" in w:
                x["critical"] = bool(w["critical"])
            levels.append(x)
        if len(levels) > 8:
            raise Bad("battery: too many warnings")
        crit = b.get("criticalLevel", 3)
        crit = -1 if crit == -1 and not isinstance(crit, bool) else int(number(crit, 1, 50, "hibernate on low battery"))
        out["battery"] = {"warnLevels": levels, "criticalLevel": crit}
    o = s.get("osd") or {}
    if o == old["osd"]:
        out["osd"] = old["osd"]
    else:
        out["osd"] = {"enabled": bool(o.get("enabled", True)), "hideDelay": int(number(o.get("hideDelay", 2000), 500, 10000, "indicator duration")),
                      "enableBrightness": bool(o.get("enableBrightness", True)), "enableMicrophone": bool(o.get("enableMicrophone", False))}
    bar = s.get("bar") or {}
    if bar == old["bar"]:
        out["bar"] = old["bar"]
    else:
        entries = []
        for e in bar.get("entries") or []:
            if not isinstance(e, dict) or not isinstance(e.get("id"), str) or not ID_RE.match(e["id"]):
                raise Bad("bar: invalid entry")
            entries.append({**extra(e, ("id", "enabled"), "bar entry"), "id": e["id"], "enabled": bool(e.get("enabled", True))})
        if len(entries) > 30:
            raise Bad("bar: too many entries")
        screens = [line(x, "bar: screen", 200, empty=False) for x in bar.get("excludedScreens") or []]
        if len(screens) > 30:
            raise Bad("bar: too many screens")
        out["bar"] = {"entries": entries, "excludedScreens": screens}
    g = s.get("gifs") or {}
    if g == old["gifs"]:
        out["gifs"] = old["gifs"]
    else:
        out["gifs"] = {}
        for k, (_, default) in GIFS.items():
            v = g.get(k, default)
            if v != default:
                v = line(v, "picture", 1024, empty=False)
                f = Path(v)
                if not f.is_absolute() or f.suffix.lower() not in IMG_EXT or not f.is_file():
                    raise Bad(f"picture: {v} is not an image file")
            out["gifs"][k] = v
        for k, (_, default, lo, hi) in SPEEDS.items():
            out["gifs"][k] = round(float(number(g.get(k, default), lo, hi, "animation speed")), 3)
    for sec, opts in SIMPLE.items():
        new = s.get(sec) or {}
        if new == old[sec]:
            out[sec] = old[sec]
            continue
        out[sec] = {}
        for k, (path, default, spec) in opts.items():
            v = new.get(k, default)
            if v == old[sec].get(k):
                out[sec][k] = v           # unchanged, even if written by hand
            elif spec is None:
                out[sec][k] = bool(v)
            elif spec == "text":
                out[sec][k] = line(v, k, 120)
            elif isinstance(spec, list):
                if v not in spec:
                    raise Bad(f"{k}: unknown choice")
                out[sec][k] = v
            else:
                v = number(v, spec[0], spec[1], k)
                out[sec][k] = int(v) if isinstance(default, int) else round(float(v), 3)
        if sec == "panels":
            b = new.get("sessionButton", old["panels"]["sessionButton"])
            if b != old["panels"]["sessionButton"] and b not in SESSION_BUTTON:
                raise Bad("session button: unknown choice")
            out[sec]["sessionButton"] = b
    return out


def shell_changes(old, new):
    """{path: value or MISSING} for what differs from what Caelestia uses now. Nothing else in shell.json is touched."""
    out = {}
    def put(path, now, was, default):
        if now != was:
            out[path] = MISSING if now == default else now
    put("general.battery.warnLevels", new["battery"]["warnLevels"], old["battery"]["warnLevels"], WARN_LEVELS)
    put("general.battery.criticalLevel", new["battery"]["criticalLevel"], old["battery"]["criticalLevel"], 3)
    for k, v in OSD.items():
        put(f"osd.{k}", new["osd"][k], old["osd"][k], v)
    put("bar.entries", new["bar"]["entries"], old["bar"]["entries"], BAR_ENTRIES)
    put("bar.excludedScreens", new["bar"]["excludedScreens"], old["bar"]["excludedScreens"], [])
    for k, (path, default, *_) in {**GIFS, **SPEEDS}.items():
        put(path, new["gifs"][k], old["gifs"][k], default)
    for sec, opts in SIMPLE.items():
        for k, (path, default, _) in opts.items():
            put(path, new[sec][k], old[sec][k], default)
    b = new["panels"]["sessionButton"]
    if b != old["panels"]["sessionButton"] and b in SESSION_BUTTON:
        cmd, icon = SESSION_BUTTON[b]
        out["session.commands.hibernate"] = MISSING if b == "hibernate" else cmd
        out["session.icons.hibernate"] = MISSING if b == "hibernate" else icon
    return out


def put_shell(changes):
    """Writes several keys of shell.json at once. Caelestia reloads it live."""
    if not changes:
        return
    d = shell_json()
    for path, v in changes.items():
        set_path(d, path, v)
    write(CAEL / "shell.json", json.dumps(d, indent=4, ensure_ascii=False) + "\n")


# --- pictures and GIPHY ---------------------------------------------------------------
GIF_DIR = DATA_DIRS[0] / "orrery/gifs"
GIPHY_KEY = OWN / "giphy.json"
GIPHY = "https://api.giphy.com/v1"
MAX_PIC = 25 * 1024 * 1024


THUMBS = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "orrery/thumbs"


def thumb(path, width=480):
    """A small WebP copy of a still picture, so the interface never decodes a 4K image (Qt does it at full size).
    Animations are returned as they are. Falls back to the original when Pillow cannot read it."""
    f = Path(path)
    try:
        st = f.stat()
    except OSError:
        return str(path)
    if f.suffix.lower() not in (".png", ".jpg", ".jpeg"):
        return str(f)       # animations and vectors stay as they are
    import hashlib
    out = THUMBS / (hashlib.sha1(f"{f}:{st.st_mtime_ns}:{st.st_size}:{width}".encode()).hexdigest()[:24] + ".webp")
    if out.exists():
        return str(out)
    try:
        from PIL import Image
        im = Image.open(f)
        if max(im.size) <= width * 1.5:
            return str(f)   # already small: reading the header was enough
        im.draft("RGB", (width * 2, width * 2))       # JPEG: decodes directly at a smaller size
        im.thumbnail((width, width * 4), Image.LANCZOS)
        if im.mode not in ("RGB", "RGBA"):
            im = im.convert("RGBA")
        THUMBS.mkdir(parents=True, exist_ok=True)
        tmp = out.with_name(out.name + ".orrery-tmp")
        im.save(tmp, "WEBP", quality=82, method=4)
        os.replace(tmp, out)
        return str(out)
    except Exception:
        return str(f)


def thumb_cached(path, width):
    """The thumbnail if it was made already (only a stat, nothing is opened)."""
    import hashlib
    try:
        st = Path(path).stat()
    except OSError:
        return ""
    out = THUMBS / (hashlib.sha1(f"{Path(path)}:{st.st_mtime_ns}:{st.st_size}:{width}".encode()).hexdigest()[:24] + ".webp")
    return str(out) if out.exists() else ""


def pic_thumbs(opts):
    """Thumbnails for the picture chooser, made in parallel (Pillow decodes outside the GIL)."""
    from concurrent.futures import ThreadPoolExecutor
    paths = [p for p in (opts.get("paths") or [])[:300] if isinstance(p, str) and p.startswith("/")]
    with ThreadPoolExecutor(6) as ex:
        return {"ok": True, "thumbs": dict(zip(paths, ex.map(lambda p: thumb(p, 280), paths)))}


def shell_dir():
    for d in (CONF / "quickshell/caelestia", Path("/etc/xdg/quickshell/caelestia")):
        if (d / "shell.qml").exists():
            return d
    return None


def resolve_pic(p):
    """root:/assets/x is inside Caelestia; ~ and $HOME work as in Caelestia."""
    if p.startswith("root:/"):
        d = shell_dir()
        return str(d / p[6:]) if d else ""
    return re.sub(r"^(~|\$HOME|\$\{HOME\})(?=/|$)", str(HOME), p)


def alpha_info(src):
    """Is the background see-through? Looks at the edges of the first frame and of one in the middle:
    at least half of the border must be clear. None when Pillow is missing or the image cannot be read."""
    try:
        from PIL import Image
    except ImportError:
        return None
    import io
    try:
        im = Image.open(io.BytesIO(src) if isinstance(src, bytes) else src)
        frames = getattr(im, "n_frames", 1)
        size, clear = im.size, 1.0
        for n in sorted({0, frames // 2}):
            im.seek(n)
            a = im.convert("RGBA").getchannel("A")
            w, h = a.size
            edge = [a.getpixel((x, y)) for x in range(0, w, max(1, w // 64)) for y in (0, h - 1)]
            edge += [a.getpixel((x, y)) for y in range(0, h, max(1, h // 64)) for x in (0, w - 1)]
            clear = min(clear, sum(v < 32 for v in edge) / len(edge))
        return {"transparent": clear >= 0.5, "frames": frames, "width": size[0], "height": size[1], "format": im.format}
    except Exception:
        return None


def pic_info(opts):
    p = resolve_pic(line(opts.get("path", ""), "picture", 1024, empty=False))
    if not p or not Path(p).is_file():
        raise Bad("picture not found")
    if p.lower().endswith(".svg"):
        return {"ok": True, "path": p, "info": {"transparent": True, "frames": 1}}
    return {"ok": True, "path": p, "info": alpha_info(p)}


def originals():
    """Copies of Caelestia's own pictures, kept by Orrery: an update or a broken install cannot take them away."""
    return {k: GIF_DIR / "caelestia" / Path(v).name for k, (_, v) in GIFS.items()}


def back_up_originals():
    done = []
    for k, target in originals().items():
        src = Path(resolve_pic(GIFS[k][1]))
        if not src.is_file():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        tmp = target.with_name(target.name + ".orrery-tmp")
        shutil.copyfile(src, tmp)
        os.replace(tmp, target)
        done.append(k)
    if not done:
        raise Bad("Caelestia's pictures were not found")
    return {"ok": True, "saved": done}


def pic_files(opts):
    """Pictures in the usual folders, newest first."""
    q = str(opts.get("query", "")).lower()[:80]
    roots = [GIF_DIR, pictures_dir(), HOME / "Downloads", Path(run("xdg-user-dir", "DOWNLOAD").stdout.strip() or HOME / "Downloads")]
    seen, out = set(), []
    for r in roots:
        if not r.is_dir() or r in seen:
            continue
        seen.add(r)
        for top, dirs, files in os.walk(r):
            depth = len(Path(top).relative_to(r).parts)
            dirs[:] = [] if depth >= 3 else [d for d in dirs if not d.startswith(".")]
            for name in files:
                f = Path(top) / name
                if name.startswith(".") or f.suffix.lower() not in IMG_EXT or (q and q not in name.lower()):
                    continue
                try:
                    st = f.stat()
                except OSError:
                    continue
                if st.st_size <= MAX_PIC and f.is_file():
                    out.append({"path": str(f), "name": name, "time": st.st_mtime, "size": st.st_size, "own": r == GIF_DIR,
                                "still": f.suffix.lower() in (".png", ".jpg", ".jpeg"),
                                "thumb": thumb_cached(f, 280) if f.suffix.lower() in (".png", ".jpg", ".jpeg") else ""})
    out.sort(key=lambda x: -x["time"])
    return {"ok": True, "files": out[:200]}


def keep(data, name):
    """Copies a picture into Orrery's folder, so moving the original does not break Caelestia."""
    GIF_DIR.mkdir(parents=True, exist_ok=True)
    target = GIF_DIR / name
    if not target.exists():
        tmp = target.with_name(target.name + ".orrery-tmp")
        tmp.write_bytes(data)
        os.replace(tmp, target)
    return str(target)


def pic_import(opts):
    f = Path(line(opts.get("path", ""), "picture", 1024, empty=False))
    if not f.is_absolute() or f.suffix.lower() not in IMG_EXT or not f.is_file():
        raise Bad("choose an image file")
    if f.stat().st_size > MAX_PIC:
        raise Bad("the file is too big (25 MB at most)")
    data = f.read_bytes()
    info = {"transparent": True, "frames": 1} if f.suffix.lower() == ".svg" else alpha_info(data)
    if info is None and f.suffix.lower() != ".svg":
        raise Bad("this image cannot be read")
    import hashlib
    path = str(f) if GIF_DIR in f.parents else keep(data, hashlib.sha256(data).hexdigest()[:16] + f.suffix.lower())
    return {"ok": True, "path": path, "info": info}


def giphy_key():
    try:
        k = json.loads(GIPHY_KEY.read_text()).get("key", "")
        return k if isinstance(k, str) else ""
    except (OSError, ValueError, AttributeError):
        return ""


def fetch(url, limit=MAX_PIC, who="GIPHY"):
    import urllib.error, urllib.request
    if DRY and os.environ.get("ORRERY_NET") != "1":
        raise Bad("no network in test mode")
    req = urllib.request.Request(url, headers={"User-Agent": "Orrery"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            data = r.read(limit + 1)
    except urllib.error.HTTPError as e:
        if who == "GitHub" and e.code in (403, 429):
            raise Bad("GitHub: too many checks this hour, try again later")
        if e.code in (401, 403):
            raise Bad("GIPHY did not accept the key")
        if e.code == 429:
            raise Bad("GIPHY: too many searches this hour with this key, try again later")
        raise Bad(f"{who} answered {e.code}")
    except (urllib.error.URLError, OSError) as e:
        raise Bad(f"{who} cannot be reached: check the connection")
    if len(data) > limit:
        raise Bad("the file is too big")
    return data


def giphy(path, **params):
    import urllib.parse
    key = params.pop("key", None) or giphy_key()
    if not key:
        raise Bad("add your GIPHY key first")
    r = json.loads(fetch(f"{GIPHY}/{path}?" + urllib.parse.urlencode({"api_key": key, **params}), 4 * 1024 * 1024))
    meta = r.get("meta") or {}
    if meta.get("status") != 200 or not meta.get("response_id"):
        raise Bad("GIPHY: " + str(meta.get("msg") or "no answer"))
    return r


def media_url(u):
    import urllib.parse
    h = urllib.parse.urlparse(u or "")
    return u if h.scheme == "https" and (h.hostname or "").endswith(".giphy.com") else ""


def set_giphy_key(opts):
    key = str(opts.get("key", "")).strip()
    if not key:
        GIPHY_KEY.unlink(missing_ok=True)
        return {"ok": True}
    if not re.fullmatch(r"[A-Za-z0-9]{16,64}", key):
        raise Bad("this does not look like a GIPHY key: copy the whole API Key from the dashboard")
    giphy("stickers/trending", key=key, limit=1)      # randomid answers OK even to a made-up key
    OWN.mkdir(parents=True, exist_ok=True)
    fd = os.open(GIPHY_KEY, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"key": key}, f)
    os.chmod(GIPHY_KEY, 0o600)
    return {"ok": True}


def giphy_search(opts):
    """Stickers in GIPHY's order. Each one is checked: those with a background are marked and cannot be used."""
    from concurrent.futures import ThreadPoolExecutor
    q = line(str(opts.get("query", "")), "search", 50).strip()
    offset = int(number(opts.get("offset", 0), 0, 4999, "page"))
    lang = (os.environ.get("LANG") or "en")[:2].lower()
    params = {"limit": 24, "offset": offset, "rating": "pg"}
    r = giphy("stickers/search", q=q, lang=lang, **params) if q else giphy("stickers/trending", **params)
    items = []
    for g in r.get("data") or []:
        im = g.get("images") or {}
        fw, small = im.get("fixed_width") or {}, im.get("fixed_width_small") or {}
        preview = media_url(fw.get("webp")) or media_url(fw.get("url"))
        if g.get("id") and preview:
            items.append({"id": str(g["id"])[:64], "title": str(g.get("title") or "")[:120], "preview": preview,
                          "check": media_url(small.get("webp")) or media_url(small.get("url")) or preview,
                          "width": int(fw.get("width") or 200), "height": int(fw.get("height") or 200)})
    def look(it):
        try:
            info = alpha_info(fetch(it.pop("check"), 4 * 1024 * 1024))
        except Bad:
            info = None
        it["transparent"] = info["transparent"] if info else None
        return it
    with ThreadPoolExecutor(8) as ex:
        items = list(ex.map(look, items))
    page = r.get("pagination") or {}
    return {"ok": True, "results": items, "next": offset + int(page.get("count") or len(items)),
            "total": int(page.get("total_count") or 0)}


def giphy_save(opts):
    gid = str(opts.get("id", ""))
    if not re.fullmatch(r"[A-Za-z0-9]{1,64}", gid):
        raise Bad("unknown sticker")
    im = ((giphy(f"gifs/{gid}").get("data") or {}).get("images") or {})
    o = im.get("original") or {}
    url, ext = (media_url(o.get("webp")), ".webp") if media_url(o.get("webp")) else (media_url(o.get("url")), ".gif")
    if not url:
        raise Bad("GIPHY has no file for this sticker")
    data = fetch(url)
    info = alpha_info(data)
    if not info:
        raise Bad("this sticker cannot be read")
    if not info["transparent"]:
        raise Bad("this sticker has a background: choose another one")
    return {"ok": True, "path": keep(data, f"giphy-{gid}{ext}"), "info": info}


# --- colours in other apps ---------------------------------------------------------------
# Caelestia recolours these apps from cli.json's "theme" (every one is on unless set to false). Orrery writes only them.
CLI = CAEL / "cli.json"
THEME_APPS = ["enableHypr", "enableTerm", "enableGtk", "enableQt", "enableDiscord", "enableSpicetify", "enableChromium",
              "enableZed", "enableFuzzel", "enableBtop", "enableHtop", "enableNvtop", "enableCava", "enableWarp", "enablePandora"]
ICON_KEYS = ("iconTheme", "iconThemeLight", "iconThemeDark")


def cli_json():
    try:
        d = json.loads(CLI.read_text())
    except FileNotFoundError:
        return {}
    if not isinstance(d, dict) or not isinstance(d.get("theme", {}), dict):
        raise Bad("cli.json is not valid")
    return d


def read_colours(d=None):
    t = (cli_json() if d is None else d).get("theme", {})
    out = {k: t.get(k, True) if isinstance(t.get(k, True), bool) else True for k in THEME_APPS}
    out.update({k: t.get(k, "") if isinstance(t.get(k, ""), str) else "" for k in ICON_KEYS})
    return out


def icon_themes():
    """Icon themes (not cursor-only ones) that GTK and Qt can use."""
    out = set()
    for base in (HOME / ".icons", DATA_DIRS[0] / "icons", Path("/usr/share/icons"), Path("/usr/local/share/icons")):
        for d in base.iterdir() if base.is_dir() else []:
            try:
                text = (d / "index.theme").read_text(errors="replace")
            except OSError:
                continue
            m = re.search(r"^Directories\s*=\s*(.+)$", text, re.M)
            if m and m[1].strip() and d.name not in ("hicolor", "locolor", "default"):
                out.add(d.name)
    return sorted(out, key=str.lower)


def check_colours(c):
    out = {k: bool(c.get(k, True)) for k in THEME_APPS}
    for k in ICON_KEYS:
        v = line(c.get(k, "") or "", k, 80)
        if v and not re.fullmatch(r"[A-Za-z0-9 _.+-]{1,80}", v):
            raise Bad("icon theme: invalid name")
        out[k] = v
    return out


def put_colours(new):
    d = cli_json()
    t = d.setdefault("theme", {})
    for k in THEME_APPS:
        if new[k]:
            t.pop(k, None)
        else:
            t[k] = False
    for k in ICON_KEYS:
        if new[k]:
            t[k] = new[k]
        else:
            t.pop(k, None)
    if not t:
        d.pop("theme")
    write(CLI, json.dumps(d, indent=4, ensure_ascii=False) + "\n")


def recolour():
    """Runs the current scheme again, so the apps take the colours now and not at the next wallpaper change."""
    if DRY:
        return
    try:
        sc = json.loads((Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "caelestia/scheme.json").read_text())
    except (OSError, ValueError):
        return
    args = [x for k, f in (("name", "-n"), ("flavour", "-f"), ("mode", "-m"), ("variant", "-v"))
            if isinstance(sc.get(k), str) and re.fullmatch(r"[a-z0-9_-]{1,40}", sc[k]) for x in (f, sc[k])]
    run("caelestia", "scheme", "set", *args)


# --- Spotify and spicetify -------------------------------------------------------------
# Orrery only drives spicetify's own commands; it never edits Spotify's files itself.
SPICE_CONF = CONF / "spicetify/config-xpui.ini"
SPICE_SAVED = OWN / "spotify.json"      # the theme you had before Caelestia's colours


def spicetify_bin():
    for c in (os.environ.get("ORRERY_SPICETIFY"), shutil.which("spicetify"), str(HOME / ".spicetify/spicetify")):
        if c and os.access(c, os.X_OK) and Path(c).is_file():
            return c
    return ""


def spice_ini():
    cp = configparser.RawConfigParser(strict=False, interpolation=None, inline_comment_prefixes=(";",))
    cp.optionxform = str
    try:
        cp.read(SPICE_CONF, encoding="utf-8")
    except (configparser.Error, UnicodeDecodeError):
        pass
    get = lambda sec, k: cp.get(sec, k, fallback="").strip()
    return get


def spice(*args):
    exe = spicetify_bin()
    if not exe:
        raise Bad("spicetify is not installed")
    r = run(exe, *args)
    out = re.sub(r"\x1b\[[0-9;]*m", "", (r.stdout or "") + (r.stderr or "")).strip()
    if r.returncode != 0 or re.search(r"^\s*error\b", out, re.I | re.M):
        raise Bad("spicetify: " + (out.splitlines()[-1] if out else f"exit {r.returncode}")[:300])
    return out


def spotify_state():
    exe = spicetify_bin()
    get = spice_ini()
    path = get("Setting", "spotify_path")
    kind = "" if not path else "flatpak" if "flatpak" in path else "spotify-launcher" if "spotify-launcher" in path else "spotify"
    xpui = Path(path) / "Apps/xpui/index.html" if path else None
    try:
        applied = bool(xpui and "spicetify" in xpui.read_text(errors="replace"))
    except OSError:
        applied = False
    found = {}
    for d in (HOME / ".spicetify/Extensions", CONF / "spicetify/Extensions", Path(exe).parent / "Extensions" if exe else None):
        if d and d.is_dir():
            for f in sorted(d.glob("*.js")):
                found.setdefault(f.name, None)
    on = [x for x in get("AdditionalOptions", "extensions").split("|") if x]
    return {"spicetify": exe, "version": run(exe, "-v").stdout.strip()[:40] if exe else "", "spotify": path, "kind": kind,
            "installed": bool(path) and Path(path).is_dir(), "applied": applied, "backup": bool(get("Backup", "version")),
            "theme": get("Setting", "current_theme"), "scheme": get("Setting", "color_scheme"),
            "caelestiaTheme": (CONF / "spicetify/Themes/caelestia/color.ini").is_file(),
            "extensions": [{"name": n, "on": n in on} for n in sorted(set(found) | set(on))],
            "watch": f"{exe} watch -s" if exe else ""}


def spice_apply():
    """apply, or backup and apply when Spotify was updated since the last backup (it puts its files back)."""
    try:
        return spice("apply")
    except Bad as e:
        if not re.search(r"backup|restore", str(e), re.I):
            raise
        spice("restore", "backup", "apply")


def spotify(opts):
    act = opts.get("action")
    st = spotify_state()
    if not st["spicetify"]:
        raise Bad("spicetify is not installed")
    if st["kind"] == "flatpak":
        raise Bad("Spotify from Flatpak is not supported yet")
    if act == "colours":
        if opts.get("on"):
            if not st["caelestiaTheme"]:
                raise Bad("Caelestia has not made its Spotify theme yet: change wallpaper or scheme once, then try again")
            if st["theme"] != "caelestia":
                write(SPICE_SAVED, json.dumps({"theme": st["theme"], "scheme": st["scheme"]}) + "\n")
            spice("config", "current_theme", "caelestia", "color_scheme", "caelestia", "replace_colors", "1")
        else:
            try:
                old = json.loads(SPICE_SAVED.read_text())
            except (OSError, ValueError):
                old = {"theme": "", "scheme": ""}
            theme, scheme = line(str(old.get("theme", "")), "theme", 80), line(str(old.get("scheme", "")), "scheme", 80)
            spice("config", "current_theme", theme, "color_scheme", scheme)
        spice_apply()
    elif act == "apply":
        spice_apply()
    elif act == "restore":
        spice("restore")
    elif act == "extension":
        name = str(opts.get("name", ""))
        if not re.fullmatch(r"[A-Za-z0-9_.+-]{1,60}\.js", name):
            raise Bad("unknown extension")
        spice("config", "extensions", name if opts.get("on") else name + "-")
        spice_apply()
    else:
        raise Bad("unknown action")
    return {"ok": True, "spotify": spotify_state()}


def monitors():
    try:
        return [{"name": m["name"], "description": m.get("description", "")}
                for m in json.loads(run("hyprctl", "monitors", "all", "-j").stdout) if isinstance(m.get("name"), str)]
    except (ValueError, TypeError, KeyError, AttributeError):
        return []


def has_battery():
    """The computer's own: mice and headphones report one too, with scope Device."""
    for d in Path("/sys/class/power_supply").glob("*"):
        try:
            if (d / "type").read_text().strip() == "Battery" and not ((d / "scope").exists() and (d / "scope").read_text().strip() == "Device"):
                return True
        except OSError:
            continue
    return False


def can_hibernate():
    r = run("busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate")
    return r.returncode == 0 and any(x in r.stdout for x in ('"yes"', '"challenge"'))


# --- backup / apply ---------------------------------------------------------------------
TRACKED = {"hypr-user.lua": USER_LUA, "engine.lua": LUADIR / "engine.lua", "settings.lua": LUADIR / "settings.lua",
           "mimeapps.list": MIMEAPPS, "config.json": CONFIG, "cli.json": CLI}


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
    # Only the keys Orrery changed, not the whole shell.json
    if (d / "idle.json").exists():      # backups made by 0.2.0beta1
        put_idle(json.loads((d / "idle.json").read_text()))
    if (d / "shell-keys.json").exists():
        put_shell({k: v[1] if v[0] else MISSING for k, v in json.loads((d / "shell-keys.json").read_text()).items()})


def hypr_errors():
    if DRY or not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return ""
    run("hyprctl", "reload")
    import time
    time.sleep(1.2)
    e = run("hyprctl", "configerrors").stdout.strip()
    return "" if e.lower() in ("", "no errors", "ok") else e


def apply(cfg):
    power = check_power(cfg["power"]) if isinstance(cfg.get("power"), dict) else None
    shell = cfg.get("shell") if isinstance(cfg.get("shell"), dict) else None
    colours = check_colours(cfg["colours"]) if isinstance(cfg.get("colours"), dict) else None
    if colours and colours == read_colours():
        colours = None          # nothing changed: cli.json is not rewritten
    cfg = validate(cfg)
    apps = desktop_apps()
    changes = {}
    if power or shell:
        raw = shell_json()
    if power:
        old = idle_json()
        idle = with_power(old, power)
        if idle != old:
            changes["general.idle"] = idle or MISSING
    if shell:
        now = read_shell(raw)
        shell = check_shell(shell, now)
        changes.update(shell_changes(now, shell))
    if not (CONF / "hypr/hyprland.lua").exists() and not DRY:
        raise Bad("Caelestia's Hyprland config was not found")
    before = hypr_errors()
    d = backup()
    if changes:
        was = {k: get_path(raw, k) for k in changes}
        (d / "shell-keys.json").write_text(json.dumps({k: [v is not MISSING, None if v is MISSING else v] for k, v in was.items()}))
    try:
        put_shell(changes)
        if colours:
            put_colours(colours)
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
    if colours:
        recolour()
    return {"ok": True, "config": {**cfg, "power": power, "shell": shell}, "backup": d.name}


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


PREFS = {"language": "auto", "follow": True, "transparent": True, "base": 0.85, "layers": 0.4, "speed": 1.0, "rounding": 1.0,
         "channel": "auto", "autoUpdate": True}


def read_prefs():
    out = dict(PREFS)
    try:
        old = json.loads((OWN / "ui.json").read_text())
        out.update({k: old[k] for k in PREFS if k in old})
    except (OSError, ValueError, TypeError):
        pass
    return out


def prefs(new):
    """The app itself: saved at once, never touches Hyprland."""
    out = read_prefs()
    path = OWN / "ui.json"
    out.update({k: v for k, v in new.items() if k in PREFS})
    if out["language"] not in ("auto", "en", "it"):
        raise Bad("language: unknown")
    if out["channel"] not in ("auto", "stable", "beta"):
        raise Bad("channel: unknown")
    for k in ("follow", "transparent", "autoUpdate"):
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
            "running": listed is not None, "previews": {k: thumb(SHARE / "wallpapers" / f, 640) for k, (f, _) in WALLS.items()}}


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


# --- shortcuts ---------------------------------------------------------------------------
# Read-only. Caelestia's Lua binds show up in hyprctl as "function: 0x…", so the names come from its variables;
# hyprctl only says which keys are really active.
SHORTCUTS = [  # group, label, variable or literal keys, suffix
    ("Shell", "Open the launcher", "kbLauncher", ""), ("Shell", "Shut down menu", "kbSession", ""),
    ("Shell", "Sidebar and notifications", "kbShowSidebar", ""), ("Shell", "Clear the notifications", "kbClearNotifs", ""),
    ("Shell", "Show every panel", "kbShowPanels", ""), ("Shell", "Lock the screen", "kbLock", ""),
    ("Shell", "Bring the lock screen back after a crash", "kbRestoreLock", ""), ("Shell", "Sleep", "kbSleep", ""),
    ("Shell", "Stop Caelestia", ["CTRL + SUPER + SHIFT + R"], ""), ("Shell", "Restart Caelestia", ["CTRL + SUPER + ALT + R"], ""),
    ("Shell", "Test notification", ["SUPER + ALT + F12"], ""),
    ("Areas", "Special workspace", "kbSpecialWs", ""), ("Areas", "Messages", "kbCommunicationWs", ""),
    ("Areas", "Music", "kbMusicWs", ""), ("Areas", "To-do", "kbTodoWs", ""), ("Areas", "System monitor", "kbSystemMonitorWs", ""),
    ("Workspaces", "Go to workspace", "kbGoToWs", "1…0"), ("Workspaces", "Move the window to workspace", "kbMoveWinToWs", "1…0"),
    ("Workspaces", "Move the window there, staying here", "kbMoveWinToWsSilent", "1…0"),
    ("Workspaces", "Go to workspace group", "kbGoToWsGroup", "1…0"), ("Workspaces", "Move the window to workspace group", "kbMoveWinToWsGroup", "1…0"),
    ("Workspaces", "Next workspace", "kbNextWs", ""), ("Workspaces", "Previous workspace", "kbPrevWs", ""),
    ("Workspaces", "Next workspace group", "kbNextWsGroup", ""), ("Workspaces", "Previous workspace group", "kbPrevWsGroup", ""),
    ("Workspaces", "Move the window to the next workspace", "kbMoveWinToWsNext", ""),
    ("Workspaces", "Move the window to the previous workspace", "kbMoveWinToWsPrev", ""),
    ("Workspaces", "Move the window to the special workspace", "kbMoveWinToWsSpecial", ""),
    ("Workspaces", "Take the window out of the special workspace", "kbMoveWinFromWsSpecial", ""),
    ("Windows", "Close the window", "kbCloseWindow", ""), ("Windows", "Full screen", "kbWindowFullscreen", ""),
    ("Windows", "Maximise", "kbWindowBorderedFullscreen", ""), ("Windows", "Floating or tiled", "kbToggleWindowFloating", ""),
    ("Windows", "Focus the window on that side", ["SUPER + Left", "SUPER + Right", "SUPER + Up", "SUPER + Down"], ""),
    ("Windows", "Move the window to that side", ["SUPER + SHIFT + Left", "SUPER + SHIFT + Right", "SUPER + SHIFT + Up", "SUPER + SHIFT + Down"], ""),
    ("Windows", "Next window", "kbWindowCycleNext", ""), ("Windows", "Previous window", "kbWindowCyclePrev", ""),
    ("Windows", "Narrower", "kbWindowDecreaseWidth", ""), ("Windows", "Wider", "kbWindowIncreaseWidth", ""),
    ("Windows", "Shorter", "kbWindowDecreaseHeight", ""), ("Windows", "Taller", "kbWindowIncreaseHeight", ""),
    ("Windows", "Move with the mouse", "kbMoveWindow", "", ["SUPER + mouse:272"]),
    ("Windows", "Resize with the mouse", "kbResizeWindow", "", ["SUPER + mouse:273"]),
    ("Windows", "Centre the window", "kbCenterWindow", ""), ("Windows", "Back to a normal size", "kbNormalizeWindow", ""),
    ("Windows", "Picture in picture", "kbWindowPip", ""), ("Windows", "Keep on every workspace", "kbPinWindow", ""),
    ("Windows", "Group windows", "kbToggleGroup", ""), ("Windows", "Take the window out of the group", "kbUngroup", ""),
    ("Windows", "Lock the group", "kbGroupLockActive", ""), ("Windows", "Next window in the group", "kbWindowGroupCycleNext", ""),
    ("Windows", "Previous window in the group", "kbWindowGroupCyclePrev", ""),
    ("Apps", "Terminal", "kbTerminal", ""), ("Apps", "Web browser", "kbBrowser", ""), ("Apps", "Text editor", "kbEditor", ""),
    ("Apps", "File manager", "kbFileExplorer", ""), ("Apps", "Audio settings", "kbAudioSettings", ""),
    ("Tools", "Screenshot", "kbScreenshot", ""), ("Tools", "Screenshot of an area", "kbScreenshotRegion", ""),
    ("Tools", "Screenshot, freezing the screen", "kbScreenshotFreeze", ""), ("Tools", "Record the screen", "kbRecord", ""),
    ("Tools", "Record with sound", "kbRecordSound", ""), ("Tools", "Record an area", "kbRecordRegion", ""),
    ("Tools", "Colour picker", "kbColorPicker", ""), ("Tools", "Clipboard history", "kbClipboard", ""),
    ("Tools", "Delete from the clipboard history", "kbClipboardDel", ""), ("Tools", "Type the last copied text", "kbClipboardPasteLatest", ""),
    ("Tools", "Emoji", "kbEmoji", ""),
    ("Media", "Play or pause", "kbMediaToggle", "", ["XF86AudioPlay", "XF86AudioPause"]),
    ("Media", "Next track", "kbMediaNext", "", ["XF86AudioNext"]), ("Media", "Previous track", "kbMediaPrev", "", ["XF86AudioPrev"]),
    ("Media", "Stop", "kbMediaStop", "", ["XF86AudioStop"]), ("Media", "Mute", "kbVolumeMute", "", ["XF86AudioMute"]),
    ("Media", "Volume up and down", ["XF86AudioRaiseVolume", "XF86AudioLowerVolume"], ""),
    ("Media", "Mute the microphone", ["XF86AudioMicMute"], ""),
    ("Media", "Brightness up and down", ["XF86MonBrightnessUp", "XF86MonBrightnessDown"], ""),
]
APP_VAR = {"kbTerminal": "terminal", "kbBrowser": "browser", "kbEditor": "editor", "kbFileExplorer": "fileExplorer",
           "kbAudioSettings": "audioSettings"}
AREA_VAR = {"special": "kbSpecialWs", "communication": "kbCommunicationWs", "music": "kbMusicWs", "todo": "kbTodoWs",
            "sysmon": "kbSystemMonitorWs"}
MODS = {"SUPER": 64, "WIN": 64, "LOGO": 64, "MOD4": 64, "SHIFT": 1, "CTRL": 4, "CONTROL": 4, "ALT": 8, "MOD1": 8}


def lua_vars(text):
    """Plain `name = "x"` and `name = { "x", "y" }` entries of a Lua table; anything computed is skipped."""
    out = {}
    # A comment starts at -- outside quotes ("gnome-text-editor --new-window" is not one)
    code = "\n".join(re.sub(r'^((?:[^"\n]|"(?:[^"\\]|\\.)*")*?)--.*$', r"\1", l) for l in text.splitlines())
    for m in re.finditer(r'^\s*([A-Za-z_]\w*)\s*=\s*("(?:[^"\\]|\\.)*"|\{[^{}]*\})\s*,?\s*$', code, re.M):
        v = m[2]
        out[m[1]] = re.findall(r'"((?:[^"\\]|\\.)*)"', v) if v.startswith("{") else v[1:-1]
    return out


def norm_key(k):
    """'SUPER + SHIFT + s' -> (65, 's'), the way hyprctl reports it."""
    parts = [p.strip() for p in str(k).split("+") if p.strip()]
    if not parts:
        return None
    mask = 0
    for p in parts[:-1]:
        mask |= MODS.get(p.upper(), 0)
    return mask, parts[-1].lower()


def active_binds():
    try:
        binds = json.loads(run("hyprctl", "binds", "-j").stdout)
    except ValueError:
        return None
    # non_consuming binds are listeners (Caelestia watching Caps Lock), not shortcuts
    return {(b.get("modmask", 0), str(b.get("key", "")).lower()): b for b in binds
            if isinstance(b, dict) and b.get("submap", "") == "" and not b.get("non_consuming")}


def shortcuts(_=None):
    v = {}
    for f in (CONF / "hypr/variables.lua", CAEL / "hypr-vars.lua"):
        try:
            v.update(lua_vars(f.read_text()))
        except OSError:
            pass
    cfg, _ = load()
    apps = desktop_apps()
    live = active_binds()
    rows, taken = [], {}
    def add(group, label, keys, suffix="", sub="", source="caelestia"):
        keys = [k for k in keys if isinstance(k, str) and k.strip()]
        shown = [f"{k} + {suffix}" if suffix else k for k in keys]
        checks = [norm_key(f"{k} + 1") if suffix else norm_key(k) for k in keys]
        on = None if live is None else any(c in live for c in checks if c)
        for c in checks:
            if c:
                taken.setdefault(c, []).append(label)
        rows.append({"group": group, "label": label, "keys": shown, "sub": sub, "source": source, "active": on})
    # What Orrery replaced
    areas = {sp["id"]: a for a in cfg.get("areas", []) if a.get("enabled") for sp in a.get("spaces", [])}
    overridden = {AREA_VAR[i] for i in areas if i in AREA_VAR}
    for a in cfg.get("areas", []):
        if a.get("enabled") and a.get("key"):
            names = ", ".join(p.get("name") or p.get("class", "") for sp in a.get("spaces", []) for p in sp.get("apps", []))
            add("Areas", a["name"], [a["key"]], sub=names, source="orrery")
    if cfg.get("keyboard", {}).get("managed") and cfg["keyboard"].get("switchKey"):
        add("Windows", "Switch keyboard layout", [cfg["keyboard"]["switchKey"]], source="orrery")
    chosen = {ROLES.get(r): apps.get(cfg["apps"].get(r, ""), {}).get("name", "") for r in ROLES if cfg.get("apps", {}).get(r)}
    for item in SHORTCUTS:
        group, label, src, suffix = item[:4]
        if isinstance(src, str) and src in overridden:
            continue
        keys = (v.get(src) if isinstance(src, str) else src) or []
        keys = [keys] if isinstance(keys, str) else list(keys)
        keys += item[4] if len(item) > 4 else []
        sub = (chosen.get(src) or (v.get(APP_VAR[src], "") if src in APP_VAR else "")) if isinstance(src, str) else ""
        add(group, label, keys, suffix, sub)
        if isinstance(src, str) and src in APP_VAR and not chosen.get(src) and sub and not shutil.which(sub.split()[0]):
            rows[-1]["missing"] = True        # Caelestia's default app is not installed: the key does nothing
    # Your own binds in hypr-user.lua (outside Orrery's block)
    try:
        mine = strip_hook(USER_LUA.read_text())
    except OSError:
        mine = ""
    for line_ in mine.splitlines():
        code = line_.split("--", 1)[0]
        m = re.search(r'hl\.bind\(\s*"([^"]+)"\s*,\s*(.+?)\)?\s*$', code)
        if m:
            what = re.search(r'exec_cmd\(\s*"([^"]+)"', m[2])
            add("Yours", what[1] if what else m[2].strip()[:60], [m[1]], source="user")
    # Active keys nobody here explains: other configuration (HyprMod, hand-made files)
    if live is not None:
        known = set(taken)
        for (mask, key), b in sorted(live.items(), key=lambda x: (x[0][1], x[0][0])):
            if (mask, key) not in known and not (mask, key[:-1]) in known and not re.fullmatch(r"[0-9]", key):
                mods = [n for n, bit in (("SUPER", 64), ("CTRL", 4), ("ALT", 8), ("SHIFT", 1)) if mask & bit]
                add("Other", "From other configuration", [" + ".join(mods + [b.get("key", key)])], source="other")
    twice = {c for c, who in taken.items() if len(set(who)) > 1}
    for r in rows:
        r["twice"] = sorted({w for k in r["keys"] for c in [norm_key(k.replace(" + 1…0", " + 1"))] if c in twice for w in taken[c]} - {r["label"]})
    return {"ok": True, "shortcuts": rows, "live": live is not None}


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


def current_wallpaper():
    try:
        p = (Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "caelestia/wallpaper/path.txt").read_text().strip()
    except OSError:
        return ""
    return p if p.startswith("/") and Path(p).is_file() else ""


def display_manager():
    try:
        name = Path(os.readlink("/etc/systemd/system/display-manager.service")).name
    except OSError:
        return ""
    return name.removesuffix(".service")


def previous_dm():
    try:
        return Path("/etc/orrery/display-manager.before-orrery").read_text().strip().removesuffix(".service")[:60]
    except OSError:
        return ""


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
    try:
        cfg["power"] = read_power()
    except (Bad, ValueError):
        cfg["power"] = None
    try:
        cfg["shell"] = read_shell()
    except (Bad, ValueError):
        cfg["shell"] = None
    try:
        cfg["colours"] = read_colours()
    except (Bad, ValueError):
        cfg["colours"] = None
    helper = "/usr/lib/orrery/orrery-helper"
    # The slow parts wait on other programs: run them side by side
    from concurrent.futures import ThreadPoolExecutor
    ex = ThreadPoolExecutor(8)
    later = {k: ex.submit(f) for k, f in (("walls", wall_state), ("hibernate", can_hibernate), ("windows", windows),
                                         ("monitors", monitors), ("spotify", spotify_state), ("layouts", xkb_layouts),
                                         ("icons", icon_themes))}
    table = mimeapps_defaults()
    walls = later["walls"].result()
    greeter = ""
    try:
        m = re.search(r'^\s*command\s*=\s*"([^"]+)"', Path("/etc/greetd/config.toml").read_text(), re.M)
        greeter = m[1] if m else ""
    except OSError:
        pass
    return {
        "config": cfg, "saved": saved, "apps": sorted(apps.values(), key=lambda a: a["name"].lower()),
        "roles": roles_for(apps), "defaults": {r: system_default(r, apps, table) for r in ALL_ROLES}, "layouts": later["layouts"].result(),
        "windows": later["windows"].result(), "conflicts": conflicts(),
        "active": USER_LUA.exists() and BEGIN in USER_LUA.read_text(),
        "walls": walls,
        "power": {"defaults": read_power({}), "hibernate": later["hibernate"].result(), "battery": has_battery()},
        "shell": {"defaults": read_shell({}), "monitors": later["monitors"].result()},
        "spotify": later["spotify"].result(),
        "colours": {"icons": later["icons"].result()},
        "pics": {"defaults": {k: thumb(resolve_pic(v), 400) if resolve_pic(v) else "" for k, (_, v) in GIFS.items()},
                 "dir": str(GIF_DIR), "giphy": bool(giphy_key()),
                 "wallpaper": thumb(current_wallpaper(), 900) if current_wallpaper() else "",
                 "thumbs": {v: thumb(resolve_pic(v), 400) for v in (cfg["shell"] or {}).get("gifs", {}).values()
                            if isinstance(v, str) and v.startswith("/")},
                 "defaultsOk": {k: Path(resolve_pic(v) or "/nonexistent").is_file() for k, (_, v) in GIFS.items()},
                 "originals": {k: str(p) if p.is_file() else "" for k, p in originals().items()}},
        "canUndo": BACKUPS.is_dir() and any(BACKUPS.iterdir()),
        "system": {
            "helper": os.path.exists(helper), "caelestia": (CONF / "hypr/hyprland.lua").exists(),
            "specola": shutil.which("specola") is not None,
            "backlight": {"present": LED is not None,
                          "max": int((LED / "max_brightness").read_text()) if LED else 0,
                          "unit": next((u for u in ("orrery-kbd-backlight.service", "kbd-backlight-on.service")
                                        if os.path.exists(f"/etc/systemd/system/{u}")), "")},
            "login": {"greetd": os.path.exists("/etc/greetd/config.toml"), "command": greeter, "dm": display_manager(),
                      "greetdInstalled": shutil.which("greetd") is not None or os.path.exists("/usr/bin/greetd"),
                      "previousDm": previous_dm(),
                      # the login screen is shared by every user: it is built from the packaged Caelestia only,
                      # never from a copy in someone's home
                      "packages": {**{p: shutil.which(b) is not None for p, b in
                                      (("cage", "cage"), ("quickshell-greetd", "quickshell-greetd-launcher"))},
                                   "caelestia-shell": os.path.isfile("/etc/xdg/quickshell/caelestia/modules/lock/LockSurface.qml")}}}}


# --- updates -------------------------------------------------------------------------
REPO = "Violet-owo/orrery"
RELEASES = f"https://api.github.com/repos/{REPO}/releases?per_page=30"
UPDATE_CACHE = THUMBS.parent / "update.json"
VER_RE = re.compile(r"([0-9]{1,4})\.([0-9]{1,4})\.([0-9]{1,4})(?:beta([0-9]{1,4}))?")
PKG_RE = re.compile(r"orrery-caelestia-(.+)-([0-9]{1,3})-any\.pkg\.tar\.zst")
DAY = 86400


def ver_key(v):
    """Sorts like pacman: 0.2.0beta1 < 0.2.0beta2 < 0.2.0 < 0.2.1beta1"""
    m = VER_RE.fullmatch(v or "")
    return (int(m[1]), int(m[2]), int(m[3]), 0 if m[4] else 1, int(m[4] or 0)) if m else None


def own_version():
    try:
        m = re.search(r'property string version: "([^"]+)"', (SHARE / "ui/core/Ui.qml").read_text())
    except OSError:
        m = None
    return m[1] if m else ""


def install_mode():
    """pacman: the package in /usr/share/orrery; source: a git checkout run in place"""
    if DRY and os.environ.get("ORRERY_MODE"):
        return os.environ["ORRERY_MODE"]
    if SHARE != Path("/usr/share/orrery"):
        return "source"
    return "pacman" if run("pacman", "-Qq", "orrery-caelestia").returncode == 0 else "other"


def beta_repo():
    """The [orrery-beta] pacman repository: pacman -Syu installs betas from it whatever the channel"""
    try:
        return re.search(r"^\s*\[orrery-beta\]", Path("/etc/pacman.conf").read_text(), re.M) is not None
    except OSError:
        return False


def releases():
    if DRY and os.environ.get("ORRERY_RELEASES"):
        return json.loads(Path(os.environ["ORRERY_RELEASES"]).read_text())
    r = json.loads(fetch(RELEASES, 4 * 1024 * 1024, "GitHub"))
    if not isinstance(r, list):
        raise Bad("GitHub: unexpected answer")
    return r


def newest(rels, channel):
    """The highest release of the channel: beta also takes a stable release when it is the newest"""
    best = None
    for r in rels:
        if not isinstance(r, dict) or r.get("draft"):
            continue
        tag = str(r.get("tag_name") or "")
        v = tag[1:] if tag.startswith("v") else ""
        k = ver_key(v)
        if not k or (channel == "stable" and (r.get("prerelease") or k[3] == 0)):
            continue
        if best is None or k > best[0]:
            best = (k, v, r)
    if not best:
        return None
    k, v, r = best
    pkg = None
    for a in r.get("assets") or []:
        if not isinstance(a, dict):
            continue
        m, d = PKG_RE.fullmatch(str(a.get("name") or "")), str(a.get("digest") or "")
        if m and m[1] == v and re.fullmatch(r"sha256:[0-9a-f]{64}", d) and (pkg is None or int(m[2]) > int(pkg["rel"])):
            pkg = {"file": m[0], "rel": m[2], "sha256": d[7:]}
    url = str(r.get("html_url") or "")
    return {"version": v, "beta": k[3] == 0, "date": str(r.get("published_at") or "")[:10], "package": pkg,
            "url": url if url.startswith(f"https://github.com/{REPO}/") else f"https://github.com/{REPO}/releases"}


def updates(opts):
    """Checks GitHub at most once a day by itself, at once when asked"""
    p, cur = read_prefs(), own_version()
    channel = p["channel"] if p["channel"] in ("stable", "beta") else "beta" if "beta" in cur else "stable"
    mode = install_mode()
    out = {"ok": True, "current": cur, "channel": channel, "mode": mode, "auto": bool(p["autoUpdate"]),
           "betaRepo": beta_repo(), "checked": False}
    if opts.get("auto") and not p["autoUpdate"]:
        return out
    try:
        cache = json.loads(UPDATE_CACHE.read_text())
        fresh = cache["channel"] == channel and 0 <= time.time() - float(cache["time"]) < DAY
    except (OSError, ValueError, KeyError, TypeError):
        cache, fresh = {}, False
    if opts.get("force") or not fresh:
        cache = {"time": time.time(), "channel": channel, "latest": newest(releases(), channel)}
        write(UPDATE_CACHE, json.dumps(cache) + "\n")
    latest = cache.get("latest") if isinstance(cache.get("latest"), dict) else None
    lk, ck = ver_key(latest["version"]) if latest else None, ver_key(cur)
    state = "none" if not lk else "same" if lk == ck else "newer" if ck is None or lk > ck else "older"
    branch = "beta" if channel == "beta" else "main"
    if mode == "source":
        command = f"git -C {shlex.quote(str(SHARE))} switch {branch} && git -C {shlex.quote(str(SHARE))} pull"
    elif latest:
        command = (f'cd "$(mktemp -d)" && curl -LO https://github.com/{REPO}/releases/download/v{latest["version"]}/PKGBUILD'
                   " && makepkg -si")
    else:
        command = ""
    return {**out, "checked": True, "time": int(cache.get("time") or 0), "latest": latest, "state": state,
            "canInstall": mode == "pacman" and state in ("newer", "older") and bool(latest and latest["package"]),
            "command": command}


def check():
    out = []
    def add(i, ok, detail="", fix="", note=""):
        out.append({"id": i, "ok": ok, "detail": detail, "fix": fix, "note": note})
    qs = run("quickshell", "--private-check-compat")
    m = re.search(r"built against Qt ([0-9.]+) but the system has updated to Qt ([0-9.]+)", qs.stdout + qs.stderr)
    stale = m is not None or bool(re.search("built against|rebuil", qs.stdout + qs.stderr))
    # AUR packages are not rebuilt by pacman. aur/ avoids repository packages that claim to be quickshell-git (noctalia-qs)
    aur = [p for p in ("quickshell-git", "caelestia-shell") if run("pacman", "-Qmq", p).returncode == 0]
    add("quickshell", shutil.which("quickshell") is not None and not stale,
        "Qt was updated: Quickshell must be rebuilt, or it may crash. Then log out and in again." if stale else "",
        "paru -S --rebuild " + " ".join(f"aur/{p}" for p in aur) if stale and aur else "", f"Qt {m[1]} → {m[2]}" if m else "")
    add("noctaliaqs", run("pacman", "-Qq", "noctalia-qs").returncode != 0)
    e = run("hyprctl", "configerrors").stdout.strip()
    add("hyprland", e.lower() in ("", "no errors"), e[:300])
    add("shell", "/quickshell/caelestia/shell.qml" in run("qs", "list", "--all").stdout)
    add("hook", USER_LUA.exists() and BEGIN in USER_LUA.read_text())
    add("conflicts", not conflicts(), ", ".join(conflicts()))
    sp = spotify_state()
    if sp["spicetify"] and sp["installed"] and sp["backup"]:
        add("spotify", sp["applied"], "Spotify was updated and lost spicetify: apply it again in Default apps")
    return {"checks": out}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "state"
    try:
        takes = {"apply": apply, "prefs": prefs, "wallpapers": wallpapers, "use-wallpaper": use_wallpaper,
                 "pic-info": pic_info, "pic-files": pic_files, "pic-import": pic_import,
                 "giphy-key": set_giphy_key, "giphy-search": giphy_search, "giphy-save": giphy_save}
        takes["pic-originals"] = lambda _: back_up_originals()
        takes["spotify"] = spotify
        takes["pic-thumbs"] = pic_thumbs
        takes["shortcuts"] = shortcuts
        takes["updates"] = updates
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
