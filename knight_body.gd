extends Node3D
## The opponent's body: Quaternius's CC0 mannequin (realistic proportions, rigged) in a
## mail suit, with the plate armour from armor.gd strapped to its bones and the
## longsword in its right hand. It moves with the Universal Animation Library sword
## clips plus KayKit's strafes, backstep and dodges, all retargeted to Godot's humanoid
## profile at import (see the .glb.import files and the *_bonemap.tres resources).
## Local frame: feet at the origin, facing -Z (the model faces +Z, so it is turned).

const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")

const BODY := "res://assets/characters/body/UAL1_Standard.glb"
const LIBRARIES := {
	"ual2": "res://assets/characters/body/UAL2_Standard.glb",
	"kay": "res://assets/characters/knight/Knight.glb",
}
const LOOPING := ["Sword_Idle", "Idle", "Walk", "Jog_Fwd", "kay/Running_Strafe_Left",
	"kay/Running_Strafe_Right", "kay/Walking_Backwards"]

# The longsword in the right fist, in the hand bone's frame: the blade runs along the
# hand's +X (forward in the T-pose), the edges along the fingers (+Y).
const SWORD_IN_HAND := Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)), Vector3(0.0, 0.085, 0.025))

# Same (radius, height) profiles as before, at the model's own heights.
const HELM := [
	Vector2(0.106, 0.00), Vector2(0.124, 0.03), Vector2(0.132, 0.10), Vector2(0.133, 0.18),
	Vector2(0.128, 0.24), Vector2(0.112, 0.275), Vector2(0.075, 0.298), Vector2(0.0, 0.305),
]
const CUIRASS := [
	Vector2(0.170, 0.96), Vector2(0.186, 1.05), Vector2(0.214, 1.20), Vector2(0.222, 1.32),
	Vector2(0.208, 1.43), Vector2(0.172, 1.51), Vector2(0.10, 1.555), Vector2(0.0, 1.565),
]
const FAULDS := [
	[Vector2(0.222, 0.90), Vector2(0.192, 1.00)],
	[Vector2(0.244, 0.82), Vector2(0.214, 0.93)],
	[Vector2(0.262, 0.74), Vector2(0.236, 0.85)],
]

var ap: AnimationPlayer
var skeleton: Skeleton3D
var sword: Node3D
var _model: Node3D
var _hand := -1
var _steel: StandardMaterial3D
var _flash := 0.0
var _bound := false


func build(tabard_color: Color, crest: bool) -> void:
	_model = (load(BODY) as PackedScene).instantiate() as Node3D
	_model.rotation.y = PI   # the model faces +Z; we face -Z
	add_child(_model)
	skeleton = _model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	ap = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
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

	# Mail suit over the whole body.
	var body_mesh := skeleton.find_child("Mannequin", true, false) as MeshInstance3D
	if body_mesh:
		body_mesh.material_override = Armor.mail()

	_steel = Armor.two_sided(Armor.steel())
	var dark := Armor.dark_steel()
	var cloth := Armor.cloth(tabard_color)
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

	# Torso: breastplate with a centre ridge, belt, surcoat and a skirt of plates.
	var chest := _attach("Chest")
	var plate := Armor.part(chest, Armor.lathe(PackedVector2Array(CUIRASS), 28), _steel, Vector3(0, -1.174, 0))
	plate.scale = Vector3(1.0, 1.0, 0.74)
	Armor.part(chest, Armor.box(Vector3(0.018, 0.46, 0.02)), _steel, Vector3(0, 0.066, 0.162)).rotation_degrees = Vector3(4, 0, 0)
	var hips := _attach("Hips")
	Armor.part(hips, Armor.cylinder(0.19, 0.19, 0.05), leather, Vector3(0, 0.083, 0)).scale = Vector3(1.0, 1.0, 0.8)
	for f in FAULDS:
		var band := Armor.part(hips, Armor.lathe(PackedVector2Array(f), 24), _steel, Vector3(0, -0.917, 0))
		band.scale = Vector3(1.0, 1.0, 0.82)
	Armor.part(hips, Armor.box(Vector3(0.34, 0.52, 0.014)), cloth, Vector3(0, -0.117, 0.21))
	Armor.part(hips, Armor.box(Vector3(0.34, 0.52, 0.014)), cloth, Vector3(0, -0.117, -0.21))

	# Arms: pauldrons, vambraces, gauntlets. Leg plates and sabatons.
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

	play("Sword_Idle", 0.0)


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
	var length := local_child.length()
	var tube := Armor.part(a, Armor.capsule(radius, length * 0.9), mat)
	Armor.place_between(tube, local_child * 0.08, local_child * 0.92)


# --- animation ------------------------------------------------------------------------

func play(clip: String, blend := 0.15, speed := 1.0) -> void:
	if not ap.has_animation(clip):
		return
	if ap.current_animation == clip and ap.is_playing():
		ap.speed_scale = speed
		return
	ap.play(clip, blend)
	ap.speed_scale = speed


## Play part of a clip, [from, to] seconds of it, so that it takes `duration` seconds.
func play_segment(clip: String, from: float, to: float, duration: float, blend := 0.08) -> void:
	if not ap.has_animation(clip):
		return
	ap.play(clip, blend)
	ap.seek(from, true)
	ap.speed_scale = maxf((to - from) / maxf(duration, 0.01), 0.05)


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
	sword.global_transform = world


func release_sword() -> void:
	if _bound:
		_bound = false
		sword.top_level = false
		sword.transform = SWORD_IN_HAND


func update_body(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		_steel.emission_enabled = _flash > 0.0
		_steel.emission = Color(0.9, 0.12, 0.05)
		_steel.emission_energy_multiplier = _flash * 1.6


func flash() -> void:
	_flash = 1.0


func collapse() -> void:
	release_sword()
	play("Death01", 0.1)
