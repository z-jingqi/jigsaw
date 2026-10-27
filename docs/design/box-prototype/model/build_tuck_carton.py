"""Reproducible Blender 4.3 tuck carton. No downloaded models/textures.
Run: blender -b --python this_file -- --repo /path/to/jigsaw --qa /path/to/output
Authored coordinates are Godot (Y up, artwork +Z); export conversion is explicit.
"""
import argparse
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector, Quaternion

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
p = argparse.ArgumentParser()
p.add_argument('--repo', required=True)
p.add_argument('--qa', required=True)
a = p.parse_args(args)
repo, qa = Path(a.repo), Path(a.qa)
qa.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for block in list(bpy.data.materials): bpy.data.materials.remove(block)

# Blender Z-up -> glTF Y-up maps (x,-z,y) back to requested Godot (x,y,z).
def coord(v): return Vector((v[0], -v[2], v[1]))
def node(name, pos=(0,0,0), parent=None):
    obj=bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location=coord(pos)
    obj.parent=parent
    obj.empty_display_size=.1
    return obj

def color_mat(name, color, roughness=1):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=(*color,1)
    mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=roughness
    bs.inputs['Specular IOR Level'].default_value=.18
    return mat

white=color_mat('Matte white exterior', (.89,.885,.865))
kraft=color_mat('Dark golden kraft paper', (.42,.265,.105))
edge=color_mat('Kraft cut edge', (.36,.22,.075))
fold=color_mat('Restrained fold impression', (.53,.42,.28))
# Procedural inspection-only fibers. glTF keeps plain material slots; Godot supplies
# its own procedural paper shader later. No bitmap generation, painting or baking.
noise=kraft.node_tree.nodes.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value=185
noise.inputs['Detail'].default_value=2
noise.inputs['Roughness'].default_value=.72
bump=kraft.node_tree.nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value=.085
bump.inputs['Distance'].default_value=.018
kraft.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height'])
kraft.node_tree.links.new(bump.outputs['Normal'],kraft.node_tree.nodes.get('Principled BSDF').inputs['Normal'])

root=node('TuckCarton')
# Thin, individually constructed polygon shells, never a primitive cube assembly.
def panel(name, points, normal, parent=root, thickness=.018, bevel=.003):
    n=Vector(normal)
    if (Vector(points[1])-Vector(points[0])).cross(Vector(points[2])-Vector(points[0])).dot(n)<0:
        points=list(reversed(points))
    verts=[coord(Vector(v)+n*thickness*.5) for v in points]
    verts += [coord(Vector(v)-n*thickness*.5) for v in points]
    count=len(points)
    faces=[tuple(range(count)),tuple(reversed(range(count,count*2)))]
    for i in range(count):
        j=(i+1)%count
        faces.append((i,j,j+count,i+count))
    mesh=bpy.data.meshes.new(name+' thin board mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent=parent
    for material in [white,kraft,edge]: obj.data.materials.append(material)
    for face in obj.data.polygons:
        face.material_index=0 if face.index==0 else (1 if face.index==1 else 2)
    # UV each broad face in its two meaningful axes, fixed and portable.
    uv=obj.data.uv_layers.new(name='PaperUV')
    for face in obj.data.polygons:
        for loop in face.loop_indices:
            v=Vector(points[obj.data.loops[loop].vertex_index%count])
            uv.data[loop].uv=((v.x+1.125)/2.25, v.y/3 if abs(n.z)>.5 else (v.z+.24)/.48)
    mod=obj.modifiers.new('Paper cut micro bevel','BEVEL')
    mod.width=bevel; mod.segments=2
    mod.affect='EDGES'
    mod=obj.modifiers.new('Weighted paper normals','WEIGHTED_NORMAL')
    return obj

# Clockwise viewed from outer side is corrected consistently by normal generation.
front=panel('FrontBoard',[(-1.125,0,.24),(1.125,0,.24),(1.125,3,.24),(-1.125,3,.24)],(0,0,1))
back=panel('BackBoard',[(1.125,0,-.24),(-1.125,0,-.24),(-1.125,3,-.24),(1.125,3,-.24)],(0,0,-1))
left=panel('LeftBoard',[(-1.125,0,-.231),(-1.125,0,.231),(-1.125,3,.231),(-1.125,3,-.231)],(-1,0,0))
right=panel('RightBoard',[(1.125,0,.231),(1.125,0,-.231),(1.125,3,-.231),(1.125,3,.231)],(1,0,0))
bottom=panel('BottomClosure',[(-1.116,.009,-.231),(1.116,.009,-.231),(1.116,.009,.231),(-1.116,.009,.231)],(0,-1,0))
# Artwork is a fixed full 3:4 rectangle; exact full-range UV, no camera bake.
mesh=bpy.data.meshes.new('FrontArtwork UV0 full rectangle')
mesh.from_pydata([coord(v) for v in [(-1.125,0,.251),(1.125,0,.251),(1.125,3,.251),(-1.125,3,.251)]],[],[(0,1,2,3)])
mesh.update()
art=bpy.data.objects.new('FrontArtwork',mesh)
bpy.context.collection.objects.link(art); art.parent=root
art.data.materials.append(white)
uv=mesh.uv_layers.new(name='UVMap')
for i,value in enumerate([(0,0),(1,0),(1,1),(0,1)]): uv.data[i].uv=value

# Main opening is ONLY .48-deep narrow top lid, not the 3-high front face.
top=node('TopFlapPivot',(0,3.016,-.24),root)
top_board=panel('TopFlap',[(-1.116,0,0),(1.116,0,0),(1.116,0,.48),(-1.116,0,.48)],(0,1,0),top)
# Rounded tuck tongue hanging inside front when closed; hinge independently unfolds.
tab=node('TuckTab',(0,0,.460),top)
r=.09; width=2.04; depth=.35
outline=[(-width/2,0),(width/2,0),(width/2,-depth+r)]
for i in range(1,7):
    theta=-math.pi/2*i/6
    outline.append((width/2-r+r*math.cos(theta),-depth+r+r*math.sin(theta)))
outline.append((-width/2+r,-depth))
for i in range(1,7):
    theta=-math.pi/2-math.pi/2*i/6
    outline.append((-width/2+r+r*math.cos(theta),-depth+r+r*math.sin(theta)))
outline.append((-width/2,0))
tongue=panel('RoundedTuckTongue',[(x,y,0) for x,y in outline[:-1]],(0,0,1),tab,bevel=.002)
# Two dust ears are tapered thin flaps, separate hinge nodes from the top lid.
ear_l=node('SideEarLeft',(-1.116,2.992,0),root)
ear_r=node('SideEarRight',(1.116,2.992,0),root)
for name, parent, sign in [('LeftDustEar',ear_l,1),('RightDustEar',ear_r,-1)]:
    points=[(0,0,-.22),(sign*.40,0,-.15),(sign*.46,0,.14),(0,0,.22)]
    if sign<0: points.reverse()
    panel(name,points,(0,1,0),parent,thickness=.014,bevel=.002)
# Fine scored hinge bands represented by shallow strips, never heavy black lines.
def crease(name, points, normal, parent):
    obj=panel(name,points,normal,parent,thickness=.0015,bevel=.0005)
    for i in range(len(obj.data.materials)): obj.data.materials[i]=fold
    return obj
crease('TopHingeScore',[(-1.10,.011,-.003),(1.10,.011,-.003),(1.10,.011,.003),(-1.10,.011,.003)],(0,1,0),top)
crease('TabHingeScore',[(-1.01,-.003,.010),(1.01,-.003,.010),(1.01,.003,.010),(-1.01,.003,.010)],(0,0,1),tab)
# Subtle manufacture glue seam is on back/side, not drawn across front artwork.
seam=panel('RearGlueSeam',[(.96,.03,-.252),(1.10,.03,-.252),(1.10,2.97,-.252),(.96,2.97,-.252)],(0,0,-1),thickness=.003,bevel=.001)

# Apply small bevels before export; source blend keeps all editable panel objects.
for obj in list(bpy.context.scene.objects):
    if obj.type=='MESH':
        bpy.context.view_layer.objects.active=obj
        obj.select_set(True)
        for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.select_set(False)

def pose(opened):
    top.rotation_mode='QUATERNION'; tab.rotation_mode='QUATERNION'
    ear_l.rotation_mode='QUATERNION'; ear_r.rotation_mode='QUATERNION'
    top.rotation_quaternion=Quaternion(coord((1,0,0)),math.radians(-105 if opened else 0))
    tab.rotation_quaternion=Quaternion(coord((1,0,0)),math.radians(-82 if opened else 0))
    ear_l.rotation_quaternion=Quaternion(coord((0,0,1)),math.radians(64 if opened else 0))
    ear_r.rotation_quaternion=Quaternion(coord((0,0,1)),math.radians(-64 if opened else 0))
pose(False)
for obj in bpy.context.scene.objects: obj.select_set(True)
output=repo/'assets/ui/box/tuck-carton.glb'
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(repo/'docs/design/box-prototype/model/tuck-carton.blend'))

# QA renders only: studio set is excluded from the already exported model and blend.
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=48; scene.cycles.use_denoising=False
scene.render.resolution_x=1100;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world.color=(.3,.3,.3)
scene.view_settings.view_transform='Standard'
scene.view_settings.look='Medium High Contrast'
scene.view_settings.exposure=0;scene.view_settings.gamma=1
world=bpy.data.worlds.new('QA warm studio');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.80,.79,.75,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5

def area(name,location,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.location=coord(location)
    obj.rotation_euler=(coord((0,1.5,0))-obj.location).to_track_quat('-Z','Y').to_euler()
area('Soft key',(-3,5,6),350,5)
area('Soft rim',(4,4,-2),180,4)
cam_data=bpy.data.cameras.new('QA Camera');cam=bpy.data.objects.new('QA Camera',cam_data)
bpy.context.collection.objects.link(cam);scene.camera=cam;cam_data.type='ORTHO';cam_data.ortho_scale=4.4

def render(name,location,target,opened):
    pose(opened);cam.location=coord(location);cam.rotation_euler=(coord(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(qa/name);bpy.ops.render.render(write_still=True)
render('01-carton-closed-front.png',(0,1.55,8),(0,1.55,0),False)
cam_data.ortho_scale=5.1
render('02-carton-open-structure.png',(4.2,4.8,7.5),(0,1.95,0),True)
print('TUCK_CARTON_EXPORT_OK',output)
