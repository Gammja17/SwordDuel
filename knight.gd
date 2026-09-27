extends Node3D
## The opponent's body: an armoured knight. The helm, breastplate and skirt of plates
## are lathed surfaces (armor.gd), limbs are primitives, all with the CC0 steel / mail /
## cloth / leather materials. Its legs walk procedurally from the body's speed, and
## opponent.gd puts both hands on the longsword every frame.
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

# (radius, height) profiles, bottom to top.
const HELM := [
	Vector2(0.106, 0.00), Vector2(0.124, 0.03), Vector2(0.132, 0.10), Vector2(0.133, 0.18),
	Vector2(0.128, 0.24), Vector2(0.112, 0.275), Vector2(0.075, 0.298), Vector2(0.0, 0.305),
]
const CUIRASS := [
	Vector2(0.170, 0.96), Vector2(0.186, 1.05), Vector2(0.214, 1.20), Vector2(0.222, 1.32),
	Vector2(0.208, 1.43), Vector2(0.172, 1.51), Vector2(0.10, 1.555), Vector2(0.0, 1.565),
]
const FAULD_1 := [Vector2(0.192, 1.00), Vector2(0.222, 0.90)]
const FAULD_2 := [Vector2(0.214, 0.93), Vector2(0.244, 0.82)]
const FAULD_3 := [Vector2(0.236, 0.85), Vector2(0.262, 0.74)]

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
	_steel = Armor.two_sided(Armor.steel())
	var dark := Armor.dark_steel()
	var mail := Armor.mail()
	var cloth := Armor.cloth(tabard_color)
	var leather := Armor.leather()

	# Everything above the hips sits on a torso node so it can breathe.
	_torso = Node3D.new()
	add_child(_torso)

	# Skirt of overlapping plates below the waist, and a surcoat panel front and back.
	for f in [FAULD_1, FAULD_2, FAULD_3]:
		var band := Armor.part(self, Armor.lathe(_reversed(f), 24), _steel)
		band.scale = Vector3(1.0, 1.0, 0.82)
	Armor.part(self, Armor.box(Vector3(0.34, 0.52, 0.014)), cloth, Vector3(0, 0.80, -0.21))
	Armor.part(self, Armor.box(Vector3(0.34, 0.52, 0.014)), cloth, Vector3(0, 0.80, 0.21))

	# Breastplate with a centre ridge, a belt, and a mail collar.
	var chest := Armor.part(_torso, Armor.lathe(PackedVector2Array(CUIRASS), 28), _steel)
	chest.scale = Vector3(1.0, 1.0, 0.74)
	Armor.part(_torso, Armor.box(Vector3(0.018, 0.46, 0.02)), _steel, Vector3(0, 1.24, -0.162)).rotation_degrees = Vector3(-4, 0, 0)
	Armor.part(_torso, Armor.cylinder(0.19, 0.19, 0.05), leather, Vector3(0, 1.0, 0)).scale = Vector3(1.0, 1.0, 0.8)
	Armor.part(_torso, Armor.cylinder(0.085, 0.11, 0.1), mail, Vector3(0, 1.55, 0))

	# Great helm: lathed barrel, eye slit, breathing holes, a reinforcing cross.
	var helm := Armor.part(_torso, Armor.lathe(PackedVector2Array(HELM), 24), _steel, Vector3(0, 1.53, 0))
	helm.scale = Vector3(1.0, 1.0, 0.96)
	Armor.part(_torso, Armor.box(Vector3(0.20, 0.017, 0.03)), Armor.visor_black(), Vector3(0, 1.69, -0.122))
	Armor.part(_torso, Armor.box(Vector3(0.022, 0.20, 0.018)), _steel, Vector3(0, 1.63, -0.131))
	for hx in [-0.05, -0.03, 0.03, 0.05]:
		for hy in [1.60, 1.575]:
			Armor.part(_torso, Armor.box(Vector3(0.008, 0.008, 0.02)), Armor.visor_black(), Vector3(hx, hy, -0.126))
	if crest:
		Armor.part(_torso, Armor.box(Vector3(0.03, 0.10, 0.26)), Armor.cloth(Color(0.85, 0.66, 0.22)), Vector3(0, 1.88, 0.02))

	# Shoulders: a rounded pauldron with a lame below it.
	for s in [-1.0, 1.0]:
		var pauldron := Armor.part(_torso, Armor.sphere(0.118), _steel, Vector3(0.23 * s, 1.46, 0.0))
		pauldron.scale = Vector3(1.05, 0.72, 1.12)
		var lame := Armor.part(_torso, Armor.sphere(0.10), _steel, Vector3(0.25 * s, 1.37, 0.0))
		lame.scale = Vector3(0.9, 0.5, 1.0)

	for side in ["l", "r"]:
		_legs["thigh_" + side] = Armor.part(self, Armor.capsule(0.08, THIGH + 0.14), _steel)
		_legs["shin_" + side] = Armor.part(self, Armor.capsule(0.066, SHIN + 0.10), _steel)
		_legs["knee_" + side] = Armor.part(self, Armor.sphere(0.075), _steel)
		_legs["foot_" + side] = Armor.part(self, Armor.box(Vector3(0.11, 0.07, 0.26)), dark)

	_arm_r = ArmScript.new(self, UPPER_ARM, FOREARM, mail, _steel, dark)
	_arm_l = ArmScript.new(self, UPPER_ARM, FOREARM, mail, _steel, dark)

	sword = SwordMesh.build(Armor.blade(), dark, leather)
	add_child(sword)
	update_body(0.0, 0.0)


func _reversed(points: Array) -> PackedVector2Array:
	# Fauld bands are written top to bottom; lathe() wants bottom to top.
	var out := PackedVector2Array()
	for i in range(points.size() - 1, -1, -1):
		out.append(points[i])
	return out


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
