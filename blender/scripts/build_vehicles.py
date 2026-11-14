"""Parked cars for the estate, modelled after what stands round Na Skalkách on Street View:
Škoda Octavia Combi and liftback, Škoda Fabia, a compact SUV (Tucson / Sportage size) and a
compact MPV (Scénic size). No badges.

Run:  blender -b --factory-startup -P blender/scripts/build_vehicles.py -- [--no-render] [--only a,b]

Writes assets/vehicles/<name>.glb (one joined mesh per car, materials named Paint / Glass /
Trim / Tire / Rim / Chrome / HeadLight / TailLight / Plate / PlateBlue; the game recolours
Paint per car), blender/vehicles.blend and blender/renders/vehicles/<name>.png previews.

Conventions: 1 unit = 1 m, Z up, front of the car towards Blender -Y (= Godot +Z), pivot at
the centre of the footprint on the ground.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "vehicles")
RENDER_DIR = os.path.join(ROOT, "blender", "renders", "vehicles")

# Side profiles: x = metres back from the front bumper, z = height.
#   top:  bumper / bonnet / beltline / boot line (the lower body's upper edge)
#   roof: greenhouse from the windscreen base to the tailgate / rear window base
#   pillars: side-window spans that are body (B pillar black, others painted)
MODELS = {
    "car_octavia_combi": dict(
        L=4.69, W=1.81, wb=2.69, fo=0.93, R=0.32, clear=0.15, rails=True,
        top=[(0, 0.58), (0.08, 0.76), (0.25, 0.86), (0.6, 0.92), (1.45, 0.99), (3.0, 1.02), (4.45, 1.04), (4.62, 1.0), (4.69, 0.95)],
        roof=[(1.45, 0.99), (2.25, 1.43), (2.6, 1.47), (3.8, 1.46), (4.45, 1.41), (4.6, 1.3), (4.67, 1.04)],
        b_pillar=(2.52, 2.62), pillars=[(3.55, 3.7), (4.42, 4.7)], rear_glass=(4.47, 4.665),
        paint=(0.93, 0.93, 0.92)),
    "car_octavia": dict(
        L=4.69, W=1.81, wb=2.69, fo=0.93, R=0.32, clear=0.15, rails=False,
        top=[(0, 0.58), (0.08, 0.76), (0.25, 0.86), (0.6, 0.92), (1.45, 0.99), (3.0, 1.02), (4.3, 1.05), (4.6, 1.03), (4.69, 0.92)],
        roof=[(1.45, 0.99), (2.25, 1.42), (2.6, 1.46), (3.35, 1.44), (3.9, 1.27), (4.3, 1.1), (4.45, 1.05)],
        b_pillar=(2.52, 2.62), pillars=[(3.55, 4.7)], rear_glass=(3.42, 4.22),
        paint=(0.55, 0.57, 0.6)),
    "car_fabia": dict(
        L=4.0, W=1.73, wb=2.47, fo=0.8, R=0.3, clear=0.14, rails=False,
        top=[(0, 0.56), (0.08, 0.74), (0.25, 0.84), (0.55, 0.9), (1.3, 0.98), (2.6, 1.0), (3.85, 1.0), (3.95, 0.96), (4.0, 0.9)],
        roof=[(1.3, 0.98), (2.05, 1.43), (2.4, 1.47), (3.4, 1.45), (3.8, 1.36), (3.93, 1.15), (3.98, 1.0)],
        b_pillar=(2.28, 2.38), pillars=[(3.3, 4.0)], rear_glass=(3.82, 3.965),
        paint=(0.72, 0.08, 0.08)),
    "car_suv": dict(
        L=4.48, W=1.86, wb=2.68, fo=0.9, R=0.36, clear=0.19, rails=True,
        top=[(0, 0.7), (0.08, 0.88), (0.25, 0.98), (0.6, 1.04), (1.4, 1.1), (3.0, 1.14), (4.3, 1.16), (4.42, 1.1), (4.48, 1.02)],
        roof=[(1.4, 1.1), (2.15, 1.6), (2.5, 1.65), (3.7, 1.63), (4.3, 1.56), (4.42, 1.4), (4.46, 1.16)],
        b_pillar=(2.55, 2.65), pillars=[(3.55, 3.66), (4.28, 4.5)], rear_glass=(4.33, 4.455),
        paint=(0.22, 0.23, 0.25)),
    "car_mpv": dict(
        L=4.4, W=1.81, wb=2.7, fo=0.85, R=0.32, clear=0.15, rails=False,
        top=[(0, 0.6), (0.1, 0.8), (0.3, 0.9), (0.75, 0.98), (1.1, 1.0), (3.0, 1.02), (4.25, 1.04), (4.36, 0.98), (4.4, 0.92)],
        roof=[(1.05, 1.0), (2.0, 1.58), (2.4, 1.62), (3.7, 1.6), (4.25, 1.52), (4.36, 1.3), (4.39, 1.04)],
        b_pillar=(2.45, 2.55), pillars=[(3.5, 3.6), (4.22, 4.4)], rear_glass=(4.28, 4.385),
        paint=(0.15, 0.27, 0.55)),
}

MATERIALS = {
    # name: (base colour, metallic, roughness, emission strength)
    "Paint": ((0.8, 0.8, 0.8), 0.4, 0.3, 0.0),
    "Glass": ((0.05, 0.07, 0.09), 0.2, 0.05, 0.0),
    "Trim": ((0.03, 0.03, 0.035), 0.0, 0.6, 0.0),
    "Tire": ((0.02, 0.02, 0.02), 0.0, 0.85, 0.0),
    "Rim": ((0.62, 0.63, 0.65), 0.9, 0.3, 0.0),
    "Chrome": ((0.8, 0.8, 0.82), 1.0, 0.15, 0.0),
    "HeadLight": ((0.85, 0.87, 0.9), 0.3, 0.1, 0.4),
    "TailLight": ((0.6, 0.02, 0.02), 0.0, 0.2, 0.3),
    "Plate": ((0.95, 0.95, 0.93), 0.0, 0.5, 0.0),
    "PlateBlue": ((0.02, 0.15, 0.6), 0.0, 0.5, 0.0),
}


# ------------------------------------------------------------------ utils ----

def interp(points, x):
    if x <= points[0][0]:
        return points[0][1]
    for (x0, z0), (x1, z1) in zip(points, points[1:]):
        if x <= x1:
            t = (x - x0) / max(x1 - x0, 1e-6)
            return z0 + (z1 - z0) * t
    return points[-1][1]


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def material(name):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    color, metallic, roughness, emission = MATERIALS[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0:
        for key in ("Emission Color", "Emission"):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = (*color, 1.0)
                break
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def new_object(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def add_box(parts, mat, size, location, rotation=(0, 0, 0)):
    mesh = bpy.data.meshes.new("box")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object("part", mesh)
    obj.location = location
    obj.rotation_euler = rotation
    obj.data.materials.append(material(mat))
    parts.append(obj)
    return obj


def add_cylinder(parts, mat, radius, depth, location, segments=24, axis="X", bevel=0.0):
    mesh = bpy.data.meshes.new("cyl")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth)
    bm.to_mesh(mesh)
    bm.free()
    obj = new_object("part", mesh)
    obj.location = location
    if axis == "X":
        obj.rotation_euler = (0, math.pi / 2, 0)
    obj.data.materials.append(material(mat))
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    parts.append(obj)
    return obj


# ------------------------------------------------------------------- body ----

def section(m, x):
    """Half cross-section (X >= 0) at x metres back from the front, bottom centre to roof centre."""
    L, W, R = m["L"], m["W"], m["R"]
    top = interp(m["top"], x)
    roof = max(top, interp(m["roof"], x)) if m["roof"][0][0] <= x <= m["roof"][-1][0] else top
    # Plan-view taper rounds the corners.
    wf = 0.86 + 0.14 * smoothstep(0.0, 0.35, x) - 0.07 * smoothstep(L - 0.3, L, x)
    w = W * wf
    # Bottom with clearance, raised overhangs and wheel arches.
    bottom = m["clear"] + 0.12 * (1 - smoothstep(0.0, 0.25, x)) + 0.14 * smoothstep(L - 0.2, L, x)
    for axle in (m["fo"], m["fo"] + m["wb"]):
        arch = R + 0.06
        d = x - axle
        if abs(d) < arch:
            bottom = max(bottom, R + math.sqrt(arch * arch - d * d))
    bottom = min(bottom, top - 0.15)
    hc = roof - top
    k = smoothstep(0.02, 0.12, hc)
    mid = (bottom + top) * 0.5 + 0.08
    return [
        (0.0, bottom),
        (w * 0.44, bottom),
        (w * 0.5, min(bottom + 0.12, mid - 0.02)),
        (w * 0.5, mid),
        (w * 0.485, top),
        (w * (0.47 - 0.03 * k), top + 0.012 + 0.02 * k),
        (w * (0.42 - 0.07 * k), top + 0.025 + (hc - 0.07) * k),
        (w * (0.3 - 0.06 * k), top + 0.035 + (hc - 0.02) * k),
        (0.0, top + 0.04 + hc * k),
    ]


def build_body(m, parts):
    L = m["L"]
    stations = [0.0, 0.03]
    x = 0.06
    while x < L - 0.06:
        stations.append(x)
        x += 0.07
    stations += [L - 0.03, L]
    mesh = bpy.data.meshes.new("body")
    bm = bmesh.new()
    rings = []
    for x in stations:
        half = section(m, x)
        y = -L / 2 + x
        ring_pts = half + [(-px, pz) for (px, pz) in reversed(half[1:-1])]
        rings.append([bm.verts.new((px, y, pz)) for (px, pz) in ring_pts])
    count = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for j in range(count):
            bm.faces.new((a[j], a[(j + 1) % count], b[(j + 1) % count], b[j]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    # Materials by position: glass in the greenhouse, black sills / arch liners / lower bumpers.
    obj = new_object("body", mesh)
    for name in ("Paint", "Glass", "Trim"):
        obj.data.materials.append(material(name))
    for face in bm.faces:
        c = face.calc_center_median()
        n = face.normal
        fx = c.y + L / 2
        top = interp(m["top"], fx)
        roof = interp(m["roof"], fx) if m["roof"][0][0] <= fx <= m["roof"][-1][0] else top
        index = 0
        ws0, ws1 = m["roof"][0][0] + 0.06, m["roof"][1][0] - 0.05
        rg0, rg1 = m["rear_glass"]
        in_screen = (ws0 <= fx <= ws1 or rg0 <= fx <= rg1) and c.z > top + 0.04 and abs(n.x) < 0.6
        if in_screen and abs(n.z) < 0.97:
            index = 1
        elif roof - top > 0.12 and top + 0.04 < c.z < roof - 0.05 and abs(n.z) < 0.97:
            index = 1
            if abs(n.x) > 0.5:
                b0, b1 = m["b_pillar"]
                if b0 <= fx <= b1:
                    index = 2
                for p0, p1 in m["pillars"]:
                    if p0 <= fx <= p1:
                        index = 0
        sec = section(m, min(max(fx, 0.0), L))
        if c.z < sec[0][1] + 0.1 and abs(n.z) > 0.3 or c.z < sec[0][1] + 0.07:
            index = 2
        if (fx < 0.12 or fx > L - 0.1) and c.z < 0.36:
            index = 2
        face.material_index = index
    bm.to_mesh(mesh)
    bm.free()
    # Smooth now, so details can be ray-snapped onto the final surface.
    mod = obj.modifiers.new("subsurf", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 1
    depsgraph = bpy.context.evaluated_depsgraph_get()
    smooth = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    obj.data = smooth
    parts.append(obj)
    return obj


def snap(parts, body, mat, size, origin, direction, lift=0.0, spin=0.0):
    """Box lying on the body surface where a ray from `origin` along `direction` hits it.
    `size` = (width along the surface, thickness along the normal, height); `lift` raises
    it off the surface along the normal (negative sinks it in)."""
    direction = Vector(direction).normalized()
    hit, location, normal, _ = body.ray_cast(Vector(origin), direction)
    if not hit:
        return None
    if normal.dot(direction) > 0:
        normal = -normal
    # Box Y along the surface normal, Z kept as upright as the surface allows.
    y_axis = normal.normalized()
    up = Vector((0, 0, 1))
    x_axis = up.cross(y_axis)
    if x_axis.length < 1e-4:
        x_axis = Vector((1, 0, 0))
    x_axis.normalize()
    z_axis = y_axis.cross(x_axis).normalized()
    rot = Matrix((x_axis, y_axis, z_axis)).transposed()
    if spin:
        rot = rot @ Matrix.Rotation(spin, 3, "Y")
    obj = add_box(parts, mat, size, tuple(location + normal * (size[1] * 0.5 + lift)))
    obj.rotation_euler = rot.to_euler()
    return obj


# ---------------------------------------------------------------- details ----

def build_details(m, parts, body):
    L, W, R = m["L"], m["W"], m["R"]
    top = lambda x: interp(m["top"], x)
    yf = -L / 2

    # Wheels: tyre, dark dish, five spokes, rim ring, hub.
    for axle in (m["fo"], m["fo"] + m["wb"]):
        for side in (-1, 1):
            out = W / 2 - 0.035
            cx = side * (out - 0.105)
            y = yf + axle
            add_cylinder(parts, "Tire", R, 0.21, (cx, y, R), 28, bevel=0.035)
            # Alloy wheel, outermost last: rim disc, dark dish, five spokes, hub.
            add_cylinder(parts, "Rim", R * 0.68, 0.012, (side * (out - 0.01), y, R), 28)
            add_cylinder(parts, "Trim", R * 0.58, 0.012, (side * (out - 0.004), y, R), 24)
            for spoke in range(5):
                angle = spoke * 2 * math.pi / 5 + 0.3
                direction = Vector((0, math.cos(angle), math.sin(angle)))
                at = Vector((side * (out + 0.004), y, R)) + direction * R * 0.3
                add_box(parts, "Rim", (0.02, R * 0.56, 0.075), tuple(at), (angle, 0, 0))
            add_cylinder(parts, "Rim", R * 0.16, 0.03, (side * (out + 0.006), y, R), 12)

    # Underbody.
    add_box(parts, "Trim", (W - 0.5, L - 0.6, 0.22), (0, 0, m["clear"] + 0.12))

    # Everything below sits on the smoothed body: rays from outside find the surface.
    ahead, behind = (0, 1, 0), (0, -1, 0)
    front_ray = lambda x, z: (x, yf - 1.0, z)
    rear_ray = lambda x, z: (x, L / 2 + 1.0, z)

    # Front: swept headlights in a dark surround, grille with a chrome bar, intake, plate.
    nose_top = top(0.06)
    head_z = nose_top - 0.08
    for side in (-1, 1):
        snap(parts, body, "Trim", (0.34, 0.015, 0.11), front_ray(side * W * 0.27, head_z), ahead, lift=-0.004, spin=side * 0.1)
        snap(parts, body, "HeadLight", (0.3, 0.025, 0.08), front_ray(side * W * 0.27, head_z), ahead, lift=-0.004, spin=side * 0.1)
        snap(parts, body, "Trim", (0.16, 0.02, 0.06), front_ray(side * W * 0.31, 0.36 + m["clear"]), ahead) # fog lamp
        snap(parts, body, "HeadLight", (0.1, 0.025, 0.045), front_ray(side * W * 0.31, 0.36 + m["clear"]), ahead)
    grille_z = head_z - 0.04
    snap(parts, body, "Trim", (W * 0.3, 0.025, 0.15), front_ray(0, grille_z), ahead)
    snap(parts, body, "Chrome", (W * 0.31, 0.03, 0.016), front_ray(0, grille_z + 0.075), ahead)
    for bar in range(3):
        snap(parts, body, "Chrome", (W * 0.28, 0.03, 0.008), front_ray(0, grille_z - 0.04 + bar * 0.04), ahead)
    snap(parts, body, "Trim", (W * 0.5, 0.02, 0.1), front_ray(0, 0.3 + m["clear"]), ahead)
    plate_z = (grille_z - 0.075 + 0.35 + m["clear"]) * 0.5
    snap(parts, body, "Plate", (0.52, 0.015, 0.11), front_ray(0, plate_z), ahead, lift=0.005)
    snap(parts, body, "PlateBlue", (0.045, 0.02, 0.105), front_ray(-0.235, plate_z), ahead, lift=0.006)

    # Rear: wraparound tail lights, plate, dark lower bumper.
    tail_z = top(L - 0.05) - 0.12
    for side in (-1, 1):
        snap(parts, body, "TailLight", (0.34, 0.03, 0.13), rear_ray(side * W * 0.33, tail_z), behind)
        snap(parts, body, "TailLight", (0.1, 0.03, 0.2), rear_ray(side * W * 0.37, tail_z + 0.13), behind)
        wrap = snap(parts, body, "TailLight", (0.16, 0.03, 0.12), (side * (W + 1.0), L / 2 - 0.12, tail_z), (-side, 0, 0))
    plate_rz = tail_z - 0.2
    snap(parts, body, "Plate", (0.52, 0.015, 0.11), rear_ray(0, plate_rz), behind, lift=0.005)
    snap(parts, body, "PlateBlue", (0.045, 0.02, 0.105), rear_ray(-0.235, plate_rz), behind, lift=0.006)
    snap(parts, body, "Trim", (W * 0.7, 0.02, 0.12), rear_ray(0, 0.33 + m["clear"]), behind)

    # Door mirrors on an arm, door handles.
    ws = m["roof"][0][0]
    for side in (-1, 1):
        my = yf + ws + 0.32
        mz = top(ws + 0.32) + 0.08
        hit, at, _, _ = body.ray_cast(Vector((side * (W + 1.0), my, mz - 0.04)), Vector((-side, 0, 0)))
        wall = abs(at.x) if hit else W * 0.47
        add_box(parts, "Trim", (0.1, 0.07, 0.05), (side * (wall + 0.04), my, mz - 0.04))
        add_box(parts, "Paint", (0.17, 0.1, 0.12), (side * (wall + 0.13), my, mz))
        add_box(parts, "Trim", (0.15, 0.012, 0.1), (side * (wall + 0.13), my + 0.052, mz))
        for handle in (m["b_pillar"][0] - 0.35, m["b_pillar"][1] + 0.55):
            snap(parts, body, "Chrome", (0.15, 0.025, 0.028), (side * (W + 1.0), yf + handle, top(handle) - 0.09), (-side, 0, 0))

    # Roof rails on the estate and the SUV.
    if m["rails"]:
        r0, r1 = m["roof"][2][0] - 0.1, m["roof"][-3][0] + 0.05
        roof_z = interp(m["roof"], (r0 + r1) / 2)
        for side in (-1, 1):
            add_box(parts, "Trim", (0.04, r1 - r0, 0.05), (side * W * 0.31, yf + (r0 + r1) / 2, roof_z + 0.075))
            for leg in (r0 + 0.05, r1 - 0.05):
                add_box(parts, "Trim", (0.05, 0.08, 0.06), (side * W * 0.31, yf + leg, interp(m["roof"], leg) + 0.03))


def build_car(name, m):
    parts = []
    body = build_body(m, parts)
    build_details(m, parts, body)
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    for obj in parts:
        bpy.context.view_layer.objects.active = obj
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    car = bpy.context.view_layer.objects.active
    car.name = name
    car.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    # Keep hard edges crisp (lights, plates, boxes) with an angle-based split.
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
    except Exception:
        pass
    return car


# ----------------------------------------------------------------- export ----

def export(car, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    car.select_set(True)
    bpy.context.view_layer.objects.active = car
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT_DIR, name + ".glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


def render_preview(car, name, paint):
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = 900
    scene.render.resolution_y = 560
    scene.render.film_transparent = False
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.75, 0.8, 0.88, 1.0)
    bg.inputs[1].default_value = 0.9
    paint_mat = bpy.data.materials["Paint"]
    bsdf = next(n for n in paint_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*paint, 1.0)
    for other in bpy.data.objects:
        if other.type == "MESH" and other.name.startswith("car_"):
            other.hide_render = other is not car
    if "PreviewGround" not in bpy.data.objects:
        bpy.ops.mesh.primitive_plane_add(size=30)
        ground = bpy.context.active_object
        ground.name = "PreviewGround"
        mat = bpy.data.materials.new("PreviewGroundMat")
        mat.use_nodes = True
        next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.35, 0.35, 0.34, 1)
        ground.data.materials.append(mat)
        sun = bpy.data.objects.new("PreviewSun", bpy.data.lights.new("PreviewSun", "SUN"))
        sun.data.energy = 3.5
        sun.rotation_euler = (math.radians(50), 0, math.radians(35))
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
        cam.data.lens = 40
        scene.collection.objects.link(cam)
        scene.camera = cam
    cam = bpy.data.objects["PreviewCam"]
    os.makedirs(RENDER_DIR, exist_ok=True)
    for label, pos in (("front", (4.4, -5.6, 2.0)), ("rear", (-4.6, 5.2, 2.1)), ("side", (7.5, 0.0, 1.2))):
        cam.location = pos
        direction = Vector((0, 0, 0.7)) - Vector(pos)
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(RENDER_DIR, f"{name}_{label}.png")
        bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    no_render = "--no-render" in argv
    only = None
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cars = {}
    for name, m in MODELS.items():
        if only and name not in only:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        car = build_car(name, m)
        export(car, name)
        cars[name] = car
        print("built", name, len(car.data.polygons), "faces")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", "vehicles.blend"))
    if not no_render:
        for name, car in cars.items():
            render_preview(car, name, MODELS[name]["paint"])
    print("DONE")


main()
