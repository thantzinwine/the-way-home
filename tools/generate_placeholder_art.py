"""
The Way Home - placeholder art generator (Milestone 1).

These are deliberately simple stand-ins. Every file this script writes is meant to be
replaced by final artwork with the SAME filename / frame layout, without touching game code:

  assets/environments/tiles/iso_tiles_placeholder.png   4x2 atlas, 64x32 iso diamonds
  assets/characters/ren/ren_sheet_placeholder.png       8 directions x (idle + 4 walk) frames,
                                                        frame size 48x64, feet at (24, 62)
  assets/environments/props/*.png                       props with base of the sprite at
                                                        the bottom-centre of the image

Run:  python tools/generate_placeholder_art.py
"""
from PIL import Image, ImageDraw
import os, math, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rnd = random.Random(20261030)

TILE_W, TILE_H = 64, 32
FRAME_W, FRAME_H = 48, 64


def path(*p):
    full = os.path.join(ROOT, *p)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def diamond(draw, cx, cy, w, h, fill, outline=None, width=1):
    pts = [(cx, cy - h / 2), (cx + w / 2, cy), (cx, cy + h / 2), (cx - w / 2, cy)]
    draw.polygon(pts, fill=fill, outline=outline)
    if outline and width > 1:
        draw.line(pts + [pts[0]], fill=outline, width=width)


def tile_base(color, shade=14):
    img = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    diamond(d, TILE_W / 2, TILE_H / 2, TILE_W, TILE_H, color)
    # soft top-light: clip a lighter diamond into the upper half
    light = tuple(min(255, c + shade) for c in color[:3]) + (255,)
    top = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    td = ImageDraw.Draw(top)
    td.polygon([(TILE_W / 2, 0), (TILE_W, TILE_H / 2), (TILE_W / 2, TILE_H / 2),
                (0, TILE_H / 2)], fill=light)
    img.alpha_composite(top)
    return img


def draw_tiles():
    img = Image.new("RGBA", (TILE_W * 4, TILE_H * 2), (0, 0, 0, 0))

    def place(col, row, tile):
        img.alpha_composite(tile, (col * TILE_W, row * TILE_H))

    # 0 grass
    t = tile_base((111, 155, 88))
    d = ImageDraw.Draw(t)
    for _ in range(40):
        x, y = rnd.randint(10, TILE_W - 10), rnd.randint(8, TILE_H - 8)
        d.line([(x, y), (x + rnd.choice([-1, 0, 1]), y - rnd.randint(1, 3))],
               fill=(96, 138, 74, 200))
    place(0, 0, t)

    # 1 grass with flowers
    t = tile_base((116, 162, 92))
    d = ImageDraw.Draw(t)
    for _ in range(5):
        x, y = rnd.randint(14, TILE_W - 14), rnd.randint(12, TILE_H - 10)
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(240, 236, 200, 255))
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=(226, 186, 86, 255))
    place(1, 0, t)

    # 2 packed dirt
    t = tile_base((168, 139, 102))
    d = ImageDraw.Draw(t)
    for _ in range(26):
        x, y = rnd.randint(8, TILE_W - 8), rnd.randint(6, TILE_H - 6)
        d.point((x, y), fill=(150, 122, 88, 255))
    place(2, 0, t)

    # 3 pavement
    t = tile_base((156, 155, 146))
    d = ImageDraw.Draw(t)
    d.line([(TILE_W / 2, 1), (TILE_W - 1, TILE_H / 2)], fill=(138, 137, 129, 255))
    d.line([(TILE_W / 2, TILE_H - 1), (1, TILE_H / 2)], fill=(138, 137, 129, 255))
    place(3, 0, t)

    # 4 asphalt road
    t = tile_base((88, 90, 96), shade=8)
    d = ImageDraw.Draw(t)
    for _ in range(30):
        x, y = rnd.randint(6, TILE_W - 6), rnd.randint(4, TILE_H - 4)
        d.point((x, y), fill=(104, 106, 112, 255))
    place(0, 1, t)

    # 5 road crossing (painted stripes)
    t = tile_base((92, 94, 100), shade=8)
    d = ImageDraw.Draw(t)
    for i in (-1, 0, 1):
        d.line([(TILE_W / 2 + i * 14, 2 + abs(i) * 3), (TILE_W / 2 + i * 14, TILE_H - 2 - abs(i) * 3)],
               fill=(228, 228, 220, 220), width=6)
    place(1, 1, t)

    # 6 solid wall / building footprint (blocked)
    t = tile_base((104, 88, 74), shade=26)
    d = ImageDraw.Draw(t)
    d.polygon([(TILE_W / 2, 4), (TILE_W - 4, TILE_H / 2), (TILE_W / 2, TILE_H - 4), (4, TILE_H / 2)],
              outline=(74, 62, 52, 255), width=2)
    place(2, 1, t)

    # 7 water / drain (blocked)
    t = tile_base((70, 116, 128), shade=16)
    d = ImageDraw.Draw(t)
    for i in range(3):
        y = 10 + i * 6
        d.arc([12, y, 52, y + 8], 200, 340, fill=(150, 196, 204, 200), width=1)
    place(3, 1, t)

    img.save(path("assets", "environments", "tiles", "iso_tiles_placeholder.png"))
    return img


# --------------------------------------------------------------------------------------
# Character
# --------------------------------------------------------------------------------------

SANDAL = (72, 58, 48)
CAMERA = (44, 46, 52)

# 8 facings, clockwise from north. (dx, dy) is the screen direction the character looks at.
FACINGS = [
    ("n", 0.0, -1.0), ("ne", 0.7, -0.7), ("e", 1.0, 0.0), ("se", 0.7, 0.7),
    ("s", 0.0, 1.0), ("sw", -0.7, 0.7), ("w", -1.0, 0.0), ("nw", -0.7, -0.7),
]

# Palette / build per character. Everyone shares the 48x64 sheet contract, so final
# art can replace any of these files without touching gameplay code.
CHARACTERS = {
    "ren": dict(
        skin=(226, 188, 152), hair=(32, 27, 24),
        shirt=(238, 234, 222), shirt_shade=(208, 203, 190),
        skirt=(46, 116, 110), skirt_shade=(34, 92, 88),
        hair_style="short", accessory="camera", body=1.0, width=1.0,
    ),
    "mother": dict(
        skin=(222, 182, 148), hair=(40, 32, 28),
        shirt=(146, 68, 72), shirt_shade=(116, 52, 58),
        skirt=(74, 66, 76), skirt_shade=(56, 50, 58),
        hair_style="bun", accessory="none", body=0.97, width=0.98,
    ),
    "father": dict(
        skin=(208, 166, 132), hair=(30, 26, 24),
        shirt=(92, 108, 122), shirt_shade=(72, 86, 98),
        skirt=(98, 80, 58), skirt_shade=(76, 62, 44),
        hair_style="short", accessory="none", body=1.03, width=1.1,
    ),
    "grandmother": dict(
        skin=(220, 190, 164), hair=(200, 198, 194),
        shirt=(176, 148, 138), shirt_shade=(146, 120, 112),
        skirt=(80, 86, 112), skirt_shade=(60, 64, 86),
        hair_style="bun", accessory="shawl", body=0.9, width=0.95,
    ),
    "sister": dict(
        skin=(232, 196, 164), hair=(42, 32, 26),
        shirt=(228, 188, 94), shirt_shade=(198, 160, 74),
        skirt=(172, 86, 80), skirt_shade=(140, 66, 62),
        hair_style="pigtails", accessory="none", body=0.84, width=0.9,
    ),
}


def draw_character(cfg, frame_index):
    """frame_index: 0 = idle, 1..4 = walk cycle."""
    img = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, feet = FRAME_W / 2, 62

    skin = cfg["skin"]
    skin_shade = tuple(max(0, c - 26) for c in skin)
    hair = cfg["hair"]
    shirt, shirt_shade = cfg["shirt"], cfg["shirt_shade"]
    skirt, skirt_shade = cfg["skirt"], cfg["skirt_shade"]
    s, w = cfg["body"], cfg["width"]

    walk = frame_index > 0
    phase = 0.0 if not walk else math.sin((frame_index - 1) / 4.0 * math.tau)
    bob = 0.0 if not walk else abs(phase) * 1.2

    hip_y = feet - 20 * s + bob * 0.3
    shoulder_y = feet - 40 * s + bob
    head_cy = feet - 50 * s + bob

    # --- legs (longyi covers most, sandals peek out) ---
    swing = phase * 3.0
    d.ellipse([cx - 7 * w + swing, feet - 4, cx - 1 * w + swing, feet], fill=SANDAL)
    d.ellipse([cx + 1 * w - swing, feet - 4, cx + 7 * w - swing, feet], fill=SANDAL)

    # --- longyi (Myanmar sarong) ---
    d.polygon([(cx - 8 * w, hip_y - 6), (cx + 8 * w, hip_y - 6),
               (cx + 10 * w, hip_y + 17), (cx - 10 * w, hip_y + 17)], fill=skirt)
    d.line([(cx - 9 * w, hip_y + 16), (cx + 9 * w, hip_y + 16)], fill=skirt_shade, width=2)
    d.line([(cx, hip_y - 4), (cx + 1, hip_y + 14)], fill=skirt_shade, width=1)

    # --- torso / shirt ---
    d.polygon([(cx - 8 * w, shoulder_y), (cx + 8 * w, shoulder_y),
               (cx + 9 * w, hip_y - 4), (cx - 9 * w, hip_y - 4)], fill=shirt)
    d.line([(cx - 9 * w, hip_y - 5), (cx + 9 * w, hip_y - 5)], fill=shirt_shade, width=2)

    # arms swing opposite to legs
    d.line([(cx - 8 * w, shoulder_y + 3), (cx - 10 * w - swing, shoulder_y + 17)],
           fill=skin, width=4)
    d.line([(cx + 8 * w, shoulder_y + 3), (cx + 10 * w + swing, shoulder_y + 17)],
           fill=skin, width=4)

    # --- neck + head ---
    d.rectangle([cx - 2.5, shoulder_y - 4, cx + 2.5, shoulder_y + 1], fill=skin_shade)
    d.ellipse([cx - 8, head_cy - 9, cx + 8, head_cy + 9], fill=skin)
    # hair: full cap, longer at the back
    d.pieslice([cx - 9, head_cy - 11, cx + 9, head_cy + 7], 178, 362, fill=hair)
    d.rectangle([cx - 9, head_cy - 3, cx - 6, head_cy + 7], fill=hair)
    d.rectangle([cx + 6, head_cy - 3, cx + 9, head_cy + 7], fill=hair)

    style = cfg.get("hair_style", "short")
    if style == "bun":
        d.ellipse([cx - 4, head_cy - 14, cx + 4, head_cy - 6], fill=hair)
        d.ellipse([cx - 2, head_cy - 13, cx + 2, head_cy - 9], fill=hair)
    elif style == "pigtails":
        d.ellipse([cx - 13, head_cy - 2, cx - 7, head_cy + 8], fill=hair)
        d.ellipse([cx + 7, head_cy - 2, cx + 13, head_cy + 8], fill=hair)

    accessory = cfg.get("accessory", "none")
    if accessory == "camera":
        # camera on a neck strap: Ren's photography habit
        d.line([(cx - 7, shoulder_y - 1), (cx + 7, shoulder_y + 6)], fill=(90, 70, 58))
        d.rounded_rectangle([cx - 4, shoulder_y + 5, cx + 4, shoulder_y + 11],
                            radius=1, fill=CAMERA)
        d.ellipse([cx - 1.5, shoulder_y + 6.5, cx + 1.5, shoulder_y + 9.5],
                  fill=(120, 140, 150))
    elif accessory == "shawl":
        d.line([(cx - 9, shoulder_y + 1), (cx + 9, shoulder_y + 1)],
               fill=(208, 202, 192), width=3)
        d.line([(cx - 9, shoulder_y + 1), (cx - 11, hip_y - 2)],
               fill=(208, 202, 192), width=2)
        d.line([(cx + 9, shoulder_y + 1), (cx + 11, hip_y - 2)],
               fill=(208, 202, 192), width=2)

    return img


def draw_character_facing(cfg, dx, dy, frame_index):
    img = draw_character(cfg, frame_index)
    cx, feet = FRAME_W / 2, 62
    head_cy = feet - 50 * cfg["body"]
    hair = cfg["hair"]
    skin_shade = tuple(max(0, c - 26) for c in cfg["skin"])

    if abs(dx) < 0.01 and dy < 0:
        # facing away from camera: paint over the face with hair
        d = ImageDraw.Draw(img)
        d.ellipse([cx - 7, head_cy - 8, cx + 7, head_cy + 8], fill=hair)
        d.ellipse([cx - 7, head_cy - 9, cx + 7, head_cy + 2], fill=hair)
        return img

    d = ImageDraw.Draw(img)
    shift = dx * 2.5

    if dy >= 0:
        # face visible
        ex = shift
        if abs(dx) < 0.6:
            d.ellipse([cx - 6 + ex, head_cy - 1, cx - 3 + ex, head_cy + 2], fill=(58, 44, 38))
            d.ellipse([cx + 3 + ex, head_cy - 1, cx + 6 + ex, head_cy + 2], fill=(58, 44, 38))
            d.line([(cx - 3 + ex, head_cy + 5), (cx + 3 + ex, head_cy + 5)],
                   fill=(176, 122, 106), width=1)
        else:
            # profile: single eye + nose bump
            sx = 1 if dx > 0 else -1
            d.ellipse([cx + sx * 2 - 1.5, head_cy - 1, cx + sx * 2 + 1.5, head_cy + 2],
                      fill=(58, 44, 38))
            d.point((cx + sx * 7, head_cy + 2), fill=skin_shade)
    else:
        # three-quarter away: hint of cheek only
        d.point((cx + shift, head_cy + 3), fill=skin_shade)

    if abs(dx) > 0.5:
        # hair sweep opposite to facing
        sx = -1 if dx > 0 else 1
        d.ellipse([cx + sx * 6 - 4, head_cy - 9, cx + sx * 6 + 4, head_cy + 1], fill=hair)
    return img


def draw_character_sheets():
    cols, rows = 5, 8
    for char_id, cfg in CHARACTERS.items():
        sheet = Image.new("RGBA", (FRAME_W * cols, FRAME_H * rows), (0, 0, 0, 0))
        for row, (name, dx, dy) in enumerate(FACINGS):
            for col in range(cols):
                sheet.alpha_composite(draw_character_facing(cfg, dx, dy, col),
                                      (col * FRAME_W, row * FRAME_H))
        sheet.save(path("assets", "characters", char_id, f"{char_id}_sheet_placeholder.png"))

        # Dialogue portrait: a square crop around the head of the south-facing idle
        # frame, scaled up with nearest-neighbour so it stays crisp pixel art.
        head_cy = 62 - 50 * cfg["body"]
        frame = sheet.crop((0, 4 * FRAME_H, FRAME_W, 5 * FRAME_H))
        box = (int(FRAME_W / 2 - 14), int(head_cy - 15),
               int(FRAME_W / 2 + 14), int(head_cy + 13))
        frame.crop(box).resize((56, 56), Image.NEAREST).save(
            path("assets", "characters", char_id, f"{char_id}_portrait.png"))


# --------------------------------------------------------------------------------------
# Props
# --------------------------------------------------------------------------------------

def draw_tree():
    w, h = 72, 104
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(w / 2 - 5, h), (w / 2 + 5, h), (w / 2 + 3, h - 34), (w / 2 - 3, h - 34)],
              fill=(94, 72, 52))
    for (cx, cy, r, c) in [(36, 40, 24, (58, 104, 58)), (24, 52, 18, (66, 116, 64)),
                           (48, 50, 19, (66, 116, 64)), (36, 26, 18, (78, 130, 72))]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)
    d.ellipse([26, 20, 44, 36], fill=(96, 148, 84))
    img.save(path("assets", "environments", "props", "tree_placeholder.png"))


def draw_pole():
    w, h = 32, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([w / 2 - 3, 6, w / 2 + 3, h], fill=(126, 122, 114))
    d.rectangle([w / 2 - 3, 6, w / 2 - 1, h], fill=(146, 142, 134))
    d.rectangle([4, 12, w - 4, 16], fill=(96, 92, 86))
    d.rectangle([6, 6, 10, 12], fill=(60, 62, 68))
    d.rectangle([w - 10, 6, w - 6, 12], fill=(60, 62, 68))
    img.save(path("assets", "environments", "props", "utility_pole_placeholder.png"))


def draw_house():
    w, h = 208, 176
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # body (timber, two storeys)
    d.polygon([(28, 74), (150, 74), (150, 168), (28, 168)], fill=(196, 168, 132))
    d.polygon([(150, 74), (180, 60), (180, 150), (150, 168)], fill=(150, 124, 96))
    # floor band
    d.rectangle([28, 116, 150, 122], fill=(150, 124, 96))

    # roof (zinc sheets, pitched)
    d.polygon([(18, 74), (158, 74), (140, 34), (36, 34)], fill=(122, 128, 132))
    d.polygon([(158, 74), (184, 60), (166, 24), (140, 34)], fill=(96, 102, 106))
    for x in range(38, 140, 12):
        d.line([(x, 36), (x - 6, 72)], fill=(140, 146, 150), width=1)

    # windows
    for wx in (44, 92):
        d.rectangle([wx, 84, wx + 24, 106], fill=(86, 108, 116))
        d.rectangle([wx, 84, wx + 24, 106], outline=(120, 96, 70), width=2)
        d.line([(wx + 12, 84), (wx + 12, 106)], fill=(120, 96, 70), width=1)
    # door on the lower storey
    d.rectangle([70, 132, 96, 168], fill=(112, 82, 58))
    d.rectangle([70, 132, 96, 168], outline=(88, 64, 44), width=2)

    # veranda rail
    d.rectangle([28, 122, 150, 126], fill=(126, 98, 70))
    # stairs
    for i in range(3):
        d.rectangle([98 + i * 4, 168 - (3 - i) * 6, 132 - i * 2, 174 - (3 - i) * 6],
                    fill=(160, 134, 104))

    img.save(path("assets", "environments", "props", "house_placeholder.png"))


def draw_stall():
    w, h = 128, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(10, 40), (118, 40), (104, 18), (24, 18)], fill=(190, 122, 104))
    d.polygon([(10, 40), (118, 40), (118, 46), (10, 46)], fill=(166, 100, 84))
    d.rectangle([18, 46, 110, 90], fill=(150, 122, 92))
    d.rectangle([18, 62, 110, 68], fill=(124, 100, 74))
    for i, c in enumerate([(214, 176, 96), (176, 96, 88), (150, 168, 110)]):
        d.ellipse([26 + i * 30, 52, 50 + i * 30, 62], fill=c)
        d.ellipse([26 + i * 30, 50, 50 + i * 30, 60], outline=(110, 88, 66))
    for x in (22, 106):
        d.rectangle([x, 68, x + 4, 94], fill=(112, 88, 64))
    img.save(path("assets", "environments", "props", "vendor_stall_placeholder.png"))


def draw_crate():
    w, h = 44, 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 8, 42, 38], fill=(158, 122, 82))
    d.rectangle([2, 8, 42, 38], outline=(112, 84, 56), width=2)
    d.line([(2, 8), (42, 38)], fill=(112, 84, 56), width=2)
    d.line([(42, 8), (2, 38)], fill=(112, 84, 56), width=2)
    d.rectangle([2, 8, 42, 14], fill=(176, 140, 96))
    img.save(path("assets", "environments", "props", "crate_placeholder.png"))


def draw_sign():
    w, h = 56, 88
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([w / 2 - 2, 30, w / 2 + 2, h], fill=(112, 104, 96))
    d.rectangle([4, 6, w - 4, 40], fill=(226, 222, 208))
    d.rectangle([4, 6, w - 4, 40], outline=(140, 132, 116), width=2)
    # footprint-like step marks instead of text (placeholder for localised signage)
    for i, y in enumerate((14, 22, 30)):
        d.ellipse([12, y, 18, y + 6], fill=(58, 64, 70))
        d.ellipse([21, y - 2, 25, y + 3], fill=(58, 64, 70))
        d.line([(30, y + 3), (44, y + 3)], fill=(120, 126, 130), width=1)
    img.save(path("assets", "environments", "props", "steps_sign_placeholder.png"))


def draw_shadow():
    """Soft contact shadow shared by the player and every prop."""
    w, h = 64, 24
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    steps = 12
    for i in range(steps, 0, -1):
        t = i / steps
        rx = (w / 2 - 2) * t
        ry = (h / 2 - 1) * t
        d = ImageDraw.Draw(img)
        d.ellipse([w / 2 - rx, h / 2 - ry, w / 2 + rx, h / 2 + ry],
                  fill=(0, 0, 0, 9))
    img.save(path("assets", "environments", "shadow_placeholder.png"))


def draw_ui_icons():
    """Step token used by the HUD (the currency is abstract, not a footprint)."""
    size = 24
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outer = [(12, 1), (23, 12), (12, 23), (1, 12)]
    inner = [(12, 5), (19, 12), (12, 19), (5, 12)]
    d.polygon(outer, fill=(206, 168, 92), outline=(138, 106, 54))
    d.polygon(inner, fill=(238, 206, 132))
    d.line([(12, 8), (12, 16)], fill=(120, 90, 44))
    d.line([(8, 12), (16, 12)], fill=(120, 90, 44))
    img.save(path("assets", "ui", "steps_token_placeholder.png"))


if __name__ == "__main__":
    draw_tiles()
    draw_character_sheets()
    draw_tree()
    draw_pole()
    draw_house()
    draw_stall()
    draw_crate()
    draw_sign()
    draw_shadow()
    draw_ui_icons()
    print("placeholder art written")
