import bpy
import sys
from mathutils import Vector


args = sys.argv[sys.argv.index("--") + 1 :]
glb_path, icon_path = args

for obj in list(bpy.data.objects):
    if obj.type in {"CAMERA", "LIGHT"}:
        bpy.data.objects.remove(obj, do_unlink=True)
    else:
        obj.hide_render = False
        obj.hide_set(False)

mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
if not mesh_objects:
    raise RuntimeError("No mesh objects found")

corners = [obj.matrix_world @ Vector(corner) for obj in mesh_objects for corner in obj.bound_box]
minimum = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
maximum = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
center = (minimum + maximum) * 0.5
size = maximum - minimum
largest = max(size.x, size.y, size.z)

bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format="GLB",
    export_apply=True,
    export_cameras=False,
    export_lights=False,
)

camera_data = bpy.data.cameras.new("ItemIconCamera")
camera = bpy.data.objects.new("ItemIconCamera", camera_data)
bpy.context.scene.collection.objects.link(camera)
camera.location = center + Vector((1.35, -1.7, 1.1)) * largest
camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = largest * 1.45
bpy.context.scene.camera = camera

for name, offset, energy, size_m in [
    ("Key", (1.8, -2.0, 2.4), 700.0, 4.0),
    ("Fill", (-2.0, -0.5, 1.0), 350.0, 3.0),
    ("Rim", (0.5, 2.0, 2.6), 500.0, 3.0),
]:
    light_data = bpy.data.lights.new(name, "AREA")
    light_data.energy = energy
    light_data.shape = "DISK"
    light_data.size = size_m
    light = bpy.data.objects.new(name, light_data)
    bpy.context.scene.collection.objects.link(light)
    light.location = center + Vector(offset) * largest
    light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.render.filepath = icon_path
scene.render.image_settings.color_depth = "8"
scene.world.color = (0.035, 0.035, 0.045)
bpy.ops.render.render(write_still=True)

print(f"EXPORT_BOUNDS center={tuple(round(v, 4) for v in center)} size={tuple(round(v, 4) for v in size)}")
