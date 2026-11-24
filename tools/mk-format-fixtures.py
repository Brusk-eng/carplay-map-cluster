#!/usr/bin/env python3
"""Build synthetic 1920x720 CarPlay panels for format-gate tests."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

out = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/carplay-fmt-test")
out.mkdir(parents=True, exist_ok=True)


def dash_map():
    im = Image.new("RGB", (1920, 720), (20, 22, 28))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 90, 720], fill=(10, 10, 12))
    d.rectangle([100, 40, 1200, 680], fill=(45, 55, 62))
    d.rectangle([180, 80, 500, 280], fill=(30, 90, 50))
    d.rectangle([700, 100, 1100, 250], fill=(40, 70, 140))
    d.line([(200, 500), (900, 200)], fill=(220, 170, 40), width=14)
    d.line([(300, 650), (1000, 120)], fill=(90, 100, 110), width=8)
    for r, col in [(50, (20, 120, 180)), (35, (40, 200, 210)), (18, (60, 230, 240))]:
        d.ellipse([640 - r, 580 - r, 640 + r, 580 + r], outline=col, width=4)
    d.polygon([(640, 520), (600, 600), (680, 600)], fill=(30, 210, 220))
    d.rectangle([1240, 40, 1880, 340], fill=(55, 58, 65))
    d.rectangle([1240, 380, 1880, 680], fill=(45, 48, 55))
    d.rectangle([1320, 440, 1580, 600], fill=(200, 70, 100))
    return im


def weather_page():
    im = Image.new("RGB", (1920, 720), (120, 70, 40))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 90, 720], fill=(10, 10, 12))
    for y in range(40, 680):
        warm = int(140 + 40 * (y / 680))
        d.line([(100, y), (1200, y)], fill=(warm, int(warm * 0.55), 35))
    d.ellipse([350, 180, 550, 380], outline=(240, 240, 240), width=4)
    for y in range(40, 680):
        c = int(200 + 40 * (y / 680))
        d.line([(1240, y), (1880, y)], fill=(c, int(c * 0.45), 30))
    d.arc([1300, 200, 1800, 500], 0, 180, fill=(255, 220, 80), width=6)
    return im


def fullscreen_map():
    im = Image.new("RGB", (1920, 720), (30, 35, 42))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 90, 720], fill=(10, 10, 12))
    d.rectangle([100, 20, 1900, 700], fill=(32, 38, 46))
    d.line([(200, 600), (1700, 100)], fill=(200, 160, 40), width=10)
    d.polygon([(960, 560), (940, 600), (980, 600)], fill=(40, 200, 210))
    return im


dash_map().save(out / "synth_map_dashboard.png")
weather_page().save(out / "synth_weather.png")
fullscreen_map().save(out / "synth_fullscreen.png")
print("wrote fixtures to", out)
