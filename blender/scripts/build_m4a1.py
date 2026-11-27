"""Build the exterior game prop and export it facing Godot's -Z."""
from math import radians
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    surface = mat.node_tree.nodes.get("Principled BSDF")
    surface.inputs["Base Color"].default_value = mat.diffuse_color
    surface.inputs["Metallic"].default_value = metallic
    surface.inputs["Roughness"].default_value = roughness
    return mat


steel = material("Charcoal anodized metal", (0.075, 0.088, 0.105), 0.62, 0.34)
edges = material("Graphite details", (0.125, 0.137, 0.146), 0.7, 0.38)
polymer = material("Slate polymer", (0.044, 0.054, 0.063), 0.05, 0.62)
rubber = material("Soft black", (0.019, 0.025, 0.03), 0.0, 0.78)
accent = material("Warm grey markings", (0.41, 0.40, 0.36), 0.2, 0.5)


def finish(obj, name, mat, bevel):
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        bevel_mod = obj.modifiers.new("Soft machined edges", "BEVEL")
        bevel_mod.width = bevel
        bevel_mod.segments = 2
        bevel_mod.harden_normals = True
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def box(name, xyz, size, mat=steel, bevel=0.004):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel)


def profile(name, outline, width, mat, bevel=0.006):
    # A shaped side silhouette extruded across the width of the prop.
    n = len(outline)
    vertices = [(x, y, z) for x in (-width / 2, width / 2) for y, z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return finish(obj, name, mat, bevel)


def cylinder(name, xyz, radius, length, mat, axis="Y", sides=24, bevel=0.002):
    rotation = (radians(90), 0, 0) if axis == "Y" else (0, radians(90), 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=length, location=xyz, rotation=rotation)
    obj = bpy.context.object
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    return finish(obj, name, mat, bevel)


profile("Upper receiver", [(-.072,.064), (.19,.064), (.19,.133), (.16,.153), (-.055,.153), (-.075,.134)], .073, steel)
profile("Lower receiver", [(-.09,.058), (.04,.026), (.173,.022), (.193,.063), (-.06,.081)], .067, steel)
profile("Curved magazine", [(.086,.043), (.155,.043), (.157,-.01), (.161,-.065), (.188,-.125), (.117,-.146), (.095,-.105), (.082,-.041)], .054, edges)
profile("Textured grip", [(-.026,.06), (.031,.035), (.016,-.008), (-.028,-.104), (-.081,-.082), (-.045,.019)], .049, polymer, .009)
profile("Trigger guard", [(.013,.027), (.068,.006), (.092,.02), (.086,.011), (.072,-.01), (.024,-.021), (.006,-.008)], .031, edges, .002)
profile("Trigger", [(.047,.042), (.065,.039), (.059,.016), (.047,.003), (.04,.004), (.049,.022)], .017, steel, .002)

cylinder("Stock tube", (0,-.156,.112), .023, .202, edges)
profile("Sculpted stock", [(-.309,.126), (-.153,.14), (-.107,.115), (-.138,.075), (-.235,.064), (-.28,-.002), (-.309,-.015)], .061, polymer, .008)
profile("Butt pad", [(-.322,.129), (-.298,.138), (-.296,-.009), (-.317,-.027), (-.329,-.012)], .068, rubber, .005)
profile("Handguard", [(.176,.067), (.212,.055), (.405,.062), (.446,.078), (.447,.128), (.41,.148), (.173,.144)], .085, polymer, .009)
box("Upper rail", (0,.208,.157), (.049,.483,.018), steel)
for i in range(20):
    box("Rail slot edge", (0,-.018 + i * .023,.169), (.051,.013,.009), edges, .0015)
for side in (-1, 1):
    for i in range(7):
        box("Recessed handguard panel", (side * .041,.22 + i * .029,.102), (.006,.020,.017), rubber, .004)
    for i in range(3):
        box("Magazine rib", (side * .027,.104 + i * .021,-.056), (.005,.007,.103), steel, .002).rotation_euler.x = radians(9)
    for i in range(5):
        box("Grip stipple", (side * .024,-.026 - i * .008,.014 - i * .018), (.005,.028,.004), rubber, .0015)
    for y, z in [(-.049,.087), (.061,.079), (.161,.049)]:
        cylinder("Receiver pin", (side * .035,y,z), .006, .006, edges, "X", 12, .001)

box("Ejection port", (.038,.073,.113), (.009,.100,.031), rubber)
box("Port cover", (.045,.078,.101), (.011,.092,.018), edges, .002)
box("Selector lever", (-.041,-.016,.079), (.012,.034,.009), edges, .002).rotation_euler.x = radians(-30)
for i in range(3):
    box("Selector marking", (-.037,-.038 + i * .012,.096), (.002,.005,.003), accent, .0005)
box("Rear sight", (0,-.002,.181), (.047,.054,.029), steel)
for side in (-1, 1):
    box("Rear sight ear", (side * .018,-.005,.202), (.012,.032,.024), edges, .003)
profile("Front sight", [(.42,.125), (.451,.125), (.448,.201), (.434,.208), (.43,.177), (.414,.151)], .032, steel, .003)

cylinder("Visible barrel", (0,.493,.103), .017, .115, edges)
cylinder("Suppressor collar", (0,.532,.103), .037, .055, edges)
cylinder("Matte suppressor", (0,.669,.103), .036, .259, steel, bevel=.006)
for y in (.558,.574,.776,.792):
    cylinder("Suppressor band", (0,y,.103), .037, .010, edges, bevel=.001)
cylinder("Dark muzzle face", (0,.801,.103), .029, .008, rubber, bevel=.002)
cylinder("Muzzle inset", (0,.806,.103), .012, .003, material("Muzzle shadow", (.004,.005,.006), 0, 1), bevel=0)
muzzle = bpy.data.objects.new("M4A1Muzzle", None)
muzzle.location = (0, .813, .103)
bpy.context.collection.objects.link(muzzle)

assets = ROOT / "assets" / "weapons"
assets.mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "blender" / "m4a1.blend"))

# Keep editable parts in the .blend and batch surfaces by material in the game.
groups = {}
for obj in list(bpy.context.scene.objects):
    if obj.type != "MESH":
        continue
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    groups.setdefault(obj.data.materials[0].name, []).append(obj)
for name, objects in groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    bpy.context.object.name = name
bpy.ops.export_scene.gltf(filepath=str(assets / "m4a1.glb"), export_apply=True)

# Render the exterior prop for inspection, with the inspection rig kept out of both assets.
bpy.ops.object.camera_add(location=(1.65, 1.08, .83))
camera = bpy.context.object
camera.rotation_euler = (Vector((0,.245,.042)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 1.36
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.studiolight_rotate_z = .65
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = "BOTH"
scene.display.shading.show_shadows = True
scene.display.shading.background_type = "WORLD"
scene.world = bpy.data.worlds.new("Dark studio")
scene.world.color = (.105, .12, .15)
scene.render.resolution_x = 1280
scene.render.resolution_y = 650
scene.render.resolution_percentage = 100
scene.render.filepath = str(ROOT / "build" / "2026.11.27.7" / "m4a1-preview.png")
bpy.ops.render.render(write_still=True)
