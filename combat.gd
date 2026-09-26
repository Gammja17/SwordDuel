extends Node
## The referee: once per physics frame, after both fighters have moved, decides whether
## the blades met and whether a cut landed on a body.
##
## Contact is tested with SWEPT segments: each blade is a line from the front of its
## crossguard to its tip, taken at last frame's and this frame's position and sampled in
## between. Two fast blades therefore can't pass through each other between frames,
## which plain physics overlap checks allowed.

const SwordScript := preload("res://sword.gd")

const BLADE_TOUCH := 0.07     # blade-to-blade distance that counts as contact
const BODY_PAD := 0.03        # added to a body's radius for a blade to count as touching it
const SUBSTEPS := 8

var player: Node3D
var opponent: Node3D


func _init() -> void:
	process_physics_priority = 100  # after the player and the opponent have moved


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(opponent):
		return
	var ps = player.sword
	if not player.alive or opponent.is_dead():
		ps.release_bind()
		return

	# Blade against blade first: if they touch, nothing reaches a body this frame.
	var touch := _swept_touch(ps.prev_base, ps.prev_tip, ps.base, ps.tip,
		opponent.blade_prev_base, opponent.blade_prev_tip, opponent.blade_base, opponent.blade_tip, BLADE_TOUCH)
	if touch.found:
		if ps.clash_lock <= 0.0:
			var rel: float = (ps.tip_vel - opponent.blade_tip_vel).length()
			if rel >= SwordScript.CLASH_THRESHOLD:
				ps.clash(touch.point, opponent, opponent.blade_tip_vel)
			else:
				ps.bind_step(delta, opponent)
		return
	ps.release_bind()

	# Our cut: only a real swing (not a still blade carried by footwork) cuts.
	if ps.clash_lock <= 0.0 and ps.swing_speed >= SwordScript.CUT_THRESHOLD:
		var hit := _swept_body(ps.prev_base, ps.prev_tip, ps.base, ps.tip, opponent.global_position, 0.32)
		if hit.found:
			ps.try_cut(opponent, hit.point)

	# Its cut.
	if opponent.can_cut():
		var hit2 := _swept_body(opponent.blade_prev_base, opponent.blade_prev_tip,
			opponent.blade_base, opponent.blade_tip, player.global_position, 0.30)
		if hit2.found:
			opponent.land_cut(player, hit2.point)


## Closest approach of two moving segments over the frame.
func _swept_touch(a_pb: Vector3, a_pt: Vector3, a_b: Vector3, a_t: Vector3,
		b_pb: Vector3, b_pt: Vector3, b_b: Vector3, b_t: Vector3, limit: float) -> Dictionary:
	var best := INF
	var point := Vector3.ZERO
	for i in SUBSTEPS + 1:
		var u := float(i) / SUBSTEPS
		var cp := Geometry3D.get_closest_points_between_segments(
			a_pb.lerp(a_b, u), a_pt.lerp(a_t, u), b_pb.lerp(b_b, u), b_pt.lerp(b_t, u))
		var d := cp[0].distance_to(cp[1])
		if d < best:
			best = d
			point = (cp[0] + cp[1]) * 0.5
	return {"found": best < limit, "point": point}


## A moving blade against a standing body (its capsule axis from shin to shoulder).
func _swept_body(pb: Vector3, pt: Vector3, b: Vector3, t: Vector3, body_pos: Vector3, radius: float) -> Dictionary:
	var axis0 := body_pos + Vector3(0.0, 0.30, 0.0)
	var axis1 := body_pos + Vector3(0.0, 1.40, 0.0)
	var best := INF
	var point := Vector3.ZERO
	for i in SUBSTEPS + 1:
		var u := float(i) / SUBSTEPS
		var cp := Geometry3D.get_closest_points_between_segments(pb.lerp(b, u), pt.lerp(t, u), axis0, axis1)
		var d := cp[0].distance_to(cp[1])
		if d < best:
			best = d
			point = cp[0]
	return {"found": best < radius + BODY_PAD, "point": point}
