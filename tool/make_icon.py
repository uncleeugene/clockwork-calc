"""Generates the Clockwork Calc icon SVGs.

Usage: python3 tool/make_icon.py assets/icon
Writes icon.svg (full, black background), foreground.svg (transparent,
scaled into the Android adaptive-icon safe zone) and monochrome.svg.
"""
import math
import sys

ORANGE = "#FF9800"
WHITE = "#FFFFFF"
BG = "#000000"
C = 512  # centre of the 1024 canvas


def pt(r, deg):
    a = math.radians(deg - 90)  # 0° = 12 o'clock
    return C + r * math.cos(a), C + r * math.sin(a)


def gear_path(teeth, r_tip, r_root, tip_frac=0.30, base_frac=0.50):
    """Closed path of a gear with trapezoid teeth."""
    pitch = 360 / teeth
    tip_half = pitch * tip_frac / 2
    base_half = pitch * base_frac / 2
    d = []
    for i in range(teeth):
        a = i * pitch
        pts = [
            (r_root, a - base_half),
            (r_tip, a - tip_half),
            (r_tip, a + tip_half),
            (r_root, a + base_half),
        ]
        for j, (r, deg) in enumerate(pts):
            x, y = pt(r, deg)
            if i == 0 and j == 0:
                d.append(f"M{x:.1f},{y:.1f}")
            elif j == 2:  # tip arc
                d.append(f"A{r},{r} 0 0 1 {x:.1f},{y:.1f}")
            else:
                d.append(f"L{x:.1f},{y:.1f}")
        # root arc to the next tooth
        nx, ny = pt(r_root, a + pitch - base_half)
        d.append(f"A{r_root},{r_root} 0 0 1 {nx:.1f},{ny:.1f}")
    return " ".join(d) + " Z"


def artwork(gear_color, hand_color, hole_color):
    big = gear_path(12, 388, 334)
    hub = gear_path(8, 92, 70, tip_frac=0.4, base_frac=0.6)
    ticks = []
    for deg in (0, 90, 180, 270):
        x1, y1 = pt(226, deg)
        x2, y2 = pt(266, deg)
        ticks.append(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}"/>'
        )
    mx, my = pt(200, 60)   # 10:10 — minute hand → 2
    hx, hy = pt(145, 305)  # hour hand → just past 10
    return f"""
  <path d="{big}" fill="none" stroke="{gear_color}" stroke-width="50" stroke-linejoin="round"/>
  <g stroke="{hand_color}" stroke-width="42" stroke-linecap="round">
    {' '.join(ticks)}
    <line x1="{C}" y1="{C}" x2="{mx:.1f}" y2="{my:.1f}"/>
    <line x1="{C}" y1="{C}" x2="{hx:.1f}" y2="{hy:.1f}"/>
  </g>
  <path d="{hub}" fill="{gear_color}"/>
  <circle cx="{C}" cy="{C}" r="26" fill="{hole_color}"/>"""


def svg(body, background=None, scale=1.0):
    bg = f'<rect width="1024" height="1024" fill="{background}"/>' if background else ""
    t = f"translate({C} {C}) scale({scale}) translate({-C} {-C})"
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        f'viewBox="0 0 1024 1024">{bg}<g transform="{t}">{body}\n</g></svg>\n'
    )


# Adaptive icons: 108dp canvas, safe zone is a 66dp circle → radius 313px.
# Artwork outer radius is ~413 incl. stroke, so scale it to ~0.75.
SAFE = 0.75

out = sys.argv[1]
files = {
    "icon.svg": svg(artwork(ORANGE, WHITE, BG), background=BG, scale=0.95),
    "foreground.svg": svg(artwork(ORANGE, WHITE, BG), scale=SAFE),
    # Android 13 themed icons use only the alpha channel; the hub hole must
    # be transparent, so punch it with a mask instead of painting black.
    "monochrome.svg": svg(
        '<mask id="m"><rect width="1024" height="1024" fill="#fff"/>'
        f'<circle cx="{C}" cy="{C}" r="26" fill="#000"/></mask>'
        f'<g mask="url(#m)">{artwork(WHITE, WHITE, WHITE)}</g>',
        scale=SAFE,
    ),
}
for name, content in files.items():
    with open(f"{out}/{name}", "w") as f:
        f.write(content)
    print("wrote", name)
