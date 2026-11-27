import os, pwd, shutil, subprocess, sys, tempfile, unittest
from pathlib import Path
H = Path(__file__).resolve().parent.parent / "helper/orrery-helper"
USER = pwd.getpwuid(os.getuid()).pw_name
TOML = '[terminal]\nvt = 1\n\n[default_session]\ncommand = "/usr/bin/noctalia-greeter-session"\nuser = "greeter"\n'


class T(unittest.TestCase):
    def setUp(self):
        self.r = Path(tempfile.mkdtemp())
        for d in ("usr/bin", "etc/greetd", "usr/share/wayland-sessions", "sys/class/leds/asus::kbd_backlight", "etc/systemd/system"):
            (self.r / d).mkdir(parents=True)
        for b in ("cage", "quickshell-greetd-launcher"):
            (self.r / "usr/bin" / b).touch()
        (self.r / "usr/share/wayland-sessions/hyprland-uwsm.desktop").touch()
        (self.r / "etc/greetd/config.toml").write_text(TOML)
        (self.r / "sys/class/leds/asus::kbd_backlight/max_brightness").write_text("3\n")

    def tearDown(self):
        shutil.rmtree(self.r)

    def run_(self, *a):
        return subprocess.run([sys.executable, "-I", str(H), *a], env={**os.environ, "ORRERY_ROOT": str(self.r)}, capture_output=True, text=True)

    def toml(self):
        return (self.r / "etc/greetd/config.toml").read_text()

    def test_login_roundtrip(self):
        for _ in range(2):
            r = self.run_("login-enable", USER, "it", "-", "1.25", "1")
            self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('command = "/usr/lib/orrery/orrery-greeter-session"', self.toml())
        self.assertIn("ORRERY_FALLBACK=/usr/bin/noctalia-greeter-session", (self.r / "etc/orrery/login.env").read_text())
        self.assertEqual(self.run_("login-disable").returncode, 0)
        self.assertEqual(self.toml(), TOML)

    def test_login_rejects(self):
        for a in ((USER, "it;x", "-", "1", "1"), (USER, "it", "$(x)", "1", "1"), (USER, "it", "-", "9", "1"),
                  (USER, "it", "-", "1", "2"), ("root", "it", "-", "1", "1"), ("nobody-x", "it", "-", "1", "1")):
            self.assertNotEqual(self.run_("login-enable", *a).returncode, 0, a)
        self.assertEqual(self.toml(), TOML)

    def test_missing_package(self):
        (self.r / "usr/bin/cage").unlink()
        self.assertNotEqual(self.run_("login-enable", USER, "it", "-", "1", "1").returncode, 0)
        self.assertEqual(self.toml(), TOML)

    def test_backlight(self):
        u = self.r / "etc/systemd/system/orrery-kbd-backlight.service"
        self.assertEqual(self.run_("backlight", "9").returncode, 0)
        self.assertIn("echo 3 >", u.read_text())
        self.assertEqual(self.run_("backlight", "0").returncode, 0)
        self.assertFalse(u.exists())
        for bad in ("x", "10", "1;reboot", ""):
            self.assertNotEqual(self.run_("backlight", bad).returncode, 0)

    def test_display_manager(self):
        link = self.r / "etc/systemd/system/display-manager.service"
        (self.r / "usr/lib/systemd/system").mkdir(parents=True)
        (self.r / "usr/lib/systemd/system/sddm.service").touch()
        link.symlink_to("/usr/lib/systemd/system/sddm.service")
        (self.r / "etc/greetd/config.toml").unlink()
        self.assertNotEqual(self.run_("dm-greetd").returncode, 0)            # greetd missing: nothing changes
        self.assertEqual(os.readlink(link), "/usr/lib/systemd/system/sddm.service")
        (self.r / "usr/bin/greetd").touch()
        r = self.run_("dm-greetd")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("systemctl disable sddm.service", r.stdout)
        self.assertIn("systemctl enable greetd.service", r.stdout)
        self.assertNotIn("stop", r.stdout)                                  # the running session is never cut
        self.assertIn('command = "agreety --cmd Hyprland"', self.toml())     # a working login until Orrery's is on
        self.assertEqual(self.run_("dm-greetd").returncode, 0)               # already greetd: no-op
        self.assertEqual((self.r / "etc/orrery/display-manager.before-orrery").read_text(), "sddm.service\n")
        r = self.run_("dm-restore")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(os.readlink(link), "/usr/lib/systemd/system/sddm.service")
        self.assertNotEqual(self.run_("dm-restore").returncode, 0)

    def test_unknown(self):
        for a in ((), ("rm",), ("backlight",), ("login-disable", "x")):
            self.assertNotEqual(self.run_(*a).returncode, 0)

    def test_refuses_without_root(self):
        e = {k: v for k, v in os.environ.items() if k != "ORRERY_ROOT"}
        self.assertNotEqual(subprocess.run([sys.executable, "-I", str(H), "login-disable"], env=e, capture_output=True).returncode, 0)


if __name__ == "__main__":
    unittest.main()
