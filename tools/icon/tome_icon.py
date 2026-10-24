"""Draws the Tome icon on white: an open book built from gold and
partner-colour brush strokes with splatter, and three painted sparkles
rising out of it. Same brush style as the Scry icon.

usage: tome_icon.py out.svg [palette] [seed]   (the app uses teal, seed 7)"""
import math
import random
import sys

PALETTES = {
    'sapphire': ['#2f5bb7', '#3a6fd1', '#24479a', '#4d82e0', '#1c3a80'],
    'teal':     ['#16867a', '#1f9e8f', '#0f6b62', '#2bb3a2', '#0b5550'],
    'crimson':  ['#a3283a', '#bd3447', '#86202f', '#cf4a5c', '#6e1826'],
    'emerald':  ['#2e7d4f', '#38955f', '#226640', '#47ad72', '#1a5233'],
    'ink':      ['#2b2f3a', '#3a3f4d', '#1f222b', '#4a5061', '#15171d'],
}
GOLDS = ['#c9a227', '#d4ae3a', '#b8892a', '#e0b93e', '#a87f1f']

PAL = sys.argv[2] if len(sys.argv) > 2 else 'teal'
SEED = int(sys.argv[3]) if len(sys.argv) > 3 else 7
random.seed(SEED)
ACC = PALETTES[PAL]
TINT = ACC[3]

out = []


def poly_stroke(center, widths, color, opacity=1.0):
    """A filled brush shape around a centre line, width varying per point."""
    left, right = [], []
    n = len(center)
    for i, (x, y) in enumerate(center):
        x0, y0 = center[max(i - 1, 0)]
        x1, y1 = center[min(i + 1, n - 1)]
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L
        w = widths[i] / 2
        wl = w * random.uniform(0.62, 1.38) * (0.35 if random.random() < 0.06 else 1)
        wr = w * random.uniform(0.62, 1.38) * (0.35 if random.random() < 0.06 else 1)
        left.append((x + nx * wl, y + ny * wl))
        right.append((x - nx * wr, y - ny * wr))
    pts = left + right[::-1]
    d = 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in pts) + ' Z'
    out.append(f'<path d="{d}" fill="{color}" opacity="{opacity:.2f}"/>')


def profile(t, peak, press, lift, wob):
    a = min(1.0, t / press) ** 0.7
    b = 1.0 if t < 1 - lift else max(0.0, (1 - t) / lift) ** 1.3
    return max(0.6, peak * a * b * (1 + wob * math.sin(t * random.uniform(7, 13))))


def bez(p0, p1, p2, n):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


def jitter(p, a):
    return (p[0] + random.uniform(-a, a), p[1] + random.uniform(-a, a))


def curve_stroke(color, p0, p1, p2, peak, n=120, dry=True, opacity=1.0, splash=True, pts=None):
    """One brush stroke along a curve, with bristle gaps and flicks."""
    press = random.uniform(0.03, 0.12)
    lift = random.uniform(0.2, 0.45)
    wob = random.uniform(0.08, 0.25)
    if pts is None:
        pts = bez(p0, p1, p2, n)
    n = len(pts) - 1
    # A gentle wobble across the stroke so it isn't a perfect curve.
    fr, ph, amp = random.uniform(3, 7), random.uniform(0, 6), random.uniform(2, 7)
    wob_pts = []
    for i, (x, y) in enumerate(pts):
        x0, y0 = pts[max(i - 1, 0)]
        x1, y1 = pts[min(i + 1, n)]
        L = math.hypot(x1 - x0, y1 - y0) or 1
        nx, ny = -(y1 - y0) / L, (x1 - x0) / L
        o = amp * math.sin(i / n * fr + ph)
        wob_pts.append((x + nx * o, y + ny * o))
    ws = [profile(i / n, peak, press, lift, wob) for i in range(n + 1)]
    poly_stroke(wob_pts, ws, color, opacity)
    if dry:
        for _ in range(random.randint(3, 7)):
            off = random.uniform(-0.42, 0.42)
            b = random.uniform(0.15, 0.7)
            e = random.uniform(b + 0.15, 1.0)
            seg = []
            for i in range(int(n * b), int(n * e)):
                x, y = wob_pts[i]
                x0, y0 = wob_pts[max(i - 1, 0)]
                x1, y1 = wob_pts[min(i + 1, n)]
                L = math.hypot(x1 - x0, y1 - y0) or 1
                nx, ny = -(y1 - y0) / L, (x1 - x0) / L
                seg.append((x + nx * ws[i] * off, y + ny * ws[i] * off))
            if len(seg) > 2:
                d = 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in seg)
                out.append(f'<path d="{d}" fill="none" stroke="#fff" '
                           f'stroke-width="{random.uniform(1.5, 5):.1f}" stroke-linecap="round" '
                           f'opacity="{random.uniform(0.5, 0.95):.2f}"/>')
    if splash:
        x, y = wob_pts[0]
        splat(x, y, color, peak * 1.3, random.randint(9, 18), 3, 14)
        xa, ya = wob_pts[-2]
        xb, yb = wob_pts[-1]
        flick(xb, yb, math.atan2(yb - ya, xb - xa), color)


def splat(x, y, color, spread, count, rmin, rmax):
    for _ in range(count):
        ang = random.uniform(0, 2 * math.pi)
        dist = spread * random.uniform(0.3, 1.3)
        rr = random.uniform(rmin, rmax) * random.choice([0.4, 0.6, 1, 1])
        out.append(f'<circle cx="{x + dist * math.cos(ang):.1f}" cy="{y + dist * math.sin(ang):.1f}" '
                   f'r="{rr:.1f}" fill="{color}" opacity="{random.uniform(0.7, 1):.2f}"/>')


def flick(x, y, ang, color):
    for _ in range(random.randint(5, 10)):
        a = ang + random.uniform(-0.5, 0.5)
        d = random.uniform(20, 120)
        L = random.uniform(10, 36)
        w = random.uniform(3, 8)
        px, py = x + d * math.cos(a), y + d * math.sin(a)
        out.append(f'<ellipse cx="{px:.1f}" cy="{py:.1f}" rx="{L:.1f}" ry="{w / 2:.1f}" '
                   f'transform="rotate({math.degrees(a):.1f} {px:.1f} {py:.1f})" fill="{color}"/>')


def drip(color, x, y, length):
    pts = [(x + random.uniform(-2, 2), y + length * t) for t in [i / 30 for i in range(31)]]
    ws = [10 * (1 - t) ** 0.4 + 3 for t in [i / 30 for i in range(31)]]
    poly_stroke(pts, ws, color)
    out.append(f'<circle cx="{pts[-1][0]:.1f}" cy="{pts[-1][1] + 4:.1f}" r="7" fill="{color}"/>')


def star_strokes(cx, cy, size, colors):
    """A four-point sparkle painted as four tapered brush strokes."""
    for k in range(4):
        base = k * math.pi / 2 + random.uniform(-0.06, 0.06)
        length = size * random.uniform(0.85, 1.1)
        bend = random.uniform(-0.18, 0.18)
        pts, ws = [], []
        n = 40
        for i in range(n + 1):
            t = i / n
            a = base + bend * t * t
            d = length * t
            pts.append((cx + d * math.cos(a), cy + d * math.sin(a)))
            ws.append(size * 0.36 * (1 - t) ** 1.25 + 1.2)
        poly_stroke(pts, ws, random.choice(colors))
        tx, ty = pts[-1]
        if random.random() < 0.5:
            d = size * random.uniform(0.12, 0.25)
            out.append(f'<circle cx="{tx + d * math.cos(base):.1f}" cy="{ty + d * math.sin(base):.1f}" '
                       f'r="{size * random.uniform(0.03, 0.06):.1f}" fill="{random.choice(colors)}"/>')
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{size * 0.16:.1f}" fill="{random.choice(colors)}"/>')


# ---------------------------------------------------------------- geometry
# An open book seen from the front: spine in the middle, pages arching
# up and out, outer edges hanging slightly lower.
SX = 512
SPINE_TOP, SPINE_BOT = (SX, 560), (SX, 760)


def page(side):
    """Corner points of one page: spine top/bottom and outer top/bottom."""
    s = side
    return {
        'top': [(SX, 560), (SX + s * 130, 470), (SX + s * 300, 520)],
        'bot': [(SX, 760), (SX + s * 140, 680), (SX + s * 300, 720)],
    }


def lerp_pts(a, b, t):
    return [(a[i][0] + (b[i][0] - a[i][0]) * t, a[i][1] + (b[i][1] - a[i][1]) * t) for i in range(3)]


# ---------------------------------------------------------------- compose

# Cast shadow under the book.
for _ in range(5):
    y = 800 + random.uniform(-6, 10)
    w = random.uniform(250, 320)
    curve_stroke(random.choice([ACC[4], ACC[2], '#8a8a96']), (SX - w, y), (SX, y + 12), (SX + w, y),
                 random.uniform(10, 24), dry=True, opacity=random.uniform(0.15, 0.28), splash=False)

# Big sweeps behind the book: separate partial arcs over the top,
# like Scry's broken ring.
for _ in range(13):
    r = random.uniform(240, 300)
    a0 = random.uniform(178, 300)
    a1 = min(a0 + random.uniform(35, 120), 362)
    if random.random() < 0.5:
        a0, a1 = a1, a0
    arc = [(SX + r * math.cos(math.radians(a0 + (a1 - a0) * i / 140)),
            525 + 0.92 * r * math.sin(math.radians(a0 + (a1 - a0) * i / 140))) for i in range(141)]
    col = random.choice(ACC if random.random() < 0.55 else GOLDS)
    curve_stroke(col, None, None, None, random.uniform(8, 44), opacity=random.uniform(0.8, 1), pts=arc)

# Glow rising from the pages.
out.append(f'<ellipse cx="{SX}" cy="420" rx="250" ry="240" fill="url(#mist)"/>')

# The cover: heavy strokes in the partner colour peeking out under the pages.
for side in (-1, 1):
    for _ in range(7):
        p0 = jitter((SX, 790), 10)
        p1 = jitter((SX + side * 150, 720), 10)
        p2 = jitter((SX + side * 300, 745), 10)
        curve_stroke(random.choice(ACC), p0, p1, p2, random.uniform(32, 62), opacity=random.uniform(0.85, 1), splash=False)


# Page body: washes laid along the page's curve, pale on top, deepening below.
for side in (-1, 1):
    pg = page(side)
    for k in range(14):
        t = k / 13
        a, b, c = lerp_pts(pg['top'], pg['bot'], t)
        col = random.choice(['#fffaf0', '#fff3cc', '#f6ecd2'] if t < 0.6 else [TINT, ACC[1]] + GOLDS[:2])
        op = random.uniform(0.25, 0.45) if t < 0.6 else random.uniform(0.15, 0.3)
        curve_stroke(col, jitter(a, 4), jitter(b, 6), jitter(c, 6), random.uniform(16, 30),
                     dry=True, opacity=op, splash=False)
    # Lines of text: short thin strokes across the upper page.
    for k in range(5):
        t = 0.18 + k * 0.13
        a, b, c = lerp_pts(pg['top'], pg['bot'], t)
        # Keep text away from the spine and the outer edge.
        pts = bez(a, b, c, 20)
        lo, hi = random.uniform(0.15, 0.25), random.uniform(0.75, 0.88)
        p0, p2 = pts[int(lo * 20)], pts[int(hi * 20)]
        pm = pts[int((lo + hi) / 2 * 20)]
        curve_stroke(random.choice(ACC[:3]), p0, pm, p2, random.uniform(4, 7), n=60,
                     dry=False, opacity=random.uniform(0.35, 0.6), splash=False)

# Page edges in gold: the top curve, the outer edge, and stacked page
# lines along the bottom.
for side in (-1, 1):
    pg = page(side)
    for _ in range(3):
        a, b, c = pg['top']
        curve_stroke(random.choice(GOLDS), jitter(a, 4), jitter(b, 6), jitter(c, 6),
                     random.uniform(10, 22), opacity=random.uniform(0.85, 1))
    a, c = pg['top'][2], pg['bot'][2]
    curve_stroke(random.choice(GOLDS), jitter(a, 4), (c[0] + side * 30, (a[1] + c[1]) / 2), jitter(c, 4),
                 random.uniform(5, 9), opacity=0.7, splash=False)
    for k in range(4):
        a, b, c = pg['bot']
        dy = k * 9
        curve_stroke(random.choice(GOLDS + ACC[:2]), (a[0], a[1] + dy), (b[0], b[1] + dy), (c[0], c[1] + dy),
                     random.uniform(6, 14), opacity=random.uniform(0.7, 0.95), splash=k == 0)

# The spine: one dark stroke down the fold.
curve_stroke(ACC[4], (SX, 555), (SX + 4, 660), (SX, 780), 12, opacity=0.85, splash=False)
curve_stroke(random.choice(GOLDS), (SX - 3, 565), (SX - 6, 660), (SX - 2, 770), 6, opacity=0.8, splash=False)

# Magic rising: loose strokes curling up from the pages toward the stars.
def swirl(color, amp, turns, phase, peak, top, opacity):
    """A ribbon of paint winding upward out of the book, widening as it
    rises and thinning to a tail near the stars."""
    n = 140
    pts, ws = [], []
    for i in range(n + 1):
        t = i / n
        x = SX + amp * (0.35 + 0.65 * t) * math.sin(phase + t * turns * 2 * math.pi)
        y = 545 - (545 - top) * t
        pts.append((x, y))
        ws.append(peak * min(1, t / 0.15) ** 0.7 * (1 - t) ** 0.8 + 1.2)
    poly_stroke(pts, ws, color, opacity)


swirl(random.choice(GOLDS), 120, 1.1, 0.0, 22, 270, 0.75)
swirl(random.choice(ACC[:3]), 140, 0.95, math.pi, 16, 240, 0.65)
swirl(random.choice(GOLDS), 80, 1.3, 1.8, 9, 300, 0.55)

# Drips off the cover and loose splatter.
for x in random.sample([SX - 220, SX - 160, SX - 120, SX + 90, SX + 150, SX + 200, SX + 260], 5):
    drip(random.choice(GOLDS + ACC), x + random.uniform(-15, 15), 760, random.uniform(35, 80))
for _ in range(120):
    a = random.uniform(0, 2 * math.pi)
    rr = 330 + random.gauss(0, 60)
    out.append(f'<circle cx="{SX + rr * math.cos(a):.1f}" cy="{540 + 0.85 * rr * math.sin(a):.1f}" '
               f'r="{random.uniform(1.5, 12):.1f}" fill="{random.choice(GOLDS + ACC)}" '
               f'opacity="{random.uniform(0.6, 1):.2f}"/>')

# Three sparkles over the book: a big gold one in the middle, a partner
# one to the left and a small gold one to the right.
STAR_AT = len(out)
star_strokes(SX + 10, 330, 108, GOLDS)
star_strokes(SX - 150, 230, 52, ACC[:4])
star_strokes(SX + 160, 205, 40, GOLDS)

body = '\n  '.join(out[:STAR_AT])
stars = '\n  '.join(out[STAR_AT:])
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="mist" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="{TINT}" stop-opacity="0.18"/>
      <stop offset="0.7" stop-color="{TINT}" stop-opacity="0.05"/>
      <stop offset="1" stop-color="{TINT}" stop-opacity="0"/>
    </radialGradient>
    <filter id="rough" x="-10%" y="-10%" width="120%" height="120%">
      <feTurbulence type="fractalNoise" baseFrequency="0.09" numOctaves="3" seed="{SEED}"/>
      <feDisplacementMap in="SourceGraphic" scale="11"/>
    </filter>
    <filter id="roughstar" x="-10%" y="-10%" width="120%" height="120%">
      <feTurbulence type="fractalNoise" baseFrequency="0.06" numOctaves="2" seed="{SEED}"/>
      <feDisplacementMap in="SourceGraphic" scale="5"/>
    </filter>
    <clipPath id="tile"><rect x="32" y="32" width="960" height="960" rx="200"/></clipPath>
  </defs>
  <rect x="32" y="32" width="960" height="960" rx="200" fill="#ffffff"/>
  <g clip-path="url(#tile)">
  <g filter="url(#rough)">
  {body}
  </g>
  <g filter="url(#roughstar)">
  {stars}
  </g>
  </g>
</svg>
'''
open(sys.argv[1], 'w', encoding='utf-8').write(svg)
print('ok', PAL, len(out), 'shapes')
