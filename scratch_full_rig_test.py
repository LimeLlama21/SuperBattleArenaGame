import bpy, math, mathutils

arm = bpy.data.objects.get('Armature')
scene = bpy.context.scene
bpy.context.view_layer.objects.active = arm

# 1. Edit Mode Setup
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones

# Delete 6 zero length bones
for zb in ['Chest.001', 'Chest.002', 'Chest.003', 'Chest.004', 'Abdomen.005', 'Thigh.L.001']:
    if zb in eb:
        eb.remove(eb[zb])

# Pre-bend knees forward: in armature local space, Y = -0.4
# (Local -Y is character forward towards the toes)
eb['Thigh.L'].tail.y = -0.4
eb['Calf.L'].head.y = -0.4

eb['Thigh.R'].tail.y = -0.4
eb['Calf.R'].head.y = -0.4

# Set bone rolls to 0.0 so knee hinge axis is lateral X
eb['Thigh.L'].roll = 0.0
eb['Calf.L'].roll = 0.0
eb['Thigh.R'].roll = 0.0
eb['Calf.R'].roll = 0.0

# Foot parenting: Foot bones should be children of Calf bones!
eb['Foot.L'].parent = eb['Calf.L']
eb['Foot.L'].use_connect = False
eb['Foot.R'].parent = eb['Calf.R']
eb['Foot.R'].use_connect = False

# Board bone exists
board_bone = eb.get('Board')

# Setup foot_IK.L and knee_pole.L parented to Board
eb['foot_IK.L'].parent = board_bone if board_bone else eb['Root']

# Setup foot_IK.R and knee_pole.R
if 'foot_IK.R' not in eb:
    fik_r = eb.new('foot_IK.R')
    fik_r.head = [-eb['foot_IK.L'].head.x, eb['foot_IK.L'].head.y, eb['foot_IK.L'].head.z]
    fik_r.tail = [-eb['foot_IK.L'].tail.x, eb['foot_IK.L'].tail.y, eb['foot_IK.L'].tail.z]
    fik_r.use_deform = False
    fik_r.parent = board_bone if board_bone else eb['Root']

if 'knee_pole.L' not in eb:
    kp_l = eb.new('knee_pole.L')
else:
    kp_l = eb['knee_pole.L']
kp_l.head = [eb['Thigh.L'].tail.x, -2.5, eb['Thigh.L'].tail.z]
kp_l.tail = [eb['Thigh.L'].tail.x, -3.5, eb['Thigh.L'].tail.z]
kp_l.use_deform = False
kp_l.parent = board_bone if board_bone else eb['Root']

if 'knee_pole.R' not in eb:
    kp_r = eb.new('knee_pole.R')
else:
    kp_r = eb['knee_pole.R']
kp_r.head = [-eb['Thigh.L'].tail.x, -2.5, eb['Thigh.L'].tail.z]
kp_r.tail = [-eb['Thigh.L'].tail.x, -3.5, eb['Thigh.L'].tail.z]
kp_r.use_deform = False
kp_r.parent = board_bone if board_bone else eb['Root']

bpy.ops.object.mode_set(mode='POSE')

# Reset all pose bones
for pb in arm.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_euler = (0, 0, 0)

# Configure IK constraints
# Left Leg
c_ik_l = arm.pose.bones['Calf.L'].constraints.get('IK')
if not c_ik_l:
    c_ik_l = arm.pose.bones['Calf.L'].constraints.new('IK')
c_ik_l.target = arm
c_ik_l.subtarget = 'foot_IK.L'
c_ik_l.pole_target = arm
c_ik_l.pole_subtarget = 'knee_pole.L'
c_ik_l.chain_count = 2
c_ik_l.pole_angle = math.radians(-90)

# Right Leg
c_ik_r = arm.pose.bones['Calf.R'].constraints.get('IK')
if not c_ik_r:
    c_ik_r = arm.pose.bones['Calf.R'].constraints.new('IK')
c_ik_r.target = arm
c_ik_r.subtarget = 'foot_IK.R'
c_ik_r.pole_target = arm
c_ik_r.pole_subtarget = 'knee_pole.R'
c_ik_r.chain_count = 2
c_ik_r.pole_angle = math.radians(-90)

# Foot Copy Rotation constraints
c_rot_l = arm.pose.bones['Foot.L'].constraints.get('Copy Rotation')
if not c_rot_l:
    c_rot_l = arm.pose.bones['Foot.L'].constraints.new('COPY_ROTATION')
c_rot_l.target = arm
c_rot_l.subtarget = 'foot_IK.L'

c_rot_r = arm.pose.bones['Foot.R'].constraints.get('Copy Rotation')
if not c_rot_r:
    c_rot_r = arm.pose.bones['Foot.R'].constraints.new('COPY_ROTATION')
c_rot_r.target = arm
c_rot_r.subtarget = 'foot_IK.R'

# Lock Hip.L and Hip.R rotation in pose mode so hips don't flop around
arm.pose.bones['Hip.L'].lock_rotation = (True, True, True)
arm.pose.bones['Hip.R'].lock_rotation = (True, True, True)

# Test crouch pose:
arm.pose.bones['Abdomen'].location.z = -0.4
bpy.context.view_layer.update()

# Render a view of this crouch pose to verify visually
scene.render.engine = 'BLENDER_WORKBENCH'
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.filepath = r'c:\Users\brand.BRANDON\Documents\GitHub\SuperBattleArenaGame\crouch_render_test.png'

cam_data = bpy.data.cameras.new('TempCamCrouch')
cam_obj = bpy.data.objects.new('TempCamCrouch', cam_data)
scene.collection.objects.link(cam_obj)

cam_obj.location = (-2.5, -2.5, 1.2)
target = (-0.2, 0.0, 0.8)
direction = mathutils.Vector(target) - mathutils.Vector(cam_obj.location)
cam_obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

old_cam = scene.camera
scene.camera = cam_obj

bpy.ops.render.render(write_still=True)

scene.camera = old_cam
scene.collection.objects.unlink(cam_obj)
bpy.data.objects.remove(cam_obj)
bpy.data.cameras.remove(cam_data)

# Put Abdomen back to 0 for rest
arm.pose.bones['Abdomen'].location = (0, 0, 0)
bpy.context.view_layer.update()

print("TEST_AND_RENDER_COMPLETE")
