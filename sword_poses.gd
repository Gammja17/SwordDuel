extends RefCounted
## The opponent's longsword moves from pose to pose. A pose is where the right hand
## holds the grip and which way the blade points, in the fighter's own frame (facing
## -Z, +X to its right) measured from the top of its chest, plus how far the torso
## turns (yaw, + toward its left) and leans forward with it. opponent.gd blends between
## poses on timing curves; both arms follow the grip by IK (knight_body.gd).

# name: [grip offset from the upper chest, blade direction, edge direction, yaw, lean]
# A cut with a "mid_" pose passes through it (where it meets the opponent), so a blade
# swinging round from behind a shoulder comes through in front, not round the back.
const POSES := {
	# Guard: hilt in front of the belly, blade raised and leaning forward a little on
	# the right, so it doesn't sit in the line of the opponent's blade.
	"guard": [Vector3(0.12, -0.18, -0.26), Vector3(0.22, 0.90, -0.38), Vector3(-1.0, 0.0, -0.3), -0.1, 0.05],
	# Lowered to the side (practice: an open target).
	"open": [Vector3(0.26, -0.40, -0.12), Vector3(0.35, -0.55, -0.75), Vector3(0.0, 0.0, -1.0), -0.1, 0.0],
	# "c": from above the head straight down.
	"wind_c": [Vector3(0.05, 0.36, -0.06), Vector3(0.05, 0.80, 0.60), Vector3(0.0, 0.0, -1.0), 0.0, -0.10],
	"end_c": [Vector3(0.02, -0.26, -0.36), Vector3(0.0, -0.55, -1.0), Vector3(0.0, -1.0, 0.3), 0.0, 0.30],
	# "a": from over the right shoulder, diagonally down to the left.
	"wind_a": [Vector3(0.22, 0.24, 0.02), Vector3(0.55, 0.60, 0.58), Vector3(-0.5, -0.3, -0.8), -0.50, 0.0],
	"mid_a": [Vector3(0.02, 0.0, -0.42), Vector3(-0.35, 0.1, -1.0), Vector3(-0.6, -0.6, 0.0), 0.1, 0.2],
	"end_a": [Vector3(-0.12, -0.24, -0.30), Vector3(-0.85, -0.45, -0.35), Vector3(-0.6, -0.7, 0.0), 0.45, 0.28],
	# "b": the mirror, from over the left shoulder down to the right.
	"wind_b": [Vector3(-0.14, 0.24, 0.02), Vector3(-0.55, 0.60, 0.58), Vector3(0.5, -0.3, -0.8), 0.45, 0.0],
	"mid_b": [Vector3(0.14, 0.0, -0.42), Vector3(0.35, 0.1, -1.0), Vector3(0.6, -0.6, 0.0), -0.1, 0.2],
	"end_b": [Vector3(0.22, -0.24, -0.30), Vector3(0.85, -0.45, -0.35), Vector3(0.6, -0.7, 0.0), -0.45, 0.28],
	# "lunge": a thrust. Drawn back to the right hip, then driven straight out.
	"wind_lunge": [Vector3(0.22, -0.12, 0.18), Vector3(-0.08, 0.7, -0.7), Vector3(0.0, 1.0, 0.0), -0.4, -0.1],
	"end_lunge": [Vector3(0.03, 0.0, -0.46), Vector3(0.0, 0.06, -1.0), Vector3(0.0, 1.0, 0.0), 0.15, 0.30],
	# Knocked aside (stagger, lost bind): the blade flung out to the right.
	"thrown": [Vector3(0.28, -0.18, -0.10), Vector3(0.85, 0.45, -0.25), Vector3(0.0, 1.0, 0.0), -0.25, -0.12],
}


static func make(name: String) -> Dictionary:
	var p: Array = POSES[name]
	return build(p[0], p[1], p[2], p[3], p[4])


static func build(grip: Vector3, dir: Vector3, edge: Vector3, yaw: float, lean: float) -> Dictionary:
	return {"grip": grip, "rot": _basis(dir, edge).get_rotation_quaternion(), "yaw": yaw, "lean": lean}


## Parry: the blade snaps up across the side the attack comes from (side: +1 right).
static func parry(side: float) -> Dictionary:
	return build(Vector3(0.06 * side, 0.02, -0.34), Vector3(0.75 * side, 0.8, -0.45),
		Vector3(-side, 0.0, -1.0), -0.2 * side, 0.05)


## Parried: the blade batted wide to the side it was struck toward, arm thrown out.
static func knocked(side: float) -> Dictionary:
	return build(Vector3(0.30 * side, 0.05, -0.05), Vector3(1.0 * side, 0.35, -0.2),
		Vector3(0.0, 1.0, 0.0), -0.35 * side, -0.2)


## Holding the blade from the grip toward a point (a bind's crossing), body space
## relative to the upper chest.
static func aimed(grip: Vector3, toward: Vector3) -> Dictionary:
	var dir := (toward - grip).normalized()
	return build(grip, dir, Vector3.UP.cross(dir) if absf(dir.y) < 0.95 else Vector3.RIGHT, 0.0, 0.1)


## From a to b at t (0..1). `bulge` pushes the hands forward along the way, so a cut
## swings out in an arc with the arms extended instead of passing close to the chest.
static func blend(a: Dictionary, b: Dictionary, t: float, bulge := 0.0) -> Dictionary:
	var grip: Vector3 = (a.grip as Vector3).lerp(b.grip, t) + Vector3(0.0, 0.0, -bulge * sin(PI * t))
	return {
		"grip": grip,
		"rot": (a.rot as Quaternion).slerp(b.rot, t),
		"yaw": lerpf(a.yaw, b.yaw, t),
		"lean": lerpf(a.lean, b.lean, t),
	}


static func _basis(dir: Vector3, edge: Vector3) -> Basis:
	var z := -dir.normalized()
	var x := edge - z * edge.dot(z)
	if x.length() < 0.001:
		x = Vector3.UP.cross(z)
	x = x.normalized()
	return Basis(x, z.cross(x).normalized(), z)
