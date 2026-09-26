extends Node3D
## The opponent's body: an armoured knight built from primitive meshes with the CC0
## steel / cloth / leather materials. Its legs walk procedurally from the body's
## speed, and opponent.gd puts both hands on the longsword every frame.
## Local frame: feet at the origin, facing -Z.

const Armor := preload("res://armor.gd")
const ArmScript := preload("res://arm.gd")
const SwordMesh := preload("res://sword_mesh.gd")

const SHOULDER_R := Vector3(0.21, 1.41, 0.0)
const SHOULDER_L := Vector3(-0.21, 1.41, 0.0)
const HIP_R := Vector3(0.11, 0.93, 0.0)
const HIP_L := Vector3(-0.11, 0.93, 0.0)
const THIGH := 0.44
const SHIN := 0.44
const UPPER_ARM := 0.345
const FOREARM := 0.335

var sword: Node3D
var _arm_r
var _arm_l
var _steel: StandardMaterial3D  # this knight's own copy, so hit flashes stay local
var _legs := {}
var _phase := 0.0
var _flash := 0.0
var _breath := 0.0
var _torso: Node3D


func build(tabard_color: Color, crest: bool) -> void:
	_steel = Armor.steel().duplicate()
	var dark := Armor.dark_steel()
	var cloth := Armor.cloth(tabard_color)
	var leather := Armor.leather()

	# Everything above the hips sits on a torso node so it can breathe and lean.
	_torso = Node3D.new()
	add_child(_torso)

	Armor.part(self, Armor.cylinder(0.19, 0.24, 0.26), _steel, Vector3(0, 0.93, 0))      # tassets
	var chest := Armor.part(_torso, Armor.capsule(0.205, 0.64), _steel, Vector3(0, 1.25, 0))
	chest.scale = Vector3(1.0, 1.0, 0.78)
	Armor.part(_torso, Armor.cylinder(0.212, 0.212, 0.05), leather, Vector3(0, 1.02, 0))  # belt
	Armor.part(self, Armor.box(Vector3(0.36, 0.62, 0.016)), cloth, Vector3(0, 0.99, -0.174))  # surcoat
	Armor.part(self, Armor.box(Vector3(0.36, 0.62, 0.016)), cloth, Vector3(0, 0.99, 0.170))
	Armor.part(_torso, Armor.cylinder(0.08, 0.10, 0.10), dark, Vector3(0, 1.53, 0))        # gorget

	# Great helm: flat-topped barrel, low dome, eye slit and breathing slot.
	Armor.part(_torso, Armor.cylinder(0.118, 0.13, 0.27), _steel, Vector3(0, 1.67, 0))
	var dome := Armor.part(_torso, Armor.sphere(0.118), _steel, Vector3(0, 1.80, 0))
	dome.scale = Vector3(1.0, 0.55, 1.0)
	Armor.part(_torso, Armor.box(Vector3(0.17, 0.016, 0.02)), Armor.visor_black(), Vector3(0, 1.69, -0.125))
	Armor.part(_torso, Armor.box(Vector3(0.016, 0.09, 0.02)), Armor.visor_black(), Vector3(0, 1.615, -0.128))
	if crest:
		Armor.part(_torso, Armor.box(Vector3(0.03, 0.10, 0.26)), Armor.cloth(Color(0.85, 0.66, 0.22)), Vector3(0, 1.88, 0.02))

	for s in [-1.0, 1.0]:
		var pauldron := Armor.part(_torso, Armor.sphere(0.115), _steel, Vector3(0.23 * s, 1.45, 0.0))
		pauldron.scale = Vector3(1.05, 0.75, 1.1)

	for side in ["l", "r"]:
		_legs["thigh_" + side] = Armor.part(self, Armor.capsule(0.078, THIGH + 0.14), dark)
		_legs["shin_" + side] = Armor.part(self, Armor.capsule(0.064, SHIN + 0.10), _steel)
		_legs["knee_" + side] = Armor.part(self, Armor.sphere(0.07), _steel)
		_legs["foot_" + side] = Armor.part(self, Armor.box(Vector3(0.11, 0.07, 0.25)), dark)

	_arm_r = ArmScript.new(self, UPPER_ARM, FOREARM, dark, _steel, dark)
	_arm_l = ArmScript.new(self, UPPER_ARM, FOREARM, dark, _steel, dark)

	sword = SwordMesh.build(Armor.blade(), dark, leather)
	add_child(sword)
	update_body(0.0, 0.0)


## Hands on the grip: right hand at grip, left hand further down toward the pommel.
func pose_arms(grip: Vector3, blade_basis: Basis) -> void:
	var dir := -blade_basis.z
	sword.transform = Transform3D(blade_basis, grip)
	_arm_r.pose(SHOULDER_R, grip, Vector3(0.6, -0.8, 0.3), blade_basis)
	_arm_l.pose(SHOULDER_L, grip - dir * SwordMesh.LEFT_HAND, Vector3(-0.6, -0.8, 0.3), blade_basis)


func update_body(delta: float, speed: float) -> void:
	var amount := clampf(speed / 2.0, 0.0, 1.0)
	_phase += delta * (1.5 + speed * 4.5)
	for i in 2:
		var side := "l" if i == 0 else "r"
		var hip := HIP_L if i == 0 else HIP_R
		var swing := sin(_phase + PI * i) * 0.5 * amount
		var thigh_dir := Vector3(0.0, -cos(swing), -sin(swing))
		var knee := hip + thigh_dir * THIGH
		var bend := maxf(0.0, -sin(_phase + PI * i)) * 0.7 * amount + 0.08
		var shin_dir := Vector3(0.0, -cos(swing - bend), -sin(swing - bend))
		var ankle := knee + shin_dir * SHIN
		Armor.place_between(_legs["thigh_" + side], hip, knee)
		Armor.place_between(_legs["shin_" + side], knee, ankle)
		(_legs["knee_" + side] as Node3D).position = knee + Vector3(0.0, 0.0, -0.045)
		(_legs["foot_" + side] as Node3D).position = ankle + Vector3(0.0, -0.02, -0.05)

	_breath += delta * 1.7
	_torso.position.y = sin(_breath) * 0.006

	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		_steel.emission_enabled = _flash > 0.0
		_steel.emission = Color(0.9, 0.12, 0.05)
		_steel.emission_energy_multiplier = _flash * 1.6


func flash() -> void:
	_flash = 1.0


func collapse() -> void:
	var tw := get_tree().create_tween()
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "rotation_degrees:x", 84.0, 0.75)
	tw.parallel().tween_property(self, "position:y", 0.12, 0.75)
