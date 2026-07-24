#!/usr/bin/env python3
"""VM Sentinel — programmatic icon generator (spec §4, §23).
SPDX-License-Identifier: MIT

Renders the VM Sentinel mark (shield + VM window + pulse + status dot) to PNGs
using ONLY the Python standard library (zlib, struct). No external assets, no
fonts, no tracking data. Deterministic output committed as assets/*.png.

Usage: python3 scripts/generate-icons.py [outdir]
"""
import os, sys, zlib, struct, math

# ---- Palette (matches assets/vm-sentinel.svg) --------------------------------
SHIELD   = (0x1f, 0x6f, 0xeb, 255)
BORDER   = (0x0b, 0x2a, 0x5b, 255)
WINDOW   = (0x0b, 0x2a, 0x5b, 255)
TITLE    = (0x0a, 0x21, 0x48, 255)
DOTBLUE  = (0x5f, 0xb0, 0xff, 255)
PULSE    = (0x7e, 0xe7, 0x87, 255)
STATUS   = (0x2e, 0xa0, 0x43, 255)
WHITE    = (0xff, 0xff, 0xff, 255)
CLEAR    = (0, 0, 0, 0)

SS = 4  # supersampling factor for anti-aliasing


def shield_path(s):
    # returns polygon points (in unit 0..128 * s) approximating the SVG shield
    P = [(64, 8), (112, 24), (112, 62)]
    # bezier-ish bottom approximated by arc samples
    for t in [i / 16 for i in range(1, 16)]:
        # quadratic-ish curve from (112,62) to (64,120) then to (16,62)
        pass
    # Use two curves sampled
    def q(p0, p1, p2, n):
        pts = []
        for i in range(1, n + 1):
            u = i / n
            x = (1 - u) ** 2 * p0[0] + 2 * (1 - u) * u * p1[0] + u ** 2 * p2[0]
            y = (1 - u) ** 2 * p0[1] + 2 * (1 - u) * u * p1[1] + u ** 2 * p2[1]
            pts.append((x, y))
        return pts
    P += q((112, 62), (112, 100), (64, 120), 16)
    P += q((64, 120), (16, 100), (16, 62), 16)
    P += [(16, 24)]
    return [(x * s, y * s) for (x, y) in P]


def point_in_poly(x, y, poly):
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
            inside = not inside
        j = i
    return inside


def dist_seg(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def rounded_rect(x, y, x0, y0, x1, y1, r):
    if x0 + r <= x <= x1 - r and y0 <= y <= y1:
        return True
    if x0 <= x <= x1 and y0 + r <= y <= y1 - r:
        return True
    for cx, cy in [(x0 + r, y0 + r), (x1 - r, y0 + r), (x0 + r, y1 - r), (x1 - r, y1 - r)]:
        if math.hypot(x - cx, y - cy) <= r:
            return True
    return False


def render(size):
    s = size * SS
    scale = s / 128.0
    poly = shield_path(scale)
    # Pulse points kept in UNIT coords (0..128) because we compare against ux,uy.
    pulse = [(40, 66), (54, 66), (58, 56), (64, 76), (70, 62), (74, 66), (88, 66)]
    buf = bytearray(s * s * 4)

    def setpx(ix, iy, c):
        o = (iy * s + ix) * 4
        buf[o:o + 4] = bytes(c)

    for iy in range(s):
        for ix in range(s):
            x, y = ix + 0.5, iy + 0.5
            ux, uy = x / scale, y / scale  # unit coords 0..128
            c = CLEAR
            if point_in_poly(x, y, poly):
                c = SHIELD
                # VM window 38,40 - 90,80
                if rounded_rect(ux, uy, 38, 40, 90, 80, 4):
                    c = TITLE if uy <= 50 else WINDOW
                    if uy <= 50:
                        for cxv in (45, 52):
                            if math.hypot(ux - cxv, uy - 45) <= 2:
                                c = DOTBLUE
                # pulse line (thickness ~4 unit)
                dmin = min(dist_seg(ux, uy, pulse[i][0], pulse[i][1],
                                    pulse[i + 1][0], pulse[i + 1][1]) for i in range(len(pulse) - 1))
                if dmin <= 2.8:
                    c = PULSE
            # status dot 96,34 r=9 with white ring r=11
            dd = math.hypot(ux - 96, uy - 34)
            if dd <= 9:
                c = STATUS
            elif dd <= 11.5:
                c = WHITE
            setpx(ix, iy, c)

    # downsample SS -> size (box filter)
    out = bytearray(size * size * 4)
    for oy in range(size):
        for ox in range(size):
            r = g = b = a = 0
            for dy in range(SS):
                for dx in range(SS):
                    o = ((oy * SS + dy) * s + (ox * SS + dx)) * 4
                    r += buf[o]; g += buf[o + 1]; b += buf[o + 2]; a += buf[o + 3]
            n = SS * SS
            oo = (oy * size + ox) * 4
            out[oo:oo + 4] = bytes((r // n, g // n, b // n, a // n))
    return bytes(out)


def write_png(path, size, raw):
    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        return c + struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff)
    stride = size * 4
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        rows += raw[y * stride:(y + 1) * stride]
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets")
    outdir = os.path.abspath(outdir)
    os.makedirs(outdir, exist_ok=True)
    targets = {
        "vm-sentinel-512.png": 512,
        "vm-sentinel-256.png": 256,
        "vm-sentinel-128.png": 128,
        "vm-sentinel-48.png": 48,
        "vm-sentinel-32.png": 32,
    }
    for name, size in targets.items():
        print(f"rendering {name} ({size}px)…")
        write_png(os.path.join(outdir, name), size, render(size))
    # WebGUI icon + favicon copies
    import shutil
    shutil.copyfile(os.path.join(outdir, "vm-sentinel-48.png"),
                    os.path.join(outdir, "vm-sentinel.png"))
    print("done")


if __name__ == "__main__":
    main()
