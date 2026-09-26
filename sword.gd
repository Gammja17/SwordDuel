extends Node3D
## Player's blade, held at a hand pivot and aimed by the mouse.
##
## Every physics frame we place the blade and measure two speeds of its tip:
##   - SWING speed: tip motion relative to our own body, i.e. the arm (the mouse).
##     It decides whether we are actually swinging — cuts, parries and pushing in a
##     bind all need it, so walking or turning with a still blade does nothing.
##   - WORLD speed: swing plus footwork. It sets how hard a cut lands (stepping into a
##     cut adds power) and, against the other blade, whether the contact is a clash.
## Outcomes:
##   - blades meet fast            -> PARRY if we swung into their attack,
##                                     BLOCKED if we only held the line, else CLANG
##   - blades rest together        -> BIND: keep pushing to force their guard aside
##   - reach the body with a swing -> CUT (depth scales with world tip speed)

signal cut_registered(strength: float, pos: Vector3)
signal clash_registered(pos: Vector3, result: String)  # "PARRY!", "BLOCKED", "GUARD BROKEN", "CLANG!"

const BLADE_LEN := 0.95
const CUT_THRESHOLD := 3.0    # swing speed below which the blade doesn't cut
const CLASH_THRESHOLD := 4.0  # blade-vs-blade relative speed above this = clash, below = bind
const PARRY_SPEED := 2.5      # our own swing speed that turns meeting an attack into a parry
const BIND_PUSH_SPEED := 1.0  # swing speed that counts as pushing while bound
const HIT_COOLDOWN := 0.35    # per-target delay before the same body can be cut again
const CLASH_LOCK := 0.25      # after a clash the blade is bouncing; no cut/clash
const BIND_BREAK_TIME := 0.6  # seconds of pushing in a bind before their guard gives

var _area: Area3D
var _tip_prev := Vector3.ZERO
var _tip_local_prev := Vector3.ZERO
var _tip_pos := Vector3.ZERO
var _tip_vel := Vector3.ZERO
var _swing_dir := Vector3.ZERO
var _has_prev := false
var _tip_speed := 0.0
var _swing_speed := 0.0
var _clash_lock := 0.0
var _bind_time := 0.0
var _binding := false
var _cooldowns := {}  # body -> seconds remaining


func get_tip_speed() -> float:
	return _tip_speed


func get_tip_pos() -> Vector3:
	return _tip_pos


func is_binding() -> bool:
	return _binding


func _ready() -> void:
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.035, BLADE_LEN)
	blade.mesh = bm
	blade.position = Vector3(0.0, 0.0, -BLADE_LEN * 0.5)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.85, 0.87, 0.92)
	blade_mat.metallic = 0.8
	blade_mat.roughness = 0.25
	blade.material_override = blade_mat
	add_child(blade)

	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.22, 0.03, 0.05)
	guard.mesh = gm
	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.25, 0.20, 0.12)
	guard.material_override = guard_mat
	add_child(guard)

	_area = Area3D.new()
	_area.collision_layer = 8        # this is a "blade"
	_area.collision_mask = 4 | 8     # find the opponent body (4) to cut and blades (8) to clash
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.10, 0.10, BLADE_LEN)  # forgiving cross-section for blade-vs-blade
	col.shape = box
	col.position = Vector3(0.0, 0.0, -BLADE_LEN * 0.5)
	_area.add_child(col)
	add_child(_area)


## Called by the player each physics frame with world-space grip and aim points.
func drive(hand_world: Vector3, aim_world: Vector3, delta: float) -> void:
	var dir := aim_world - hand_world
	if dir.length() < 0.001:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()

	var t := Transform3D()
	t.origin = hand_world
	t.basis = _basis_pointing_along(dir)
	global_transform = t

	var tip := hand_world + dir * BLADE_LEN
	var tip_local := (get_parent() as Node3D).to_local(tip)  # tip as seen from our body
	if _has_prev:
		var dt := maxf(delta, 0.0001)
		_tip_vel = (tip - _tip_prev) / dt
		_tip_speed = _tip_vel.length()
		_swing_speed = (tip_local - _tip_local_prev).length() / dt
		if _tip_speed > 0.001:
			_swing_dir = _tip_vel.normalized()
	_tip_prev = tip
	_tip_local_prev = tip_local
	_tip_pos = tip
	_has_prev = true

	_resolve(tip, delta)


func _resolve(tip: Vector3, delta: float) -> void:
	for body in _cooldowns.keys():
		_cooldowns[body] -= delta

	if _clash_lock > 0.0:
		_clash_lock -= delta
		_binding = false
		return

	var areas := _area.get_overlapping_areas()
	if not areas.is_empty():
		# Clash on the RELATIVE speed of the two blades, so it fires whether we are
		# attacking into a held guard or a held blade is meeting an incoming attack.
		var opp := _opponent_of(areas[0])
		var opp_vel := Vector3.ZERO
		if opp != null and opp.has_method("get_blade_vel"):
			opp_vel = opp.get_blade_vel()
		if (_tip_vel - opp_vel).length() >= CLASH_THRESHOLD:
			_binding = false
			_bind_time = 0.0
			_do_clash(tip, opp, opp_vel)
		else:
			# Blades resting together: bind. Only actually pushing wears their guard down.
			_binding = true
			if _swing_speed >= BIND_PUSH_SPEED:
				_bind_time += delta
			else:
				_bind_time = maxf(_bind_time - delta, 0.0)
			if _bind_time >= BIND_BREAK_TIME:
				_bind_time = 0.0
				if opp != null and opp.has_method("guard_broken"):
					opp.guard_broken()
		return  # a blade is in the way; nothing reaches the body

	_binding = false
	_bind_time = 0.0

	if _swing_speed < CUT_THRESHOLD:
		return
	for body in _area.get_overlapping_bodies():
		if _cooldowns.get(body, 0.0) > 0.0:
			continue
		if body.has_method("receive_cut"):
			body.receive_cut(_tip_speed, tip, _swing_dir)
			_cooldowns[body] = HIT_COOLDOWN
			cut_registered.emit(_tip_speed, tip)


func _do_clash(tip: Vector3, opp: Node, opp_vel: Vector3) -> void:
	_clash_lock = CLASH_LOCK

	# Ask before notifying: on_blade_clashed() changes the opponent's state.
	var attacked: bool = opp != null and opp.has_method("is_attacking") and opp.is_attacking()
	var parried := attacked and _swing_speed >= PARRY_SPEED
	var blocked := attacked and not parried
	var result := "CLANG!"
	if parried:
		result = "PARRY!"
	elif blocked:
		result = "BLOCKED"

	var p := get_parent()
	if p is Node3D and p.has_method("deflect"):
		var right := (p as Node3D).global_transform.basis.x
		var h: float
		if attacked:
			h = signf(opp_vel.dot(right))     # shoved the way the incoming blade travels
		else:
			h = -signf(_swing_dir.dot(right)) # bounce back opposite our own swing
		if h == 0.0:
			h = 1.0
		if blocked and p.has_method("absorb_block"):
			# A passive block knocks our guard open and fills the guard meter.
			if p.absorb_block(h):
				result = "GUARD BROKEN"
		else:
			p.deflect(Vector2(h * 0.30, 0.18), 0.18)
	clash_registered.emit(tip, result)

	if opp != null and opp.has_method("on_blade_clashed"):
		opp.on_blade_clashed(tip, parried)

	_spawn_spark(tip)


func _opponent_of(node: Node) -> Node:
	var n := node
	while n != null:
		if n.has_method("on_blade_clashed") or n.has_method("guard_broken"):
			return n
		n = n.get_parent()
	return null


func _spawn_spark(pos: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	spark.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.55)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.4)
	m.emission_energy_multiplier = 6.0
	spark.material_override = m
	get_tree().current_scene.add_child(spark)
	spark.global_position = pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spark, "scale", Vector3(2.5, 2.5, 2.5), 0.2)
	tw.tween_property(m, "emission_energy_multiplier", 0.0, 0.2)
	get_tree().create_timer(0.25).timeout.connect(spark.queue_free)


func _basis_pointing_along(dir: Vector3) -> Basis:
	var z := -dir  # local -Z should map to dir, so basis z-axis = -dir
	var up := Vector3.UP
	if absf(z.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)
