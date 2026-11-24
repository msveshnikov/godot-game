"""Alice, the second player character, from her turnaround sheet.

First run  python blender/scripts/alice_sheet.py  (cuts the sheet's three views, builds
the body volume, measures the joints). Then:

    blender -b --factory-startup -P blender/scripts/build_female_player.py -- [--no-render]

takes blender/build/alice_hull.npz, smooths and thins it to a game mesh, and paints it
by projecting the sheet straight onto it, each face from the view that looks at it
best (front, side or back), the way Max's model carries his sheet. Writes
female_player.glb (one mesh, one material) at the project root and previews in
blender/renders/alice_{front,side,back,three_quarter,face}.png.

Axes as everywhere here: z up, her front towards -Y (= Godot +Z), her right hand on -X.
"""
import json
import math
import os
import sys

import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BUILD = os.path.join(ROOT, "blender", "build")
OUT = os.path.join(ROOT, "female_player.glb")
RENDER_DIR = os.path.join(ROOT, "blender", "renders")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hull = np.load(os.path.join(BUILD, "alice_hull.npz"))
    views = json.load(open(os.path.join(BUILD, "alice_views.json")))
    verts = hull["verts"]
    verts[:, 2] -= verts[:, 2].min() # feet on the ground
    faces = hull["faces"]
    mesh = bpy.data.meshes.new("Alice")
    mesh.from_pydata(verts.tolist(), [], faces[:, ::-1].tolist())
    mesh.validate()
    obj = bpy.data.objects.new("Alice", mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # Smooth away the voxel steps, then thin to a game mesh.
    smooth = obj.modifiers.new("smooth", "CORRECTIVE_SMOOTH")
    smooth.iterations = 6
    smooth.use_only_smooth = True
    bpy.ops.object.modifier_apply(modifier="smooth")
    decimate = obj.modifiers.new("thin", "DECIMATE")
    decimate.ratio = 0.11
    bpy.ops.object.modifier_apply(modifier="thin")
    bpy.ops.object.shade_smooth()
    # Normals out.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    project_uvs(obj, views)
    obj.data.materials.append(texture_material())
    xs = [v.co.x for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    print("Alice: %d verts, %d faces, height %.3f, x %.3f..%.3f" % (len(obj.data.vertices), len(obj.data.polygons), max(zs), min(xs), max(xs)))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True)
    print("wrote", OUT)
    if "--no-render" not in ARGS:
        render_previews()
    print("DONE")


def project_uvs(obj, views):
    """Each face takes its texture from the view facing it: side faces from the side
    profile (the same picture serves both sides), the rest from the front or the back."""
    w, h = views["size"]
    m = views["metres_per_px"]
    front, side, back = views["front"], views["side"], views["back"]
    me = obj.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        n = poly.normal
        c = poly.center
        # In the side view the arm is drawn over the torso, so neither arms nor torso can
        # take colour from it: only the head and the legs do.
        # (The hands hang beside the thighs down to ~0.74 m, the jaw is at ~1.5 m.)
        head = c.z > 1.49 # from the jaw up
        legs = c.z < 0.7 and abs(c.x) < 0.2
        # On the head only behind the eyes: in front of them the side view has her profile
        # (nose, lips), which would land on the cheeks as a ghost of a second face.
        behind_eyes = c.y > -0.045
        side_ok = (head and behind_eyes and abs(n.x) > max(abs(n.y), 0.5)) or (legs and abs(n.x) > max(abs(n.y), 0.5))
        for li in poly.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            if side_ok:
                px = side["centre"] - p.y / m
                py = side["feet"] - p.z / m
            elif n.y <= 0.0:
                px = front["centre"] + p.x / m
                py = front["feet"] - p.z / m
            else:
                px = back["centre"] - p.x / m
                py = back["feet"] - p.z / m
            uv.data[li].uv = (px / w, 1.0 - py / h)


def texture_material():
    image = bpy.data.images.load(os.path.join(BUILD, "alice_texture.png"))
    image.name = "alice_texture"
    mat = bpy.data.materials.new("alice")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


def render_previews():
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 800
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.75, 0.78, 0.82, 1.0)
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(-30))
    bpy.context.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(RENDER_DIR, exist_ok=True)
    for name, loc, rot, ortho in [
        ("front", (0.0, -4.0, 0.9), (90, 0, 0), True),
        ("side", (4.0, 0.0, 0.9), (90, 0, 90), True),
        ("back", (0.0, 4.0, 0.9), (90, 0, 180), True),
        ("three_quarter", (2.6, -3.0, 1.1), (88, 0, 41), False),
        ("face", (0.22, -0.75, 1.6), (90, 0, 16), False),
    ]:
        cam.location = loc
        cam.rotation_euler = tuple(math.radians(a) for a in rot)
        cam.data.type = "ORTHO" if ortho else "PERSP"
        cam.data.ortho_scale = 1.95
        cam.data.lens = 50 if name == "three_quarter" else 60
        scene.render.filepath = os.path.join(RENDER_DIR, "alice_%s.png" % name)
        bpy.ops.render.render(write_still=True)


main()
