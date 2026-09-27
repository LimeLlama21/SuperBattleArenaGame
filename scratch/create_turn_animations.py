import bpy
from mathutils import Vector, Euler, Quaternion
import math

blend_path = r"C:\Users\brand.BRANDON\Documents\Diversion\SuperBattleArena\Cleodolinda.blend"
bpy.ops.wm.open_mainfile(filepath=blend_path)

arm = bpy.data.objects.get('Armature')
if not arm:
    raise ValueError("Armature object not found")

# Ensure knee limits allow backwards bending
for bname in ['Calf.L', 'Calf.R']:
    c = arm.pose.bones[bname].constraints.get('Limit Knee Hinge')
    if c:
        c.min_x = 0.0
        c.max_x = math.radians(150.0)
        c.use_limit_x = True

pb_root = arm.pose.bones['Root']
pb_thigh_l = arm.pose.bones['Thigh.L']
pb_thigh_r = arm.pose.bones['Thigh.R']
pb_calf_l = arm.pose.bones['Calf.L']
pb_calf_r = arm.pose.bones['Calf.R']
pb_chest = arm.pose.bones['Chest']
pb_board = arm.pose.bones['Board']
pb_hip_l = arm.pose.bones['Hip.L']
pb_hip_r = arm.pose.bones['Hip.R']
pb_abdomen = arm.pose.bones['Abdomen']
pb_foot_l = arm.pose.bones['Foot.L']

# Set rotation modes
pb_root.rotation_mode = 'QUATERNION'
pb_thigh_l.rotation_mode = 'XYZ'
pb_thigh_r.rotation_mode = 'XYZ'
pb_calf_l.rotation_mode = 'XYZ'
pb_calf_r.rotation_mode = 'XYZ'
pb_chest.rotation_mode = 'QUATERNION'
pb_board.rotation_mode = 'QUATERNION'
pb_hip_l.rotation_mode = 'QUATERNION'
pb_hip_r.rotation_mode = 'QUATERNION'
pb_abdomen.rotation_mode = 'QUATERNION'

# Measure neutral rest pose
for pb in arm.pose.bones:
    pb.location = Vector((0, 0, 0))
    if pb.rotation_mode == 'QUATERNION':
        pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
    else:
        pb.rotation_euler = Euler((0, 0, 0), pb.rotation_mode)
bpy.context.view_layer.update()

foot_rest = arm.matrix_world @ pb_foot_l.matrix.translation

# Ensure Idle has fake user
act_idle = bpy.data.actions.get('Idle')
if act_idle:
    act_idle.use_fake_user = True

def build_turn_action(action_name, apex_thigh, apex_calf, apex_chest, apex_board):
    # Remove existing action if already created
    old_act = bpy.data.actions.get(action_name)
    if old_act:
        bpy.data.actions.remove(old_act)
        
    action = bpy.data.actions.new(name=action_name)
    action.use_fake_user = True
    arm.animation_data.action = action
    
    # 5 Keyframes across 60 frames:
    # Frame 1:  Neutral (0.0)
    # Frame 15: Halfway into turn (0.5 * apex)
    # Frame 30: Peak Exaggerated Turn Apex (1.0 * apex) -> Decelerates to 0 (harmonic apex)
    # Frame 45: Halfway returning (0.5 * apex)
    # Frame 60: Neutral (0.0) -> Matches Frame 1 seamlessly
    frames_data = [
        (1,  0.0),
        (15, 0.7071),  # sin(pi/4) = 0.7071 for exact harmonic half-quarter
        (30, 1.0),
        (45, 0.7071),
        (60, 0.0)
    ]
    
    for frame, factor in frames_data:
        t_deg = apex_thigh * factor
        k_deg = apex_calf * factor
        c_deg = apex_chest * factor
        b_deg = apex_board * factor
        
        # 1. Root locked
        pb_root.location = Vector((0, 0, 0))
        pb_root.rotation_quaternion = Quaternion((1, 0, 0, 0))
        pb_root.keyframe_insert("location", frame=frame)
        pb_root.keyframe_insert("rotation_quaternion", frame=frame)
        
        # 2. Hips locked relative to spine
        pb_hip_l.rotation_quaternion = Quaternion((1, 0, 0, 0))
        pb_hip_r.rotation_quaternion = Quaternion((1, 0, 0, 0))
        pb_abdomen.rotation_quaternion = Quaternion((1, 0, 0, 0))
        pb_hip_l.keyframe_insert("rotation_quaternion", frame=frame)
        pb_hip_r.keyframe_insert("rotation_quaternion", frame=frame)
        pb_abdomen.keyframe_insert("rotation_quaternion", frame=frame)
        
        # 3. Thighs
        rad_t = math.radians(t_deg)
        pb_thigh_l.rotation_euler = Euler((rad_t, 0, 0), 'XYZ')
        pb_thigh_r.rotation_euler = Euler((rad_t, 0, 0), 'XYZ')
        pb_thigh_l.keyframe_insert("rotation_euler", frame=frame)
        pb_thigh_r.keyframe_insert("rotation_euler", frame=frame)
        
        # 4. Calves (backward knee bend)
        rad_k = math.radians(k_deg)
        pb_calf_l.rotation_euler = Euler((rad_k, 0, 0), 'XYZ')
        pb_calf_r.rotation_euler = Euler((rad_k, 0, 0), 'XYZ')
        pb_calf_l.keyframe_insert("rotation_euler", frame=frame)
        pb_calf_r.keyframe_insert("rotation_euler", frame=frame)
        
        # 5. Chest (upper body rotates in same circular direction, but less)
        rad_c = math.radians(c_deg)
        pb_chest.rotation_quaternion = Quaternion((1, 0, 0), rad_c)
        pb_chest.keyframe_insert("rotation_quaternion", frame=frame)
        
        # 6. Board follows foot position
        bpy.context.view_layer.update()
        foot_pos = arm.matrix_world @ pb_foot_l.matrix.translation
        foot_disp = foot_pos - foot_rest
        
        rad_b = math.radians(b_deg)
        pb_board.rotation_quaternion = Quaternion((0, 1, 0), rad_b)
        dY_arm = foot_disp.y / arm.scale.y
        dZ_arm = foot_disp.z / arm.scale.z
        pb_board.location = Vector((-dY_arm, 0.0, dZ_arm))
        pb_board.keyframe_insert("rotation_quaternion", frame=frame)
        pb_board.keyframe_insert("location", frame=frame)

    # Tangent smoothing: Harmonic pendulum handles
    for layer in action.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                for fc in cb.fcurves:
                    kps = fc.keyframe_points
                    if len(kps) == 5:
                        kp_1 = kps[0]
                        kp_15 = kps[1]
                        kp_30 = kps[2]
                        kp_45 = kps[3]
                        kp_60 = kps[4]
                        
                        dt = 14.5 / 3.0
                        
                        # 1. Apex at Frame 30: horizontal turnaround (v = 0)
                        kp_30.handle_left_type = 'ALIGNED'
                        kp_30.handle_right_type = 'ALIGNED'
                        kp_30.handle_left = Vector((30.0 - dt, kp_30.co[1]))
                        kp_30.handle_right = Vector((30.0 + dt, kp_30.co[1]))
                        
                        # Frame 15 and 45 automatic aligned tangents for smooth harmonic curve
                        kp_15.handle_left_type = 'AUTO'
                        kp_15.handle_right_type = 'AUTO'
                        kp_45.handle_left_type = 'AUTO'
                        kp_45.handle_right_type = 'AUTO'
                        
                        # Frame 1 and 60: aligned loop restart
                        s_start = (kp_15.co[1] - kp_1.co[1]) / 14.0
                        s_end = (kp_60.co[1] - kp_45.co[1]) / 15.0
                        
                        kp_1.handle_left_type = 'ALIGNED'
                        kp_1.handle_right_type = 'ALIGNED'
                        kp_1.handle_left = Vector((1.0 - dt, kp_1.co[1] - s_start * dt))
                        kp_1.handle_right = Vector((1.0 + dt, kp_1.co[1] + s_start * dt))
                        
                        kp_60.handle_left_type = 'ALIGNED'
                        kp_60.handle_right_type = 'ALIGNED'
                        kp_60.handle_left = Vector((60.0 - dt, kp_60.co[1] - s_end * dt))
                        kp_60.handle_right = Vector((60.0 + dt, kp_60.co[1] + s_end * dt))
                        
    print(f"Action '{action_name}' built successfully.")
    return action

# Build Side 1: Forward Lean Turn (Toe-side)
# In Idle: -6.5 thigh, +3.5 calf, -2.0 chest, -6.5 board
# In Exaggerated Turn: -20.0 thigh, +12.0 calf, -7.0 chest, -22.0 board
act_side1 = build_turn_action("Turn_Side1", apex_thigh=-20.0, apex_calf=+12.0, apex_chest=-7.0, apex_board=-22.0)

# Build Side 2: Backward Lean Turn (Heel-side)
# In Idle: +2.0 thigh, +4.5 calf, +2.0 chest, +6.5 board
# In Exaggerated Turn: +7.0 thigh, +20.0 calf, +7.0 chest, +22.0 board
act_side2 = build_turn_action("Turn_Side2", apex_thigh=+7.0, apex_calf=+20.0, apex_chest=+7.0, apex_board=+22.0)

# Leave Idle as default active action
arm.animation_data.action = act_idle

# Reset pose
for pb in arm.pose.bones:
    pb.location = Vector((0, 0, 0))
    if pb.rotation_mode == 'QUATERNION':
        pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
    else:
        pb.rotation_euler = Euler((0, 0, 0), pb.rotation_mode)
bpy.context.view_layer.update()

bpy.ops.wm.save_mainfile()
print("Saved Cleodolinda.blend with Turn_Side1 and Turn_Side2 actions!")
