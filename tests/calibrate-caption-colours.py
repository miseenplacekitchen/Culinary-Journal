#!/usr/bin/env python3
"""Simulate ring-caption arc sampling on calibration photos."""
import json
import math
import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("pip install pillow required")
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path(r"C:\Users\betty\.cursor\projects\c-Users-betty-Downloads-Culinary-Journal-main\assets")

BRAND_ANGLE = 130
USER_ANGLE = 310
ARC_HALF = 42
VB = 420
CX = CY = 210
RING_R = 168
STROKE = 3
FONT_SIZE = 13
GAP_BRAND_MM = 2
GAP_USER_MM = 0.5
MM_TO_PX = 96 / 25.4
VB_SCALE = VB / 400
CAP_ASC = FONT_SIZE * 0.72

# Slate ring theme (matches user's grey ring screenshots)
ON_LIGHT = (47, 51, 56)
ON_DARK = (236, 238, 240)


def lum(rgb):
    def ch(c):
        c /= 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(fg_lum, bg_lum):
    hi = max(fg_lum, bg_lum) + 0.05
    lo = min(fg_lum, bg_lum) + 0.05
    return hi / lo


def to_clock(their):
    return (90 - their) % 360


def inner_radius():
    return RING_R - STROKE


def mm_gap(mm):
    return mm * MM_TO_PX * VB_SCALE


def brand_r():
    return inner_radius() - mm_gap(GAP_BRAND_MM) - CAP_ASC


def user_r():
    return inner_radius() - mm_gap(GAP_USER_MM) - CAP_ASC


def polar(clock_deg, r):
    a = math.radians(clock_deg)
    return CX + r * math.sin(a), CY - r * math.cos(a)


ARC_STOPS = [
    -ARC_HALF,
    -ARC_HALF * 0.66,
    -ARC_HALF * 0.33,
    0,
    ARC_HALF * 0.33,
    ARC_HALF * 0.66,
    ARC_HALF,
]


def build_circle_canvas(img, size=320):
    """Cover-fit image into circle (matches hero preview)."""
    w, h = img.size
    scale = max(size / w, size / h)
    nw, nh = int(w * scale), int(h * scale)
    resized = img.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGB", (size, size), (255, 255, 255))
    ox = (size - nw) // 2
    oy = (size - nh) // 2
    canvas.paste(resized, (ox, oy))
    return canvas


def sample_arc(img, their_angle, r_vb, wrap=400):
    """Map viewBox arc to image pixels in 80% circle."""
    circle = int(wrap * 0.8)
    scale = circle / (RING_R * 2)
    vb_to_px = scale * (wrap / VB) / (wrap / VB)  # circle maps to RING_R*2 in vb
    # circle diameter = 0.8*wrap px; vb diameter = 2*RING_R
    px_per_vb = circle / (2 * RING_R)
    clock_center = to_clock(their_angle)
    cx = cy = circle / 2
    samples = []
    for stop in ARC_STOPS:
        x_vb, y_vb = polar(clock_center + stop, r_vb)
        lx = int((x_vb - CX) * px_per_vb + cx)
        ly = int((y_vb - CY) * px_per_vb + cy)
        lx = max(0, min(circle - 1, lx))
        ly = max(0, min(circle - 1, ly))
        samples.append(lum(img.getpixel((lx, ly))))
    samples.sort()
    return {
        "min": samples[0],
        "max": samples[-1],
        "median": samples[len(samples) // 2],
        "spread": samples[-1] - samples[0],
    }


def pick_maximin(stats):
    on_light_l = lum(ON_LIGHT)
    on_dark_l = lum(ON_DARK)
    min_dark = min(contrast(on_light_l, s) for s in [stats["min"], stats["median"], stats["max"]])
    min_light = min(contrast(on_dark_l, s) for s in [stats["min"], stats["median"], stats["max"]])
    return "onDark" if min_light > min_dark else "onLight"


def pick_busy_aware(stats):
    """Proposed: busy arcs (food texture) favour light theme text."""
    spread = stats["spread"]
    median = stats["median"]
    if spread >= 0.22:
        return "onDark"
    if median >= 0.52:
        return "onLight"
    return "onDark"


def pick_maximin_full(stats, canvas_samples):
    on_light_l = lum(ON_LIGHT)
    on_dark_l = lum(ON_DARK)
    min_dark = min(contrast(on_light_l, s) for s in canvas_samples)
    min_light = min(contrast(on_dark_l, s) for s in canvas_samples)
    return "onDark" if min_light > min_dark else "onLight"


def arc_samples_list(img, their_angle, r_vb, wrap=400):
    circle = int(wrap * 0.8)
    px_per_vb = circle / (2 * RING_R)
    clock_center = to_clock(their_angle)
    cx = cy = circle / 2
    out = []
    for stop in ARC_STOPS:
        x_vb, y_vb = polar(clock_center + stop, r_vb)
        lx = int((x_vb - CX) * px_per_vb + cx)
        ly = int((y_vb - CY) * px_per_vb + cy)
        lx = max(0, min(circle - 1, lx))
        ly = max(0, min(circle - 1, ly))
        out.append(lum(img.getpixel((lx, ly))))
    return out


def main():
    paths = sorted(ASSETS.glob("c__Users_betty_*images_*.png"))
    if not paths:
        print("No calibration images in", ASSETS)
        return 1

    rows = []
    mm_fail = 0
    ba_fail = 0
    for p in paths:
        img = Image.open(p).convert("RGB")
        canvas = build_circle_canvas(img)
        b_stats = sample_arc(canvas, BRAND_ANGLE, brand_r())
        u_stats = sample_arc(canvas, USER_ANGLE, user_r())
        b_samples = arc_samples_list(canvas, BRAND_ANGLE, brand_r())
        u_samples = arc_samples_list(canvas, USER_ANGLE, user_r())

        b_mm = pick_maximin_full({"spread": b_stats["spread"]}, b_samples)
        u_mm = pick_maximin_full({"spread": u_stats["spread"]}, u_samples)
        b_ba = pick_busy_aware(b_stats)
        u_ba = pick_busy_aware(u_stats)

        name = p.name.split("images_")[-1].rsplit("-", 1)[0]
        rows.append({
            "name": name,
            "brand_spread": round(b_stats["spread"], 3),
            "brand_median": round(b_stats["median"], 3),
            "brand_maximin": b_mm,
            "brand_busy": b_ba,
            "user_busy": u_ba,
        })
        if b_mm != b_ba:
            mm_fail += 1
        if b_ba == "onLight" and b_stats["spread"] >= 0.22:
            ba_fail += 1

    print(json.dumps(rows, indent=2))
    print(f"\n{len(paths)} images | maximin vs busy brand differ: {mm_fail}")
    brand_light_busy = sum(1 for r in rows if r["brand_busy"] == "onDark")
    print(f"busy-aware picks light brand text on {brand_light_busy}/{len(paths)} images")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
