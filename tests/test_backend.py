import copy, json, os, shutil, subprocess, sys, tempfile, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
CTL = ROOT / "lib/orreryctl.py"

BASE_USER = '''hl.config({ input = { kb_layout = "it" } })

-- HyprMod: last
-- second comment line
require("hyprland-gui")
'''


class T(unittest.TestCase):
    def setUp(self):
        self.t = Path(tempfile.mkdtemp())
        (self.t / "caelestia").mkdir()
        (self.t / "caelestia/hypr-user.lua").write_text(BASE_USER)
        apps = self.t / "data/applications"
        apps.mkdir(parents=True)
        for n, ex in (("zen", "/opt/zen %u"), ("evil", 'sh -c "echo \\"x\\"" %F')):
            (apps / f"{n}.desktop").write_text(f"[Desktop Entry]\nType=Application\nName={n}\nExec={ex}\nMimeType=x-scheme-handler/https;text/plain;\n")
        self.env = {**os.environ, "XDG_CONFIG_HOME": str(self.t), "XDG_DATA_HOME": str(self.t / "data"),
                    "XDG_DATA_DIRS": "/nonexistent", "ORRERY_DRY": "1"}

    def tearDown(self):
        shutil.rmtree(self.t)

    def ctl(self, cmd, data=None):
        r = subprocess.run([sys.executable, str(CTL), cmd], input=json.dumps(data) if data is not None else None,
                           capture_output=True, text=True, env=self.env)
        self.assertTrue(r.stdout, r.stderr)
        return json.loads(r.stdout)

    def cfg(self, **kw):
        c = {"apps": {"browser": "zen.desktop"},
             "keyboard": {"managed": True, "layouts": [{"layout": "it", "variant": ""}, {"layout": "us", "variant": "intl"}],
                          "switchKey": "SUPER + Space", "numlock": True},
             "areas": [{"name": "Chat", "key": "SUPER + D", "spaces": [
                 {"id": "communication", "apps": [{"class": "discord", "command": "discord"}]},
                 {"id": "teamspeak", "apps": [{"class": "com.teamspeak.teamspeak", "command": "teamspeak"}]}]}]}
        c.update(kw)
        return c

    def lua(self, code):
        stub = '''
        local calls = {}
        local function rec(n) return function(...) calls[#calls+1] = {n, ...} end end
        hl = setmetatable({ get_windows=function() return WINS or {} end, get_active_special_workspace=function() return SP end,
          get_active_window=function() return ACTIVE end, dsp=setmetatable({}, {__index=function(_,k)
            if k=="window" or k=="workspace" then return setmetatable({}, {__index=function(_,j) return function(a) return {k.."."..j,a} end end}) end
            return function(a,b) return {k,a,b} end end}) }, {__index=function(_,k) return rec(k) end})
        CALLS = calls
        package.path = "%s/caelestia/?.lua;" .. package.path
        package.preload["variables"] = function() return { kbBrowser = "SUPER + W" } end
        ''' % self.t
        r = subprocess.run(["lua", "-e", stub + code], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout

    def test_apply_and_hook_position(self):
        self.assertTrue(self.ctl("apply", self.cfg())["ok"])
        self.assertTrue(self.ctl("apply", self.cfg())["ok"])
        t = (self.t / "caelestia/hypr-user.lua").read_text()
        self.assertEqual(t.count("orrery.engine"), 1)
        self.assertLess(t.index("orrery.engine"), t.index("-- HyprMod: last"))
        self.assertTrue(t.rstrip().endswith('require("hyprland-gui")'))

    def test_undo_restores_exactly(self):
        self.ctl("apply", self.cfg())
        self.assertTrue(self.ctl("undo")["ok"])
        self.assertEqual((self.t / "caelestia/hypr-user.lua").read_text(), BASE_USER)
        self.assertFalse((self.t / "orrery/config.json").exists())
        self.assertIn("error", self.ctl("undo"))

    def test_disable(self):
        self.ctl("apply", self.cfg())
        self.ctl("disable")
        self.assertNotIn("orrery", (self.t / "caelestia/hypr-user.lua").read_text())

    def test_lua_escaping(self):
        nasty = 'a"]] .. os.execute("touch /tmp/pwn") -- \\ é'
        c = self.cfg()
        c["areas"][0]["spaces"][0]["apps"][0].update({"class": nasty, "command": nasty})
        self.ctl("apply", c)
        out = self.lua('io.write(require("orrery.settings").areas[1].spaces[1].apps[1].command)')
        self.assertEqual(out, nasty)

    def test_rejects(self):
        for bad in (dict(keyboard={"managed": True, "layouts": [{"layout": "it;rm", "variant": ""}]}),
                    dict(keyboard={"managed": True, "layouts": []}), dict(apps={"browser": "nope.desktop"}),
                    dict(areas=[{"name": "x", "key": "D", "spaces": [{"id": "a"}]}]),
                    dict(areas=[{"name": "x", "key": "SUPER + D", "spaces": []}]),
                    dict(areas=[{"name": "x\ny", "key": "SUPER + D", "spaces": [{"id": "a"}]}]),
                    dict(areas=[{"name": n, "key": "SUPER + D", "spaces": [{"id": n}]} for n in "ab"]),
                    dict(areas=[{"name": n, "key": k, "spaces": [{"id": "same"}]} for n, k in (("a", "SUPER + D"), ("b", "SUPER + M"))])):
            r = self.ctl("apply", self.cfg(**bad))
            self.assertFalse(r.get("ok", True), bad)
        self.assertEqual((self.t / "caelestia/hypr-user.lua").read_text(), BASE_USER)

    def test_wallpapers(self):
        home = self.t / "home"
        home.mkdir()
        self.env["HOME"] = str(home)
        sj = self.t / "caelestia/shell.json"
        sj.write_text('{"lock": {"useWallpaper": true}}')
        r = self.ctl("wallpapers", {"dir": str(home / "Immagini/Wallpapers")})
        self.assertTrue(r["ok"], r)
        self.assertEqual(len(r["added"]), 2)
        d = json.loads(sj.read_text())
        self.assertEqual((d["lock"], d["paths"]["wallpaperDir"]), ({"useWallpaper": True}, str(home / "Immagini/Wallpapers")))
        self.assertEqual(self.ctl("wallpapers", {"dir": str(home / "Immagini/Wallpapers")})["added"], [])
        self.assertTrue(self.ctl("use-wallpaper", {"name": "night"})["ok"])
        self.assertFalse(self.ctl("use-wallpaper", {"name": "../x"}).get("ok", True))
        for bad in ("/etc/x", "relative", str(home / "../../etc")):
            self.assertFalse(self.ctl("wallpapers", {"dir": bad}).get("ok", True), bad)
        sj.write_text("{broken")
        self.assertFalse(self.ctl("wallpapers", {}).get("ok", True))
        self.assertEqual(sj.read_text(), "{broken")

    def power(self, shell=None, **kw):
        sj = self.t / "caelestia/shell.json"
        if shell is not None:
            sj.write_text(json.dumps(shell))
        c = self.cfg(power={**self.ctl("state")["config"]["power"], **kw})
        return self.ctl("apply", c), (json.loads(sj.read_text()) if sj.exists() else None)

    def test_power_untouched(self):
        self.assertEqual(self.power()[1], None)      # nothing changed: no file is created
        sj = self.t / "caelestia/shell.json"
        sj.write_text('{"lock":   {}}')
        self.assertTrue(self.power()[0]["ok"])
        self.assertEqual(sj.read_text(), '{"lock":   {}}')

    def test_power_times(self):
        base = {"paths": {"wallpaperDir": "/x"}, "general": {"logo": "a"}}
        r, d = self.power(base, battery=900, ac=3600)
        self.assertTrue(r["ok"], r)
        self.assertEqual((d["paths"], d["general"]["logo"]), (base["paths"], "a"))
        t = d["general"]["idle"]["timeouts"]
        self.assertEqual([(x["timeout"], x.get("inhibitWhenCharging")) for x in t if x["idleAction"] == ["suspendThenHibernate"]],
                         [(3600, None), (900, True)])
        self.assertEqual([x["idleAction"] for x in t[:2]], ["lock", "dpms off"])     # the list replaces the defaults: all rows
        self.assertEqual(t[1]["returnAction"], "dpms on")
        p = self.ctl("state")["config"]["power"]
        self.assertEqual((p["battery"], p["ac"]), (900, 3600))
        r, d = self.power(battery=900, ac=0, screen=0, action="suspend")             # never while charging
        p = self.ctl("state")["config"]["power"]
        self.assertEqual((p["battery"], p["ac"], p["screen"], p["action"]), (900, 0, 0, "suspend"))
        r, d = self.power(**self.ctl("state")["power"]["defaults"])
        p, want = self.ctl("state")["config"]["power"], self.ctl("state")["power"]["defaults"]
        self.assertEqual(p, want)

    def test_power_defaults_leave_no_trace(self):
        base = {"general": {"logo": "a"}}
        self.power(base, lock=60, audio=False, charging=True, lockBefore=False)
        r, d = self.power(**self.ctl("state")["power"]["defaults"])
        self.assertEqual(d, base)

    def test_power_keeps_own_rows(self):
        own = [{"timeout": 30, "idleAction": ["notify-send", "x"]}, {"timeout": 200, "idleAction": "lock", "respectInhibitors": False},
               {"timeout": 500, "idleAction": ["systemctl", "suspend"], "inhibitWhenAudio": True}, {"timeout": 999, "idleAction": "lock"}, "junk"]
        r, d = self.power({"general": {"idle": {"timeouts": own, "future": 1}}}, lock=240, battery=300)
        self.assertTrue(r["ok"], r)
        t = d["general"]["idle"]["timeouts"]
        self.assertEqual((t[0], t[3], t[4], d["general"]["idle"]["future"]), (own[0], own[3], "junk", 1))
        self.assertEqual(t[1], {"timeout": 240, "idleAction": "lock", "respectInhibitors": False})
        self.assertEqual(t[2], own[2])
        self.assertEqual(t[5], {"timeout": 300, "idleAction": ["systemctl", "suspend"], "inhibitWhenAudio": True, "inhibitWhenCharging": True})
        self.assertEqual(len(t), 6)      # a row that is off and never existed is not added

    def test_power_undo(self):
        base = {"general": {"idle": {"timeouts": [{"timeout": 77, "idleAction": "lock"}]}}, "lock": {}}
        self.power(base, lock=600)
        sj = self.t / "caelestia/shell.json"
        d = json.loads(sj.read_text()); d["lock"] = {"later": True}; sj.write_text(json.dumps(d))
        self.assertTrue(self.ctl("undo")["ok"])
        self.assertEqual(json.loads(sj.read_text()), {**base, "lock": {"later": True}})   # later changes stay

    def test_power_rejects(self):
        for bad in (dict(battery=900, ac=600), dict(battery=0, ac=600), dict(lock=-1), dict(lock="x"), dict(lock=True), dict(lock=False), dict(screen=5), dict(action="poweroff")):
            r, d = self.power({"a": 1}, **bad)
            self.assertFalse(r.get("ok", True), bad)
            self.assertEqual(d, {"a": 1})
        sj = self.t / "caelestia/shell.json"
        for broken in ("{broken", '{"general": {"idle": []}}', '{"general": {"idle": {"timeouts": 3}}}'):
            sj.write_text(broken)
            self.assertIsNone(self.ctl("state")["config"]["power"])
            self.assertTrue(self.ctl("apply", self.cfg(power=None))["ok"])    # the rest still works
            self.assertFalse(self.ctl("apply", self.cfg(power=self.ctl("state")["power"]["defaults"])).get("ok", True))
            self.assertEqual(sj.read_text(), broken)

    def shell(self, base=None, **sections):
        sj = self.t / "caelestia/shell.json"
        if base is not None:
            sj.write_text(json.dumps(base))
        cur = self.ctl("state")["config"]["shell"]
        for k, fn in sections.items():
            fn(cur[k])
        return self.ctl("apply", self.cfg(shell=cur)), (json.loads(sj.read_text()) if sj.exists() else None)

    def test_shell_untouched(self):
        self.assertEqual(self.shell()[1], None)
        sj = self.t / "caelestia/shell.json"
        odd = '{"bar":  {"entries": [{"id": "clock", "x": [1]}], "excludedScreens": "no"}, "general": {"battery": {"warnLevels": [{"level": 0}]}}}'
        sj.write_text(odd)
        r, d = self.shell()
        self.assertTrue(r["ok"], r)          # strange hand-made values do not block the rest
        self.assertEqual(sj.read_text(), odd)

    def test_shell_battery_osd(self):
        base = {"general": {"logo": "a"}, "osd": {"future": 1}}
        def bat(b):
            b["warnLevels"] = [w for w in b["warnLevels"] if w["level"] != 10]
            b["warnLevels"][0]["level"] = 25
            b["criticalLevel"] = -1
        def osd(o):
            o["hideDelay"] = 3000
            o["enableMicrophone"] = True
        r, d = self.shell(base, battery=bat, osd=osd)
        self.assertTrue(r["ok"], r)
        b = d["general"]["battery"]
        self.assertEqual(([w["level"] for w in b["warnLevels"]], b["criticalLevel"], d["general"]["logo"]), ([25, 5], -1, "a"))
        self.assertEqual(b["warnLevels"][1]["critical"], True)
        self.assertEqual(b["warnLevels"][0]["title"], "Low battery")
        self.assertEqual(d["osd"], {"future": 1, "hideDelay": 3000, "enableMicrophone": True})   # only what differs
        dflt = self.ctl("state")["shell"]["defaults"]
        def back(k):
            return lambda x: (x.clear(), x.update(copy.deepcopy(dflt[k])))
        r, d = self.shell(None, battery=back("battery"), osd=back("osd"))
        self.assertEqual(d, base)            # Caelestia's defaults leave no trace

    def test_shell_bar_and_undo(self):
        base = {"bar": {"persistent": True}, "general": {"idle": {"inhibitWhenCharging": True}}}
        def bar(b):
            b["entries"] = [e for e in b["entries"] if e["id"] != "logo"]
            b["entries"][0], b["entries"][1] = b["entries"][1], b["entries"][0]
            b["entries"][-1]["enabled"] = False
            b["excludedScreens"] = ["HDMI-A-1"]
        r, d = self.shell(base, bar=bar)
        self.assertTrue(r["ok"], r)
        self.assertEqual([e["id"] for e in d["bar"]["entries"]][:2], ["spacer", "workspaces"])
        self.assertEqual((d["bar"]["entries"][-1], d["bar"]["excludedScreens"], d["bar"]["persistent"]),
                         ({"id": "power", "enabled": False}, ["HDMI-A-1"], True))
        sj = self.t / "caelestia/shell.json"
        d["lock"] = {"later": True}; sj.write_text(json.dumps(d))
        self.assertTrue(self.ctl("undo")["ok"])
        self.assertEqual(json.loads(sj.read_text()), {**base, "lock": {"later": True}})

    def test_shell_rejects(self):
        def lvl(v):
            return lambda b: b["warnLevels"][0].update(level=v)
        cases = [dict(battery=lvl(0)), dict(battery=lvl("x")), dict(battery=lambda b: b.update(criticalLevel=80)),
                 dict(battery=lambda b: b["warnLevels"][0].update(icon="a b")), dict(osd=lambda o: o.update(hideDelay=1)),
                 dict(bar=lambda b: b["entries"].append({"id": "a b"})), dict(bar=lambda b: b.update(excludedScreens=["a\nb"]))]
        for bad in cases:
            r, d = self.shell({"a": 1}, **bad)
            self.assertFalse(r.get("ok", True), bad)
            self.assertEqual(d, {"a": 1})
        sj = self.t / "caelestia/shell.json"
        sj.write_text("{broken")
        self.assertIsNone(self.ctl("state")["config"]["shell"])
        self.assertTrue(self.ctl("apply", self.cfg(shell=None))["ok"])
        self.assertEqual(sj.read_text(), "{broken")

    def picture(self, name, clear):
        from PIL import Image
        im = Image.new("RGBA", (40, 30), (0, 0, 0, 0) if clear else (255, 255, 255, 255))
        im.paste((200, 50, 50, 255), (10, 8, 30, 22))
        f = self.t / name
        im.save(f)
        return f

    def test_pictures(self):
        clear, solid = self.picture("cat.gif", True), self.picture("box.png", False)
        r = self.ctl("pic-import", {"path": str(clear)})
        self.assertTrue(r["ok"], r)
        self.assertTrue(r["info"]["transparent"])
        kept = Path(r["path"])
        self.assertEqual((kept.parent, kept.read_bytes()), (self.t / "data/orrery/gifs", clear.read_bytes()))
        self.assertEqual(self.ctl("pic-import", {"path": str(kept)})["path"], str(kept))     # already Orrery's: not copied again
        self.assertFalse(self.ctl("pic-import", {"path": str(solid)})["info"]["transparent"])
        for bad in (str(self.t / "nope.gif"), str(self.t / "caelestia/hypr-user.lua"), "relative.gif"):
            self.assertFalse(self.ctl("pic-import", {"path": bad}).get("ok", True), bad)
        def gifs(g):
            g["media"] = str(kept)
            g["mediaSpeed"] = 150
        r, d = self.shell({"paths": {"wallpaperDir": "/x"}}, gifs=gifs)
        self.assertTrue(r["ok"], r)
        self.assertEqual(d["paths"], {"wallpaperDir": "/x", "mediaGif": str(kept)})
        self.assertEqual(d["general"], {"mediaGifSpeedAdjustment": 150.0})
        dflt = self.ctl("state")["shell"]["defaults"]["gifs"]
        r, d = self.shell(None, gifs=lambda g: g.update(dflt))
        self.assertEqual(d, {"paths": {"wallpaperDir": "/x"}})
        for bad in (dict(media=str(self.t / "caelestia/hypr-user.lua")), dict(media="relative.gif"), dict(sessionSpeed=0), dict(mediaSpeed=True)):
            r, d = self.shell(None, gifs=lambda g: g.update(bad))
            self.assertFalse(r.get("ok", True), bad)
        self.assertIn("files", self.ctl("pic-files", {}))
        if Path("/etc/xdg/quickshell/caelestia/assets/bongocat.gif").exists():
            self.assertTrue(self.ctl("pic-originals", {})["ok"])
            o = self.ctl("state")["pics"]["originals"]
            self.assertEqual(Path(o["media"]).read_bytes(), Path("/etc/xdg/quickshell/caelestia/assets/bongocat.gif").read_bytes())
            self.assertTrue(o["media"].startswith(str(self.t / "data/orrery/gifs/caelestia/")))

    def test_giphy_offline(self):
        self.assertFalse(self.ctl("giphy-search", {"query": "cat"}).get("ok", True))       # no key
        self.assertFalse(self.ctl("giphy-key", {"key": "not a key!"}).get("ok", True))
        self.assertFalse(self.ctl("giphy-save", {"id": "../x"}).get("ok", True))
        self.assertTrue(self.ctl("giphy-key", {"key": ""})["ok"])                         # removing works offline
        self.assertFalse(self.ctl("state")["pics"]["giphy"])

    def test_giphy_flow(self):
        """GIPHY's answers are faked: order is kept, a sticker with a background is marked and cannot be saved."""
        import importlib.util, io
        from PIL import Image
        os.environ.update({k: v for k, v in self.env.items() if k.startswith("XDG_")})
        spec = importlib.util.spec_from_file_location("octl", CTL)
        m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
        def pic(clear):
            b = io.BytesIO()
            Image.new("RGBA", (20, 20), (0, 0, 0, 0) if clear else (9, 9, 9, 255)).save(b, "GIF")
            return b.getvalue()
        img = lambda i: {"fixed_width": {"url": f"https://media.giphy.com/{i}/w.gif", "width": "200", "height": "150"},
                         "fixed_width_small": {"url": f"https://media.giphy.com/{i}/s.gif"},
                         "original": {"url": f"https://media.giphy.com/{i}/o.gif"}}
        api = {"stickers/search": {"data": [{"id": "aaa", "title": "cat", "images": img("aaa")}, {"id": "bbb", "images": img("bbb")},
                                            {"id": "ccc", "images": {"fixed_width": {"url": "http://evil.example/x.gif"}}}],
                                   "pagination": {"count": 3, "total_count": 50}, "meta": {"status": 200, "response_id": "r"}},
               "gifs/aaa": {"data": {"images": img("aaa")}, "meta": {"status": 200, "response_id": "r"}},
               "gifs/bbb": {"data": {"images": img("bbb")}, "meta": {"status": 200, "response_id": "r"}}}
        calls = []
        def fetch(url, limit=0):
            calls.append(url)
            if url.startswith(m.GIPHY):
                return json.dumps(api[url[len(m.GIPHY) + 1:].split("?")[0]]).encode()
            return pic("/aaa/" in url)
        m.fetch, m.giphy_key = fetch, lambda: "k" * 32
        r = m.giphy_search({"query": "cat"})
        self.assertEqual([(x["id"], x["transparent"]) for x in r["results"]], [("aaa", True), ("bbb", False)])   # no foreign URLs
        self.assertEqual((r["next"], r["total"]), (3, 50))
        self.assertTrue(any("q=cat" in c and "api_key=" in c for c in calls))
        saved = m.giphy_save({"id": "aaa"})
        self.assertTrue(Path(saved["path"]).is_file() and saved["path"].endswith("giphy-aaa.gif"))
        with self.assertRaises(m.Bad):
            m.giphy_save({"id": "bbb"})

    def test_prefs(self):
        self.assertTrue(self.ctl("prefs", {"transparent": False, "junk": 1})["ok"])
        self.assertTrue(self.ctl("prefs", {"base": 0.5, "language": "it"})["ok"])
        d = json.loads((self.t / "orrery/ui.json").read_text())
        self.assertEqual((d["transparent"], d["base"], d["language"], "junk" in d), (False, 0.5, "it", False))
        for bad in ({"base": 9}, {"speed": "x"}, {"language": "xx"}):
            self.assertFalse(self.ctl("prefs", bad).get("ok", True))
        self.assertEqual((self.t / "caelestia/hypr-user.lua").read_text(), BASE_USER)

    def test_first_run_presets_apply(self):
        st = self.ctl("state")
        keys = [a["key"] for a in st["config"]["areas"]]
        for k in ("SUPER + S", "SUPER + D", "SUPER + M"):
            self.assertIn(k, keys)
        self.assertEqual(set(st["config"]["apps"].values()), {""})
        self.assertTrue(all(not a["enabled"] for a in st["config"]["areas"]))
        self.assertTrue(self.ctl("apply", {**st["config"], "keyboard": self.cfg()["keyboard"]})["ok"])
        self.assertEqual(self.lua('io.write(#require("orrery.settings").areas)'), "0")

    def test_engine_navigation(self):
        self.ctl("apply", self.cfg())
        out = self.lua('''
        local function win(c, ws, x) return {class=c, address=c, mapped=true, floating=false, workspace={name=ws}, at={x=x,y=0}, size={x=900,y=1000}} end
        WINS = { win("discord","special:communication",0), win("com.teamspeak.teamspeak","special:other",0) }
        local M = require("orrery.engine")
        local function last() for i=#CALLS,1,-1 do if CALLS[i][1]=="dispatch" then local d=CALLS[i][2] return d[1],d[2] end end end
        M.toggle("area1")
        local moved=false for _,c in ipairs(CALLS) do if c[1]=="dispatch" and c[2][1]=="window.move" and c[2][2].workspace=="special:teamspeak" then moved=true end end
        local n,a = last(); print(moved, n, a.workspace)
        WINS[2].workspace.name="special:teamspeak"; SP={name="special:communication"}; ACTIVE=WINS[1]
        M.focus("right"); n,a=last(); print(n, a.workspace)
        M.move("right"); n,a=last(); print(n, a.workspace, a.follow)
        WINS[2].workspace.name="special:communication"; WINS[2].at.x=1000
        M.focus("right"); n,a=last(); print(n, a.direction)
        M.move("right"); n,a=last(); print(n, a.direction)
        SP=nil; M.focus("left"); n,a=last(); print(n, a.direction)
        ''').split("\n")
        self.assertEqual(out[:6], ["true\tfocus\tspecial:communication", "focus\tspecial:teamspeak",
                                   "window.move\tspecial:teamspeak\ttrue", "focus\tright", "window.move\tright", "focus\tleft"])

    def test_window_names(self):
        # Telegram: StartupWMClass and the Wayland class differ. Opening the area must not start it again.
        (self.t / "data/applications/org.telegram.desktop.desktop").write_text("[Desktop Entry]\nType=Application\nName=Telegram\nExec=Telegram -- %U\nStartupWMClass=TelegramDesktop\n")
        c = self.cfg(); apps = c["areas"][0]["spaces"][1]["apps"]
        apps.append({"class": "TelegramDesktop", "command": "Telegram"}); self.ctl("apply", c)
        self.assertIn("(?i)^(TelegramDesktop|org\\092.telegram\\092.desktop)$", (self.t / "caelestia/orrery/settings.lua").read_text())
        run = lambda cls: self.lua('''
        local function win(c, ws) return {class=c, address=c, mapped=true, floating=false, workspace={name=ws}, at={x=0,y=0}, size={x=9,y=9}} end
        WINS = { win("discord","special:communication"), win("com.teamspeak.teamspeak","special:teamspeak"), win("%s","special:teamspeak") }
        local M = require("orrery.engine")
        SP={name="special:communication"}; M.toggle("area1"); SP=nil
        M.toggle("area1")
        for _,c in ipairs(CALLS) do if c[1]=="dispatch" then local d=c[2] print(d[1], type(d[2])=="table" and d[2].workspace or d[2]) end end
        ''' % cls).split("\n")[:-1]
        for cls in ("org.telegram.desktop", "TelegramDesktop", "telegramdesktop"):
            out = run(cls)
            self.assertFalse([l for l in out if l.startswith("exec_cmd")], out)
            self.assertEqual(out[-1], "focus\tspecial:communication")  # exactly where it was left
        self.assertIn("exec_cmd\tTelegram", run("other"))  # really closed: it starts
        # a name another app already uses is never taken over
        apps.append({"class": "org.telegram.desktop", "command": "x"}); self.ctl("apply", c)
        self.assertIn('"(?i)^TelegramDesktop$"', (self.t / "caelestia/orrery/settings.lua").read_text())

    def test_engine_binds(self):
        self.ctl("apply", self.cfg())
        out = self.lua('require("orrery.engine") for _,c in ipairs(CALLS) do if c[1]=="bind" then print(c[2]) end end')
        for k in ("SUPER + Space", "SUPER + W", "SUPER + D", "SUPER + left", "SUPER + SHIFT + right"):
            self.assertIn(k + "\n", out)


if __name__ == "__main__":
    unittest.main()
