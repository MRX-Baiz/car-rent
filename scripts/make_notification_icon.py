#!/usr/bin/env python3
"""Builds the small status-bar icon from the launcher foreground.

Android draws the notification icon as a silhouette from Lollipop onwards: it
keeps the alpha channel and throws the colours away. Passing @mipmap/ic_launcher
therefore renders the gold logo as a solid white square. This flattens the
artwork to white-on-transparent so the shape survives.

Usage: python3 scripts/make_notification_icon.py
"""

import os
import sys

from PIL import Image

SOURCE = "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png"
NAME = "ic_stat_notification.png"

# Status bar icon sizes, in dp 24 at each density.
DENSITIES = {
    "drawable-mdpi": 24,
    "drawable-hdpi": 36,
    "drawable-xhdpi": 48,
    "drawable-xxhdpi": 72,
    "drawable-xxxhdpi": 96,
}

# The launcher foreground is padded for the adaptive-icon safe zone. The status
# bar icon has no such mask, so that padding is trimmed and re-applied smaller.
CONTENT_RATIO = 0.92

# The full logo carries the "MRX-BAIZ / CAR RENTAL" wordmark underneath the
# monogram. At 24dp that text collapses into an unreadable smear, so only the
# top of the artwork -- the M and the car silhouette -- is kept.
MARK_HEIGHT_FRACTION = 0.63

# Above this the pixel counts as part of the mark. Low, because the gradient
# leaves large areas only faintly opaque.
ALPHA_CUTOFF = 30


def main() -> int:
    if not os.path.exists(SOURCE):
        print(f"missing {SOURCE}", file=sys.stderr)
        return 1

    source = Image.open(SOURCE).convert("RGBA")
    alpha = source.getchannel("A")

    # The launcher artwork's alpha follows the metallic gradient, so the middle
    # of a stroke is barely opaque. Rendered as a silhouette that reads as a
    # hollowed-out shape. Flatten it: anything meaningfully painted is solid.
    alpha = alpha.point(lambda value: 255 if value > ALPHA_CUTOFF else 0)

    box = alpha.getbbox()
    if box is None:
        print("source is fully transparent", file=sys.stderr)
        return 1
    alpha = alpha.crop(box)

    mark_height = int(alpha.height * MARK_HEIGHT_FRACTION)
    alpha = alpha.crop((0, 0, alpha.width, mark_height))
    # Re-trim: dropping the wordmark usually leaves slack on the sides.
    trimmed = alpha.getbbox()
    if trimmed is not None:
        alpha = alpha.crop(trimmed)

    for folder, size in DENSITIES.items():
        content = max(1, int(size * CONTENT_RATIO))
        scaled = alpha.copy()
        scaled.thumbnail((content, content), Image.LANCZOS)

        # White everywhere, shaped purely by the alpha channel.
        icon = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        white = Image.new("RGBA", scaled.size, (255, 255, 255, 255))
        icon.paste(
            white,
            ((size - scaled.width) // 2, (size - scaled.height) // 2),
            scaled,
        )

        target_dir = os.path.join("android/app/src/main/res", folder)
        os.makedirs(target_dir, exist_ok=True)
        icon.save(os.path.join(target_dir, NAME))
        print(f"wrote {folder}/{NAME} ({size}x{size})")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
