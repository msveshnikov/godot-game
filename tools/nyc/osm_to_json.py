"""Turn an Overpass dump around Times Square into assets/nyc/times_square.json.

Frame: u = metres "Manhattan east" (across the avenues), n = metres "Manhattan
south" (down the avenues), origin where 7th Avenue crosses West 45th Street.
The street grid is turned 29.1 degrees so the avenues run along n.

Keeps every building and building:part between 8th and 6th Avenue and 41st and
48th Street (the island); a building outline is dropped when parts describe it.
Data (c) OpenStreetMap contributors, ODbL.

Fetch the dump with tools/nyc/overpass_query.txt:
  curl --data-urlencode "data@tools/nyc/overpass_query.txt" https://overpass-api.de/api/interpreter -o raw.json
Then: python -I tools/nyc/osm_to_json.py raw.json assets/nyc/times_square.json
"""
import json
import math
import sys

LAT0, LON0 = 40.7580, -73.9855
TH = math.radians(29.107)
KX = math.cos(math.radians(LAT0)) * 111320.0
KY = 110574.0
# Centre lines of the boundary streets (the waterfront) in the u/n frame.
U_MIN, U_MAX = -275.1, 271.8   # 8th Avenue, 6th Avenue
N_MIN, N_MAX = -231.5, 333.0   # West 48th Street, West 41st Street


def proj(lat, lon):
    x = (lon - LON0) * KX
    y = (lat - LAT0) * KY
    north = x * math.sin(TH) + y * math.cos(TH)
    east = x * math.cos(TH) - y * math.sin(TH)
    return (east, -north)


def area(p):
    return 0.5 * sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p)))


def centroid(p):
    a = area(p)
    if abs(a) < 1e-6:
        return (sum(q[0] for q in p) / len(p), sum(q[1] for q in p) / len(p))
    cx = cy = 0.0
    for i in range(len(p)):
        x0, y0 = p[i]
        x1, y1 = p[(i + 1) % len(p)]
        f = x0 * y1 - x1 * y0
        cx += (x0 + x1) * f
        cy += (y0 + y1) * f
    return (cx / (6 * a), cy / (6 * a))


def inside(pt, poly):
    x, y = pt
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            hit = not hit
        j = i
    return hit


def num(v):
    if v is None:
        return None
    try:
        return float(str(v).lower().replace('m', '').replace(',', '.').split(';')[0].strip())
    except ValueError:
        return None


def simplify(p):
    """Drop duplicate and nearly collinear points (same shape, fewer walls)."""
    out = []
    for q in p:
        if not out or math.dist(out[-1], q) > 0.25:
            out.append(q)
    if len(out) > 1 and math.dist(out[0], out[-1]) < 0.25:
        out.pop()
    changed = True
    while changed and len(out) > 3:
        changed = False
        for i in range(len(out)):
            a, b, c = out[i - 1], out[i], out[(i + 1) % len(out)]
            cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])
            if math.dist(a, c) > 0 and abs(cross) < 0.05 * max(math.dist(a, c), 0.01):
                out.pop(i)
                changed = True
                break
    return out


def main():
    data = json.load(open(sys.argv[1], encoding='utf-8'))
    nodes, ways, rels = {}, {}, []
    for e in data['elements']:
        if e['type'] == 'node':
            nodes[e['id']] = e
        elif e['type'] == 'way':
            ways[e['id']] = e
        else:
            rels.append(e)

    def ring(node_ids):
        return [proj(nodes[i]['lat'], nodes[i]['lon']) for i in node_ids if i in nodes]

    def join_outer(member_ways):
        segs = [list(w['nodes']) for w in member_ways]
        rings = []
        while segs:
            cur = segs.pop(0)
            grown = True
            while cur[0] != cur[-1] and grown:
                grown = False
                for s in segs:
                    if s[0] == cur[-1]:
                        cur += s[1:]
                    elif s[-1] == cur[-1]:
                        cur += s[::-1][1:]
                    elif s[-1] == cur[0]:
                        cur = s[:-1] + cur
                    elif s[0] == cur[0]:
                        cur = s[::-1][:-1] + cur
                    else:
                        continue
                    segs.remove(s)
                    grown = True
                    break
            rings.append(cur)
        return rings

    shapes = []  # (tags, polygon, is_part, id)
    for w in ways.values():
        t = w.get('tags', {})
        if ('building' in t or 'building:part' in t) and w['nodes'][0] == w['nodes'][-1]:
            shapes.append((t, ring(w['nodes']), 'building:part' in t and 'building' not in t, w['id']))
    for r in rels:
        t = r.get('tags', {})
        if 'building' not in t and 'building:part' not in t:
            continue
        outers = [ways[m['ref']] for m in r['members'] if m['type'] == 'way' and m.get('role') == 'outer' and m['ref'] in ways]
        for node_ids in join_outer(outers):
            if node_ids[0] == node_ids[-1]:
                shapes.append((t, ring(node_ids), 'building:part' in t and 'building' not in t, r['id']))

    def on_island(c):
        return U_MIN + 3 < c[0] < U_MAX - 3 and N_MIN + 3 < c[1] < N_MAX - 3

    parts = [s for s in shapes if s[2]]
    buildings = []
    outlines = []
    for t, poly, is_part, oid in shapes:
        poly = simplify(poly)
        if len(poly) < 3 or abs(area(poly)) < 2.0:
            continue
        c = centroid(poly)
        if not on_island(c):
            continue
        if not is_part and any(len(p[1]) > 2 and inside(centroid(p[1]), poly) for p in parts):
            # Drawn by its parts; keep the name and height for signs and labels.
            outlines.append({'id': oid, 'name': t.get('name', ''), 'c': [round(c[0], 2), round(c[1], 2)],
                             'p': [[round(x, 2), round(y, 2)] for x, y in poly]})
            continue
        h = num(t.get('height'))
        levels = num(t.get('building:levels'))
        if h is None:
            h = levels * 3.4 + 1.0 if levels else 18.0
        mh = num(t.get('min_height')) or 0.0
        if mh <= 0.0 and t.get('building:min_level'):
            mh = (num(t.get('building:min_level')) or 0.0) * 3.4
        if area(poly) < 0:
            poly = poly[::-1]
        buildings.append({
            'id': oid, 'name': t.get('name', ''), 'kind': t.get('building') or t.get('building:part') or 'yes',
            'h': round(h, 2), 'mh': round(mh, 2), 'roof': t.get('roof:shape', ''),
            'colour': t.get('building:colour', ''), 'material': t.get('building:material', ''),
            'p': [[round(x, 2), round(y, 2)] for x, y in poly],
        })

    points = []
    for n in nodes.values():
        t = n.get('tags', {})
        if not t:
            continue
        u, v = proj(n['lat'], n['lon'])
        if not (U_MIN - 20 < u < U_MAX + 20 and N_MIN - 15 < v < N_MAX + 15):
            continue
        kind = t.get('natural') or t.get('railway') or t.get('amenity') or t.get('tourism') or t.get('historic') or t.get('highway')
        if kind in ('tree', 'subway_entrance', 'bench', 'waste_basket', 'post_box', 'bicycle_rental', 'bicycle_parking',
                    'artwork', 'memorial', 'information', 'drinking_water', 'clock', 'street_lamp', 'traffic_signals'):
            points.append({'kind': kind, 'name': t.get('name', ''), 'at': [round(u, 2), round(v, 2)]})

    lines = []
    for w in ways.values():
        t = w.get('tags', {})
        if 'highway' not in t:
            continue
        pts = ring(w['nodes'])
        if not any(U_MIN - 40 < p[0] < U_MAX + 40 and N_MIN - 40 < p[1] < N_MAX + 40 for p in pts):
            continue
        lines.append({'hw': t['highway'], 'name': t.get('name', ''), 'footway': t.get('footway', ''),
                      'area': t.get('area', ''), 'oneway': t.get('oneway', ''),
                      'p': [[round(x, 2), round(y, 2)] for x, y in pts]})

    out = {
        'source': 'OpenStreetMap contributors (ODbL), Overpass dump ' + data['osm3s']['timestamp_osm_base'],
        'frame': 'u = metres east across the avenues, n = metres south along them; origin 7th Ave x W 45th St; grid turned 29.107 deg',
        'buildings': buildings,
        'outlines': outlines,
        'points': points,
        'lines': lines,
    }
    with open(sys.argv[2], 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    print(len(buildings), 'buildings', len(outlines), 'outlines', len(points), 'points', len(lines), 'lines')


if __name__ == '__main__':
    main()
