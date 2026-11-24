"""Close-ups of a player model's head:  blender -b --factory-startup -P blender/scripts/render_head.py -- model.glb out_prefix"""
import math
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args[0]))
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
top = max((mesh.matrix_world @ v.co).z for v in mesh.data.vertices)
scene = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
scene.render.resolution_x = 600
scene.render.resolution_y = 600
world = bpy.data.worlds.new("w")
world.use_nodes = True
next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.75, 0.78, 0.82, 1)
scene.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(55), 0, math.radians(-20))
bpy.context.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
bpy.context.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 85
z = top - 0.15
for name, angle, pitch in [("front", 0, 0), ("three_quarter", 35, 0), ("side", 90, 0), ("below", 20, -25)]:
    a = math.radians(angle)
    p = math.radians(pitch)
    d = 0.9
    cam.location = (d * math.sin(a) * math.cos(p), -d * math.cos(a) * math.cos(p), z + d * math.sin(p))
    cam.rotation_euler = (math.radians(90) + p, 0, a)
    scene.render.filepath = os.path.abspath("%s_%s.png" % (args[1], name))
    bpy.ops.render.render(write_still=True)
print("DONE")
