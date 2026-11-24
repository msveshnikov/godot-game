"""Alice from her turnaround sheet (concept/characters/alice_sheet.png, ChatGPT): front,
right-side and back views on white. Run with plain Python (numpy, opencv, scipy,
scikit-image):  python blender/scripts/alice_sheet.py

1. Cuts the three silhouettes out of the white (flood fill from the edges, so the white
   sneakers with their grey outlines survive) and finds where she stands in each view.
2. Builds her body as a voxel volume: every height slice is a set of ellipses, as wide
   as the front view shows each part (torso, legs, arms, head) and as deep as the side
   view shows; the ponytail is a round strand where the side view sticks out behind.
   Smoothed, then turned into a surface by marching cubes.
3. Measures the joints the game's shader rig needs (hips, knees, shoulders, hands).
4. Fills the white round each figure with its own edge colours, so a projected texture
   never samples background.

Writes blender/build/alice_hull.npz (verts, faces, metres, Blender axes: x her left,
-y front, z up), blender/build/alice_texture.png, blender/build/alice_rig.json and
blender/build/alice_masks.png (a check picture). build_female_player.py (in Blender)
turns that into female_player.glb.
"""
import json
import os

import cv2
import numpy as np
from scipy import ndimage
from skimage import measure

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SHEET = os.path.join(ROOT, "concept", "characters", "alice_sheet.png")
OUT = os.path.join(ROOT, "blender", "build")
HEIGHT = 1.70  # feet to the top of the head (not the bun), metres
VOXEL = 0.005


def masks(image):
    h, w = image.shape[:2]
    flood = np.zeros((h + 2, w + 2), np.uint8)
    work = image.copy()
    for seed in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1)]:
        if work[seed[1], seed[0]].min() > 235:
            cv2.floodFill(work, flood, seed, (255, 0, 255), (6, 6, 6), (6, 6, 6), cv2.FLOODFILL_FIXED_RANGE | 8)
    background = flood[1:-1, 1:-1] > 0
    figure = ~background
    figure = ndimage.binary_opening(figure, iterations=1)
    figure = ndimage.binary_fill_holes(figure)
    return figure


def split_views(figure):
    """Three figures left to right: column ranges between the empty gaps."""
    cols = figure.sum(axis=0) > 0
    runs = []
    start = None
    for x, on in enumerate(cols):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append((start, x))
            start = None
    if start is not None:
        runs.append((start, len(cols)))
    runs = sorted(runs, key=lambda r: r[1] - r[0], reverse=True)[:3]
    runs.sort()
    views = []
    for a, b in runs:
        m = np.zeros_like(figure)
        m[:, a:b] = figure[:, a:b]
        # Keep the biggest blob (drops specks).
        labels, n = ndimage.label(m)
        if n > 1:
            sizes = ndimage.sum(m, labels, range(1, n + 1))
            m = labels == (1 + int(np.argmax(sizes)))
        views.append(m)
    return views


def rows_segments(row):
    """[start, end) runs of True in a 1-D array."""
    d = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
    starts = np.where(d == 1)[0]
    ends = np.where(d == -1)[0]
    return list(zip(starts, ends))


EYES = 1.585 # eye line, metres up from the feet
CHEEK = 1.56 # below this the head is the face (jaw, chin); above it the skull
SKULL = {"z": 1.585, "half_z": 0.135, "half_x": 0.082, "half_y": 0.103}


def skin(pixel):
    b, g, r = (int(v) for v in pixel)
    return r > 120 and r > g > b and r - b > 35


def face_half_width(row, c, gap):
    """Half the run of skin through the middle of a row, in pixels, stepping over
    short gaps (the eyes) but stopping at hair or background."""
    out = []
    for step in (-1, 1):
        x = c
        last = c
        miss = 0
        while 0 < x < len(row) - 1 and miss <= gap:
            x += step
            if skin(row[x]):
                last = x
                miss = 0
            else:
                miss += 1
        out.append(abs(last - c))
    return (out[0] + out[1]) / 2.0


def head_profile(image, front, fc, px, f_bottom, side_front, head_from, top):
    """Smooth half-width of the head per height: the face's skin below the cheekbones
    (median-filtered, so the eyes and lips don't notch it), an ellipsoid skull above,
    blended over the cheek line. Hair locks hanging beside the face are left out."""
    zs = np.arange(head_from - 0.06, top + 0.03, VOXEL)
    c = int(round(fc))
    raw = []
    for z in zs:
        r = int(round(f_bottom - z / px))
        row = image[r]
        raw.append(face_half_width(row, c, int(0.03 / px)) * px if skin(row[c]) or z > 1.5 else 0.0)
    raw = ndimage.median_filter(np.array(raw), size=9)
    raw = ndimage.gaussian_filter1d(raw, 2.0)
    widths = {}
    for z, w in zip(zs, raw):
        t = (z - SKULL["z"]) / SKULL["half_z"]
        skull = SKULL["half_x"] * np.sqrt(max(0.0, 1.0 - t * t))
        if z < CHEEK - 0.02:
            half = w * 0.97 # just inside the outline, clear of the hair beside it
        elif z < CHEEK + 0.03:
            k = (z - (CHEEK - 0.02)) / 0.05
            half = (1.0 - k) * w + k * max(w, skull)
        else:
            half = skull
        widths[round(z, 4)] = half
    return widths


def head_slice(widths, z, body, head_from):
    """Head cross-section at z: [(xa, xb)] and its front-to-back extent, or None for the
    T-shirt's collar (body as usual)."""
    key = min(widths, key=lambda k: abs(k - z))
    half = widths[key]
    if half < 0.02:
        return None
    ya, yb = body
    if z >= 1.5:
        # Back of the skull from the ellipsoid, set back from the brow.
        t = (z - SKULL["z"]) / SKULL["half_z"]
        back = SKULL_BACK_Y + SKULL["half_y"] * np.sqrt(max(0.0, 1.0 - t * t))
        yb = min(yb, max(back, ya + 0.07))
    return [(-half, half)], (ya, yb)


SKULL_BACK_Y = 0.0 # set in main: the skull's centre (y) from the side view's brow

# How far back (+y) her back reaches from the shoulder blades to the neck: the back
# of the chest, curving forward over the shoulders. (height, y)
UPPER_BACK = [(1.24, 0.118), (1.30, 0.112), (1.34, 0.1), (1.40, 0.082), (1.46, 0.075)]


def upper_back(z):
    if z < UPPER_BACK[0][0]:
        return 1.0
    return float(np.interp(z, [p[0] for p in UPPER_BACK], [p[1] for p in UPPER_BACK]))


def main():
    os.makedirs(OUT, exist_ok=True)
    image = cv2.imread(SHEET, cv2.IMREAD_COLOR)
    figure = masks(image)
    front, side, back = split_views(figure)

    def extent(m):
        ys, xs = np.nonzero(m)
        return ys.min(), ys.max(), xs.min(), xs.max()

    # Scale: feet (lowest pixel) to the top of the head. The bun sits on top, so take
    # the head top as the front view's top minus the bun, measured where the front
    # silhouette first gets wider than the bun (a narrow knot on the crown).
    f_top, f_bottom, _, _ = extent(front)
    widths = front.sum(axis=1)
    head_top = f_top
    max_head = widths[f_top:f_top + 160].max()
    for y in range(f_top, f_top + 160):
        if widths[y] > 0.55 * max_head:
            head_top = y
            break
    px = HEIGHT / float(f_bottom - head_top)
    print("front rows %d..%d, head top %d, %.2f mm per px" % (f_top, f_bottom, head_top, px * 1000))

    # Body centres: the front and back views by the middle of the hips, the side view
    # by the middle of the waist.
    def centre_x(m, y):
        segs = rows_segments(m[y])
        a = segs[0][0]
        b = segs[-1][1]
        return (a + b) / 2.0

    s_top, s_bottom, _, _ = extent(side)
    b_top, b_bottom, _, _ = extent(back)
    hip_row = int(f_bottom - 0.9 / px)
    waist_row = int(f_bottom - 1.05 / px)
    fc = centre_x(front, hip_row)
    bc = centre_x(back, int(b_bottom - 0.9 / px))
    sc = centre_x(side, int(s_bottom - 1.05 / px))

    # Voxel grid in metres: x her left (+), y back (+), z up.
    nx, ny, nz = int(1.2 / VOXEL), int(0.7 / VOXEL), int((HEIGHT + 0.12) / VOXEL)
    grid = np.zeros((nx, ny, nz), np.float32)
    xs = (np.arange(nx) + 0.5) * VOXEL - 0.6
    ys = (np.arange(ny) + 0.5) * VOXEL - 0.35

    def to_row(z, bottom):
        return int(round(bottom - z / px))

    neck_z = None
    # Find the shoulder line: where the front silhouette widens from the neck.
    for z in np.arange(1.2, 1.6, 0.005):
        r = to_row(z, f_bottom)
        if widths[r] * px < 0.16 and neck_z is None and z > 1.3:
            neck_z = z
    head_from = neck_z + 0.03 if neck_z else 1.47
    print("neck from %.3f" % (neck_z or -1))

    # The skull's centre sits ~0.1 m behind the brow (the front of the side view at eye level).
    global SKULL_BACK_Y
    eye_row = to_row(EYES + 0.02, s_bottom)
    brow_front = -(rows_segments(side[eye_row])[-1][1] - sc) * px
    SKULL_BACK_Y = brow_front + SKULL["half_y"] - 0.005
    head_widths = head_profile(image, front, fc, px, f_bottom, None, head_from, HEIGHT)
    print("skull centre y %.3f, face half-widths at 1.48/1.52/1.56: %s" % (SKULL_BACK_Y, [round(head_widths[min(head_widths, key=lambda k: abs(k - z))], 3) for z in (1.48, 1.52, 1.56)]))

    # Where the arms meet the torso in the front view (the armpit), and how wide the
    # torso is just below: above the armpit the silhouette is one piece, but the body
    # is still a torso with two arms against it, and the rig moves those apart.
    armpit_z = None
    torso_half = 0.14
    for z in np.arange(1.0, 1.5, VOXEL):
        segs = [((a - fc) * px, (b - fc) * px) for a, b in rows_segments(front[to_row(z, f_bottom)])]
        middle = [s for s in segs if s[0] <= 0.0 <= s[1]]
        if len(segs) >= 3 and middle:
            torso_half = (middle[0][1] - middle[0][0]) / 2.0
        elif len(segs) <= 1 and armpit_z is None:
            armpit_z = z
    print("armpit %.3f, torso half-width under it %.3f" % (armpit_z, torso_half))

    for k in range(nz):
        z = (k + 0.5) * VOXEL
        rf = to_row(z, f_bottom)
        rs = to_row(z, s_bottom)
        rb = to_row(z, b_bottom)
        if rf < 0 or rf >= front.shape[0]:
            continue
        fsegs = [((a - fc) * px, (b - fc) * px) for a, b in rows_segments(front[rf])]
        if not fsegs:
            continue
        # Front and back should agree on the outline: mirror the back view and keep
        # x where both show her (cleans up hair strands seen from one side only).
        if 0 <= rb < back.shape[0]:
            bsegs = [(-(b - bc) * px, -(a - bc) * px) for a, b in rows_segments(back[rb])]
        else:
            bsegs = fsegs
        ssegs = []
        if 0 <= rs < side.shape[0]:
            # Facing the image's right: her front is +x in the picture = -y here.
            ssegs = [(-(b - sc) * px, -(a - sc) * px) for a, b in rows_segments(side[rs])]
        if not ssegs:
            continue
        body = max(ssegs, key=lambda s: s[1] - s[0])
        side_body = body
        if z < head_from - 0.06 and body[1] > upper_back(z):
            # From the shoulder blades up the side view's back edge is the ponytail
            # hanging behind her, not her back: a torso (and arms) as deep as that sat
            # far behind the chest, the shoulders sticking out backwards. The body
            # keeps a back's profile; the rest is the ponytail strand (added below).
            body = (body[0], upper_back(z))
        if armpit_z is not None and armpit_z - 0.01 <= z <= armpit_z + 0.13:
            # Split the one-piece silhouette into torso and arms (overlapping a little).
            split = []
            for xa, xb in fsegs:
                if xa < -torso_half - 0.03 and xb > torso_half + 0.03:
                    split += [(xa, -torso_half + 0.01), (-torso_half - 0.005, torso_half + 0.005), (torso_half - 0.01, xb)]
                else:
                    split.append((xa, xb))
            fsegs = split
        head_depth = None
        if z > head_from - 0.06:
            cut = head_slice(head_widths, z, body, head_from)
            if cut is not None:
                fsegs, (hy0, hy1) = cut
                head_depth = hy1 - hy0
        slab = np.zeros((nx, ny), np.float32)
        for xa, xb in fsegs:
            width = xb - xa
            if width < 0.01:
                continue
            xc = (xa + xb) / 2.0
            a = width / 2.0
            ya, yb = body
            if head_depth is not None:
                # Head: chin-to-nape or face-to-back-of-skull deep; what sticks out further
                # back is the ponytail (added below).
                yb = min(yb, ya + head_depth)
            is_arm = abs(xc) > 0.12 and width < 0.13 and z < 1.45
            if is_arm:
                b = a * 0.95
                yc = (body[0] + body[1]) / 2.0 - 0.01
            else:
                b = (yb - ya) / 2.0
                yc = (ya + yb) / 2.0
            X, Y = np.meshgrid(xs, ys, indexing="ij")
            slab = np.maximum(slab, (((X - xc) / a) ** 2 + ((Y - yc) / max(b, 0.01)) ** 2 <= 1.0).astype(np.float32))
        # The ponytail: side-view bits behind the head and back, round, on the middle line.
        for ya, yb in ssegs:
            if head_depth is not None and (ya, yb) == side_body:
                back_of_head = ya + head_depth
                if yb - back_of_head > 0.02:
                    ya = back_of_head - 0.02
                else:
                    continue
            elif (ya, yb) == side_body:
                if body == side_body:
                    continue
                ya = body[1] - 0.02 # the ponytail behind the trimmed back
            d = yb - ya
            if d < 0.015:
                continue
            r = min(d / 2.0, 0.05 if body == side_body else 0.035)
            yc = (ya + yb) / 2.0
            X, Y = np.meshgrid(xs, ys, indexing="ij")
            slab = np.maximum(slab, ((X / r) ** 2 + ((Y - yc) / (d / 2.0)) ** 2 <= 1.0).astype(np.float32))
        grid[:, :, k] = slab

    grid = ndimage.gaussian_filter(grid, sigma=(1.6, 1.6, 1.2))
    verts, faces, _, _ = measure.marching_cubes(grid, level=0.5, spacing=(VOXEL, VOXEL, VOXEL))
    verts[:, 0] -= 0.6
    verts[:, 1] -= 0.35
    print("hull: %d verts, %d faces" % (len(verts), len(faces)))
    np.savez(os.path.join(OUT, "alice_hull.npz"), verts=verts.astype(np.float32), faces=faces.astype(np.int32))

    # Rig landmarks from the front silhouette.
    def segs_at(z):
        return [((a - fc) * px, (b - fc) * px) for a, b in rows_segments(front[to_row(z, f_bottom)])]

    crotch = None
    for z in np.arange(0.5, 1.0, 0.005):
        legs = [s for s in segs_at(z) if abs((s[0] + s[1]) / 2) < 0.15]
        if len(legs) == 1 and crotch is None:
            crotch = z
    armpit = None
    for z in np.arange(1.0, 1.5, 0.005):
        if len(segs_at(z)) <= 1 and armpit is None:
            armpit = z
    shoulder_top = None
    for z in np.arange(armpit, armpit + 0.25, 0.005):
        segs = segs_at(z)
        width = segs[-1][1] - segs[0][0]
        if width < 0.2:
            shoulder_top = z
            break
    # Arm centre just under the armpit, and the hand: the lowest arm rows.
    arm_x = np.mean([abs((s[0] + s[1]) / 2) for s in segs_at(armpit - 0.06) if abs((s[0] + s[1]) / 2) > 0.14])
    hand_low = None
    for z in np.arange(0.4, 1.0, 0.005):
        arms = [s for s in segs_at(z) if abs((s[0] + s[1]) / 2) > 0.2]
        if arms and hand_low is None:
            hand_low = z
    hand_z = hand_low + 0.07
    hand_x = np.mean([abs((s[0] + s[1]) / 2) for s in segs_at(hand_z) if abs((s[0] + s[1]) / 2) > 0.2])
    rig = {
        "crotch": round(crotch, 3), "hip_height": round(crotch + 0.06, 3), "knee_height": round((crotch + 0.06 + 0.06) / 2, 3),
        "armpit": round(armpit, 3), "shoulder_top": round(shoulder_top, 3),
        "shoulder_height": round(shoulder_top - 0.045, 3), "shoulder_x": round(float(arm_x) - 0.01, 3),
        "hand": [round(float(hand_x), 3), 0.0, round(hand_z, 3)], "neck": round(neck_z or 1.45, 3),
        "head_top": HEIGHT,
    }
    print("rig:", rig)
    with open(os.path.join(OUT, "alice_rig.json"), "w") as f:
        json.dump(rig, f, indent=1)

    # Texture: the sheet with the white round each figure filled from its edges.
    fill = image.copy()
    # Start a little inside the outline: the edge pixels are blended with the white.
    known = ndimage.binary_erosion(figure, iterations=3)
    for _ in range(40):
        grown = ndimage.binary_dilation(known, iterations=1)
        ring = grown & ~known
        if not ring.any():
            break
        acc = np.zeros(fill.shape, np.float32)
        cnt = np.zeros(fill.shape[:2], np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                shifted_known = np.roll(np.roll(known, dy, 0), dx, 1)
                shifted = np.roll(np.roll(fill, dy, 0), dx, 1).astype(np.float32)
                acc += shifted * shifted_known[..., None]
                cnt += shifted_known
        avg = acc / np.maximum(cnt, 1)[..., None]
        fill[ring] = avg[ring].astype(np.uint8)
        known = grown
    cv2.imwrite(os.path.join(OUT, "alice_texture.png"), fill)
    check = image.copy()
    check[front] = (check[front] * 0.5 + np.array([0, 0, 255]) * 0.5).astype(np.uint8)
    check[side] = (check[side] * 0.5 + np.array([0, 255, 0]) * 0.5).astype(np.uint8)
    check[back] = (check[back] * 0.5 + np.array([255, 0, 0]) * 0.5).astype(np.uint8)
    for z in [rig["hip_height"], rig["knee_height"], rig["shoulder_height"], rig["neck"], hand_z]:
        cv2.line(check, (0, to_row(z, f_bottom)), (check.shape[1], to_row(z, f_bottom)), (0, 0, 0), 1)
    cv2.imwrite(os.path.join(OUT, "alice_masks.png"), check)
    # How the views map to metres, for the texture projection in Blender.
    with open(os.path.join(OUT, "alice_views.json"), "w") as f:
        json.dump({
            "size": [image.shape[1], image.shape[0]], "metres_per_px": px,
            "front": {"centre": fc, "feet": int(f_bottom)},
            "side": {"centre": sc, "feet": int(s_bottom)},
            "back": {"centre": bc, "feet": int(b_bottom)},
        }, f, indent=1)
    print("DONE")


main()
