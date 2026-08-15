#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = [
    "home", "home-unconfigured", "bottle-type", "bottle-type-formula",
    "bottle-amount", "bottle-amount-min", "bottle-amount-max", "bottle-success",
    "wet-dirty-success", "sleep-inactive", "sleep-active", "sleep-start-success",
    "sleep-stop-success", "sleep-conflict-running", "event-log", "glance-profile",
]

output = ROOT / "output/e2e/contact-sheets"
output.mkdir(parents=True, exist_ok=True)
for device in ("fenix7", "fenix7s", "fenix7x"):
    sheet = Image.new("RGB", (1200, 1280), "#222222")
    draw = ImageDraw.Draw(sheet)
    for index, scenario in enumerate(SCENARIOS):
        image = Image.open(ROOT / "output/e2e/scenarios" / scenario / f"{device}.png")
        image.thumbnail((280, 280))
        x = (index % 4) * 300
        y = (index // 4) * 320
        draw.text((x + 8, y + 2), scenario, fill="white")
        sheet.paste(image, (x + (280 - image.width) // 2, y + 20))
    sheet.save(output / f"{device}.png")
