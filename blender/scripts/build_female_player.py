"""Alice, the second player character: a young woman in a black T-shirt, blue jeans and
white sneakers, long dark hair in a ponytail. Built so the game's procedural rig
(player_body.gdshader + player_model_animator.gd) drives her exactly like Max:

  feet on the ground at z = 0, hips 0.86, knees 0.46, shoulder joints at x = +-0.22,
  z = 1.43, A-posed arms with the palms at (+-0.525, -0.143, 0.855), front towards -Y
  (= Godot +Z), her right hand on -X. The torso stays inside |x| < 0.2 and the legs
  inside |x| < 0.24 below the crotch, which is how the shader tells arms, legs and
  body apart.

The body is a Skin-modifier skeleton (one smooth closed surface), subdivided, then
shaped (waist, hips, chest); head, hair, face details are separate pieces joined in.
Colours come from region rules (by height and distance from the bones) evaluated in
a node material, baked by Cycles into one 1024 px texture over a Smart-UV layout.
The T-shirt stays near-black and the jeans blue, so the shop's recolouring works.

Run:  blender -b --factory-startup -P blender/scripts/build_female_player.py -- [--no-render]

Writes female_player.glb (one mesh, one material with the baked texture) at the
project root, and blender/renders/alice_{front,side,back}.png previews.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "female_player.glb")
RENDER_DIR = os.path.join(ROOT, "blender", "renders")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

SKIN = (0.93, 0.74, 0.62)
SHIRT = (0.035, 0.035, 0.04)
JEANS = (0.16, 0.29, 0.56)
JEANS_DARK = (0.1, 0.19, 0.4)
SHOE = (0.94, 0.94, 0.93)
SOLE = (0.75, 0.74, 0.72)
HAIR = (0.2, 0.11, 0.06)
LIPS = (0.72, 0.3, 0.32)
EYE_WHITE = (0.95, 0.95, 0.93)
IRIS = (0.24, 0.36, 0.22)
PUPIL = (0.03, 0.03, 0.03)
BROW = (0.16, 0.09, 0.05)


def lin(c):
    """sRGB colour (as picked by eye) to the linear values Blender's nodes take."""
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, rough=0.7):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*lin(color), 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return mat


# ------------------------------------------------------------------ body ----

# Skeleton for the Skin modifier: (name, position, radius x, radius y).
# Positions in metres, Blender axes (x right of the viewer, -y towards the viewer, z up).
def body_points():
    pts = {
        "pelvis": ((0.0, 0.0, 0.93), 0.150, 0.105),
        "waist": ((0.0, 0.005, 1.07), 0.118, 0.085),
        "chest": ((0.0, 0.0, 1.24), 0.14, 0.095),
        "upper_chest": ((0.0, 0.01, 1.38), 0.15, 0.085),
        "neck": ((0.0, 0.015, 1.49), 0.052, 0.055),
        "neck_top": ((0.0, 0.012, 1.56), 0.05, 0.055),
    }
    for side, sx in (("r", -1.0), ("l", 1.0)):
        pts["hip_" + side] = ((sx * 0.092, 0.0, 0.86), 0.092, 0.095)
        pts["thigh_" + side] = ((sx * 0.094, 0.0, 0.66), 0.075, 0.08)
        pts["knee_" + side] = ((sx * 0.095, -0.005, 0.46), 0.052, 0.056)
        pts["calf_" + side] = ((sx * 0.096, 0.012, 0.3), 0.05, 0.055)
        pts["ankle_" + side] = ((sx * 0.097, 0.0, 0.085), 0.032, 0.036)
        pts["heel_" + side] = ((sx * 0.097, 0.035, 0.04), 0.038, 0.035)
        pts["toe_" + side] = ((sx * 0.1, -0.12, 0.035), 0.04, 0.03)
        # Arms: shoulder joint at x 0.22, z 1.43; palm at (0.525, -0.143, 0.855).
        shoulder = Vector((sx * 0.2, 0.0, 1.43))
        hand = Vector((sx * 0.525, -0.143, 0.855))
        elbow = shoulder.lerp(hand, 0.5) + Vector((sx * 0.0, 0.03, 0.0))
        wrist = shoulder.lerp(hand, 0.9)
        pts["shoulder_" + side] = (tuple(shoulder), 0.055, 0.055)
        pts["upper_arm_" + side] = (tuple(shoulder.lerp(elbow, 0.5)), 0.045, 0.045)
        pts["elbow_" + side] = (tuple(elbow), 0.036, 0.036)
        pts["forearm_" + side] = (tuple(elbow.lerp(wrist, 0.5)), 0.034, 0.032)
        pts["wrist_" + side] = (tuple(wrist), 0.024, 0.022)
        pts["hand_" + side] = (tuple(hand), 0.038, 0.017)
        pts["fingers_" + side] = (tuple(hand + (hand - wrist).normalized() * 0.07), 0.028, 0.012)
    edges = [("pelvis", "waist"), ("waist", "chest"), ("chest", "upper_chest"), ("upper_chest", "neck"), ("neck", "neck_top")]
    for side in ("r", "l"):
        edges += [
            ("pelvis", "hip_" + side), ("hip_" + side, "thigh_" + side), ("thigh_" + side, "knee_" + side),
            ("knee_" + side, "calf_" + side), ("calf_" + side, "ankle_" + side), ("ankle_" + side, "heel_" + side),
            ("ankle_" + side, "toe_" + side),
            ("upper_chest", "shoulder_" + side), ("shoulder_" + side, "upper_arm_" + side),
            ("upper_arm_" + side, "elbow_" + side), ("elbow_" + side, "forearm_" + side),
            ("forearm_" + side, "wrist_" + side), ("wrist_" + side, "hand_" + side), ("hand_" + side, "fingers_" + side),
        ]
    return pts, edges


def build_body():
    pts, edges = body_points()
    names = list(pts)
    mesh = bpy.data.meshes.new("body")
    mesh.from_pydata([pts[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in edges], [])
    obj = bpy.data.objects.new("body", mesh)
    bpy.context.collection.objects.link(obj)
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    skin.branch_smoothing = 0.6
    for i, n in enumerate(names):
        sv = mesh.skin_vertices[0].data[i]
        sv.radius = (pts[n][1], pts[n][2])
        if n == "pelvis":
            sv.use_root = True
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier="skin")
    bpy.ops.object.modifier_apply(modifier="sub")
    shape_body(obj)
    return obj


def bump(d, r):
    """1 at d = 0 falling smoothly to 0 at d = r."""
    if d >= r:
        return 0.0
    t = d / r
    return (1.0 - t * t) ** 2


def shape_body(obj):
    """Female shape on the skin surface: a narrower waist, fuller hips and seat, a chest."""
    for v in obj.data.vertices:
        p = v.co
        ax = abs(p.x)
        # Torso only (not the arms).
        if ax < 0.2 and 0.8 < p.z < 1.48:
            # Waist pinch.
            w = bump(abs(p.z - 1.06), 0.12)
            p.x *= 1.0 - 0.1 * w
            # Chest: two soft bumps forward.
            for sx in (-1.0, 1.0):
                d = math.hypot(p.x - sx * 0.075, p.z - 1.27)
                if p.y < 0.0:
                    p.y -= 0.045 * bump(d, 0.085)
            # Shoulder blades flatter, back a little arched.
            if p.y > 0.0 and 1.1 < p.z < 1.42:
                p.y *= 0.95
        # Hips and seat.
        if ax < 0.24 and 0.72 < p.z < 1.0:
            w = bump(abs(p.z - 0.88), 0.13)
            p.x *= 1.0 + 0.06 * w
            if p.y > 0.0:
                p.y += 0.025 * bump(abs(p.z - 0.86), 0.12) * bump(abs(ax - 0.08), 0.12)


# ------------------------------------------------------------------ head ----

def sphere(name, loc, scale, mat, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


HEAD_C = Vector((0.0, -0.005, 1.668))


HEAD_R = (0.082, 0.098, 0.118)


def face_y(x, z):
    """Where the front of the face is (y) at x, z relative to the head centre, jaw included."""
    rx, ry, rz = HEAD_R
    k = max(0.0, 1.0 - (x / rx) ** 2 - (z / rz) ** 2)
    y = -ry * math.sqrt(k)
    if z < 0.0:
        t = min(-z / rz, 1.0)
        y = y * (1.0 - 0.18 * t * t) - 0.012 * t * t
    return HEAD_C.y + y


def build_head(mats):
    parts = []
    head = sphere("head", HEAD_C, HEAD_R, mats["skin"], 32, 24)
    # Jaw: narrow the lower half towards the chin, the chin a touch forward.
    for v in head.data.vertices:
        rel = v.co - HEAD_C
        if rel.z < 0.0:
            t = min(-rel.z / HEAD_R[2], 1.0)
            v.co.x = HEAD_C.x + rel.x * (1.0 - 0.3 * t * t)
            v.co.y = HEAD_C.y + rel.y * (1.0 - 0.18 * t * t) - 0.012 * t * t
    parts.append(head)

    def on_face(name, x, z, size, mat, sink=0.002, segs=(16, 10)):
        y = face_y(x, z) + sink
        return sphere(name, (x, y, HEAD_C.z + z), size, mat, *segs)

    # Nose: a soft bump; lips: upper and lower.
    parts.append(on_face("nose", 0.0, -0.022, (0.011, 0.013, 0.02), mats["skin"], 0.004))
    parts.append(on_face("lip_upper", 0.0, -0.052, (0.017, 0.005, 0.0045), mats["lips"], 0.002))
    parts.append(on_face("lip_lower", 0.0, -0.06, (0.015, 0.005, 0.005), mats["lips"], 0.002))
    for sx in (-1.0, 1.0):
        x = sx * 0.031
        parts.append(on_face("eye", x, 0.008, (0.0155, 0.004, 0.0085), mats["eye_white"], 0.0015))
        parts.append(on_face("iris", x, 0.007, (0.0072, 0.003, 0.0072), mats["iris"], -0.0015, (12, 8)))
        parts.append(on_face("pupil", x, 0.007, (0.0032, 0.002, 0.0032), mats["pupil"], -0.0028, (8, 6)))
        parts.append(on_face("lash", x, 0.0165, (0.0175, 0.003, 0.0022), mats["brow"], -0.0005, (12, 6)))
        parts.append(on_face("brow", x + sx * 0.003, 0.031, (0.018, 0.003, 0.003), mats["brow"], -0.0005, (12, 6)))
        parts.append(sphere("ear", (sx * (HEAD_R[0] - 0.004), HEAD_C.y + 0.008, HEAD_C.z - 0.008), (0.011, 0.02, 0.028), mats["skin"], 12, 8))
    return parts


def build_hair(mats):
    parts = []
    centre = HEAD_C + Vector((0.0, 0.007, 0.012))
    rx, ry, rz = HEAD_R[0] + 0.009, HEAD_R[1] + 0.01, HEAD_R[2] + 0.008
    cap = sphere("hair_cap", centre, (rx, ry, rz), mats["hair"], 40, 28)
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    cut = []
    for v in bm.verts:
        rel = v.co - HEAD_C
        hairline = 0.045 - 3.2 * rel.x * rel.x # the fringe line, lower at the temples
        if rel.y < -0.025 and rel.z < hairline:
            cut.append(v) # the face
        elif rel.z < -0.035 and rel.y < 0.035:
            cut.append(v) # in front of and below the ears
        elif rel.z < -0.085:
            cut.append(v) # under the nape
    bmesh.ops.delete(bm, geom=cut, context="VERTS")
    bm.to_mesh(cap.data)
    bm.free()
    solid = cap.modifiers.new("solid", "SOLIDIFY")
    solid.thickness = 0.01
    bpy.context.view_layer.objects.active = cap
    bpy.ops.object.select_all(action="DESELECT")
    cap.select_set(True)
    bpy.ops.object.modifier_apply(modifier="solid")
    parts.append(cap)
    # Ponytail: a band at the back of the crown and a tapering tail down the back.
    parts.append(sphere("tie", (0.0, HEAD_C.y + 0.108, HEAD_C.z + 0.04), (0.024, 0.018, 0.024), mats["brow"], 12, 8))
    curve = bpy.data.curves.new("tail", "CURVE")
    curve.dimensions = "3D"
    spline = curve.splines.new("BEZIER")
    points = [
        (0.0, HEAD_C.y + 0.112, HEAD_C.z + 0.04),
        (0.0, HEAD_C.y + 0.15, HEAD_C.z - 0.05),
        (0.0, HEAD_C.y + 0.135, HEAD_C.z - 0.2),
        (0.0, HEAD_C.y + 0.125, HEAD_C.z - 0.34),
    ]
    spline.bezier_points.add(len(points) - 1)
    for bp, co, r in zip(spline.bezier_points, points, [0.03, 0.04, 0.03, 0.006]):
        bp.co = co
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
        bp.radius = r / 0.04
    curve.bevel_depth = 0.04
    curve.bevel_resolution = 4
    curve.resolution_u = 10
    curve.use_fill_caps = True
    tail = bpy.data.objects.new("tail", curve)
    bpy.context.collection.objects.link(tail)
    tail.data.materials.append(mats["hair"])
    bpy.ops.object.select_all(action="DESELECT")
    tail.select_set(True)
    bpy.context.view_layer.objects.active = tail
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.shade_smooth()
    parts.append(bpy.context.active_object)
    return parts


# --------------------------------------------------------------- texture ----

def body_material():
    """Skin / T-shirt / jeans / sneakers by position, as a node tree (baked later)."""
    mat = bpy.data.materials.new("alice_body")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    links = nt.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.75
    coords = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], sep.inputs["Vector"])
    x, y, z = sep.outputs["X"], sep.outputs["Y"], sep.outputs["Z"]

    def math_node(op, a, b=None, clamp=False):
        n = nodes.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        if isinstance(a, (int, float)):
            n.inputs[0].default_value = a
        else:
            links.new(a, n.inputs[0])
        if b is not None:
            if isinstance(b, (int, float)):
                n.inputs[1].default_value = b
            else:
                links.new(b, n.inputs[1])
        return n.outputs[0]

    def mix(fac, a, b):
        n = nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        links.new(fac, n.inputs["Factor"])
        for i, c in ((6, a), (7, b)):
            if isinstance(c, tuple):
                n.inputs[i].default_value = (*lin(c), 1.0)
            else:
                links.new(c, n.inputs[i])
        return n.outputs[2]

    def step(value, edge, soft=0.004):
        # smoothstep(edge - soft, edge + soft, value)
        n = nodes.new("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        if not isinstance(edge, (int, float)):
            value = math_node("SUBTRACT", value, edge) # an edge that varies: step around 0
            edge = 0.0
        links.new(value, n.inputs["Value"])
        n.inputs["From Min"].default_value = edge - soft
        n.inputs["From Max"].default_value = edge + soft
        return n.outputs["Result"]

    ax = math_node("ABSOLUTE", x)
    # Distance along the arm from the shoulder joint (|x| 0.2, z 1.43): sleeves end ~0.13 out.
    dx = math_node("SUBTRACT", ax, 0.2)
    dz = math_node("SUBTRACT", z, 1.43)
    arm_d = math_node("SQRT", math_node("ADD", math_node("POWER", dx, 2.0), math_node("POWER", dz, 2.0)))
    on_arm = step(ax, 0.215, 0.01)
    sleeve = math_node("SUBTRACT", 1.0, math_node("MULTIPLY", on_arm, step(arm_d, 0.15, 0.005)))
    # T-shirt between the waistband (0.95) and the neckline (a scoop: lower in front).
    # A crew neck that rises over the shoulders and dips a little in front.
    neck = math_node("ADD", math_node("ADD", 1.47, math_node("MULTIPLY", ax, 0.3)), math_node("MULTIPLY", math_node("MINIMUM", y, 0.0), 0.45))
    top = math_node("MULTIPLY", step(z, 0.95), math_node("SUBTRACT", 1.0, step(z, neck)))
    shirt = math_node("MULTIPLY", top, sleeve)
    legs = math_node("SUBTRACT", 1.0, step(ax, 0.27, 0.01)) # not the hands, which hang this low too
    jeans = math_node("MULTIPLY", math_node("MULTIPLY", step(z, 0.105), math_node("SUBTRACT", 1.0, step(z, 0.955))), legs)
    shoe = math_node("MULTIPLY", math_node("SUBTRACT", 1.0, step(z, 0.105)), legs)
    sole = math_node("SUBTRACT", 1.0, step(z, 0.03))
    # Denim: darker seams down the outside of each leg and a little noise.
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 90.0
    links.new(coords.outputs["Object"], noise.inputs["Vector"])
    seam = math_node("SUBTRACT", 1.0, step(math_node("ABSOLUTE", math_node("SUBTRACT", ax, 0.17)), 0.006, 0.003))
    denim = mix(math_node("MULTIPLY", seam, 0.6), JEANS, JEANS_DARK)
    denim = mix(math_node("MULTIPLY", noise.outputs["Fac"], 0.25), denim, JEANS_DARK)
    belt_line = math_node("MULTIPLY", step(z, 0.93), math_node("SUBTRACT", 1.0, step(z, 0.955)))
    denim = mix(math_node("MULTIPLY", belt_line, 0.8), denim, (0.05, 0.05, 0.06))

    color = mix(jeans, SKIN, denim)
    color = mix(shirt, color, SHIRT)
    color = mix(shoe, color, SHOE)
    color = mix(math_node("MULTIPLY", shoe, sole), color, SOLE)
    links.new(color, bsdf.inputs["Base Color"])
    return mat


def bake(obj, size=1024):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.cycles.device = "CPU"
    image = bpy.data.images.new("alice_texture", size, size)
    for slot in obj.material_slots:
        nt = slot.material.node_tree
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = image
        nt.nodes.active = node
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.bake.margin = 6
    bpy.ops.object.bake(type="DIFFUSE")
    return image


def main():
    reset()
    mats = {
        "skin": material("skin", SKIN, 0.6),
        "hair": material("hair", HAIR, 0.5),
        "eye_white": material("eye_white", EYE_WHITE, 0.3),
        "iris": material("iris", IRIS, 0.3),
        "pupil": material("pupil", PUPIL, 0.2),
        "brow": material("brow", BROW, 0.8),
        "lips": material("lips", LIPS, 0.4),
    }
    body = build_body()
    body.data.materials.append(body_material())
    parts = [body] + build_head(mats) + build_hair(mats)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    alice = bpy.context.active_object
    alice.name = "Alice"
    bpy.ops.object.shade_smooth()
    # One UV layout for everything, then bake every material's colour into it.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    image = bake(alice)
    image.filepath_raw = os.path.join(ROOT, "blender", "renders", "alice_texture.png")
    image.file_format = "PNG"
    os.makedirs(RENDER_DIR, exist_ok=True)
    image.save()
    # Replace all materials with one that uses the baked texture.
    final = bpy.data.materials.new("alice")
    final.use_nodes = True
    bsdf = next(n for n in final.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = final.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    final.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    alice.data.materials.clear()
    alice.data.materials.append(final)
    for poly in alice.data.polygons:
        poly.material_index = 0
    zs = [v.co.z for v in alice.data.vertices]
    xs = [v.co.x for v in alice.data.vertices]
    print("height %.3f  x %.3f..%.3f  verts %d" % (max(zs) - min(zs), min(xs), max(xs), len(alice.data.vertices)))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True)
    print("wrote", OUT)
    if "--no-render" not in ARGS:
        render_previews(alice)
    print("DONE")


def render_previews(obj):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 800
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.75, 0.78, 0.82, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(-30))
    bpy.context.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.0
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    for name, loc, rot in [
        ("front", (0.0, -4.0, 0.95), (math.radians(90), 0.0, 0.0)),
        ("side", (4.0, 0.0, 0.95), (math.radians(90), 0.0, math.radians(90))),
        ("back", (0.0, 4.0, 0.95), (math.radians(90), 0.0, math.radians(180))),
        ("face", (0.25, -0.9, 1.7), (math.radians(90), 0.0, math.radians(15))),
    ]:
        cam.location = loc
        cam.rotation_euler = rot
        cam.data.type = "PERSP" if name == "face" else "ORTHO"
        cam.data.lens = 60
        scene.render.filepath = os.path.join(RENDER_DIR, "alice_%s.png" % name)
        bpy.ops.render.render(write_still=True)


main()
