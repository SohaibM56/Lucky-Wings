"""Builds the App Store graphics from the same artwork as make_assets.py.

Run from the project root:  python store_assets/make_assets_ios.py
Outputs (store_assets/out_ios/):
  icon_1024.png              App Store icon, 1024x1024, RGB (no alpha, no rounded corners)
  iphone69_01..06_*.png      6.9" iPhone screenshots, 1320x2868
  iphone65_01..06_*.png      6.5" iPhone screenshots, 1284x2778
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(ROOT)
RAW = os.path.join(ROOT, "screenshots_raw")
OUT = os.path.join(ROOT, "out_ios")
os.makedirs(OUT, exist_ok=True)

NAVY = (15, 20, 40)
NAVY2 = (26, 26, 46)
GOLD = (255, 208, 0)
ORANGE = (245, 166, 35)
FONT = os.path.join(PROJECT, "assets", "fonts", "DiloWorld.ttf")


def font(size):
    return ImageFont.truetype(FONT, size)


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size, top)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def centered_text(draw, text, y, fnt, fill, width, off):
    box = draw.textbbox((0, 0), text, font=fnt)
    x = (width - (box[2] - box[0])) // 2
    draw.text((x + off, y + off + 1), text, font=fnt, fill=(0, 0, 0))
    draw.text((x, y), text, font=fnt, fill=fill)


# ── App Store icon 1024x1024 (opaque, square: Apple rounds it itself) ───────
logo = Image.open(os.path.join(PROJECT, "assets/images/logo/lucky_wings_logo.png")).convert("RGBA")
icon = gradient((1024, 1024), NAVY, (8, 10, 24)).convert("RGBA")
size = 940
icon.alpha_composite(logo.resize((size, size), Image.LANCZOS), ((1024 - size) // 2, (1024 - size) // 2))
icon.convert("RGB").save(os.path.join(OUT, "icon_1024.png"), optimize=True)

# ── iPhone screenshots ──────────────────────────────────────────────────────
SHOTS = [
    ("01_menu", "01_menu.png", ["PLAY. QUALIFY.", "WIN."]),
    ("02_gameplay", "07_after.png", ["TAP TO FLY", "THROUGH THE CRATES"]),
    ("03_gameover", "04_playing.png", ["BEAT YOUR", "BEST SCORE"]),
    ("04_raffle", "08_dashboard.png", ["5 MINUTES A DAY", "= 1 RAFFLE ENTRY"]),
    ("05_stats", "09_dashboard_stats.png", ["TRACK YOUR", "ENTRIES"]),
    ("06_store", "10_store.png", ["UNLOCK BIRDS", "AND MAPS"]),
]
SIZES = [("iphone69", 1320, 2868), ("iphone65", 1284, 2778)]

for prefix, CW, CH in SIZES:
    k = CW / 1080
    for name, src, lines in SHOTS:
        sp = os.path.join(RAW, src)
        if not os.path.exists(sp):
            print("missing", sp)
            continue
        shot = Image.open(sp).convert("RGB")
        # drop the status bar and the test-ad banner + nav bar
        shot = shot.crop((0, 100, shot.width, 2180))
        py = int(330 * k)
        th = CH - py - int(70 * k)
        tw = int(shot.width * th / shot.height)
        tw = min(tw, int(CW * 0.9))
        th = int(shot.height * tw / shot.width)
        shot = shot.resize((tw, th), Image.LANCZOS)
        canvas = gradient((CW, CH), NAVY2, NAVY).convert("RGBA")
        d = ImageDraw.Draw(canvas)
        y = int(70 * k)
        for i, line in enumerate(lines):
            centered_text(d, line, y, font(int(88 * k)), GOLD if i == 0 else ORANGE, CW, int(4 * k))
            y += int(110 * k)
        radius = int(44 * k)
        mask = Image.new("L", shot.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, tw, th), radius, fill=255)
        px = (CW - tw) // 2
        shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle((px, py + 14, px + tw, py + th + 14), radius, fill=(0, 0, 0, 150))
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
        canvas.paste(shot, (px, py), mask)
        canvas.convert("RGB").save(os.path.join(OUT, f"{prefix}_{name}.png"), optimize=True)

for f in sorted(os.listdir(OUT)):
    im = Image.open(os.path.join(OUT, f))
    print(f"{f:36s} {im.size} {im.mode} {os.path.getsize(os.path.join(OUT, f))//1024} KB")
