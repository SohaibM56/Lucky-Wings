"""Builds the Google Play graphics from the app's own artwork and screenshots.

Run from the project root:  python store_assets/make_assets.py
Outputs (store_assets/out/):
  icon_512.png               Play "App icon"        512x512, 32-bit PNG
  feature_graphic_1024x500.png                      1024x500
  phone_01..06_*.png         Phone screenshots      1080x2160 (exactly 2:1, the limit)
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(ROOT)
RAW = os.path.join(ROOT, "screenshots_raw")
OUT = os.path.join(ROOT, "out")
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


def centered_text(draw, text, y, fnt, fill, width, shadow=True):
    box = draw.textbbox((0, 0), text, font=fnt)
    x = (width - (box[2] - box[0])) // 2
    if shadow:
        draw.text((x + 4, y + 5), text, font=fnt, fill=(0, 0, 0))
    draw.text((x, y), text, font=fnt, fill=fill)


# ── 1. App icon 512x512 ─────────────────────────────────────────────────────
logo = Image.open(os.path.join(PROJECT, "assets/images/logo/lucky_wings_logo.png")).convert("RGBA")
icon = gradient((512, 512), NAVY, (8, 10, 24)).convert("RGBA")
size = 470  # the emblem fills the frame; Play applies its own rounded mask
emblem = logo.resize((size, size), Image.LANCZOS)
icon.alpha_composite(emblem, ((512 - size) // 2, (512 - size) // 2))
icon.save(os.path.join(OUT, "icon_512.png"), optimize=True)

# ── 2. Feature graphic 1024x500 ─────────────────────────────────────────────
W, H = 1024, 500
fg = gradient((W, H), NAVY2, NAVY)
# soft glow behind the emblem
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((-40, 20, 460, 520), fill=(245, 166, 35, 70))
glow = glow.filter(ImageFilter.GaussianBlur(60))
fg = fg.convert("RGBA")
fg.alpha_composite(glow)
emb = logo.resize((380, 380), Image.LANCZOS)
fg.alpha_composite(emb, (30, 60))
d = ImageDraw.Draw(fg)
tx = 450
d.text((tx + 4, 112 + 5), "LUCKY", font=font(112), fill=(0, 0, 0))
d.text((tx, 112), "LUCKY", font=font(112), fill=GOLD)
d.text((tx + 4, 222 + 5), "WINGS", font=font(112), fill=(0, 0, 0))
d.text((tx, 222), "WINGS", font=font(112), fill=ORANGE)
# tagline: words separated by drawn dots (the game font has no "·" glyph)
x = tx
for i, word in enumerate(["PLAY", "QUALIFY", "WIN"]):
    d.text((x + 3, 372 + 3), word, font=font(34), fill=(0, 0, 0))
    d.text((x, 372), word, font=font(34), fill=(220, 224, 245))
    x += int(d.textlength(word, font=font(34)))
    if i < 2:
        d.ellipse((x + 16, 392, x + 26, 402), fill=ORANGE)
        x += 42
# a few of the game's birds flying across the top right
for i, (ch, x, y, s) in enumerate([("char1", 790, 24, 0.28), ("char5", 880, 70, 0.22)]):
    p = os.path.join(PROJECT, "assets/images/birds", ch, "frame-1.png")
    if os.path.exists(p):
        b = Image.open(p).convert("RGBA")
        b = b.resize((int(b.width * s), int(b.height * s)), Image.LANCZOS)
        fg.alpha_composite(b, (x, y))
fg.convert("RGB").save(os.path.join(OUT, "feature_graphic_1024x500.png"), optimize=True)

# ── 3. Phone screenshots 1080x2160 ──────────────────────────────────────────
SHOTS = [
    ("01_menu", "01_menu.png", ["PLAY. QUALIFY.", "WIN."]),
    ("02_gameplay", "07_after.png", ["TAP TO FLY", "THROUGH THE CRATES"]),
    ("03_gameover", "04_playing.png", ["BEAT YOUR", "BEST SCORE"]),
    ("04_raffle", "08_dashboard.png", ["5 MINUTES A DAY", "= 1 RAFFLE ENTRY"]),
    ("05_stats", "09_dashboard_stats.png", ["TRACK YOUR", "ENTRIES"]),
    ("06_store", "10_store.png", ["UNLOCK BIRDS", "AND MAPS"]),
]
CW, CH = 1080, 2160
for name, src, lines in SHOTS:
    sp = os.path.join(RAW, src)
    if not os.path.exists(sp):
        print("missing", sp)
        continue
    shot = Image.open(sp).convert("RGB")
    # drop the status bar (clock/battery) and the test-ad banner + nav bar
    shot = shot.crop((0, 100, shot.width, 2180))
    tw = 940
    th = int(shot.height * tw / shot.width)
    shot = shot.resize((tw, th), Image.LANCZOS)
    canvas = gradient((CW, CH), NAVY2, NAVY).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    y = 60
    for i, line in enumerate(lines):
        centered_text(d, line, y, font(84), GOLD if i == 0 else ORANGE, CW)
        y += 104
    # rounded corners + drop shadow
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, tw, th), 40, fill=255)
    px, py = (CW - tw) // 2, 300
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((px, py + 14, px + tw, py + th + 14), 40, fill=(0, 0, 0, 150))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    canvas.paste(shot, (px, py), mask)
    canvas.convert("RGB").save(os.path.join(OUT, f"phone_{name}.png"), optimize=True)
    print("ok", name, (px, py, tw, th))

for f in sorted(os.listdir(OUT)):
    im = Image.open(os.path.join(OUT, f))
    print(f"{f:40s} {im.size} {os.path.getsize(os.path.join(OUT, f))//1024} KB")
