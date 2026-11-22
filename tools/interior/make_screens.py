"""Static display images for the control-room prerender (Mission 004C).

Run:  python3 tools/interior/make_screens.py <out_dir>
Restrained, functional-looking naval displays: dark backgrounds, thin lines,
small monospaced text. No story content. Live screens (sonar, chart, ship
control, periscope video) are replaced at runtime by the game.
"""
import math
import random
import sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
W, H = 1024, 640
BG = (6, 12, 16)
CYAN = (90, 190, 210)
DIM = (50, 90, 100)
AMBER = (220, 160, 70)
GREEN = (90, 200, 120)
RED = (210, 70, 60)
WHITE = (200, 210, 215)
rnd = random.Random(31)


def font(size, mono=True):
    return ImageFont.truetype(MONO if mono else SANS, size)


def frame(title, d):
    d.rectangle([0, 0, W - 1, 34], fill=(14, 26, 32))
    d.text((14, 7), title, font=font(18), fill=CYAN)
    d.text((W - 220, 9), "UTC  ----   SEC", font=font(14), fill=DIM)
    d.line([0, 35, W, 35], fill=DIM, width=1)
    d.rectangle([0, H - 30, W - 1, H - 1], fill=(10, 18, 22))
    for i, k in enumerate(["F1 MODE", "F2 SEL", "F3 RNG", "F4 PAGE", "F5 ACK"]):
        d.text((14 + i * 150, H - 24), k, font=font(13), fill=DIM)


def ballast():
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    frame("BALLAST / TRIM  -  MIMIC", d)
    tanks = [("MBT 1", 60, 120), ("MBT 2", 250, 120), ("TRIM FWD", 450, 120), ("COMP", 620, 120), ("TRIM AFT", 790, 120)]
    for name, x, y in tanks:
        d.rectangle([x, y, x + 150, y + 170], outline=CYAN, width=2)
        lvl = rnd.uniform(0.2, 0.9)
        d.rectangle([x + 3, y + 3 + int(164 * (1 - lvl)), x + 147, y + 167], fill=(20, 60, 80))
        d.text((x + 8, y + 176), name, font=font(16), fill=WHITE)
        d.text((x + 8, y + 198), "%3d %%" % int(lvl * 100), font=font(16), fill=AMBER)
    d.line([40, 380, 980, 380], fill=CYAN, width=3)
    for x in [135, 325, 525, 695, 865]:
        d.line([x, 290, x, 380], fill=CYAN, width=3)
        c = GREEN if rnd.random() > 0.3 else RED
        d.rectangle([x - 9, 330, x + 9, 348], fill=c)
    d.text((40, 400), "HP AIR   210 BAR      LP BLOW   READY      VENTS   SHUT", font=font(18), fill=WHITE)
    d.text((40, 432), "PUMP 1   STBY         PUMP 2    STBY       HYDR    165 BAR", font=font(18), fill=WHITE)
    for i in range(6):
        d.text((40, 480 + i * 22), "%02d  VALVE  %s   %s" % (i + 1, rnd.choice(["V-%03d" % rnd.randint(10, 99)]), rnd.choice(["SHUT", "SHUT", "OPEN"])), font=font(15), fill=DIM)
    return im


def fire_control():
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    frame("FIRE CONTROL  -  WEAPON STATUS", d)
    for i in range(4):
        x = 40 + i * 240
        d.rectangle([x, 60, x + 210, 200], outline=DIM, width=2)
        d.text((x + 12, 70), "TUBE %d" % (i + 1), font=font(20), fill=WHITE)
        d.text((x + 12, 104), "LOADED", font=font(16), fill=GREEN)
        d.text((x + 12, 130), "DOOR  SHUT", font=font(16), fill=DIM)
        d.text((x + 12, 156), "SAFE", font=font(16), fill=AMBER)
    d.text((40, 230), "WEAPONS STATE:  TIGHT", font=font(22), fill=AMBER)
    d.line([40, 270, 980, 270], fill=DIM)
    cx, cy, r = 760, 450, 150
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=DIM, width=1)
    for a in range(0, 360, 30):
        ra = math.radians(a)
        d.line([cx, cy, cx + math.sin(ra) * r, cy - math.cos(ra) * r], fill=(25, 45, 52))
    for i in range(5):
        d.text((40, 290 + i * 30), "TRK %02d   BRG %03d   ---.-   CLASS ----" % (i + 1, rnd.randint(0, 359)), font=font(17), fill=WHITE if i < 2 else DIM)
    return im


def esm():
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    frame("ESM  -  INTERCEPT", d)
    for x in range(40, 980, 6):
        h = rnd.random() ** 3 * 160 + 4
        d.line([x, 460, x, 460 - h], fill=(40, 120, 110))
    d.line([40, 461, 980, 461], fill=DIM)
    d.text((40, 480), "BAND  2-18 GHZ      MAST  HOUSED      NO EMITTERS", font=font(18), fill=WHITE)
    for i in range(3):
        d.text((40, 520 + i * 26), "LOG %02d   ----------   ---   ---" % (i + 1), font=font(16), fill=DIM)
    return im


def comms():
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    frame("COMMS  -  BROADCAST SCHEDULE", d)
    for i, t in enumerate(["0000", "0600", "1200", "1800"]):
        d.text((40, 70 + i * 40), "%sZ   VLF / SAT   COPY AT PD" % t, font=font(20), fill=WHITE)
    d.text((40, 260), "LAST COPIED  ----      QUEUE  0", font=font(20), fill=AMBER)
    d.text((40, 300), "CRYPTO  LOADED          EMCON  SILENT", font=font(20), fill=GREEN)
    return im


def sonar_placeholder():
    im = Image.new("RGB", (W, H), (3, 10, 6))
    d = ImageDraw.Draw(im)
    for y in range(40, H, 2):
        for x in range(0, W, 3):
            v = rnd.random() ** 4 * 90
            d.point((x, y), fill=(int(v * 0.4), int(v), int(v * 0.6)))
    return im


def nav_placeholder():
    im = Image.new("RGB", (W, H), (8, 16, 22))
    d = ImageDraw.Draw(im)
    for x in range(0, W, 64):
        d.line([x, 0, x, H], fill=(20, 38, 46))
    for y in range(0, H, 64):
        d.line([0, y, W, y], fill=(20, 38, 46))
    d.polygon([(600, 120), (760, 160), (800, 300), (700, 380), (590, 300)], fill=(46, 52, 44))
    return im


def ship_control():
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    frame("SHIP CONTROL", d)
    for i, (k, v) in enumerate([("DEPTH", "040.0 M"), ("ORD", "040 M"), ("HDG", "026"), ("SPEED", "09.0 KT"), ("TRIM", "+0.4"), ("RUDDER", "00")]):
        d.text((60 + (i % 2) * 480, 80 + (i // 2) * 120), k, font=font(22), fill=DIM)
        d.text((60 + (i % 2) * 480, 110 + (i // 2) * 120), v, font=font(46), fill=WHITE)
    return im


def status_board():
    im = Image.new("RGB", (900, 600), (225, 228, 222))
    d = ImageDraw.Draw(im)
    d.text((24, 18), "CONTROL ROOM - STATE BOARD", font=font(30, False), fill=(30, 40, 60))
    d.line([24, 60, 876, 60], fill=(60, 60, 70), width=2)
    rows = ["WATCH:  ---", "DEPTH:  ---", "CO2  0.4%   O2  19.8%", "BATTERY: ---", "HOVER / TRIM: OK", "NEXT BCST:  ---"]
    for i, r in enumerate(rows):
        d.text((30, 80 + i * 70), r, font=font(30), fill=(20, 40, 120) if i % 2 == 0 else (120, 30, 30))
    return im


if __name__ == "__main__":
    import os
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("ballast", ballast), ("fire_control", fire_control), ("esm", esm), ("comms", comms),
                     ("sonar", sonar_placeholder), ("nav", nav_placeholder), ("ship_control", ship_control), ("status_board", status_board)]:
        fn().save(os.path.join(OUT, name + ".png"))
        print("wrote", name)
