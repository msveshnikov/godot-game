"""Build metric district data from OpenStreetMap's 0.6/map.json response.

Usage: python tools/europe/osm_to_json.py paris raw.json assets/europe/paris.json
Requires Shapely 2.1. The input bounding boxes and visual references are in Readme.md.
"""

import argparse
import json
import math
import re
from pathlib import Path

from shapely import constrained_delaunay_triangles, make_valid, union_all
from shapely.geometry import LineString, Point, Polygon
from shapely.geometry.polygon import orient
from shapely.ops import linemerge, nearest_points, polygonize
from shapely.strtree import STRtree


DISTRICTS = {
    "paris": {
        "origin": (48.87168, 2.34205),
        "focus": {"Boulevard Montmartre", "Boulevard Poissonnière", "Boulevard Haussmann",
                  "Rue Vivienne", "Rue du Faubourg Montmartre", "Rue Saint-Marc"},
        "traffic": {"Boulevard Montmartre", "Boulevard Poissonnière", "Rue Vivienne",
                    "Rue du Faubourg Montmartre", "Rue Montmartre", "Boulevard Haussmann"},
        "passages": {"Passage des Panoramas", "Passage Jouffroy", "Galerie des Variétés",
                     "Galerie Saint-Marc", "Galerie Montmartre", "Galerie Feydeau"},
        # Door locations and the view point outside each facade.
        "fronts": [
            ("grevin", (48.871756, 2.342119), (48.8716677, 2.3420928)),
            ("varietes", (48.87153, 2.342165), (48.8716677, 2.3420928)),
            ("panoramas", (48.871531, 2.341823), (48.871594, 2.341831)),
            ("jouffroy", (48.871741, 2.341874), (48.871671, 2.34185)),
            ("chartier", (48.871941, 2.342943), (48.871949, 2.34283)),
        ],
        "spawns": [(48.871769, 2.341890), (48.871581, 2.342246), (48.8715, 2.34263),
                   (48.871762, 2.342430), (48.871921, 2.341013), (48.871703, 2.341352),
                   (48.871443, 2.343410), (48.870366, 2.341728)],
    },
    "dublin": {
        "origin": (53.34171, -6.26013),
        "focus": {"Grafton Street", "Anne Street South", "Harry Street", "Duke Street",
                  "Wicklow Street", "Lemon Street", "Chatham Street", "South William Street",
                  "Suffolk Street", "King Street South", "St. Stephen's Green"},
        "traffic": {"Dawson Street", "Suffolk Street", "Wicklow Street", "South William Street",
                    "St. Stephen's Green", "Nassau Street", "Clarendon Street"},
        "passages": set(),
        "fronts": [
            ("bewleys", (53.341721, -6.260244), (53.3417277, -6.2600971)),
            ("brown_thomas", (53.342373, -6.259888), (53.34237, -6.259723)),
            ("gaiety", (53.340291, -6.261690), (53.340218, -6.261690)),
            ("bruxelles", (53.341255, -6.260882), (53.341291, -6.260827)),
            ("stephens_centre", (53.340027, -6.260914), (53.340016, -6.2607)),
        ],
        "spawns": [(53.34175, -6.26009), (53.3414, -6.26024), (53.3423, -6.25976),
                   (53.34104, -6.26049), (53.34027, -6.26078), (53.34288, -6.2595),
                   (53.34111, -6.25990), (53.34131, -6.26072)],
    },
}
RADIUS = 239.0  # The playable edge is 250 m, with a promenade outside the city blocks.
CITY = Point(0, 0).buffer(RADIUS, quad_segs=32)
WIDTHS = {
    "primary": 13, "secondary": 9, "tertiary": 7, "unclassified": 6.1,
    "residential": 5.4, "living_street": 5, "service": 3.5, "pedestrian": 6.5,
    "footway": 2.2, "steps": 2.3, "cycleway": 1.8, "path": 2.2,
}
PAVING = {"pedestrian", "footway", "steps", "path"}


def components(geometry, kind):
    if geometry.is_empty:
        return
    if geometry.geom_type == kind:
        yield geometry
    elif hasattr(geometry, "geoms"):
        for part in geometry.geoms:
            yield from components(part, kind)


def coordinates(points):
    return [[round(x, 2), round(z, 2)] for x, z in points]


def ring(line):
    return coordinates(line.coords[:-1])


def caps(polygon):
    if not polygon.interiors:
        return [ring(polygon.exterior)]
    return [ring(part.exterior) for part in constrained_delaunay_triangles(polygon).geoms]


def number(value, fallback):
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)\s*m?", value or "")
    return float(match[1]) if match else fallback


def polygon_from_closed(points):
    if len(points) >= 4 and points[0] == points[-1]:
        return make_valid(Polygon(points))
    return Polygon()


def tag_width(tags):
    highway = tags["highway"]
    width = WIDTHS[highway]
    name = tags.get("name", "")
    if name == "Grafton Street" and highway == "pedestrian":
        width = 9.0
    elif highway == "primary" and tags.get("oneway") == "yes":
        width = max(4.0, number(tags.get("lanes"), 2) * 3.0)
    elif highway == "pedestrian" and name in {"Lemon Street", "Duke Lane Lower", "Anne's Lane"}:
        width = 3.7
    return min(30.0, number(tags.get("width"), width))


class District:
    def __init__(self, name, elements):
        self.name = name
        self.spec = DISTRICTS[name]
        self.lat, self.lon = self.spec["origin"]
        radians = math.radians(self.lat)
        w = (1.0 - 0.00669437999 * math.sin(radians) ** 2) ** 0.5
        self.east = math.pi / 180 * 6378137.0 / w * math.cos(radians)
        self.north = math.pi / 180 * 6335439.327 / w**3
        self.nodes = {item["id"]: self.project(item["lat"], item["lon"])
                      for item in elements if item["type"] == "node"}
        self.node_items = [item for item in elements if item["type"] == "node"]
        self.ways = {item["id"]: item for item in elements if item["type"] == "way"
                     and all(node in self.nodes for node in item["nodes"])}
        self.relations = [item for item in elements if item["type"] == "relation"]

    def project(self, lat, lon):
        return (lon - self.lon) * self.east, (self.lat - lat) * self.north

    def points(self, way):
        return [self.nodes[node] for node in way["nodes"]]

    def streets(self):
        streets, areas, rail = [], {"road": [], "paving": [], "park": [], "cycle": []}, []
        for way in self.ways.values():
            tags = way.get("tags", {})
            points = self.points(way)
            if len(points) < 2:
                continue
            highway = tags.get("highway")
            if tags.get("leisure") in {"park", "garden"} or tags.get("landuse") in {"grass", "village_green"}:
                areas["park"].append(polygon_from_closed(points))
            if tags.get("railway") == "tram" and tags.get("tunnel") != "yes":
                rail.extend(components(LineString(points).intersection(CITY), "LineString"))
            if highway not in WIDTHS or tags.get("tunnel") == "yes" or tags.get("indoor") == "yes":
                continue
            kind = "paving" if highway in PAVING else ("cycle" if highway == "cycleway" else "road")
            if tags.get("area") == "yes":
                areas[kind].append(polygon_from_closed(points))
                continue
            width = tag_width(tags)
            name = tags.get("name", "")
            covered = tags.get("covered") == "yes" and name in self.spec["passages"]
            if tags.get("covered") == "yes" and not covered:
                continue
            for line in components(LineString(points).intersection(CITY), "LineString"):
                if line.length < 0.5:
                    continue
                streets.append((line, width, name, kind, tags, covered))
                areas[kind].append(line.buffer(width / 2, quad_segs=3))
        return streets, areas, rail

    def footprints(self):
        members = set()
        for relation in self.relations:
            tags = relation.get("tags", {})
            if tags.get("type") != "multipolygon" or "building" not in tags:
                continue
            rings = {"outer": [], "inner": []}
            for member in relation["members"]:
                if member["type"] == "way" and member["ref"] in self.ways and member["role"] in rings:
                    points = self.points(self.ways[member["ref"]])
                    if len(points) >= 2:
                        rings[member["role"]].append(LineString(points))
            outer = union_all(list(polygonize(rings["outer"])))
            inner = union_all(list(polygonize(rings["inner"])))
            if not outer.is_empty:
                members.update(member["ref"] for member in relation["members"] if member["type"] == "way")
                yield -relation["id"], outer.difference(inner), tags
        for key, way in self.ways.items():
            tags = way.get("tags", {})
            if key not in members and tags.get("building") not in {None, "no", "roof"}:
                yield key, polygon_from_closed(self.points(way)), tags

    def buildings(self, passages, frontage):
        buildings, walls, solids = [], [], []
        for key, geometry, tags in self.footprints():
            for piece in components(geometry.intersection(CITY).simplify(0.13), "Polygon"):
                if piece.area < 5.0:
                    continue
                piece = orient(piece)
                base = piece.difference(passages)
                levels = number(tags.get("building:levels"), 0)
                h = number(tags.get("height") or tags.get("building:height"), 0)
                seed = (key * 7919 % 1009) / 1009
                if not h:
                    default = 5 + (seed > 0.62) if self.name == "paris" else 3 + (seed > 0.35) + (seed > 0.82)
                    if piece.area < 35 or tags["building"] in {"shed", "garage", "hut", "kiosk"}:
                        default = 1
                    h = (levels or default) * (3.18 if self.name == "paris" else 3.30) + 0.6
                h = min(75, max(3.1, h))
                front = piece.distance(frontage) < 12 and h > 6.0
                material = tags.get("building:material", "")
                style = "stone" if self.name == "paris" or seed > 0.63 else "brick"
                if material in {"brick", "stone", "glass"}:
                    style = material
                roof = tags.get("roof:shape", "mansard" if self.name == "paris" else "gabled")
                building = {"id": key, "p": ring(piece.exterior), "h": round(h, 1),
                            "s": style, "roof": roof, "shops": front}
                if piece.interiors:
                    building["holes"] = [ring(hole) for hole in piece.interiors]
                    building["caps"] = caps(piece)
                if piece.area - base.area > 0.4 and h > 6.0:
                    building["base"] = [[ring(poly.exterior), *[ring(hole) for hole in poly.interiors]]
                                        for poly in components(base, "Polygon") if poly.area > 0.8]
                solids.append(base if "base" in building else piece)
                buildings.append(building)
                for a, b in zip(piece.exterior.coords, list(piece.exterior.coords)[1:]):
                    if math.dist(a, b) > 0.6:
                        walls.append(LineString([a, b]))
        return buildings, walls, union_all(solids)

    def fronts(self, walls):
        output = {}
        index = STRtree(walls)
        for key, at, view in self.spec["fronts"]:
            anchor, exterior = Point(self.project(*at)), Point(self.project(*view))
            candidates = []
            for idx in index.query(anchor, predicate="dwithin", distance=13.0):
                wall = walls[idx]
                a, b = wall.coords
                pos, _ = nearest_points(wall, anchor)
                vx, vz = exterior.x - pos.x, exterior.y - pos.y
                outward = ((b[1] - a[1]) * vx - (b[0] - a[0]) * vz) / wall.length
                if outward > 1.0:
                    candidates.append((wall.distance(anchor) + max(0, 4.5 - wall.length) * 1.7, wall, pos))
            if candidates:
                _, wall, pos = min(candidates, key=lambda item: item[0])
                output[key] = coordinates([*wall.coords, pos.coords[0]])
        return output

    def graph(self, streets, solids):
        lines = [line for line, _, _, kind, tags, covered in streets
                 if kind != "cycle" and (tags["highway"] != "service" or tags.get("access", "") != "private")
                 and (not covered or line.length >= 1)]
        clear = union_all(lines).difference(solids.buffer(0.6))
        nodes, edges, neighbours = {}, set(), {}
        for line in components(clear, "LineString"):
            length = line.length
            if length < 0.3:
                continue
            count = math.ceil(length / 11)
            # Retain the original vertices so an edge never cuts through a building on a bend.
            distances = {length * step / count for step in range(count + 1)}
            distances.update(line.project(Point(point)) for point in line.coords)
            vertices = [tuple(coordinates([line.interpolate(distance).coords[0]])[0])
                        for distance in sorted(distances)]
            for a, b in zip(vertices, vertices[1:]):
                if a == b:
                    continue
                for point in (a, b):
                    nodes.setdefault(point, len(nodes))
                i, j = nodes[a], nodes[b]
                edges.add((min(i, j), max(i, j)))
                neighbours.setdefault(i, set()).add(j)
                neighbours.setdefault(j, set()).add(i)
        # Remove disconnected paths in private yards and isolated building entrances.
        groups, unseen = [], set(neighbours)
        while unseen:
            group = {unseen.pop()}
            stack = list(group)
            while stack:
                linked = neighbours[stack.pop()] & unseen
                unseen -= linked
                group |= linked
                stack.extend(linked)
            groups.append(group)
        keep = max(groups, key=len)
        remap = {index: new for new, index in enumerate(sorted(keep))}
        return {"nodes": [p for p, i in nodes.items() if i in keep],
                "edges": [[remap[i], remap[j]] for i, j in sorted(edges) if i in keep and j in keep]}

    def props(self, solids, streets):
        props = {"trees": [], "lamps": [], "crossings": [], "metro": [], "statues": []}
        for item in self.node_items:
            point = self.nodes[item["id"]]
            at = Point(point)
            if not CITY.contains(at) or solids.distance(at) < 0.25:
                continue
            tags = item.get("tags", {})
            xy = coordinates([point])[0]
            if tags.get("natural") == "tree":
                props["trees"].append(xy)
            if tags.get("highway") == "street_lamp":
                props["lamps"].append(xy)
            if tags.get("railway") == "subway_entrance" and tags.get("entrance") != "exit":
                props["metro"].append(xy)
            if tags.get("tourism") == "artwork" and tags.get("name", "").startswith(("Phil Lynott", "Molly Malone")):
                props["statues"].append([xy, tags["name"].split(";")[0]])
            if tags.get("highway") == "crossing":
                roads = [(line, width) for line, width, _, kind, _, _ in streets if kind == "road"
                         and line.distance(at) < 2.0 and width >= 5.5]
                if roads:
                    line, width = max(roads, key=lambda item: item[1])
                    s = line.project(at)
                    a = line.interpolate(max(0, s - 2)).coords[0]
                    b = line.interpolate(min(line.length, s + 2)).coords[0]
                    props["crossings"].append([xy, round(math.atan2(b[1] - a[1], b[0] - a[0]), 3), width])
        return props

    def make(self):
        streets, areas, rail = self.streets()
        focus = [(line, width, name) for line, width, name, _, _, _ in streets if name in self.spec["focus"]]
        frontage = union_all([line for line, _, _ in focus])
        passages = union_all([line.buffer(1.48, cap_style="square", join_style="mitre")
                              for line, _, name, _, _, _ in streets if name in self.spec["passages"]])
        buildings, walls, solids = self.buildings(passages, frontage)
        ground = {}
        for kind, shapes in areas.items():
            surface = union_all(shapes).intersection(CITY).simplify(0.11)
            ground[kind] = [p for part in components(surface, "Polygon") for p in caps(part)]
            if kind == "road":
                ground["kerbs"] = [ring(part.exterior) for part in components(surface, "Polygon")]
        spawns = []
        for lat, lon in self.spec["spawns"]:
            point = Point(self.project(lat, lon))
            if solids.distance(point) < 2.6:
                point, _ = nearest_points(solids.buffer(2.7).boundary, point)
            spawns.extend(coordinates([point.coords[0]]))
        lanes = []
        for name in sorted(self.spec["traffic"]):
            directions = {False: [], True: []}
            for line, width, street, kind, tags, _ in streets:
                if street != name or kind != "road":
                    continue
                oneway = tags.get("oneway")
                if oneway == "-1":
                    line = line.reverse()
                directions[oneway in {"yes", "-1"}].append((line, width))
            for one_way, roads in directions.items():
                if not roads:
                    continue
                joined = linemerge([line for line, _ in roads], directed=one_way)
                for line in components(joined, "LineString"):
                    if line.length >= 45:
                        offset = 0.0 if one_way else min(3.0, max(w for _, w in roads) / 4)
                        lanes.append([coordinates(line.simplify(0.25).coords), round(offset, 2), name])
        return {
            "origin": [self.lat, self.lon], "buildings": buildings, "ground": ground,
            "fronts": self.fronts(walls),
            "focus": [[coordinates(line.coords), width, name] for line, width, name in focus if line.length > 3],
            "passages": [coordinates(line.simplify(0.15).coords)
                         for line, _, _, _, _, covered in streets if covered and line.length > 0.5],
            "rail": [coordinates(line.simplify(0.1).coords) for line in rail if line.length > 1],
            "graph": self.graph(streets, solids), "spawns": spawns, "lanes": lanes,
            "props": self.props(solids, streets),
        }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("city", choices=DISTRICTS)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    data = District(args.city, json.loads(args.input.read_text(encoding="utf-8"))["elements"]).make()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{args.city}: {len(data['buildings'])} buildings, {len(data['graph']['nodes'])} route nodes, "
          f"{len(data['fronts'])} landmark fronts, {len(data['lanes'])} traffic routes")


if __name__ == "__main__":
    main()
