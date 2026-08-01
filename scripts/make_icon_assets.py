#!/usr/bin/env python3
"""Build launcher-icon assets from a source logo.

    python3 scripts/make_icon_assets.py <path-to-logo>

Writes assets/icon/icon.png (square, full-bleed) and
assets/icon/icon_foreground.png (artwork only, for Android adaptive icons),
then run:  dart run flutter_launcher_icons
"""
import sys
from pathlib import Path

from PIL import Image

SIZE = 1024
# mipmap-anydpi-v26/ic_launcher.xml insets the foreground by 16% per side,
# leaving 68% of the layer. Filling 94% here puts the artwork at ~64% of the
# final icon, just inside the adaptive-icon safe zone.
FILL = 0.94
# Pixels this close to the backdrop are treated as background, absorbing
# compression noise and any faint vignette.
NOISE = 0.06


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1

    src_path = Path(sys.argv[1])
    if not src_path.is_file():
        print(f"ERROR: no such file: {src_path}")
        return 1

    src = Image.open(src_path).convert("RGBA")
    w, h = src.size
    print(f"source: {src_path.name}  {w}x{h}")

    # Sample the corners to learn the backdrop colour.
    corners = [src.getpixel(p) for p in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2))]
    bg = tuple(sum(c[i] for c in corners) // len(corners) for i in range(3))
    print(f"backdrop: rgb{bg}  #{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}")

    out_dir = Path("assets/icon")
    out_dir.mkdir(parents=True, exist_ok=True)

    # --- full-bleed square icon (legacy launcher icon) ---
    side = max(w, h)
    square = Image.new("RGBA", (side, side), bg + (255,))
    square.paste(src, ((side - w) // 2, (side - h) // 2), src)
    square.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(out_dir / "icon.png")
    print(f"wrote {out_dir / 'icon.png'}")

    # --- adaptive foreground: artwork on transparency ---
    # Alpha comes from each pixel's distance off the backdrop, so a coloured or
    # metallic logo keeps its own hues instead of being flattened to one colour.
    px = src.load()
    art = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ap = art.load()
    span = [max(bg[i], 255 - bg[i]) or 1 for i in range(3)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            frac = max(abs(r - bg[0]) / span[0],
                       abs(g - bg[1]) / span[1],
                       abs(b - bg[2]) / span[2])
            if frac <= NOISE:
                continue
            frac = (frac - NOISE) / (1 - NOISE)
            ap[x, y] = (r, g, b, int(min(1.0, frac) * (a / 255) * 255))

    bbox = art.getbbox()
    if bbox is None:
        print("ERROR: no artwork found - is the image a single flat colour?")
        return 1
    art = art.crop(bbox)
    aw, ah = art.size
    scale = min(SIZE * FILL / aw, SIZE * FILL / ah)
    art = art.resize((max(1, int(aw * scale)), max(1, int(ah * scale))), Image.LANCZOS)

    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fg.paste(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2), art)
    fg.save(out_dir / "icon_foreground.png")
    print(f"wrote {out_dir / 'icon_foreground.png'}")
    print(f"  ink bbox {bbox} -> artwork {art.size}")
    print(f"  {art.width / SIZE:.0%} of canvas, ~{art.width / SIZE * 0.68:.0%} after the xml inset")
    print(f"\nSet adaptive_icon_background to #{bg[0]:02X}{bg[1]:02X}{bg[2]:02X} in pubspec.yaml")
    return 0


if __name__ == "__main__":
    sys.exit(main())
