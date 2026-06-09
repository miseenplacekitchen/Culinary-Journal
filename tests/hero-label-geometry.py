import math
BRAND, HANDLE = 150, 330
RING_VB, RING_R, PADDING_MM = 420, 168, 2

def mm_px(mm):
    return mm * 96 / 25.4

def get_geometry(w, h):
    half = min(w, h) / 2
    frame_r = half * (RING_R / (RING_VB / 2))
    return frame_r - 1.5 - mm_px(PADDING_MM), w / 2, h / 2

def polar(lr, cx, cy, deg):
    rad = math.radians(deg)
    return cx + lr * math.cos(rad), cy - lr * math.sin(rad)

lr, cx, cy = get_geometry(400, 400)
b = polar(lr, cx, cy, BRAND)
h = polar(lr, cx, cy, HANDLE)
sep = min(abs(BRAND - HANDLE) % 360, 360 - abs(BRAND - HANDLE) % 360)
assert abs(sep - 180) < 0.1, sep
assert b[0] < cx and h[0] > cx and b[1] < cy and h[1] > cy
assert abs(math.hypot(b[0]-cx, b[1]-cy) - lr) < 0.01
assert abs(math.hypot(h[0]-cx, h[1]-cy) - lr) < 0.01
print('PASS labelR=%.1f sep=%.0f brand=%s handle=%s' % (lr, sep, b, h))
