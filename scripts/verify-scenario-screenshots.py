#!/usr/bin/env python3
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = [
    "home", "home-unconfigured", "bottle-type", "bottle-type-formula", "bottle-amount", "bottle-amount-min",
    "bottle-amount-max", "bottle-success", "wet-dirty-success", "sleep-inactive", "sleep-active",
    "sleep-start-success", "sleep-stop-success", "sleep-conflict-running", "event-log", "glance-profile",
]
DEVICES = {"fenix7": (520, 520), "fenix7s": (480, 480), "fenix7x": (560, 560)}

for scenario in SCENARIOS:
    for device, expected_size in DEVICES.items():
        path = ROOT / "output/e2e/scenarios" / scenario / f"{device}.png"
        image = Image.open(path).convert("L")
        if image.size != expected_size:
            raise SystemExit(f"{path}: expected {expected_size}, got {image.size}")
        if image.getextrema()[0] == image.getextrema()[1]:
            raise SystemExit(f"{path}: screenshot is blank")

# The native picker contract is a white amount on a black canvas (matching the
# Garmin SDK Picker sample). Isolate the center column and assert background,
# geometry, and strong foreground fill so same-color text cannot pass.
for scenario in ("bottle-amount-min", "bottle-amount", "bottle-amount-max"):
    for device in DEVICES:
        path = ROOT / "output/e2e/scenarios" / scenario / f"{device}.png"
        image = Image.open(path).convert("L")
        width, height = image.size
        left, top, right, bottom = int(width * .20), int(height * .40), int(width * .80), int(height * .60)
        crop = image.crop((left, top, right, bottom))
        black_ratio = sum(pixel < 32 for pixel in crop.getdata()) / (crop.width * crop.height)
        if black_ratio < .80:
            raise SystemExit(f"{path}: picker canvas is not black enough ({black_ratio:.1%})")
        points = [(x, y) for y in range(crop.height) for x in range(crop.width) if crop.getpixel((x, y)) > 200]
        if not points:
            raise SystemExit(f"{path}: no visible selected amount")
        xs = [point[0] for point in points]
        ys = [point[1] for point in points]
        glyph_center_x = left + (min(xs) + max(xs)) / 2
        delta = abs(glyph_center_x - width / 2)
        if delta > width * .01:
            raise SystemExit(f"{path}: amount is {delta:.1f}px off center")
        glyph_area = (max(xs) - min(xs) + 1) * (max(ys) - min(ys) + 1)
        light_fill = len(points) / glyph_area
        if light_fill < .28:
            raise SystemExit(f"{path}: amount contrast is too weak ({light_fill:.1%} light fill)")

print(f"OK: {len(SCENARIOS) * len(DEVICES)} screenshots; min/default/max bottle amounts centered and high-contrast on all devices")
