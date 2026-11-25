#!/usr/bin/env python3
"""Draws Orrery's two wallpapers (3840x2160). Usage: make.py  -> orrery-dawn.svg/png, orrery-night.svg/png"""
import math, random, re, subprocess
from pathlib import Path
HERE = Path(__file__).resolve().parent
LOGO = Path("/etc/xdg/quickshell/caelestia/assets/logo.svg")

THEMES = {
    "dawn": dict(sky=["#fff4f6", "#ffdbe6", "#f9b9d0"], glow="#ffffff", orbit="#d9789f", planet=["#f08fb4", "#ffc2a8", "#c987d6"], star="#ffffff",
                 hill=["#f5a9c4", "#e889ae", "#d56c97"], ink="#7a2f52", skin="#ffe3d6", blush="#ff9fb0", hair="#8d4a78", hair2="#743a64", ear="#ffb3c7",
                 coat="#fff8fb", coat2="#f2d3e0", trim="#e0709a", shirt="#b05a8a", trousers="#6d4468", boot="#4c2c4b", boot2="#e0709a", eye="#8a2f63", moon="#fff9ee", logo="#8a3560"),
    "night": dict(sky=["#0b1026", "#1a1b45", "#3a2a63"], glow="#8f7bff", orbit="#8fa4ff", planet=["#7fd6e8", "#c79bff", "#ff9fc9"], star="#ffffff",
                  hill=["#241f4d", "#1a173d", "#110f2c"], ink="#0a0a1e", skin="#f6d9d2", blush="#e88fa6", hair="#5a5fa8", hair2="#454a8c", ear="#d79bd0",
                  coat="#e9ebff", coat2="#b9bee8", trim="#7fd6e8", shirt="#454c94", trousers="#2f3370", boot="#4a50a0", boot2="#7fd6e8", eye="#3fb4d0", moon="#fdf3d0", logo="#dfe3ff"),
}


def figure(c):
    """Adult catgirl astronomer, front view. Feet at y=0, ~1480 units tall, centred on x=0."""
    g = []
    a = g.append
    p = lambda d, f, extra="": a(f'<path d="{d}" fill="{f}" {extra}/>')
    line = lambda d, w, col, extra="": a(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" {extra}/>')
    # tail
    line("M70,-640 C260,-600 330,-420 250,-300 C200,-220 250,-150 330,-190", 46, c["hair"])
    line("M316,-196 C326,-198 334,-196 338,-192", 46, c["ear"])
    # back hair
    p("M-60,-1330 C-190,-1270 -205,-900 -158,-760 C-110,-706 110,-706 158,-760 C205,-900 190,-1270 60,-1330 Z", c["hair2"])
    # legs
    p("M-118,-640 L-104,-150 L-30,-150 L-6,-600 L6,-600 L34,-150 L108,-150 L122,-640 Z", c["trousers"])
    line("M-66,-560 L-66,-190", 4, c["boot"], 'opacity=".35"'); line("M72,-560 L70,-190", 4, c["boot"], 'opacity=".35"')
    # boots
    p("M-116,-250 L-24,-250 L-24,-60 C-24,-30 -30,0 -60,0 L-176,0 C-196,0 -198,-34 -172,-44 C-136,-58 -116,-80 -116,-110 Z", c["boot"])
    p("M24,-250 L116,-250 L116,-110 C116,-80 136,-58 172,-44 C198,-34 196,0 176,0 L60,0 C30,0 24,-30 24,-60 Z", c["boot"])
    p("M-122,-272 L-18,-272 L-18,-236 L-122,-236 Z M18,-272 L122,-272 L122,-236 L18,-236 Z", c["boot2"])
    p("M-186,-14 L-26,-14 L-30,0 L-178,0 Z M186,-14 L26,-14 L30,0 L178,0 Z", c["boot2"], 'opacity=".8"')
    # shirt
    p("M-120,-1050 L120,-1050 L104,-620 L-104,-620 Z", c["shirt"])
    p("M-110,-690 L110,-690 L108,-650 L-108,-650 Z", c["boot"]); p("M-24,-700 h48 v60 h-48 Z", c["trim"])
    # coat body (open)
    p("M-160,-1060 C-190,-900 -190,-700 -260,-330 C-210,-300 -150,-300 -96,-330 C-60,-560 -70,-860 -44,-1066 Z", c["coat"])
    p("M160,-1060 C190,-900 190,-700 260,-330 C210,-300 150,-300 96,-330 C60,-560 70,-860 44,-1066 Z", c["coat"])
    p("M-96,-330 C-60,-560 -70,-860 -44,-1066 L-70,-1066 C-100,-860 -96,-560 -140,-316 Z", c["coat2"])
    p("M96,-330 C60,-560 70,-860 44,-1066 L70,-1066 C100,-860 96,-560 140,-316 Z", c["coat2"])
    line("M-258,-334 C-210,-304 -150,-304 -98,-334", 12, c["trim"]); line("M258,-334 C210,-304 150,-304 98,-334", 12, c["trim"])
    for x, y, r in ((-196, -470, 9), (-168, -600, 6), (-214, -400, 5), (200, -440, 9), (172, -560, 6), (218, -380, 5)):
        p(star(x, y, r * 2.2), c["trim"])
    # left arm (down, hand on coat) and right arm (raised, holding the orrery)
    p("M-150,-1056 C-200,-1040 -226,-960 -232,-860 C-238,-780 -230,-720 -214,-690 L-150,-700 C-160,-780 -150,-880 -128,-960 Z", c["coat"])
    p("M-222,-716 L-146,-724 L-142,-684 L-216,-676 Z", c["trim"])
    p("M-212,-680 C-222,-640 -206,-606 -184,-606 C-160,-606 -146,-640 -150,-686 Z", c["skin"])
    p("M140,-1056 C190,-1046 240,-980 286,-920 C330,-960 352,-1010 366,-1064 L432,-1042 C420,-950 372,-858 306,-824 C250,-810 190,-870 150,-930 Z", c["coat"])
    p("M360,-1078 L438,-1050 L430,-1014 L350,-1042 Z", c["trim"])
    p("M372,-1072 C372,-1120 386,-1140 408,-1140 C430,-1140 438,-1100 428,-1052 Z", c["skin"])
    # neck, scarf
    p("M-36,-1110 h72 v80 h-72 Z", c["skin"])
    p("M-130,-1086 C-70,-1030 70,-1030 130,-1086 C136,-1040 110,-1004 0,-1000 C-110,-1004 -136,-1040 -130,-1086 Z", c["trim"])
    p("M-70,-1014 C-84,-960 -92,-900 -86,-830 L-34,-836 C-38,-900 -34,-960 -22,-1006 Z", c["trim"]); line("M-84,-850 L-36,-856", 8, c["coat"])
    a('<g transform="translate(0,-1085) scale(.9) translate(0,1085)">')
    # head
    p("M-118,-1250 C-122,-1150 -74,-1072 0,-1072 C74,-1072 122,-1150 118,-1250 C114,-1350 -114,-1350 -118,-1250 Z", c["skin"])
    # ears
    p("M-128,-1330 C-150,-1420 -150,-1470 -138,-1496 C-96,-1470 -50,-1420 -30,-1376 Z", c["hair"]); p("M-116,-1354 C-128,-1410 -130,-1440 -126,-1462 C-100,-1440 -72,-1408 -58,-1380 Z", c["ear"])
    p("M128,-1330 C150,-1420 150,-1470 138,-1496 C96,-1470 50,-1420 30,-1376 Z", c["hair"]); p("M116,-1354 C128,-1410 130,-1440 126,-1462 C100,-1440 72,-1408 58,-1380 Z", c["ear"])
    # face
    for s in (-1, 1):
        p(f"M{s*28},-1206 C{s*30},-1236 {s*78},-1240 {s*84},-1204 C{s*80},-1176 {s*38},-1172 {s*28},-1206 Z", "#ffffff")
        a(f'<ellipse cx="{s*57}" cy="-1204" rx="19" ry="25" fill="{c["eye"]}"/><ellipse cx="{s*57}" cy="-1198" rx="9" ry="13" fill="{c["ink"]}"/><circle cx="{s*57-7}" cy="-1214" r="7" fill="#fff"/>')
        line(f"M{s*24},-1208 C{s*32},-1242 {s*78},-1246 {s*92},-1212", 8, c["ink"]); line(f"M{s*30},-1262 C{s*48},-1272 {s*70},-1270 {s*84},-1260", 6, c["hair2"])
        a(f'<ellipse cx="{s*78}" cy="-1156" rx="24" ry="11" fill="{c["blush"]}" opacity=".5"/>')
    line("M-4,-1166 L2,-1158", 4, c["blush"]); line("M-24,-1126 C-10,-1112 12,-1112 26,-1128", 6, c["ink"])
    # fringe
    p("M-136,-1180 C-160,-1300 -110,-1404 0,-1404 C110,-1404 160,-1300 136,-1180 C126,-1230 112,-1262 92,-1292 C70,-1262 40,-1250 10,-1246 C24,-1262 34,-1280 36,-1296 C4,-1258 -50,-1240 -92,-1238 C-110,-1226 -124,-1206 -136,-1180 Z", c["hair"])
    p("M-138,-1200 C-160,-1120 -156,-1040 -130,-970 C-116,-1030 -112,-1110 -114,-1190 Z M138,-1200 C160,-1120 156,-1040 130,-970 C116,-1030 112,-1110 114,-1190 Z", c["hair"])
    line("M-84,-1370 C-40,-1392 40,-1392 84,-1370", 10, "#ffffff", 'opacity=".22"')
    # goggles on the hair, round glasses chain star
    p(star(96, -1330, 26), c["trim"])
    a('</g>')
    # the orrery above the hand
    a(f'<g transform="translate(404,-1290)">{mini(c)}</g>')
    return "\n".join(g)


def star(x, y, r, n=4, k=.36):
    pts = [(x + math.sin(i * math.pi / n) * (r if i % 2 == 0 else r * k), y - math.cos(i * math.pi / n) * (r if i % 2 == 0 else r * k)) for i in range(n * 2)]
    return "M" + " L".join(f"{a:.1f},{b:.1f}" for a, b in pts) + " Z"


def mini(c):
    o = [f'<circle r="150" fill="{c["glow"]}" opacity=".16"/>', f'<circle r="36" fill="{c["moon"]}"/>']
    for i, (r, ang, s) in enumerate(((70, 40, 13), (104, 200, 17), (138, 320, 11))):
        x, y = r * math.cos(math.radians(ang)), r * math.sin(math.radians(ang)) * .5
        o.append(f'<ellipse rx="{r}" ry="{r*.5}" fill="none" stroke="{c["trim"]}" stroke-width="5"/><circle cx="{x:.1f}" cy="{y:.1f}" r="{s}" fill="{c["planet"][i]}"/>')
    return f'<g transform="rotate(-14)">{"".join(o)}</g>'


def brand(c):
    """Orrery's mark: a sun and three orbits."""
    o = [f'<circle r="30" fill="{c}"/>']
    for r, ang, s in ((66, 200, 14), (106, 320, 18), (146, 85, 12)):
        o.append(f'<circle r="{r}" fill="none" stroke="{c}" stroke-width="6" opacity=".55"/><circle cx="{r*math.cos(math.radians(ang)):.1f}" cy="{r*math.sin(math.radians(ang)):.1f}" r="{s}" fill="{c}"/>')
    return "".join(o)


def caelestia(c):
    """Caelestia's own logo (GPL-3.0, caelestia-dots/shell), in one colour."""
    import xml.etree.ElementTree as ET
    out = []

    def walk(e, tf):
        tf = tf + ([e.get("transform")] if e.get("transform") else [])
        if e.tag.endswith("}path") and e.get("d"):
            out.append("".join(f'<g transform="{t}">' for t in tf) + f'<path d="{e.get("d")}"/>' + "</g>" * len(tf))
        for k in e:
            if not k.tag.endswith("}defs"):
                walk(k, tf)
    walk(ET.parse(LOGO).getroot(), [])
    return f'<g transform="scale(2.5) translate(-64,-64)" fill="{c}">{"".join(out)}</g>'


def scene(name):
    c, rnd = THEMES[name], random.Random(7)
    W, H = 3840, 2160
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {W} {H}" width="{W}" height="{H}"><defs>'
         f'<linearGradient id="sky" x1="0" y1="0" x2="0.25" y2="1"><stop offset="0" stop-color="{c["sky"][0]}"/><stop offset=".55" stop-color="{c["sky"][1]}"/><stop offset="1" stop-color="{c["sky"][2]}"/></linearGradient>'
         f'<radialGradient id="halo"><stop offset="0" stop-color="{c["glow"]}" stop-opacity=".75"/><stop offset="1" stop-color="{c["glow"]}" stop-opacity="0"/></radialGradient></defs>'
         f'<rect width="{W}" height="{H}" fill="url(#sky)"/><circle cx="2900" cy="1000" r="1150" fill="url(#halo)" opacity=".7"/>']
    for _ in range(230 if name == "night" else 90):
        x, y, r = rnd.uniform(0, W), rnd.uniform(0, 1500), rnd.choice((2, 2, 3, 4))
        o.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="{c["star"]}" opacity="{rnd.uniform(.35, .95):.2f}"/>')
    for _ in range(16):
        o.append(f'<path d="{star(rnd.uniform(100, W-100), rnd.uniform(80, 1250), rnd.uniform(14, 30), 4, .18)}" fill="{c["star"]}" opacity=".85"/>')
    # big orbits around the figure
    o.append('<g transform="translate(2900,1000) rotate(-16)">')
    for i, (rx, ang, s) in enumerate(((640, 205, 34), (960, 168, 52), (1320, 190, 40))):
        x, y = rx * math.cos(math.radians(ang)), rx * .36 * math.sin(math.radians(ang))
        o.append(f'<ellipse rx="{rx}" ry="{rx*.36}" fill="none" stroke="{c["orbit"]}" stroke-width="4" opacity=".4"/><circle cx="{x:.0f}" cy="{y:.0f}" r="{s}" fill="{c["planet"][i]}"/>')
    o.append("</g>")
    # moon and hills
    o.append(f'<circle cx="2900" cy="760" r="430" fill="{c["moon"]}" opacity="{.92 if name == "night" else .8}"/>')
    for (cx, cy, r) in ((2740, 640, 60), (3060, 900, 44), (2800, 940, 34), (3080, 620, 28)):
        o.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{c["sky"][1]}" opacity=".22"/>')
    o.append(f'<path d="M0,1860 C700,1660 1300,1900 1900,1800 C2500,1700 3000,1800 3840,1690 V2160 H0 Z" fill="{c["hill"][0]}"/>')
    o.append(f'<path d="M0,1990 C900,1830 1500,2030 2200,1930 C2700,1850 3300,1860 3840,1900 V2160 H0 Z" fill="{c["hill"][1]}"/>')
    o.append(f'<ellipse cx="2990" cy="2010" rx="330" ry="36" fill="{c["ink"]}" opacity=".25"/>')
    o.append(f'<g transform="translate(2990,2006) scale(1.06)">{figure(c)}</g>')
    o.append(f'<path d="M0,2110 C800,2010 1700,2120 2500,2070 C3000,2040 3400,2060 3840,2040 V2160 H0 Z" fill="{c["hill"][2]}"/>')
    # logos
    o.append(f'<g transform="translate(620,980)">{brand(c["logo"])}</g><path d="M860,850 V1110" stroke="{c["logo"]}" stroke-width="6" stroke-linecap="round" opacity=".4"/><g transform="translate(1110,980)">{caelestia(c["logo"])}</g>')
    o.append("</svg>")
    return "\n".join(o)


for n in THEMES:
    f = HERE / f"orrery-{n}.svg"
    f.write_text(scene(n))
    subprocess.run(["rsvg-convert", "-o", str(HERE / f"orrery-{n}.png"), str(f)], check=True)
    print(f.name, (HERE / f"orrery-{n}.png").stat().st_size // 1024, "KB")
