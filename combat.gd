extends Node
## The referee: once per physics frame, after both fighters have moved, decides whether
## the blades met, whether a cut landed on a body, and runs the bind.
##
## Contact is tested with SWEPT segments: each blade is a line from the front of its
## crossguard to its tip, taken at last frame's and this frame's position and sampled in
## between, so two fast blades can't pass through each other between frames.
##
## BIND: when the blades rest together (slow contact) or the opponent presses in, the
## swords lock. The opponent pushes the crossing to one side; the player pushes back by
## moving the mouse the other way. The balance runs from -1 (we lose: our blade is
## shoved aside and it cuts) to +1 (we win: its blade is thrown aside). It switches the
## side it pushes now and then, with a short shiver first. S pulls out of the bind, at
## the risk of being cut on the way out.

signal bind_started
signal bind_ended(result: String)   # "won", "lost", "pulled_out", "apart"

const SwordScript := preload("res://sword.gd")
const Fx := preload("res://fx.gd")

const BLADE_TOUCH := 0.07     # blade-to-blade distance that counts as contact
const BODY_PAD := 0.03        # added to a body's radius for a blade to count as touching it
const SUBSTEPS := 8
const BIND_SLOW_TIME := 0.12  # slow blade contact this long becomes a bind
const BIND_RATE := 1.6        # balance change per second per unit of net push
const BIND_PUSH_DECAY := 1.5  # the player's push fades unless they keep pushing
const BIND_TELL := 0.4        # shiver before the opponent switches sides
const BIND_TIMEOUT := 6.0
const DODGE_CLEAR_MS := 500   # blades pass each other this long after a dodge starts

var player: Node3D
var opponent: Node3D
var tier := {}
var allow_binds := true   # practice turns binds off outside its bind step
var bind := {}     # empty unless bound: point, a, ai_dir, switch_in, tell, t, push

var _slow_touch := 0.0
var _rearm := 0.0


func _init() -> void:
	process_physics_priority = 100  # after the player and the opponent have moved


func is_bound() -> bool:
	return not bind.is_empty()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(opponent):
		return
	var ps = player.sword
	_rearm -= delta
	opponent.refresh_blade(delta)   # the animated sword, after this frame's animation
	if player.has_method("in_special") and player.in_special():
		ps.release_bind()
		return   # a critical thrust or an execution plays out on its own
	if not player.alive or opponent.is_dead():
		if is_bound():
			_end_bind("apart")
		ps.release_bind()
		return
	if is_bound():
		_update_bind(delta)
		return

	# The opponent chose to press into a bind (after a blocked cut, or when we cut into
	# its guard): the swords lock where they are.
	if opponent.consume_bind_request() and allow_binds and _rearm <= 0.0:
		begin_bind((ps.base + ps.tip + opponent.blade_base + opponent.blade_tip) * 0.25)
		return

	# Just after a dodge, the blade went with the body: it isn't caught either.
	var touch := {"found": false} if player.dodged_within(DODGE_CLEAR_MS) else _swept_touch(ps.prev_base, ps.prev_tip, ps.base, ps.tip,
		opponent.blade_prev_base, opponent.blade_prev_tip, opponent.blade_base, opponent.blade_tip, BLADE_TOUCH)
	if touch.found:
		if ps.clash_lock <= 0.0:
			var rel: float = (ps.tip_vel - opponent.blade_tip_vel).length()
			if rel >= SwordScript.CLASH_THRESHOLD:
				_slow_touch = 0.0
				ps.clash(touch.point, opponent, opponent.blade_tip_vel)
			else:
				_slow_touch += delta
				if _slow_touch >= BIND_SLOW_TIME and allow_binds and _rearm <= 0.0:
					begin_bind(touch.point)
		return   # a blade is in the way: nothing reaches a body this frame
	_slow_touch = 0.0
	ps.release_bind()

	# Our cut: only a real swing (not a still blade carried by footwork) cuts.
	# A cut into its parry is parried; while it dodges, cuts pass through.
	if ps.can_cut() and not opponent.is_dodging():
		var hit := _swept_body(ps.prev_base, ps.prev_tip, ps.base, ps.tip, opponent.global_position, 0.32)
		if hit.found:
			if opponent.is_parrying():
				ps.clash(hit.point, opponent, opponent.blade_tip_vel)
			else:
				ps.try_cut(opponent, hit.point)
	elif ps.swing_speed > 1.0 and not opponent.is_dodging():
		# Moving, but not a real cut: say so, instead of letting it pass unnoticed.
		var weak := _swept_body(ps.prev_base, ps.prev_tip, ps.base, ps.tip, opponent.global_position, 0.32)
		if weak.found:
			ps.touch_weakly(weak.point)

	# Its cut (a well-timed dodge makes it pass through). Holding guard (right mouse)
	# turns a cut that reaches us into a parry if it was just pressed, else a block.
	if opponent.can_cut() and not player.is_invulnerable():
		var hit2 := _swept_body(opponent.blade_prev_base, opponent.blade_prev_tip,
			opponent.blade_base, opponent.blade_tip, player.global_position, 0.30)
		if hit2.found:
			if player.is_guarding():
				ps.clash(hit2.point, opponent, opponent.blade_tip_vel)
			else:
				opponent.land_cut(player, hit2.point)


# --- bind --------------------------------------------------------------------------

func begin_bind(point: Vector3) -> void:
	bind = {
		"point": point, "a": 0.0, "ai_dir": 1.0 if randf() < 0.5 else -1.0,
		"switch_in": _switch_time(), "tell": 0.0, "t": 0.0, "push": 0.0, "since_switch": 1.0,
	}
	_slow_touch = 0.0
	player.enter_bind()
	player.sword.binding = true
	opponent.enter_bind()
	Sfx.play("scrape", point, 0.0)
	bind_started.emit()


func _update_bind(delta: float) -> void:
	bind.t += delta
	if player.wants_disengage():
		_end_bind("pulled_out")
		return

	# The opponent switches the side it pushes now and then, shivering first.
	if bind.tell > 0.0:
		bind.tell -= delta
		if bind.tell <= 0.0:
			bind.ai_dir = -bind.ai_dir
			bind.switch_in = _switch_time()
			bind.since_switch = 0.0
			bind.push = 0.0   # the old push no longer counts: just push the new way
	else:
		bind.switch_in -= delta
		if bind.switch_in <= 0.0:
			bind.tell = BIND_TELL
			Sfx.play("scrape", bind.point, -6.0)

	var push: float = bind.push + player.take_bind_push()
	push -= push * BIND_PUSH_DECAY * delta
	push = clampf(push, -1.5, 1.5)
	bind.push = push
	# > 0 when pushing back against it; pushing the wrong way only helps it a little.
	var against := clampf(push * -float(bind.ai_dir), -0.25, 1.5)
	var strength := float(tier.get("bind_strength", 0.7)) * 0.8 * (1.0 + 0.15 * sin(bind.t * 7.0))
	if bind.tell > 0.0:
		strength *= 0.35
	else:
		strength *= clampf(float(bind.since_switch) / 0.4, 0.3, 1.0)   # builds up after a switch
	bind.since_switch += delta
	bind.a = clampf(bind.a + (against - strength) * BIND_RATE * delta, -1.0, 1.0)

	# The crossing slides toward whoever is losing; it shivers before a switch.
	var right: Vector3 = player.global_transform.basis.x
	var losing := clampf(-float(bind.a), 0.0, 1.0)
	var winning := clampf(float(bind.a), 0.0, 1.0)
	var shake := 0.012 if bind.tell > 0.0 else 0.004
	var point: Vector3 = bind.point + right * float(bind.ai_dir) * (0.25 * losing - 0.12 * winning) \
		+ Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0.0)
	var local: Vector3 = player.to_local(point)
	player.hold_blade_at(Vector2(local.x, local.y))
	opponent.set_bind_point(point)

	if bind.a >= 1.0:
		_end_bind("won")
	elif bind.a <= -1.0:
		_end_bind("lost")
	elif bind.t > BIND_TIMEOUT:
		_end_bind("apart")


func _end_bind(result: String) -> void:
	var point: Vector3 = bind.point
	var side: float = bind.ai_dir
	bind = {}
	_rearm = 0.8
	_slow_touch = 0.0
	player.exit_bind()
	player.sword.release_bind()
	var scene := get_tree().current_scene
	match result:
		"won":
			opponent.bind_lost(side)
			Sfx.play("clash", point, 2.0)
			Fx.sparks(scene, point, 1.0)
		"lost":
			player.get_parried(side)
			opponent.bind_won()
			Sfx.play("block", point, 2.0)
			Fx.sparks(scene, point, 0.8)
		"pulled_out":
			opponent.bind_released(true)
		_:
			opponent.bind_released(false)
			player.deflect(Vector2(0.0, 0.1), 0.1)
	bind_ended.emit(result)


func _switch_time() -> float:
	var r: Vector2 = tier.get("bind_switch", Vector2(1.0, 1.8))
	return randf_range(r.x, r.y)


# --- geometry ------------------------------------------------------------------------

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
