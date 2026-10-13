#!/usr/bin/env python3
"""Generate a scaled copy of a resolution resource folder (T4.5).

Builds e.g. resources-round-390x390/fonts from resources-round-416x416/fonts so the
390x390 face is the 416x416 face scaled by 390/416, pixel-aligned:

  * tile fonts (worldMap, dial, hour-*, minute-*): every tile set is reassembled into
    full images, scaled, and re-cut into 24x24 tiles (empty tiles dropped, identical
    tiles shared), producing new .fnt/.png/.json in the tilemapper format
    (packed = char | x << 12 | y << 22)
  * text BMFonts (cas_digital*, garmin-icons): copied UNSCALED by default - resampling
    the 7-segment glyphs made them blurry with faint halos on the watch (the 454 set
    uses the same text fonts as 416 too). Pass --scale-text to scale them anyway.
  * layout.xml: every numeric <param> is scaled; the WorldMap size is set to the
    exact 2:1 map size that was generated

Usage:
  python tools/scale_resources.py resources-round-416x416 resources-round-390x390 390 [--scale-text]
Requires Pillow (pip install pillow).
"""
import json
import math
import os
import re
import sys

from PIL import Image

TILE = 24
TILE_FONTS = {                     # font name -> json "layers" (list of tile lists)
    "worldMap": "worldMap",
    "dial": "dial",
    "hour-0-29": "hour-0-29",
    "hour-30-59": "hour-30-59",
    "minute-0-29": "minute-0-29",
    "minute-30-59": "minute-30-59",
}
TEXT_FONTS = ["cas_digital", "cas_digital_medium", "cas_digital_big", "garmin-icons"]

# Hand-tuned layout values per target size, applied after scaling. Needed because the
# text fonts are NOT scaled (see above), so wide text must move to stay on screen.
#   (drawable id, param) -> value
# Text fonts that ARE scaled per target size (crisp: supersample, threshold, area-downscale).
# The big time is 369 px wide at full size (HH:MM 299 + seconds 70); on 390 the screen chord
# at the bottom of the digits is only ~324 px, so HH:MM is scaled to 85 % (254 px).
# The seconds font stays original: a scaled copy rendered digits 3-9 wrongly on the watch.
TEXT_SCALE = {
    390: {"cas_digital_big": 0.85},
}

LAYOUT_OVERRIDES = {
    390: {
        ("TimeFieldDisplay", "positionX"): 33,         # 254 + 70 = 324 px time block
        ("AodDisplay", "timeX"): 33,
        ("DataFieldsMiddleDisplay", "left"): 27,       # sunrise/sunset row centred on screen
        ("DataFieldsMiddleDisplay", "right"): 282,
        ("DataFieldsBottomDisplay", "right"): 340,     # your manual tweak
        ("MoveBarDisplay", "width"): 188,               # your manual tweaks
        ("GoalMeterDisplay", "gap"): 6,
    },
}


# ----------------------------------------------------------------------------- BMFont io
def parse_fnt(path):
    lines = open(path, encoding="utf-8").read().splitlines()
    info, common, pages, chars, other = None, None, {}, [], []
    for ln in lines:
        key = ln.split(" ", 1)[0]
        kv = dict(re.findall(r'(\w+)=("[^"]*"|\S+)', ln))
        if key == "info":
            info = (ln, kv)
        elif key == "common":
            common = (ln, kv)
        elif key == "page":
            pages[int(kv["id"])] = kv["file"].strip('"')
        elif key == "char":
            chars.append({k: int(v) for k, v in kv.items()})
        elif key == "chars":
            pass
        else:
            other.append(ln)
    return info, common, pages, chars, other


def set_kv(line, key, value):
    return re.sub(r"\b%s=(\"[^\"]*\"|\S+)" % key, "%s=%s" % (key, value), line, count=1)


def load_alpha(path):
    im = Image.open(path)
    return im.getchannel("A") if im.mode == "RGBA" else im.convert("L"), im.mode


# ----------------------------------------------------------------------------- tile fonts
def tile_glyphs(src_dir, name):
    _, _, pages, chars, _ = parse_fnt(os.path.join(src_dir, name + ".fnt"))
    page = Image.open(os.path.join(src_dir, pages[0])).convert("L")
    return {c["id"]: page.crop((c["x"], c["y"], c["x"] + c["width"], c["y"] + c["height"]))
            for c in chars}


def assemble(glyphs, packed_list):
    """Rebuild one image from packed tiles; returns (image, origin=(0,0))."""
    if not packed_list:
        return None
    w = max(((p >> 12) & 0x3FF) + TILE for p in packed_list)
    h = max(((p >> 22) & 0x3FF) + TILE for p in packed_list)
    img = Image.new("L", (w, h), 0)
    for p in packed_list:
        g = glyphs[p & 0xFFF]
        img.paste(g, ((p >> 12) & 0x3FF, (p >> 22) & 0x3FF))
    return img


def content_bbox(img):
    return img.point(lambda v: 255 if v > 8 else 0).getbbox()


def write_tile_font(dst_dir, name, images):
    """images: list of PIL L images (or None) -> writes name.fnt/.png/.json."""
    tiles, index, layers = [], {}, []
    for img in images:
        packed = []
        if img is not None:
            for ty in range(0, img.height, TILE):
                for tx in range(0, img.width, TILE):
                    t = Image.new("L", (TILE, TILE), 0)
                    t.paste(img.crop((tx, ty, min(tx + TILE, img.width), min(ty + TILE, img.height))), (0, 0))
                    if t.getbbox() is None or max(t.getdata()) <= 8:
                        continue
                    key = t.tobytes()
                    if key not in index:
                        index[key] = 32 + len(tiles)
                        tiles.append(t)
                    packed.append(index[key] | (tx << 12) | (ty << 22))
        layers.append(packed)
    per_row = 24
    rows = max(1, math.ceil(len(tiles) / per_row))
    atlas_w = per_row * TILE
    atlas_h = max(rows * TILE, TILE)
    atlas = Image.new("RGB", (atlas_w, atlas_h), (0, 0, 0))
    lines = [
        "info face=%s size=24 bold=0 italic=0 charset=ascii unicode=0 stretchH=100 smooth=1 aa=1 "
        "padding=0,0,0,0 spacing=0,0 outline=0" % name,
        "common lineHeight=24 base=24 scaleW=%d scaleH=%d pages=1 packed=0" % (atlas_w, atlas_h),
        'page id=0 file="%s.png"' % name,
        "chars count=%d" % len(tiles),
    ]
    for i, t in enumerate(tiles):
        x, y = (i % per_row) * TILE, (i // per_row) * TILE
        atlas.paste(t.convert("RGB"), (x, y))
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
                     % (32 + i, x, y, TILE, TILE, TILE))
    atlas.save(os.path.join(dst_dir, name + ".png"))
    open(os.path.join(dst_dir, name + ".fnt"), "w", newline="\n").write("\n".join(lines) + "\n")
    json.dump(layers, open(os.path.join(dst_dir, name + ".json"), "w"), separators=(", ", ": "))
    return len(tiles)


def scale_img(img, s):
    # BOX (area average) instead of LANCZOS: no ringing, so no faint halo pixels
    w, h = max(1, round(img.width * s)), max(1, round(img.height * s))
    return img.resize((w, h), Image.BOX)


def scale_tile_fonts(src_dir, dst_dir, s, map_size):
    report = {}
    for name in TILE_FONTS:
        glyphs = tile_glyphs(src_dir, name)
        layers = json.load(open(os.path.join(src_dir, name + ".json")))
        out = []
        for packed in layers:
            img = assemble(glyphs, packed)
            if img is None:
                out.append(None)
                continue
            if name == "worldMap":
                # crop to the real artwork (2:1 equirectangular, starts at 0,0) then scale exactly
                bb = content_bbox(img)
                art_w = bb[2]
                art_h = art_w // 2
                img = img.crop((0, 0, art_w, art_h)).resize(map_size, Image.BOX)
            else:
                img = scale_img(img, s)
            out.append(img)
        report[name] = write_tile_font(dst_dir, name, out)
    return report


# ----------------------------------------------------------------------------- text fonts
def pack(sizes, max_w):
    """Simple shelf packer. sizes: list of (w, h). Returns positions and atlas size."""
    order = sorted(range(len(sizes)), key=lambda i: -sizes[i][1])
    pos = [None] * len(sizes)
    x = y = shelf_h = 0
    for i in order:
        w, h = sizes[i]
        if x + w > max_w:
            x, y, shelf_h = 0, y + shelf_h + 2, 0
        pos[i] = (x, y)
        x += w + 2                      # 2 px gap: no bleeding between glyphs
        shelf_h = max(shelf_h, h)
    height = y + shelf_h
    side = 1
    while side < max(max_w, height):
        side *= 2
    return pos, side


def crisp_scale(g, s):
    """Scale an alpha glyph without blur or halos: 4x supersample, threshold to a hard
    shape, then area-average down. Gives clean antialiased edges like a font rasterizer."""
    if g.width <= 1 or g.height <= 1:
        return g
    big = g.resize((g.width * 4, g.height * 4), Image.BICUBIC).point(lambda v: 255 if v >= 128 else 0)
    w, h = max(1, round(g.width * s)), max(1, round(g.height * s))
    return big.resize((w, h), Image.BOX)


def scale_text_font(src_dir, dst_dir, name, s):
    info, common, pages, chars, other = parse_fnt(os.path.join(src_dir, name + ".fnt"))
    page_imgs, mode = {}, None
    for pid, f in pages.items():
        page_imgs[pid], mode = load_alpha(os.path.join(src_dir, f))
    glyphs, sizes = [], []
    for c in chars:
        g = page_imgs[c["page"]].crop((c["x"], c["y"], c["x"] + c["width"], c["y"] + c["height"]))
        if c["width"] > 1 and c["height"] > 1:
            g = crisp_scale(g, s)
        glyphs.append(g)
        sizes.append(g.size)
    # Prefer the source atlas layout (scaled positions): it is known to work with the
    # Garmin font compiler. A freshly packed atlas made digits 3-9 of the seconds font
    # render wrongly on 390x390. Fall back to shelf packing only if glyphs would overlap.
    pos = [(math.floor(c["x"] * s), math.floor(c["y"] * s)) for c in chars] if len(pages) == 1 else None
    side = 256
    if pos is not None:
        rects = [(p[0], p[1], p[0] + g.width, p[1] + g.height) for p, g in zip(pos, glyphs)]
        clash = any(not (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])
                    for i, a in enumerate(rects) for b in rects[i + 1:])
        if clash or max(r[2] for r in rects) > 256 or max(r[3] for r in rects) > 256:
            pos = None
    if pos is None:
        pos, side = pack(sizes, 256)
        if side > 256:
            pos, side = pack(sizes, 512)
    alpha = Image.new("L", (side, side), 0)
    for g, p in zip(glyphs, pos):
        alpha.paste(g, p)
    page_name = name + "_0.png"
    if mode == "RGBA":
        # Same layout as the source atlases: colour = alpha (premultiplied on black).
        # White colour under transparent pixels made the Garmin font compiler produce a
        # blurry glow around every glyph.
        out = Image.merge("RGBA", (alpha, alpha, alpha, alpha))
    else:
        out = alpha
    out.save(os.path.join(dst_dir, page_name))

    info_line = set_kv(info[0], "size", str(max(1, round(int(info[1]["size"]) * s))))
    common_line = common[0]
    for k in ("lineHeight", "base"):
        common_line = set_kv(common_line, k, str(max(1, round(int(common[1][k]) * s))))
    common_line = set_kv(set_kv(set_kv(common_line, "scaleW", str(side)), "scaleH", str(side)), "pages", "1")
    lines = [info_line, common_line, 'page id=0 file="%s"' % page_name, "chars count=%d" % len(chars)]
    for c, g, p in zip(chars, glyphs, pos):
        lines.append("char id=%-4d x=%-5d y=%-5d width=%-5d height=%-5d xoffset=%-5d yoffset=%-5d "
                     "xadvance=%-5d page=0  chnl=15"
                     % (c["id"], p[0], p[1], g.width, g.height, round(c["xoffset"] * s),
                        round(c["yoffset"] * s), max(1, round(c["xadvance"] * s))))
    open(os.path.join(dst_dir, name + ".fnt"), "w", newline="\n").write("\n".join(lines) + "\n")


# ----------------------------------------------------------------------------- layout
def scale_layout(src, dst, s, map_size, overrides):
    text = open(src, encoding="utf-8").read()

    def repl(m):
        return "%s%d%s" % (m.group(1), round(int(m.group(2)) * s), m.group(3))

    text = re.sub(r'(<param name="(?:positionX|positionY|width|height|posX|posY|gap|separator|'
                  r'left|right|top|bottom|timeX|timeY|dateX|dateY)">)(-?\d+)(</param>)', repl, text)
    # exact map size
    i = text.index('class="WorldMap"')
    j = text.index("</drawable>", i)
    block = text[i:j]
    block = re.sub(r'(<param name="width">)\d+', r"\g<1>%d" % map_size[0], block)
    block = re.sub(r'(<param name="height">)\d+', r"\g<1>%d" % map_size[1], block)
    block = re.sub(r"\(\d+x\d+\)", "(%dx%d)" % map_size, block)
    text = text[:i] + block + text[j:]
    text = re.sub(r"worldMap artwork \(\d+x\d+\)", "worldMap artwork (%dx%d)" % map_size, text)
    for (did, param), val in overrides.items():
        i = text.index('id="%s"' % did)
        j = text.index("</drawable>", i)
        block, n = re.subn(r'(<param name="%s">)-?\d+' % param, r"\g<1>%d" % val, text[i:j])
        assert n == 1, (did, param)
        text = text[:i] + block + text[j:]
    open(dst, "w", encoding="utf-8", newline="").write(text)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    src_root, dst_root, target = args[0], args[1], int(args[2])
    src_size = int(re.search(r"(\d+)x\d+", os.path.basename(src_root.rstrip("/\\"))).group(1))
    s = target / src_size
    map_w = round(140 * s / 2) * 2 if src_size == 416 else round(160 * s / 2) * 2
    map_size = (map_w, map_w // 2)
    src_f, dst_f = os.path.join(src_root, "fonts"), os.path.join(dst_root, "fonts")
    os.makedirs(dst_f, exist_ok=True)
    os.makedirs(os.path.join(dst_root, "layouts"), exist_ok=True)
    rep = scale_tile_fonts(src_f, dst_f, s, map_size)
    import shutil
    per_font = TEXT_SCALE.get(target, {})
    for f in TEXT_FONTS:
        if "--scale-text" in sys.argv or f in per_font:
            scale_text_font(src_f, dst_f, f, per_font.get(f, s))
        else:
            _, _, pages, _, _ = parse_fnt(os.path.join(src_f, f + ".fnt"))
            shutil.copy(os.path.join(src_f, f + ".fnt"), dst_f)
            for pf in pages.values():
                shutil.copy(os.path.join(src_f, pf), dst_f)
    scale_layout(os.path.join(src_root, "layouts", "layout.xml"),
                 os.path.join(dst_root, "layouts", "layout.xml"), s, map_size,
                 LAYOUT_OVERRIDES.get(target, {}))
    print("scale %.4f, map %dx%d, tiles per font: %s" % (s, map_size[0], map_size[1], rep))


if __name__ == "__main__":
    main()
