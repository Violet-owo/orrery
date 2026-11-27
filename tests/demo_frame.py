"""Frames the raw screenshots of tests/demo.sh: demo_frame.py RAW_DIR WALLPAPERS_DIR OUT_DIR -> OUT_DIR/*.jpg"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

raw, walls, out = map(Path, sys.argv[1:4])
out.mkdir(parents=True, exist_ok=True)
FONT = "/etc/xdg/quickshell/caelestia/assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
W, H = 1920, 1080
LINK = "github.com/Violet-owo/orrery"

SHOTS = [  # name, wallpaper, title, subtitle, crop top
    ("gif-search", "night", "GIPHY stickers, never with a background", "Search with your own free key: Orrery checks every result", 0),
    ("gif-places", "night", "Every GIF Caelestia shows, live", "Media, shut down menu and empty notifications, with their speed", 0),
    ("areas", "dawn", "Hidden workspaces, one shortcut away", "Super+D, Super+M and your own, with the apps that open in them", 0),
    ("lock", "night", "Caelestia's lock screen as your login", "Same colours and wallpaper as your desktop, on every monitor", 30),
    ("bar", "night", "Your bar, your order", "Blocks, screens, and the volume and brightness indicators", 0),
    ("power", "dawn", "When to lock, sleep, and warn you", "Times on battery and while charging, low battery warnings", 0),
]


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    try:
        axes = f.get_variation_axes()
        f.set_variation_by_axes([weight if a["name"] in (b"Weight", "Weight") else a["default"] for a in axes])
    except Exception:
        pass
    return f


def rounded(img, r):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, *img.size), r, fill=255)
    img = img.convert("RGBA")
    img.putalpha(m)
    return img


def logo(size, fg, bg):
    """The Orrery logo, drawn as in docs/logo.svg."""
    k = size / 128
    im = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = 4 * k
    d.rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), 36 * s, fill=bg)
    for r in (22, 35, 48):
        d.ellipse(((64 - r) * s, (64 - r) * s, (64 + r) * s, (64 + r) * s), outline=fg + (140,), width=round(2.5 * s))
    for cx, cy, r in ((64, 64, 11), (43.5, 56, 5.5), (91, 41.5, 7.5), (69, 111.7, 5)):
        d.ellipse(((cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s), fill=fg + (255,))
    return im.resize((size, size), Image.LANCZOS)


def backdrop(wall, dark):
    bg = Image.open(walls / f"orrery-{wall}.png").convert("RGB")
    bg = bg.resize((W, round(bg.height * W / bg.width))).crop((0, 0, W, H)) if bg.width / bg.height < W / H else \
        bg.resize((round(bg.width * H / bg.height), H)).crop((0, 0, W, H))
    bg = bg.filter(ImageFilter.GaussianBlur(28))
    shade = Image.new("RGB", (W, H), (10, 8, 20) if dark else (255, 248, 250))
    return Image.blend(bg, shade, 0.45 if dark else 0.35)


def card(name, wall, title, sub, crop):
    dark = wall == "night"
    fg, mute = ((242, 238, 255), (200, 194, 225)) if dark else ((52, 30, 44), (110, 80, 98))
    shot = Image.open(raw / f"{name}.png").convert("RGB")
    shot = shot.crop((4, crop, shot.width - 4, shot.height - 4)) if crop else shot
    sw = 1400
    shot = shot.resize((sw, round(shot.height * sw / shot.width)), Image.LANCZOS)
    img = backdrop(wall, dark).convert("RGBA")
    x, y = (W - sw) // 2, 230
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((x - 4, y + 14, x + sw + 4, y + shot.height + 26), 34, fill=(0, 0, 0, 150 if dark else 90))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(30)))
    img.alpha_composite(rounded(shot, 26), (x, y))
    d = ImageDraw.Draw(img)
    img.alpha_composite(logo(84, (47, 44, 82), (195, 192, 234, 255)), (x, 92))
    d.text((x + 108, 92), "Orrery", font=font(30, 600), fill=mute)
    d.text((x + 108, 128), title, font=font(46, 640), fill=fg)
    d.text((x + sw, 108), sub, font=font(24, 420), fill=mute, anchor="ra")
    d.text((x + sw, 150), LINK, font=font(24, 560), fill=fg, anchor="ra")
    img.convert("RGB").save(out / f"{name}.jpg", quality=88, optimize=True, progressive=True)
    return img


made = {n: card(n, w, t, s, c) for n, w, t, s, c in SHOTS if (raw / f"{n}.png").exists()}

# Cover: four shots in a grid
pick = [n for n in ("gif-search", "areas", "lock", "gif-places") if n in made]
cover = backdrop("night", True).convert("RGBA")
d = ImageDraw.Draw(cover)
cover.alpha_composite(logo(96, (47, 44, 82), (195, 192, 234, 255)), (200, 62))
d.text((320, 58), "Orrery", font=font(64, 680), fill=(242, 238, 255))
d.text((322, 130), "The settings Caelestia doesn't have yet  ·  " + LINK, font=font(28, 450), fill=(200, 194, 225))
tw = 740
for i, n in enumerate(pick):
    s = Image.open(raw / f"{n}.png").convert("RGB")
    s = s.crop((4, 30, s.width - 4, s.height - 4)) if n == "lock" else s
    s = s.resize((tw, round(s.height * tw / s.width)), Image.LANCZOS)
    x, y = (W - 2 * tw - 40) // 2 + (i % 2) * (tw + 40), 214 + (i // 2) * 440
    sh = Image.new("RGBA", cover.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((x, y + 10, x + tw, y + s.height + 18), 24, fill=(0, 0, 0, 140))
    cover = Image.alpha_composite(cover, sh.filter(ImageFilter.GaussianBlur(22)))
    cover.alpha_composite(rounded(s, 18), (x, y))
cover.convert("RGB").save(out / "cover.jpg", quality=88, optimize=True, progressive=True)
print(sorted(p.name for p in out.iterdir()))
