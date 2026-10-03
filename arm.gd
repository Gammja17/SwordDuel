extends RefCounted
## One armoured arm made of primitive meshes, posed with an analytic two-bone IK:
## the shoulder is fixed on the body, the hand goes onto the sword grip, and the
## elbow bends toward a pole hint. All positions are in the parent's local space.

const Armor := preload("res://armor.gd")

var upper_len: float
var fore_len: float
var last_gap := 0.0   # how far the hand fell short of its target last pose (0 = on the grip)
var _upper: MeshInstance3D
var _fore: MeshInstance3D
var _elbow: MeshInstance3D
var _hand: MeshInstance3D


func _init(parent: Node3D, upper: float, fore: float, sleeve: Material, plate: Material,
		glove: Material, shadows := true) -> void:
	upper_len = upper
	fore_len = fore
	_upper = Armor.part(parent, Armor.capsule(0.034, upper + 0.08), sleeve)
	_fore = Armor.part(parent, Armor.capsule(0.028, fore + 0.05), plate)
	_elbow = Armor.part(parent, Armor.sphere(0.036), sleeve)
	_hand = Armor.part(parent, Armor.box(Vector3(0.062, 0.055, 0.085)), glove)
	if not shadows:
		for mi in [_upper, _fore, _elbow, _hand]:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_visible(on: bool) -> void:
	for mi in [_upper, _fore, _elbow, _hand]:
		(mi as MeshInstance3D).visible = on


## Poses the arm and returns where the hand actually is (the target, unless it was out
## of reach, in which case the arm is fully extended toward it).
func pose(shoulder: Vector3, target: Vector3, pole: Vector3, hand_basis: Basis) -> Vector3:
	var d := target - shoulder
	var dist := d.length()
	var dir := d / dist if dist > 0.0001 else Vector3.DOWN
	var reach := clampf(dist, absf(upper_len - fore_len) + 0.01, upper_len + fore_len - 0.001)
	var x := (upper_len * upper_len - fore_len * fore_len + reach * reach) / (2.0 * reach)
	var h := sqrt(maxf(upper_len * upper_len - x * x, 0.0))
	var bend := pole - dir * pole.dot(dir)
	if bend.length() < 0.0001:
		bend = Vector3.DOWN - dir * dir.y
	bend = bend.normalized()
	var elbow := shoulder + dir * x + bend * h
	var hand := shoulder + dir * reach
	last_gap = (target - hand).length()
	Armor.place_between(_upper, shoulder, elbow)
	Armor.place_between(_fore, elbow, hand)
	_elbow.position = elbow
	_hand.transform = Transform3D(hand_basis, hand)
	return hand
