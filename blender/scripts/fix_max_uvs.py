"""Re-projects the texture on Max's head (main_player.glb carries his turnaround sheet
projected onto the mesh: front, side, back). Two flaws are fixed:

- the cheeks took the side view, where the sheet has his profile (nose, glasses), so
  a ghost of a second face sat on each cheek. Now only what is behind the cheekbones
  (ears, the hair on the sides) takes the side view; the face takes the front view;
- the underside of the jaw took the front view's chin line and neck shading, stretched
  into dark streaks. Now it takes plain skin from the cheek.

The projections were recovered from the model's own UVs (exact fits, < 1 px):
    front: u = 256.81 x + 216.42      side: u = 254.36 y + 565.02
    back:  u = -252.35 x + 866.08     all:  v = 534.5 - 255.5 z      (pixels, 1024 x 559)

Run:  blender -b --factory-startup -P blender/scripts/fix_max_uvs.py
Rewrites main_player.glb in place (everything below the neck untouched).
"""
import os

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLB = os.path.join(ROOT, "main_player.glb")
W, H = 1024.0, 559.0
NECK = 1.52 # head and jaw above this
CHEEKBONE_Y = -0.08 # behind the eyes (towards +y) the side view shows cheek, temple, ear, hair
SKIN = (256.81 * 0.045 + 216.42, 534.5 - 255.79 * 1.68) # a patch of cheek in the front view


def front(p):
    return 256.81 * p.x + 216.42, 534.5 - 255.79 * p.z


def side(p):
    return 254.36 * p.y + 565.02, 534.5 - 255.26 * p.z


def back(p):
    return -252.35 * p.x + 866.08, 534.5 - 255.26 * p.z


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    me = obj.data
    uv = me.uv_layers.active.data
    changed = 0
    for poly in me.polygons:
        c = poly.center
        if c.z < NECK:
            continue
        n = poly.normal
        loops = list(poly.loop_indices)
        was_side = all(0.36 <= uv[li].uv[0] < 0.68 for li in loops)
        under_jaw = n.z < -0.55 and c.z < 1.66 and c.y < 0.03
        ghost = was_side and c.z < 1.74 and c.y < CHEEKBONE_Y # profile features on a cheek
        if not (under_jaw or ghost):
            continue # the rest of the head keeps its projection
        changed += 1
        for li in loops:
            p = me.vertices[me.loops[li].vertex_index].co
            px, py = front(p)
            if under_jaw:
                # Plain neck skin from just under the shadow the sheet draws below the jaw.
                py = 534.5 - 255.79 * 1.56
            uv[li].uv = (px / W, 1.0 - py / H)
    print("re-projected %d faces (cheeks and under the jaw)" % changed)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True)
    print("DONE")


main()
