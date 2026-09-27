# Procedural Animation System (Godot 4 GDScript)

A real-time procedural animation and Inverse Kinematics (IK) locomotion system written purely in **GDScript** for Godot 4. Compatible with Godot 4.3 through 4.6+ Forward+ / Mobile / Compatibility renderers.

---

## Key Features

### 1. Analytical Two-Bone Inverse Kinematics (Zero-Twist)
- **Zero-Twist Pole Vector Orientation**: Calculates exact limb bend plane using projected pole hint vectors, eliminating gimbal lock and rotational bone pops.
- **Law of Cosines Solver**: Mathematically stable reach clamping and soft-stretch limits preventing numerical explosion at full limb extension.
- **Dual Support**: Operates seamlessly on both hierarchical `Node3D` limb rigs and `Skeleton3D` bone chains.
- **Ground Surface Normal Alignment**: Aligns foot orientation with terrain slope normals.

### 2. Biomechanical Procedural Locomotion Engine
- **Full Gait Cycle**:
  - **Swing Phase**: Smooth cubic Hermite horizontal progression with parabolic clearance height and dynamic foot pitch (toe push-off dip $\rightarrow$ mid-swing lift $\rightarrow$ heel-strike tilt).
  - **Stance Phase**: Ground-locked linear foot travel supporting character body weight with heel settling and toe takeoff roll.
- **Pelvis & Balance Dynamics**:
  - **Vertical Bobbing**: Frequency-doubled vertical oscillation simulating two step impacts per walk cycle.
  - **Lateral Sway**: Dynamic mass shifting toward the supporting planted foot.
  - **Hip Drop & Roll**: Natural pelvic tilt and yaw into the forward stepping foot.
  - **Turn Banking**: Centrifugal roll banking into sharp turns.
- **Torso & Spine Dynamics**:
  - Counter-rotational spine twisting opposing pelvic yaw for conservation of angular momentum.
  - Speed-scaled forward pitch lean.
- **Arm Dynamics**:
  - Contralateral coordination (left arm coordinates with right leg, right arm with left leg).
  - Apex vertical lift as arms swing outward.
- **Head Stabilization & Look-At**:
  - Stabilizes against torso counter-rotation so head remains forward-facing.
  - Optional 3D look-at target aiming with clamped pitch and yaw limits.

### 3. Physical Secondary Motion & Inertia
- **2nd-Order Spring-Mass-Damper Oscillators**:
  - Dynamic inertia, drag, and follow-through on the pelvis, chest, and head.
  - Landing impact absorption (hips compress on ground contact after falling and spring back organically).

### 4. Terrain Floor Raycasting (Ground Adaptation)
- Downward physics raycasts sample terrain elevation and surface normals under each foot.
- Automatically adjusts foot planting height for stairs, slopes, and uneven terrain.

### 5. Procedural Rig & Mannequin Generators
- **Biped Humanoid Mannequin**: Programmatically constructs a stylized cyberpunk mannequin character with PBR materials, glowing visor, and pre-wired 2-bone IK solvers.
- **Multi-Legged Spider / Mech Rig**: Generates arachnid / quadruped / hexapod rigs with alternating tripod gait stepping and ground tracking.

---

## Directory Structure

| File | Description |
| :--- | :--- |
| [`procedural_math.gd`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/procedural_math.gd) | Analytical 2-bone IK solver, `SpringDamper3D`/`SpringDamper1D`, Hermite curves, parabolic clearance |
| [`two_bone_ik_solver.gd`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/two_bone_ik_solver.gd) | Two-bone IK node component for `Node3D` hierarchies and `Skeleton3D` bones |
| [`procedural_engine.gd`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/procedural_engine.gd) | Core locomotion engine: gait cycles, pelvis sway, spine counter-rotation, arm swing, head tracking |
| [`procedural_rig_generator.gd`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/procedural_rig_generator.gd) | Programmatic generator for stylized biped mannequins and multi-legged spider rigs |
| [`procedural_locomotion_controller.gd`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/procedural_locomotion_controller.gd) | Plug-and-play character component node driving full procedural animation |
| [`procedural_spider_controller.gd`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/procedural_spider_controller.gd) | Multi-legged arachnid procedural locomotion controller with tripod gait |
| [`procedural_demo_player.gd`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/procedural_demo_player.gd) | Demo player controller with WASD movement, sprint, and jump |
| [`procedural_anim_demo.gd`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/procedural_anim_demo.gd) | Demo scene manager with live telemetry UI and interactive toggles |
| [`procedural_anim_demo.tscn`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/procedural_anim_demo.tscn) | Ready-to-play 3D demonstration scene with arena, platforms, lighting, and camera |
| [`test_procedural_animation.gd`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/test_procedural_animation.gd) | Complete unit test suite verifying math, IK convergence, 60-frame gait cycles, and rig generation |

---

## Quick Start Guide

### 1. Play the Demo Scene
Open and run [`res://procedural_animation/procedural_anim_demo.tscn`](file:///c:/Users/brand.BRANDON/Documents/GitHub/SuperBattleArenaGame/procedural_animation/procedural_anim_demo.tscn) in Godot:
- **WASD**: Walk / Move
- **Shift**: Sprint
- **Space**: Jump onto platforms / test landing impact recoil
- **HUD Buttons**: Toggle spring-damper dynamics or terrain raycasting in real-time

### 2. Adding Procedural Animation to Any Character
To add procedural locomotion to any existing `CharacterBody3D`:
1. Add a `ProceduralLocomotionController` node as a child of your character.
2. In the Godot Inspector, configure:
   - `Stride Length`: e.g. `0.65`
   - `Step Height`: e.g. `0.16`
   - `Walk Cycle Duration`: e.g. `0.65` s
   - `Use Springs`: `true` (enables organic secondary motion)
   - `Enable Terrain Raycast`: `true` (enables ground elevation and slope tracking)
3. If `auto_spawn_mannequin` is enabled, a stylized humanoid mannequin is automatically built and animated.
4. If you have custom limbs or a `Skeleton3D`, connect them to the `TwoBoneIKSolver3D` instances.
