# Knight (KayKit Adventurers 1.0) inspection

Made by parsing the glTF JSON chunk of `Knight.glb` with Python (no engine import). Units are glTF units
(the pack is not in real metres, see Height).

Source: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
(`addons/kaykit_character_pack_adventures/Characters/gltf/Knight.glb`), exported by
"Khronos glTF Blender I/O v1.7.33". License CC0 1.0 (see `LICENSE.txt` in this folder).

## Files

| File | Bytes | What |
|---|---|---|
| `Knight.glb` | 3,659,532 | Skinned knight, 41-joint rig, 76 animations, all weapons/shields as nodes, texture embedded |
| `knight_texture.png` | 14,172 | 1024 x 1024 RGBA gradient atlas (byte-identical to the one embedded in the .glb) |
| `LICENSE.txt` | 891 | The pack's CC0 license text |
| `weapons/sword_1handed.gltf` + `.bin` | 3,080 + 13,256 | Stand-alone one-handed sword |
| `weapons/sword_2handed.gltf` + `.bin` | 3,081 + 19,912 | Stand-alone two-handed sword |
| `weapons/sword_2handed_color.gltf` + `.bin` | 3,093 + 19,880 | Two-handed sword, coloured variant |
| `weapons/knight_texture.png` | 14,172 | Copy of the atlas; the weapon .gltf files point to `knight_texture.png` next to them |

## Scene tree (rest pose)

```
Rig
  Knight_ArmLeft, Knight_ArmRight, Knight_Body, Knight_Head, Knight_LegLeft, Knight_LegRight  (skinned, skin "Rig")
  root
    hips > spine > chest
      chest > upperarm.l > lowerarm.l > wrist.l > hand.l > handslot.l
                 handslot.l children: 1H_Sword_Offhand, Badge_Shield, Rectangle_Shield, Round_Shield, Spike_Shield
      chest > upperarm.r > lowerarm.r > wrist.r > hand.r > handslot.r
                 handslot.r children: 1H_Sword, 2H_Sword
      chest > head > Knight_Helmet
      chest > Knight_Cape
    hips > upperleg.l > lowerleg.l > foot.l > toes.l   (same for .r)
    kneeIK.l/.r, control-toe-roll.l/.r > control-heel-roll > control-foot-roll > heelIK, IK-foot; IK-toe
    elbowIK.l/.r, handIK.l/.r
```

## Weapons, helmet and cape

They are **separate, unskinned mesh nodes rigidly parented to bones** (Godot will import them as children
of `BoneAttachment3D` nodes on those bones). All are visible by default, so the knight holds both swords
in the right hand and four shields plus an off-hand sword in the left at once; hide the ones you do not want.

| Node | Parent bone | Mesh local bounds (min / max) | Notes |
|---|---|---|---|
| `1H_Sword` | `handslot.r` | (-0.252, -0.366, -0.065) / (0.252, 1.409, 0.065) | blade along local +Y, total length 1.78 |
| `2H_Sword` | `handslot.r` | (-0.420, -0.401, -0.124) / (0.420, 1.964, 0.124) | blade along local +Y, total length 2.37 |
| `1H_Sword_Offhand` | `handslot.l` | same mesh data as 1H_Sword | |
| `Badge_Shield`, `Rectangle_Shield`, `Round_Shield`, `Spike_Shield` | `handslot.l` | about 0.88 to 1.0 wide | |
| `Knight_Helmet` | `head` | | big helmet, top of the model |
| `Knight_Cape` | `chest` | | hangs at the back (-Z) |

In the T pose both swords point straight forward (+Z): `1H_Sword` world bounds X -1.135..-0.631,
Y 0.984..1.115, Z -0.332..1.443; `2H_Sword` X -1.303..-0.464, Y 0.925..1.173, Z -0.368..1.998.
The stand-alone `weapons/*.gltf` files hold the same sword meshes (identical bounds) as single nodes with no transform.

## Height, up axis, facing

- Up axis: **+Y** (feet at Y = 0.000, all nodes above).
- Facing: **+Z** (toes, knee IK targets and the T-pose swords point to +Z; the cape is on -Z). The character's
  right hand is on -X. (Standard glTF front; in Godot a model facing +Z looks along the node's +Z basis,
  i.e. opposite to `-basis.z` "forward".)
- Height: body without helmet 2.315 (top of `Knight_Head`), **with helmet 2.467**. Width in T pose 1.942
  (hand tip to hand tip). No node scale is applied (root, Rig and skinned mesh nodes have identity transforms).
- Proportions are chibi: the head/helmet is about 1.1 to 1.25 units of the 2.47 total. To make the knight
  about 1.8 m tall, scale by roughly 0.73.
- Bone world positions in rest pose: hips Y 0.406, spine 0.598, chest 0.973, head 1.241,
  hand.r (-0.787, 1.107, 0), handslot.r (-0.883, 1.049, 0), hand.l (0.787, 1.107, 0), handslot.l (0.883, 1.049, 0).

## Skeleton (skin "Rig", 41 joints, in skin order)

`root`, `hips`, `spine`, `chest`, `upperarm.l`, `lowerarm.l`, `wrist.l`, `hand.l`, `handslot.l`,
`upperarm.r`, `lowerarm.r`, `wrist.r`, `hand.r`, `handslot.r`, `head`, `upperleg.l`, `lowerleg.l`, `foot.l`,
`toes.l`, `upperleg.r`, `lowerleg.r`, `foot.r`, `toes.r`, `kneeIK.l`, `control-toe-roll.l`,
`control-heel-roll.l`, `control-foot-roll.l`, `heelIK.l`, `IK-foot.l`, `IK-toe.l`, `kneeIK.r`,
`control-toe-roll.r`, `control-heel-roll.r`, `control-foot-roll.r`, `heelIK.r`, `IK-foot.r`, `IK-toe.r`,
`elbowIK.l`, `handIK.l`, `elbowIK.r`, `handIK.r`

Key bones:
- Right hand: `hand.r`, weapon socket `handslot.r` (the swords hang here)
- Left hand: `hand.l`, socket `handslot.l` (shields and off-hand sword)
- Spine / chest: `spine`, `chest` (chest parents arms, head and cape); pelvis `hips`
- Head: `head` (helmet hangs here)
- Only 20 joints carry vertex weights: hips, spine, chest, head, upperarm/lowerarm/wrist/hand (.l/.r),
  upperleg/lowerleg/foot/toes (.l/.r). `root`, `handslot.l/.r` and the 18 Blender IK/control joints
  (`kneeIK`, `control-*`, `heelIK`, `IK-*`, `elbowIK`, `handIK`) have no weights.

## Materials and textures

One material, `knight_texture` (double sided, metallic 0, roughness 0.5, base colour texture only, no normal
map), using the embedded PNG `knight_texture` (1024 x 1024, sampler linear / linear-mipmap-linear). The same
image is shipped as `knight_texture.png`.

## Animations (76)

Duration = the largest `max` of the sampler input (time) accessors. Clips with 0.000 are single-frame poses.

| # | Animation | Duration (s) |
|---|---|---|
| 1 | `1H_Melee_Attack_Chop` | 1.067 |
| 2 | `1H_Melee_Attack_Slice_Diagonal` | 1.000 |
| 3 | `1H_Melee_Attack_Slice_Horizontal` | 1.067 |
| 4 | `1H_Melee_Attack_Stab` | 1.600 |
| 5 | `1H_Ranged_Aiming` | 1.067 |
| 6 | `1H_Ranged_Reload` | 1.167 |
| 7 | `1H_Ranged_Shoot` | 1.067 |
| 8 | `1H_Ranged_Shooting` | 1.600 |
| 9 | `2H_Melee_Attack_Chop` | 1.633 |
| 10 | `2H_Melee_Attack_Slice` | 1.100 |
| 11 | `2H_Melee_Attack_Spin` | 2.400 |
| 12 | `2H_Melee_Attack_Spinning` | 0.667 |
| 13 | `2H_Melee_Attack_Stab` | 1.600 |
| 14 | `2H_Melee_Idle` | 1.067 |
| 15 | `2H_Ranged_Aiming` | 1.600 |
| 16 | `2H_Ranged_Reload` | 1.600 |
| 17 | `2H_Ranged_Shoot` | 1.067 |
| 18 | `2H_Ranged_Shooting` | 1.067 |
| 19 | `Block` | 1.067 |
| 20 | `Block_Attack` | 1.067 |
| 21 | `Block_Hit` | 1.067 |
| 22 | `Blocking` | 1.067 |
| 23 | `Cheer` | 1.667 |
| 24 | `Death_A` | 0.800 |
| 25 | `Death_A_Pose` | 0.000 |
| 26 | `Death_B` | 2.633 |
| 27 | `Death_B_Pose` | 0.000 |
| 28 | `Dodge_Backward` | 0.400 |
| 29 | `Dodge_Forward` | 0.400 |
| 30 | `Dodge_Left` | 0.400 |
| 31 | `Dodge_Right` | 0.400 |
| 32 | `Dualwield_Melee_Attack_Chop` | 1.267 |
| 33 | `Dualwield_Melee_Attack_Slice` | 1.167 |
| 34 | `Dualwield_Melee_Attack_Stab` | 1.600 |
| 35 | `Hit_A` | 0.667 |
| 36 | `Hit_B` | 0.867 |
| 37 | `Idle` | 1.067 |
| 38 | `Interact` | 1.300 |
| 39 | `Jump_Full_Long` | 2.333 |
| 40 | `Jump_Full_Short` | 1.167 |
| 41 | `Jump_Idle` | 1.067 |
| 42 | `Jump_Land` | 0.667 |
| 43 | `Jump_Start` | 0.600 |
| 44 | `Lie_Down` | 3.000 |
| 45 | `Lie_Idle` | 2.667 |
| 46 | `Lie_Pose` | 0.000 |
| 47 | `Lie_StandUp` | 2.333 |
| 48 | `PickUp` | 1.300 |
| 49 | `Running_A` | 0.800 |
| 50 | `Running_B` | 1.067 |
| 51 | `Running_Strafe_Left` | 0.800 |
| 52 | `Running_Strafe_Right` | 0.800 |
| 53 | `Sit_Chair_Down` | 0.800 |
| 54 | `Sit_Chair_Idle` | 3.600 |
| 55 | `Sit_Chair_Pose` | 0.000 |
| 56 | `Sit_Chair_StandUp` | 0.800 |
| 57 | `Sit_Floor_Down` | 1.000 |
| 58 | `Sit_Floor_Idle` | 4.000 |
| 59 | `Sit_Floor_Pose` | 0.000 |
| 60 | `Sit_Floor_StandUp` | 1.133 |
| 61 | `Spellcast_Long` | 2.533 |
| 62 | `Spellcast_Raise` | 2.100 |
| 63 | `Spellcast_Shoot` | 0.933 |
| 64 | `Spellcasting` | 0.667 |
| 65 | `T-Pose` | 0.000 |
| 66 | `Throw` | 1.367 |
| 67 | `Unarmed_Idle` | 1.067 |
| 68 | `Unarmed_Melee_Attack_Kick` | 0.933 |
| 69 | `Unarmed_Melee_Attack_Punch_A` | 1.467 |
| 70 | `Unarmed_Melee_Attack_Punch_B` | 1.667 |
| 71 | `Unarmed_Pose` | 0.000 |
| 72 | `Use_Item` | 1.600 |
| 73 | `Walking_A` | 1.067 |
| 74 | `Walking_B` | 1.067 |
| 75 | `Walking_Backwards` | 1.067 |
| 76 | `Walking_C` | 1.600 |

Useful for a sword duel: `2H_Melee_Idle`, `2H_Melee_Attack_Chop`, `2H_Melee_Attack_Slice`,
`2H_Melee_Attack_Stab`, `2H_Melee_Attack_Spin`, the `1H_Melee_Attack_*` set, `Block`, `Blocking`,
`Block_Hit`, `Block_Attack`, `Dodge_Forward/Backward/Left/Right`, `Hit_A`, `Hit_B`, `Death_A`, `Death_B`,
`Walking_A/B/C`, `Walking_Backwards`, `Running_Strafe_Left/Right`. There is no walking strafe and no
clip with a `2H_` prefix for blocking; the `Block*` clips have no weapon prefix and were not checked
visually (in `Block` the left forearm turns about 88 degrees from rest, the right about 56).
