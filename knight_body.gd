extends Node3D
## The opponent's body: Quaternius's CC0 mannequin (realistic proportions, rigged) in a
## mail suit and a cloth coat, with the plate armour from armor.gd strapped to its
## bones and the longsword in its right hand. Clips come from the Universal Animation
## Library (UAL1/UAL2) plus KayKit, all retargeted to Godot's humanoid profile at import
## (see the .glb.import files and the *_bonemap.tres resources).
##
## Animation is layered in an AnimationTree:
##   - legs: idle / walk / jog / walk-in-reverse, crossfaded by the body's velocity
##     (one gait at a time, so two cycles of different lengths never mix)
##   - upper body: held in a guard (sword raised in front) while moving, so the blade
##     never swings about or rests on the shoulder the way the run clips carry it
##   - actions (attacks, parry, hits, dodges, death): full-body clips faded in on top
##     and out again, played as time segments at chosen speeds
##   - the left hand held on the grip below the right one by an IK chain, so the
##     longsword is carried in two hands
## Local frame: feet at the origin, facing -Z (the model faces +Z, so it is turned).

const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")
const HipTwist := preload("res://hip_twist.gd")

const BODY := "res://assets/characters/body/UAL1_Standard.glb"
const LIBRARIES := {
	"ual2": "res://assets/characters/body/UAL2_Standard.glb",
	"kay": "res://assets/characters/knight/Knight.glb",
}
const LOOPING := ["Sword_Idle", "Walk", "Jog_Fwd"]
# The guard the upper body holds while moving: the first frame of the "A" cut, upright
# with the point toward the opponent (and the "A" cut starts from exactly this pose).
const GUARD_CLIP := "ual2/Sword_Regular_A"
const GUARD_TIME := 0.0
# Gaits: [name, clip, played backward]. Stepping back is the walk in reverse.
const GAITS := [
	["idle", "Sword_Idle", false],
	["walk", "Walk", false],
	["jog", "Jog_Fwd", false],
	["back", "Walk", true],
]
const WALK_SPEED := 0.85   # the walk's ground speed at playback 1 (m/s): its planted foot
const JOG_SPEED := 3.2     # the jog's feet slide at any speed; kept near its own cadence
# Some UAL sword cuts fold the body nearly double; their hips, spine and legs are pulled
# this far back toward the standing pose (the arms and so the blade keep the clip's
# path relative to the chest). The "A" cut keeps its low lunge, which gives it reach.
const UPRIGHT := {"ual2/Sword_Regular_B": 0.45, "ual2/Sword_Regular_C": 0.45, "ual2/Sword_Dash": 0.45}
const CORE_BONES := ["Hips", "Spine", "Chest", "UpperChest",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]
# Clips where the left hand lets go of the grip.
const ONE_HAND_CLIPS := ["Hit_Chest", "ual2/Hit_Knockback", "Death01"]
const UPPER_BONES := ["Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Little"]
const SEGMENTS := ["Metacarpal", "Proximal", "Intermediate", "Distal"]

# The longsword in the right fist, in the hand bone's frame: the blade runs along the
# hand's +X (forward in the T-pose), the edges along the fingers (+Y).
const SWORD_IN_HAND := Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)), Vector3(0.0, 0.085, 0.025))
# The left wrist sits like the right one, LEFT_HAND further toward the pommel (which is
# the hand's -X), and its elbow bends down and out to the left.
const LEFT_WRIST := Vector3(-SwordMesh.LEFT_HAND, 0.0, 0.0)
const LEFT_POLE := Vector3(0.5, 0.6, 0.1)     # skeleton space (the model faces +Z)
const RIGHT_POLE := Vector3(-0.5, 0.6, 0.1)

# (radius, height) profiles, bottom to top, at the model's own heights.
const HELM := [
	Vector2(0.106, 0.00), Vector2(0.124, 0.03), Vector2(0.132, 0.10), Vector2(0.133, 0.18),
	Vector2(0.128, 0.24), Vector2(0.112, 0.275), Vector2(0.075, 0.298), Vector2(0.0, 0.305),
]
const CUIRASS := [
	Vector2(0.170, 0.96), Vector2(0.186, 1.05), Vector2(0.214, 1.20), Vector2(0.222, 1.32),
	Vector2(0.208, 1.43), Vector2(0.172, 1.51), Vector2(0.10, 1.555), Vector2(0.0, 1.565),
]
# Cloth coat (jupon) over the breastplate, flaring over the hips.
const COAT := [
	Vector2(0.268, 0.78), Vector2(0.232, 0.90), Vector2(0.196, 1.02), Vector2(0.204, 1.12),
	Vector2(0.228, 1.24), Vector2(0.232, 1.33), Vector2(0.214, 1.42),
]
const FAULDS := [
	[Vector2(0.222, 0.90), Vector2(0.192, 1.00)],
	[Vector2(0.244, 0.82), Vector2(0.214, 0.93)],
	[Vector2(0.262, 0.74), Vector2(0.236, 0.85)],
]

var ap: AnimationPlayer
var tree: AnimationTree
var skeleton: Skeleton3D
var sword: Node3D
var _model: Node3D
var _hand := -1
var _steel: StandardMaterial3D
var _flash := 0.0
var _bound := false
var _action_weight := 0.0
var _action_target := 0.0
var _action_fade := 8.0
var _guard := 1.0
var _action_clip := ""
var _twist
var _twist_target := 0.0
var _gait := "idle"
var _left_ik: SkeletonModifier3D
var _right_ik: SkeletonModifier3D
var _left_on_hand: Node3D
var _left_on_sword: Node3D
var _two_hands := 1.0


func build(tabard_color: Color, crest: bool) -> void:
	_model = (load(BODY) as PackedScene).instantiate() as Node3D
	_model.rotation.y = PI   # the model faces +Z; we face -Z
	add_child(_model)
	skeleton = _model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	ap = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for lib in LIBRARIES:
		if ResourceLoader.exists(LIBRARIES[lib]):
			var other := (load(LIBRARIES[lib]) as PackedScene).instantiate()
			var other_ap := other.find_child("AnimationPlayer", true, false) as AnimationPlayer
			ap.add_animation_library(lib, other_ap.get_animation_library(""))
			other.free()
	for clip in LOOPING:
		if ap.has_animation(clip):
			ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_hand = skeleton.find_bone("RightHand")
	_twist = HipTwist.new()
	skeleton.add_child(_twist)
	_build_tree()
	_dress(tabard_color, crest)
	_build_grip()


# --- armour ---------------------------------------------------------------------------

func _dress(tabard_color: Color, crest: bool) -> void:
	# Mail suit over the whole body.
	var body_mesh := skeleton.find_child("Mannequin", true, false) as MeshInstance3D
	if body_mesh:
		body_mesh.material_override = Armor.mail()

	_steel = Armor.two_sided(Armor.steel())
	var dark := Armor.dark_steel()
	var cloth := Armor.two_sided(Armor.cloth(tabard_color))
	var leather := Armor.leather()

	# Head: great helm with eye slit, breathing holes and a reinforcing cross.
	var head := _attach("Head")
	var helm := Armor.part(head, Armor.lathe(PackedVector2Array(HELM), 24), _steel, Vector3(0, -0.04, 0))
	helm.scale = Vector3(1.0, 1.0, 0.96)
	Armor.part(head, Armor.box(Vector3(0.20, 0.017, 0.03)), Armor.visor_black(), Vector3(0, 0.121, 0.122))
	Armor.part(head, Armor.box(Vector3(0.022, 0.20, 0.018)), _steel, Vector3(0, 0.06, 0.131))
	for hx in [-0.05, -0.03, 0.03, 0.05]:
		for hy in [0.03, 0.005]:
			Armor.part(head, Armor.box(Vector3(0.008, 0.008, 0.02)), Armor.visor_black(), Vector3(hx, hy, 0.126))
	if crest:
		Armor.part(head, Armor.box(Vector3(0.03, 0.10, 0.26)), Armor.cloth(Color(0.85, 0.66, 0.22)), Vector3(0, 0.31, -0.02))

	# Torso: breastplate under a cloth coat, a belt, and a skirt of plates below.
	var chest := _attach("Chest")
	var plate := Armor.part(chest, Armor.lathe(PackedVector2Array(CUIRASS), 28), _steel, Vector3(0, -1.174, 0))
	plate.scale = Vector3(1.0, 1.0, 0.74)
	var coat := Armor.part(chest, Armor.lathe(PackedVector2Array(COAT), 28), cloth, Vector3(0, -1.174, 0))
	coat.scale = Vector3(1.04, 1.0, 0.8)
	var hips := _attach("Hips")
	Armor.part(hips, Armor.cylinder(0.205, 0.205, 0.05), leather, Vector3(0, 0.12, 0)).scale = Vector3(1.0, 1.0, 0.82)
	for f in FAULDS:
		var band := Armor.part(hips, Armor.lathe(PackedVector2Array(f), 24), _steel, Vector3(0, -0.917, 0))
		band.scale = Vector3(1.0, 1.0, 0.82)

	# Arms: pauldrons, vambraces, gauntlets. Leg plates, knees and sabatons.
	for side in ["Left", "Right"]:
		var upper := _attach(side + "UpperArm")
		var pauldron := Armor.part(upper, Armor.sphere(0.118), _steel, Vector3(0, 0.03, 0))
		pauldron.scale = Vector3(1.1, 1.05, 1.1)
		_limb(side + "LowerArm", side + "Hand", 0.046, _steel)
		var hand := _attach(side + "Hand")
		Armor.part(hand, Armor.box(Vector3(0.085, 0.11, 0.06)), dark, Vector3(0, 0.05, 0.005))
		_limb(side + "UpperLeg", side + "LowerLeg", 0.082, _steel)
		_limb(side + "LowerLeg", side + "Foot", 0.066, _steel)
		Armor.part(_attach(side + "LowerLeg"), Armor.sphere(0.072), _steel, Vector3(0, 0.0, 0.04))
		Armor.part(_attach(side + "Foot"), Armor.box(Vector3(0.11, 0.25, 0.08)), dark, Vector3(0, 0.07, 0.0))

	sword = SwordMesh.build(Armor.blade(), dark, leather)
	var grip := _attach("RightHand")
	grip.add_child(sword)
	sword.transform = SWORD_IN_HAND


## A BoneAttachment3D following the named bone (one per bone, reused).
func _attach(bone: String) -> Node3D:
	var existing := skeleton.get_node_or_null("attach_" + bone)
	if existing:
		return existing as Node3D
	var a := BoneAttachment3D.new()
	a.name = "attach_" + bone
	a.bone_name = bone
	skeleton.add_child(a)
	return a


## A plate tube along a limb bone, from just below its joint to near the next joint.
func _limb(bone: String, child: String, radius: float, mat: Material) -> void:
	var a := _attach(bone)
	var i := skeleton.find_bone(bone)
	var j := skeleton.find_bone(child)
	var local_child := (skeleton.get_bone_global_rest(i).affine_inverse() * skeleton.get_bone_global_rest(j)).origin
	var tube := Armor.part(a, Armor.capsule(radius, local_child.length() * 0.9), mat)
	Armor.place_between(tube, local_child * 0.08, local_child * 0.92)


# --- two-handed grip -------------------------------------------------------------------

## The left hand follows the right hand on the grip. Built from skeleton modifiers,
## which run in child order after the animation: the hip twist, then a node that
## tracks the right hand's final pose, then the arm IK aimed at a point below it (so
## the hands never lag a frame apart, even mid-swing). In a bind the sword is held on
## the crossing point instead, and both hands go to it.
func _build_grip() -> void:
	var on_hand := ModifierBoneTarget3D.new()
	on_hand.bone_name = "RightHand"
	skeleton.add_child(on_hand)
	_left_on_hand = Node3D.new()
	_left_on_hand.position = LEFT_WRIST
	on_hand.add_child(_left_on_hand)
	var right_wrist := SWORD_IN_HAND.affine_inverse()
	var right_on_sword := Node3D.new()
	right_on_sword.transform = right_wrist
	sword.add_child(right_on_sword)
	_left_on_sword = Node3D.new()
	_left_on_sword.transform = right_wrist.translated_local(LEFT_WRIST)
	sword.add_child(_left_on_sword)
	_left_ik = _arm_ik("Left", _left_on_hand, LEFT_POLE)
	_right_ik = _arm_ik("Right", right_on_sword, RIGHT_POLE)
	_right_ik.active = false


func _arm_ik(side: String, target: Node3D, pole_at: Vector3) -> SkeletonModifier3D:
	var pole := Node3D.new()
	pole.position = pole_at
	skeleton.add_child(pole)
	var ik := TwoBoneIK3D.new()
	ik.setting_count = 1
	skeleton.add_child(ik)
	ik.set_root_bone_name(0, side + "UpperArm")
	ik.set_middle_bone_name(0, side + "LowerArm")
	ik.set_end_bone_name(0, side + "Hand")
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	return ik


# --- animation tree --------------------------------------------------------------------

func _build_tree() -> void:
	var root := AnimationNodeBlendTree.new()

	var loco := AnimationNodeTransition.new()
	loco.xfade_time = 0.22
	for g in GAITS:
		loco.add_input(g[0])
		var n := AnimationNodeAnimation.new()
		n.animation = g[1]
		if g[2]:
			n.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
		root.add_node("gait_" + g[0], n)
	root.add_node("loco", loco)
	root.add_node("loco_speed", AnimationNodeTimeScale.new())

	var guard := AnimationNodeAnimation.new()
	guard.animation = GUARD_CLIP
	root.add_node("guard", guard)
	root.add_node("guard_seek", AnimationNodeTimeSeek.new())

	# Legs from the locomotion blend, upper body from the guard.
	var stance := AnimationNodeBlend2.new()
	stance.filter_enabled = true
	for bone in _upper_bone_names():
		stance.set_filter_path(NodePath("%GeneralSkeleton:" + bone), true)
	root.add_node("stance", stance)

	root.add_node("action", AnimationNodeAnimation.new())
	root.add_node("action_seek", AnimationNodeTimeSeek.new())
	root.add_node("action_speed", AnimationNodeTimeScale.new())
	var stand := AnimationNodeAnimation.new()
	stand.animation = "Sword_Idle"
	root.add_node("stand", stand)
	root.add_node("stand_seek", AnimationNodeTimeSeek.new())
	var upright := AnimationNodeBlend2.new()
	upright.filter_enabled = true
	for bone in CORE_BONES:
		upright.set_filter_path(NodePath("%GeneralSkeleton:" + bone), true)
	root.add_node("upright", upright)
	root.add_node("mix", AnimationNodeBlend2.new())

	for i in GAITS.size():
		root.connect_node("loco", i, "gait_" + GAITS[i][0])
	root.connect_node("loco_speed", 0, "loco")
	root.connect_node("guard_seek", 0, "guard")
	root.connect_node("stance", 0, "loco_speed")
	root.connect_node("stance", 1, "guard_seek")
	root.connect_node("action_seek", 0, "action")
	root.connect_node("action_speed", 0, "action_seek")
	root.connect_node("mix", 0, "stance")
	root.connect_node("stand_seek", 0, "stand")
	root.connect_node("upright", 0, "action_speed")
	root.connect_node("upright", 1, "stand_seek")
	root.connect_node("mix", 1, "upright")
	root.connect_node("output", 0, "mix")

	tree = AnimationTree.new()
	tree.tree_root = root
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_model.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(_model)
	tree.active = true
	(root.get_node("action") as AnimationNodeAnimation).animation = GUARD_CLIP
	tree.set("parameters/stance/blend_amount", 1.0)
	tree.set("parameters/mix/blend_amount", 0.0)
	tree.set("parameters/loco/transition_request", "idle")
	tree.set("parameters/loco_speed/scale", 1.0)
	tree.set("parameters/action_speed/scale", 1.0)


func _upper_bone_names() -> Array:
	var names := UPPER_BONES.duplicate()
	for side in ["Left", "Right"]:
		for f in FINGERS:
			for s in SEGMENTS:
				names.append(side + f + s)
	return names


## Legs follow the body's velocity (in its own frame: x right, y forward, m/s). The
## forward gaits serve every direction: the hips turn toward the travel and the upper
## body turns back (hip_twist.gd). Mostly-backward travel steps back the same way.
func move(local_velocity: Vector2) -> void:
	var speed := local_velocity.length()
	var gait: String
	if speed < (0.3 if _gait == "idle" else 0.15):
		gait = "idle"
	elif local_velocity.y < -0.3 * speed:
		gait = "back"
	elif speed > (1.5 if _gait == "jog" else 1.9):
		gait = "jog"
	else:
		gait = "walk"
	if gait != _gait:
		_gait = gait
		tree.set("parameters/loco/transition_request", gait)
	# In the model's frame (it faces +Z, and our right is its -X).
	var mx := -local_velocity.x
	var mz := local_velocity.y
	var rate := 1.0
	match gait:
		"idle":
			_twist_target = 0.0
		"back":
			_twist_target = clampf(atan2(-mx, -mz), -1.0, 1.0)
			rate = clampf(speed / WALK_SPEED, 0.6, 2.4)
		"walk":
			_twist_target = clampf(atan2(mx, mz), -1.6, 1.6)
			rate = clampf(speed / WALK_SPEED, 0.6, 2.2)
		"jog":
			_twist_target = clampf(atan2(mx, mz), -1.6, 1.6)
			rate = clampf(speed / JOG_SPEED, 0.7, 1.3)
	tree.set("parameters/loco_speed/scale", rate)


## Raise (1) or lower (0) the guard while moving; lowered shows the clips' own arms.
func set_guard(amount: float) -> void:
	_guard = amount


## Start a full-body action: [from, to] seconds of the clip played over `duration`.
func act(clip: String, from: float, to: float, duration: float, fade := 0.1) -> void:
	if not ap.has_animation(clip):
		return
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node("action") as AnimationNodeAnimation
	if _action_clip != clip:
		node.animation = clip
		_action_clip = clip
	tree.set("parameters/action_seek/seek_request", from)
	tree.set("parameters/action_speed/scale", maxf((to - from) / maxf(duration, 0.01), 0.0))
	_two_hands = 0.0 if clip in ONE_HAND_CLIPS else 1.0
	tree.set("parameters/upright/blend_amount", UPRIGHT.get(clip, 0.0))
	_action_target = 1.0
	_action_fade = 1.0 / maxf(fade, 0.01)


## Keep the current action going at a new speed (e.g. from windup into the strike).
func act_speed(scale: float) -> void:
	tree.set("parameters/action_speed/scale", maxf(scale, 0.0))


## Fade the current action out, back to stance and footwork.
func release(fade := 0.25) -> void:
	_two_hands = 1.0
	_action_target = 0.0
	_action_fade = 1.0 / maxf(fade, 0.01)


func is_acting() -> bool:
	return _action_target > 0.0


func clip_length(clip: String) -> float:
	return ap.get_animation(clip).length if ap.has_animation(clip) else 0.0


## Where the longsword is right now (world space), straight from the skeleton so it is
## current even before the bone attachments refresh.
func sword_transform() -> Transform3D:
	if _bound:
		return sword.global_transform
	return skeleton.global_transform * skeleton.get_bone_global_pose(_hand) * SWORD_IN_HAND


## In a bind the sword is held on the crossing point, not by the animation.
func hold_sword(world: Transform3D) -> void:
	if not _bound:
		_bound = true
		sword.top_level = true
		_left_ik.set_target_node(0, _left_ik.get_path_to(_left_on_sword))
		_right_ik.active = true
	sword.global_transform = world


func release_sword() -> void:
	if _bound:
		_bound = false
		sword.top_level = false
		sword.transform = SWORD_IN_HAND
		_left_ik.set_target_node(0, _left_ik.get_path_to(_left_on_hand))
		_right_ik.active = false


func update_body(delta: float) -> void:
	# Legs turn toward the travel smoothly; no twist during full-body actions.
	var want := _twist_target * (1.0 - _action_weight)
	_twist.twist = lerp_angle(_twist.twist, want, clampf(delta * 8.0, 0.0, 1.0))
	_action_weight = move_toward(_action_weight, _action_target, _action_fade * delta)
	tree.set("parameters/mix/blend_amount", _action_weight)
	_left_ik.influence = move_toward(_left_ik.influence, _two_hands, 6.0 * delta)
	tree.set("parameters/guard_seek/seek_request", GUARD_TIME)
	tree.set("parameters/stand_seek/seek_request", 0.0)
	var s := float(tree.get("parameters/stance/blend_amount"))
	tree.set("parameters/stance/blend_amount", move_toward(s, _guard, 4.0 * delta))
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		_steel.emission_enabled = _flash > 0.0
		_steel.emission = Color(0.9, 0.12, 0.05)
		_steel.emission_energy_multiplier = _flash * 1.6


func flash() -> void:
	_flash = 1.0


func collapse() -> void:
	release_sword()
	act("Death01", 0.0, clip_length("Death01"), clip_length("Death01"), 0.1)
