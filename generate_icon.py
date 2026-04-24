#!/usr/bin/env python3
"""Generate a liquid glass style app icon for CalorieCounter."""

import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SIZE = 1024
CORNER = 220  # iOS icon corner radius at 1024px


def make_canvas():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def add_bg_gradient(canvas):
    """Deep midnight gradient background."""
    draw = ImageDraw.Draw(canvas)
    for y in range(SIZE):
        t = y / SIZE
        r = int(8 + t * 14)
        g = int(10 + t * 18)
        b = int(28 + t * 36)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

    # Subtle radial glow in the center
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    cx, cy = SIZE // 2, SIZE // 2
    for radius in range(420, 0, -1):
        alpha = int(30 * (1 - radius / 420))
        gdraw.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            fill=(60, 80, 180, alpha),
        )
    canvas = Image.alpha_composite(canvas, glow)
    return canvas


def rounded_rect_mask(size, radius):
    """Create a mask with rounded corners."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def draw_macro_ring(canvas):
    """Draw a glowing 3-segment macro donut ring."""
    cx, cy = SIZE // 2, SIZE // 2
    outer_r = 340
    inner_r = 210
    glow_width = 18

    # Colors: carbs=orange, protein=pink, fat=yellow (with alpha for glow)
    segments = [
        ((255, 140, 40), 0.38),    # carbs (orange)
        ((255, 80, 130), 0.35),    # protein (pink)
        ((255, 210, 40), 0.27),    # fat (yellow)
    ]

    # Draw glow layers (blur for liquid glass glow effect)
    for glow_pass in range(3):
        glow_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow_img)
        angle = -90  # start top
        for color, fraction in segments:
            sweep = fraction * 360
            ext = [cx - outer_r - glow_width * glow_pass,
                   cy - outer_r - glow_width * glow_pass,
                   cx + outer_r + glow_width * glow_pass,
                   cy + outer_r + glow_width * glow_pass]
            glow_color = (*color, 60 - glow_pass * 15)
            glow_draw.arc(ext, start=angle, end=angle + sweep,
                          fill=glow_color, width=inner_r - 10 + glow_width * (glow_pass + 1))
            angle += sweep
        glow_img = glow_img.filter(ImageFilter.GaussianBlur(radius=14 + glow_pass * 10))
        canvas = Image.alpha_composite(canvas, glow_img)

    # Draw actual ring segments
    ring_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring_img)
    ring_width = outer_r - inner_r

    angle = -90
    gap_deg = 3
    for color, fraction in segments:
        sweep = fraction * 360 - gap_deg
        ext = [cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r]
        ring_draw.arc(ext, start=angle + gap_deg / 2, end=angle + sweep,
                      fill=(*color, 255), width=ring_width)
        angle += fraction * 360

    canvas = Image.alpha_composite(canvas, ring_img)
    return canvas


def draw_center_flame(canvas):
    """Draw a vivid flame using additive/screen blending for natural glow."""
    cx, cy = SIZE // 2, SIZE // 2 + 28

    def flame_pts(rx, ry, cy_offset=0):
        """Teardrop polygon: wide base, pointed tip at top."""
        pts = []
        for i in range(120):
            a = math.pi * 2 * i / 120
            # top_factor: 1 when pointing up (a≈π in PIL coords), 0 at bottom
            top_factor = max(0, math.cos(a))  # 1 at "top" of circle
            squeeze = 1 - 0.75 * top_factor
            px = cx + rx * squeeze * math.sin(a)
            py = (cy + cy_offset) - ry * math.cos(a) * 0.85
            pts.append((px, py))
        return pts

    # Work on a black RGB canvas so screen/add blending works naturally
    flame_rgb = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))

    # Outer wide glow — very blurred orange
    for rx, ry, yo, color, blur in [
        (160, 195, -20, (180, 60, 0),  50),
        (130, 165, -10, (220, 90, 0),  34),
        (105, 140, -5,  (255, 120, 5), 22),
        (85,  118,  0,  (255, 155, 10), 14),
        (68,  100,  6,  (255, 190, 25),  8),
        (52,   82, 10,  (255, 220, 50),  5),
        (36,   64, 16,  (255, 240, 100), 3),
        (22,   48, 22,  (255, 252, 170), 2),
        (10,   28, 28,  (255, 255, 230), 1),
    ]:
        layer = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
        ldraw = ImageDraw.Draw(layer)
        ldraw.polygon(flame_pts(rx, ry, yo), fill=color)
        if blur > 0:
            layer = layer.filter(ImageFilter.GaussianBlur(radius=blur))
        flame_rgb = ImageChops.add(flame_rgb, layer)

    # Clamp to valid range and convert back to RGBA with full alpha
    flame_rgba = flame_rgb.convert("RGBA")

    # Use the brightness of flame_rgb as the alpha mask (bright = visible)
    r, g, b = flame_rgb.split()
    # max channel as alpha, so dark background is transparent
    alpha_mask = Image.merge("RGB", (r, g, b)).convert("L")
    # Boost contrast of the mask
    alpha_mask = alpha_mask.point(lambda p: min(255, int(p * 1.6)))
    flame_rgba.putalpha(alpha_mask)

    canvas = Image.alpha_composite(canvas, flame_rgba)
    return canvas


def draw_glass_overlay(canvas):
    """Add a frosted glass specular highlight."""
    glass = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glass)

    # Top-left specular sweep
    for i in range(80):
        t = i / 80
        alpha = int(28 * (1 - t))
        # Arc of white across the top
        r = 480 + i * 3
        gdraw.arc(
            [SIZE // 2 - r, SIZE // 2 - r, SIZE // 2 + r, SIZE // 2 + r],
            start=-145, end=-35,
            fill=(255, 255, 255, alpha),
            width=2,
        )

    glass = glass.filter(ImageFilter.GaussianBlur(radius=8))

    # Top highlight strip (wide, very soft)
    strip = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(strip)
    sdraw.ellipse([80, -180, SIZE - 80, 280], fill=(255, 255, 255, 22))
    strip = strip.filter(ImageFilter.GaussianBlur(radius=40))

    canvas = Image.alpha_composite(canvas, glass)
    canvas = Image.alpha_composite(canvas, strip)
    return canvas


def apply_corner_mask(canvas):
    """Apply iOS rounded corner mask."""
    mask = rounded_rect_mask(SIZE, CORNER)
    result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    result.paste(canvas, mask=mask)
    return result


def generate_icon(path, size):
    canvas = make_canvas()
    canvas = add_bg_gradient(canvas)
    canvas = draw_macro_ring(canvas)
    canvas = draw_center_flame(canvas)
    canvas = draw_glass_overlay(canvas)
    canvas = apply_corner_mask(canvas)

    if size != SIZE:
        canvas = canvas.resize((size, size), Image.LANCZOS)

    # Save as PNG (no alpha if needed for some sizes, keep RGBA)
    rgb = Image.new("RGB", canvas.size, (0, 0, 0))
    rgb.paste(canvas, mask=canvas.split()[3])
    rgb.save(path, "PNG", optimize=True)
    print(f"  ✓ {path} ({size}x{size})")


def main():
    base = "/Users/mateovansweevelt/projects/caloriecounter/.claude/worktrees/jolly-buck-2efae0/CalorieCounter/Resources"
    appiconset = os.path.join(base, "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(appiconset, exist_ok=True)

    icons = [
        ("Icon-1024.png", 1024),
        ("Icon-180.png", 180),
        ("Icon-167.png", 167),
        ("Icon-152.png", 152),
        ("Icon-120.png", 120),
        ("Icon-87.png", 87),
        ("Icon-80.png", 80),
        ("Icon-76.png", 76),
        ("Icon-60.png", 60),
        ("Icon-58.png", 58),
        ("Icon-40.png", 40),
        ("Icon-29.png", 29),
    ]

    print("Generating CalorieCounter app icons...")
    for filename, size in icons:
        generate_icon(os.path.join(appiconset, filename), size)

    # Write Contents.json
    contents = """{
  "images" : [
    { "filename" : "Icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "filename" : "Icon-180.png",  "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "Icon-120.png",  "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "Icon-87.png",   "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "Icon-58.png",   "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "Icon-80.png",   "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "Icon-120.png",  "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "Icon-167.png",  "idiom" : "ipad",   "scale" : "2x", "size" : "83.5x83.5" },
    { "filename" : "Icon-152.png",  "idiom" : "ipad",   "scale" : "2x", "size" : "76x76" },
    { "filename" : "Icon-76.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "76x76" },
    { "filename" : "Icon-80.png",   "idiom" : "ipad",   "scale" : "2x", "size" : "40x40" },
    { "filename" : "Icon-40.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "40x40" },
    { "filename" : "Icon-58.png",   "idiom" : "ipad",   "scale" : "2x", "size" : "29x29" },
    { "filename" : "Icon-29.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "29x29" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
    with open(os.path.join(appiconset, "Contents.json"), "w") as f:
        f.write(contents)
    print("  ✓ Contents.json")
    print("\nDone! Icons saved to CalorieCounter/Resources/Assets.xcassets/AppIcon.appiconset/")


if __name__ == "__main__":
    main()
