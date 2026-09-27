# Body (Quaternius Universal Animation Library, Standard) inspection

Made by parsing the glTF JSON chunk of each `.glb` with Python (no engine import). Units are metres.

Source: Quaternius, "Universal Animation Library" and "Universal Animation Library 2", free Standard versions
(https://quaternius.itch.io/universal-animation-library, https://quaternius.itch.io/universal-animation-library-2).
Both itch pages list "Asset license: Creative Commons Zero v1.0 Universal" and both zips ship `License.txt` (CC0 1.0),
copied here as `LICENSE.txt`. Both files were exported by "Khronos glTF Blender I/O v4.5.48" and are the builds without root motion
(`Unreal-Godot/UAL1_Standard.glb`, `Unreal-Godot/UAL2_Standard.glb`, pack versions v3.0 and v2.1). The `_RM` root motion builds were not copied.

## Files

| File | Bytes | What |
|---|---|---|
| `UAL1_Standard.glb` | 7,618,436 | `Mannequin` skinned mesh on a 65-joint humanoid rig, 43 animations, no textures |
| `UAL2_Standard.glb` | 8,091,444 | The same `Mannequin` mesh on the same rig (identical joint names and rest pose), 43 more animations (sword combos, block, knockback) |
| `LICENSE.txt` | 332 | The packs' CC0 license text (byte-identical in both zips) |

Because both files use one rig, the UAL2 clips play on the UAL1 mannequin directly: no retargeting is needed between them.
Only the KayKit clips need retargeting (mapping below).

Rest pose check: the largest difference of any joint world matrix between the two files is 0.0e+00.

## Height, up axis, facing

- Up axis: **+Y**. Feet at Y = 0.000, top of head at Y = **1.829**, so the body is about 1.83 m tall at real scale (no rescale needed).
- Facing: **+Z** (toe joints `ball_l/r` are ahead of `foot_l/r` on +Z; the face is on +Z). The character's left side is **+X**,
  right side -X. This is the same convention as the KayKit knight, so the two rigs face the same way.
- Rest pose: **T pose**, arms straight out along X at shoulder height (Y 1.441), palms down. Width fingertip to fingertip 1.944.
- Mesh bounds: X -0.972..0.972, Y 0.000..1.829, Z -0.164..0.205.
- Node transforms: `Armature` and `Mannequin` are identity. `root` has rotation (-0.7071, 0, 0, 0.7071), i.e. -90 degrees about X
  (the usual Blender Z-up armature), so bone-local axes under `root` are Blender style (in `pelvis` translation keys, local +Z is world up).
- The inverse bind matrices match the node rest pose (max difference 7.4e-07), so rest pose = bind pose.

## Rest pose world positions

| Part | Left joint | Left (x, y, z) | Right joint | Right (x, y, z) |
|---|---|---|---|---|
| Root | `root` | (0.000, 0.000, 0.000) | | |
| Hips | `pelvis` | (0.000, 0.917, -0.050) | | |
| Spine | `spine_01` | (0.000, 1.051, -0.016) | | |
| Chest | `spine_02` | (0.000, 1.174, -0.000) | | |
| Upper chest | `spine_03` | (0.000, 1.315, -0.005) | | |
| Neck | `neck_01` | (0.000, 1.488, -0.011) | | |
| Head | `Head` | (0.000, 1.569, 0.005) | | |
| Shoulder (clavicle) | `clavicle_l` | (0.019, 1.458, 0.071) | `clavicle_r` | (-0.019, 1.458, 0.071) |
| Upper arm | `upperarm_l` | (0.192, 1.441, -0.065) | `upperarm_r` | (-0.192, 1.441, -0.065) |
| Forearm (elbow) | `lowerarm_l` | (0.466, 1.441, -0.070) | `lowerarm_r` | (-0.466, 1.441, -0.070) |
| Hand (wrist) | `hand_l` | (0.739, 1.441, -0.065) | `hand_r` | (-0.739, 1.441, -0.065) |
| Middle finger base | `middle_01_l` | (0.860, 1.441, -0.060) | `middle_01_r` | (-0.860, 1.441, -0.060) |
| Middle finger tip | `middle_04_leaf_l` | (0.971, 1.441, -0.065) | `middle_04_leaf_r` | (-0.971, 1.441, -0.065) |
| Thigh (hip joint) | `thigh_l` | (0.089, 0.932, 0.001) | `thigh_r` | (-0.089, 0.932, 0.001) |
| Shin (knee) | `calf_l` | (0.089, 0.532, -0.001) | `calf_r` | (-0.089, 0.532, -0.001) |
| Foot (ankle) | `foot_l` | (0.089, 0.104, -0.036) | `foot_r` | (-0.089, 0.104, -0.036) |
| Toes (ball) | `ball_l` | (0.089, 0.015, 0.113) | `ball_r` | (-0.089, 0.015, 0.113) |
| Toe tip | `ball_leaf_l` | (0.089, 0.015, 0.192) | `ball_leaf_r` | (-0.089, 0.015, 0.192) |

Segment lengths: upper arm 0.274, forearm 0.273, thigh 0.400, shin 0.429, pelvis to neck 0.571, head joint to top of mesh 0.260.
Adult human proportions: the head is roughly 1/7 of the height and the hip joints sit at about half height.
For comparison the KayKit knight has hips at 0.406 of 2.467 (chibi); scaled by 0.73 it would still have hips at 0.30 m versus 0.92 m here.

## Skeleton (skin "Armature", 65 joints, in skin order)

`root`, `pelvis`, `spine_01`, `spine_02`, `spine_03`, `neck_01`, `Head`, `clavicle_l`, `upperarm_l`, `lowerarm_l`, `hand_l`, `index_01_l`, `index_02_l`, `index_03_l`, `index_04_leaf_l`, `middle_01_l`, `middle_02_l`, `middle_03_l`, `middle_04_leaf_l`, `pinky_01_l`, `pinky_02_l`, `pinky_03_l`, `pinky_04_leaf_l`, `ring_01_l`, `ring_02_l`, `ring_03_l`, `ring_04_leaf_l`, `thumb_01_l`, `thumb_02_l`, `thumb_03_l`, `thumb_04_leaf_l`, `clavicle_r`, `upperarm_r`, `lowerarm_r`, `hand_r`, `index_01_r`, `index_02_r`, `index_03_r`, `index_04_leaf_r`, `middle_01_r`, `middle_02_r`, `middle_03_r`, `middle_04_leaf_r`, `pinky_01_r`, `pinky_02_r`, `pinky_03_r`, `pinky_04_leaf_r`, `ring_01_r`, `ring_02_r`, `ring_03_r`, `ring_04_leaf_r`, `thumb_01_r`, `thumb_02_r`, `thumb_03_r`, `thumb_04_leaf_r`, `thigh_l`, `calf_l`, `foot_l`, `ball_l`, `ball_leaf_l`, `thigh_r`, `calf_r`, `foot_r`, `ball_r`, `ball_leaf_r`

Hierarchy: `root > pelvis > spine_01 > spine_02 > spine_03`; `spine_03` parents `neck_01 > Head` and `clavicle_l/r > upperarm > lowerarm > hand > fingers`;
`pelvis` parents `thigh_l/r > calf > foot > ball > ball_leaf`. Fingers per hand: `thumb`, `index`, `middle`, `ring`, `pinky`, each `_01`, `_02`, `_03`, `_04_leaf`.

52 joints carry vertex weights. The 13 without weights: `root`, `index_04_leaf_l`, `middle_04_leaf_l`, `pinky_04_leaf_l`, `ring_04_leaf_l`, `thumb_04_leaf_l`, `index_04_leaf_r`, `middle_04_leaf_r`, `pinky_04_leaf_r`, `ring_04_leaf_r`, `thumb_04_leaf_r`, `ball_leaf_l`, `ball_leaf_r`.
There are no IK or control bones and no weapon socket bones; a sword can hang on a `BoneAttachment3D` on `hand_r`.

## Meshes and materials

One skinned mesh node `Mannequin` (mesh `Mannequin`, skin `Armature`) with two primitives. Both files hold the same mesh.

| Primitive | Material | Base colour (linear RGB) | Vertices | Triangles |
|---|---|---|---|---|
| 0 | `M_Main` | (0.799, 0.402, 0.042), metallic 0, roughness 0.5, double sided | 3389 | 5732 |
| 1 | `M_Joints` | (0.402, 0.133, 0.708), metallic 0, roughness 0.5, double sided | 5157 | 8012 |

Attributes: POSITION, NORMAL, TEXCOORD_0, TEXCOORD_1, JOINTS_0, WEIGHTS_0.
**No textures or images** in either file. `M_Main` is the orange outer shell of the mannequin, `M_Joints` the purple joint pieces.

## Animations

Duration = the largest `max` of the sampler input (time) accessors. 30 fps, LINEAR interpolation, rotation, translation and scale channels.
These are in place: `root` translation stays (0, 0, 0) in every clip; only `pelvis` moves (bob, lean, a roll that ends where it started).

### `UAL1_Standard.glb` (43)

| # | Animation | Duration (s) |
|---|---|---|
| 1 | `A_TPose` | 2.500 |
| 2 | `Crouch_Fwd_Loop` | 2.000 |
| 3 | `Crouch_Idle_Loop` | 2.933 |
| 4 | `Dance_Loop` | 1.000 |
| 5 | `Death01` | 2.400 |
| 6 | `Driving_Loop` | 1.667 |
| 7 | `Fixing_Kneeling` | 5.200 |
| 8 | `Hit_Chest` | 0.333 |
| 9 | `Hit_Head` | 0.433 |
| 10 | `Idle_Loop` | 2.500 |
| 11 | `Idle_Talking_Loop` | 2.933 |
| 12 | `Idle_Torch_Loop` | 1.267 |
| 13 | `Interact` | 2.000 |
| 14 | `Jog_Fwd_Loop` | 0.933 |
| 15 | `Jump_Land` | 1.267 |
| 16 | `Jump_Loop` | 2.500 |
| 17 | `Jump_Start` | 1.333 |
| 18 | `PickUp_Table` | 0.833 |
| 19 | `Pistol_Aim_Down` | 0.167 |
| 20 | `Pistol_Aim_Neutral` | 0.167 |
| 21 | `Pistol_Aim_Up` | 0.167 |
| 22 | `Pistol_Idle_Loop` | 1.667 |
| 23 | `Pistol_Reload` | 1.667 |
| 24 | `Pistol_Shoot` | 0.633 |
| 25 | `Punch_Cross` | 1.000 |
| 26 | `Punch_Jab` | 0.867 |
| 27 | `Push_Loop` | 2.667 |
| 28 | `Roll` | 1.467 |
| 29 | `Sitting_Enter` | 1.300 |
| 30 | `Sitting_Exit` | 1.033 |
| 31 | `Sitting_Idle_Loop` | 1.667 |
| 32 | `Sitting_Talking_Loop` | 2.933 |
| 33 | `Spell_Simple_Enter` | 0.533 |
| 34 | `Spell_Simple_Exit` | 0.433 |
| 35 | `Spell_Simple_Idle_Loop` | 2.100 |
| 36 | `Spell_Simple_Shoot` | 0.500 |
| 37 | `Sprint_Loop` | 0.667 |
| 38 | `Swim_Fwd_Loop` | 1.333 |
| 39 | `Swim_Idle_Loop` | 3.333 |
| 40 | `Sword_Attack` | 1.533 |
| 41 | `Sword_Idle` | 1.667 |
| 42 | `Walk_Formal_Loop` | 1.333 |
| 43 | `Walk_Loop` | 1.333 |

### `UAL2_Standard.glb` (43)

| # | Animation | Duration (s) |
|---|---|---|
| 1 | `A_TPose` | 2.500 |
| 2 | `Chest_Open` | 1.367 |
| 3 | `ClimbUp_1m` | 0.667 |
| 4 | `Consume` | 1.333 |
| 5 | `Farm_Harvest` | 2.500 |
| 6 | `Farm_PlantSeed` | 2.767 |
| 7 | `Farm_Watering` | 3.800 |
| 8 | `Hit_Knockback` | 0.833 |
| 9 | `Idle_FoldArms_Loop` | 2.500 |
| 10 | `Idle_Lantern_Loop` | 2.500 |
| 11 | `Idle_No_Loop` | 2.500 |
| 12 | `Idle_Rail_Call` | 2.500 |
| 13 | `Idle_Rail_Loop` | 2.500 |
| 14 | `Idle_Shield_Break` | 1.067 |
| 15 | `Idle_Shield_Loop` | 2.500 |
| 16 | `Idle_TalkingPhone_Loop` | 2.933 |
| 17 | `LayToIdle` | 1.533 |
| 18 | `Melee_Hook` | 0.467 |
| 19 | `Melee_Hook_Rec` | 0.600 |
| 20 | `NinjaJump_Idle_Loop` | 2.000 |
| 21 | `NinjaJump_Land` | 1.267 |
| 22 | `NinjaJump_Start` | 0.967 |
| 23 | `OverhandThrow` | 1.333 |
| 24 | `Shield_Dash` | 1.100 |
| 25 | `Shield_OneShot` | 0.833 |
| 26 | `Slide_Exit` | 0.500 |
| 27 | `Slide_Loop` | 2.000 |
| 28 | `Slide_Start` | 0.833 |
| 29 | `Sword_Block` | 1.233 |
| 30 | `Sword_Dash` | 1.567 |
| 31 | `Sword_Heavy_Combo` | 4.333 |
| 32 | `Sword_Regular_A` | 0.433 |
| 33 | `Sword_Regular_A_Rec` | 0.967 |
| 34 | `Sword_Regular_B` | 0.533 |
| 35 | `Sword_Regular_B_Rec` | 1.033 |
| 36 | `Sword_Regular_C` | 2.000 |
| 37 | `Sword_Regular_Combo` | 3.000 |
| 38 | `TreeChopping_Loop` | 0.967 |
| 39 | `Walk_Carry_Loop` | 2.000 |
| 40 | `Yes` | 2.500 |
| 41 | `Zombie_Idle_Loop` | 1.333 |
| 42 | `Zombie_Scratch` | 1.800 |
| 43 | `Zombie_Walk_Fwd_Loop` | 1.333 |

Clips useful for a sword duel:
- idle: `Sword_Idle`, `Idle_Loop`, `Idle_Shield_Loop`
- move: `Walk_Loop`, `Walk_Formal_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`, `Crouch_Fwd_Loop`
- attack: `Sword_Attack`, `Sword_Regular_A`, `Sword_Regular_B`, `Sword_Regular_C` (A and B have `_Rec` recoveries), `Sword_Regular_Combo`, `Sword_Heavy_Combo`, `Sword_Dash`, `Melee_Hook`, `Punch_Jab`, `Punch_Cross`
- defence: `Sword_Block`, `Idle_Shield_Break`, `Shield_OneShot`, `Shield_Dash`
- dodge: `Roll`; hit: `Hit_Chest`, `Hit_Head`, `Hit_Knockback`; death: `Death01`

**Not in the free Standard versions:** strafe, sideways and backwards walking (the store page advertises 8-direction locomotion, which must be in the paid Pro build; the free glb has none).
The KayKit knight has what is missing (`Running_Strafe_Left/Right`, `Walking_Backwards`, `Dodge_Forward/Backward/Left/Right`, `Block_Hit`),
which is why its clips get retargeted onto this body.

## Bone map to Godot `SkeletonProfileHumanoid`

Left/right are the character's own sides in all three (UAL `_l`, KayKit `.l` and Godot `Left*` are all on +X here).

| Godot profile bone | This body (UAL) | KayKit Knight |
|---|---|---|
| `Root` | `root` | `root` |
| `Hips` | `pelvis` | `hips` |
| `Spine` | `spine_01` | `spine` |
| `Chest` | `spine_02` | `chest` |
| `UpperChest` | `spine_03` | (none, leave empty) |
| `Neck` | `neck_01` | (none, leave empty) |
| `Head` | `Head` | `head` |
| `LeftShoulder` | `clavicle_l` | (none, leave empty) |
| `LeftUpperArm` | `upperarm_l` | `upperarm.l` |
| `LeftLowerArm` | `lowerarm_l` | `lowerarm.l` |
| `LeftHand` | `hand_l` | `hand.l` |
| `RightShoulder` | `clavicle_r` | (none, leave empty) |
| `RightUpperArm` | `upperarm_r` | `upperarm.r` |
| `RightLowerArm` | `lowerarm_r` | `lowerarm.r` |
| `RightHand` | `hand_r` | `hand.r` |
| `LeftUpperLeg` | `thigh_l` | `upperleg.l` |
| `LeftLowerLeg` | `calf_l` | `lowerleg.l` |
| `LeftFoot` | `foot_l` | `foot.l` |
| `LeftToes` | `ball_l` | `toes.l` |
| `RightUpperLeg` | `thigh_r` | `upperleg.r` |
| `RightLowerLeg` | `calf_r` | `lowerleg.r` |
| `RightFoot` | `foot_r` | `foot.r` |
| `RightToes` | `ball_r` | `toes.r` |

Fingers (UAL only; KayKit has no finger bones), shown for the left hand, the right hand is the same with `Right` and `_r`:

| Godot profile bone | UAL |
|---|---|
| `LeftThumbMetacarpal` | `thumb_01_l` |
| `LeftThumbProximal` | `thumb_02_l` |
| `LeftThumbDistal` | `thumb_03_l` |
| `LeftIndexProximal` | `index_01_l` |
| `LeftIndexIntermediate` | `index_02_l` |
| `LeftIndexDistal` | `index_03_l` |
| `LeftMiddleProximal` | `middle_01_l` |
| `LeftMiddleIntermediate` | `middle_02_l` |
| `LeftMiddleDistal` | `middle_03_l` |
| `LeftRingProximal` | `ring_01_l` |
| `LeftRingIntermediate` | `ring_02_l` |
| `LeftRingDistal` | `ring_03_l` |
| `LeftLittleProximal` | `pinky_01_l` |
| `LeftLittleIntermediate` | `pinky_02_l` |
| `LeftLittleDistal` | `pinky_03_l` |

Not mapped: UAL `*_04_leaf_*` and `ball_leaf_*` (unweighted tip bones). KayKit `wrist.l/r`, `handslot.l/r` and the 18 IK/control bones
(`kneeIK`, `control-*`, `heelIK`, `IK-*`, `elbowIK`, `handIK`).

Notes for the KayKit side:
- `LeftHand`/`RightHand` must be `hand.l`/`hand.r`, not `wrist.l`/`wrist.r`. Measured over all 76 KayKit clips, `wrist.l/r` never rotate
  from rest (max 0.0 degrees) while `hand.l/r` rotate up to 124 and 131 degrees, so `wrist` is only a fixed extension of the forearm.
- KayKit has no neck, no upper chest and no shoulder (clavicle) bones. After retargeting, `neck_01`, `spine_03` and `clavicle_l/r` on this body
  stay at their rest pose; the KayKit `chest` rotation drives `spine_02` and everything above it follows.
- Both rigs rest in a T pose, face +Z and use +Y up, so no extra rest fixing for facing is needed. The limb lengths differ a lot (chibi versus adult),
  so hand positions in retargeted clips will not match the KayKit ones exactly; rotations transfer, positions do not.
- `hips` translation in KayKit clips is in chibi units (hips 0.406 high); Godot rescales position tracks per skeleton by its motion scale (hip height), about 0.917 / 0.406 here.
