extends Node3D
## The player's longsword: where it is, how fast it moves, and what happens to us when
## it meets the opponent's blade. Whether it touched anything is decided by combat.gd
## once per frame, after both fighters have moved.
##
## Two speeds of the tip matter:
##   - SWING speed: tip motion relative to our own body, i.e. the arms (the mouse).
##     It decides whether we are actually swinging — cuts, parries and pushing in a
##     bind all need it, so walking or turning with a still blade does nothing.
##   - WORLD speed: swing plus footwork. It sets how hard a cut lands (stepping into a
##     cut adds power) and, against the other blade, whether the contact is a clash.
## Blade meets blade fast -> PARRY if we swung into their attack, BLOCKED if we only
## held the line, else CLANG. Slowly -> BIND: keep pushing to force their guard aside.

signal cut_registered(strength: float, pos: Vector3)
signal clash_registered(pos: Vector3, result: String)  # "PARRY!", "BLOCKED", "GUARD BROKEN", "CLANG!"

const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")
const Fx := preload("res://fx.gd")

const REACH := SwordMesh.REACH
const CUT_THRESHOLD := 3.0    # swing speed below which the blade doesn't cut
const CLASH_THRESHOLD := 4.0  # blade-vs-blade relative speed above this = clash, below = bind
const PARRY_SPEED := 2.5      # our own swing speed that turns meeting an attack into a parry
const BIND_PUSH_SPEED := 1.0  # swing speed that counts as pushing while bound
const HIT_COOLDOWN := 0.35    # delay before the same swing can cut again
const CLASH_LOCK := 0.25      # after a clash the blade is bouncing; no cut/clash
const BIND_BREAK_TIME := 0.6  # seconds of pushing in a bind before their guard gives
const SWING_SOUND_SPEED := 6.0

# Blade state read by combat.gd, world space. The edge runs from base (front of the
# crossguard) to tip; prev_* are last frame's positions.
var base := Vector3.ZERO
var tip := Vector3.ZERO
var prev_base := Vector3.ZERO
var prev_tip := Vector3.ZERO
var tip_vel := Vector3.ZERO
var tip_speed := 0.0
var swing_speed := 0.0
var clash_lock := 0.0
var binding := false

var _tip_local_prev := Vector3.ZERO
var _swing_dir := Vector3.ZERO
var _edge_local := Vector3.RIGHT
var _has_prev := false
var _bind_time := 0.0
var _swing_cd := 0.0
var _cut_cd := 0.0


func get_tip_speed() -> float:
	return tip_speed


func get_swing_speed() -> float:
	return swing_speed


func get_tip_pos() -> Vector3:
	return tip


func is_binding() -> bool:
	return binding


func _ready() -> void:
	add_child(SwordMesh.build(Armor.blade(), Armor.dark_steel(), Armor.leather(), false))


## Called by the player each physics frame with the grip point (right hand) and the
## direction the blade points, both in world space.
func drive(grip_world: Vector3, dir_world: Vector3, delta: float) -> void:
	var body := get_parent() as Node3D
	var dir := dir_world.normalized()
	var new_tip := grip_world + dir * REACH
	var new_base := grip_world + dir * SwordMesh.BLADE_START
	var tip_local := body.to_local(new_tip)
	if _has_prev:
		var dt := maxf(delta, 0.0001)
		tip_vel = (new_tip - tip) / dt
		tip_speed = tip_vel.length()
		var swing_local := tip_local - _tip_local_prev
		swing_speed = swing_local.length() / dt
		if tip_speed > 0.001:
			_swing_dir = tip_vel.normalized()
		if swing_local.length() > 0.002:
			# The cutting edge leads the cut.
			_edge_local = _edge_local.lerp(swing_local.normalized(), 0.35).normalized()
		prev_base = base
		prev_tip = tip
	else:
		prev_base = new_base
		prev_tip = new_tip
	base = new_base
	tip = new_tip
	_tip_local_prev = tip_local
	_has_prev = true

	clash_lock = maxf(clash_lock - delta, 0.0)
	_cut_cd -= delta

	global_transform = Transform3D(Armor.blade_basis(dir, body.global_transform.basis * _edge_local), grip_world)

	_swing_cd -= delta
	if swing_speed > SWING_SOUND_SPEED and _swing_cd <= 0.0:
		_swing_cd = 0.35
		Sfx.play("swing", tip, lerpf(-8.0, 0.0, clampf((swing_speed - 6.0) / 8.0, 0.0, 1.0)))


## combat.gd: our blade met theirs at speed.
func clash(point: Vector3, opp: Node, opp_vel: Vector3) -> void:
	clash_lock = CLASH_LOCK
	release_bind()

	# Ask before notifying: on_blade_clashed() changes the opponent's state.
	# Parry: we swung into their cut or windup. Block: we only held the line against a
	# cut actually coming down. Anything else (bumping a rising blade, cutting into
	# their guard) is a plain clang.
	var attacked: bool = opp != null and opp.has_method("is_attacking") and opp.is_attacking()
	var striking: bool = opp != null and opp.has_method("is_striking") and opp.is_striking()
	var parried := attacked and swing_speed >= PARRY_SPEED
	var blocked := striking and not parried
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
	clash_registered.emit(point, result)

	if opp != null and opp.has_method("on_blade_clashed"):
		opp.on_blade_clashed(point, parried)

	var scene := get_tree().current_scene
	match result:
		"PARRY!":
			Sfx.play("parry", point, 2.0)
			Fx.sparks(scene, point, 1.3)
		"BLOCKED":
			Sfx.play("block", point, 0.0)
			Fx.sparks(scene, point, 0.6)
		"GUARD BROKEN":
			Sfx.play("block", point, 3.0)
			Sfx.play("clash", point, -2.0)
			Fx.sparks(scene, point, 1.0)
		_:
			Sfx.play("clash", point, 0.0)
			Fx.sparks(scene, point, 0.9)


## combat.gd: the blades are resting together. Only actually pushing wears their guard down.
func bind_step(delta: float, opp: Node) -> void:
	binding = true
	if swing_speed >= BIND_PUSH_SPEED:
		_bind_time += delta
	else:
		_bind_time = maxf(_bind_time - delta, 0.0)
	if _bind_time >= BIND_BREAK_TIME:
		_bind_time = 0.0
		if opp != null and opp.has_method("guard_broken"):
			opp.guard_broken()
			Sfx.play("block", tip, -4.0)


func release_bind() -> void:
	binding = false
	_bind_time = 0.0


## combat.gd: our swinging blade reached their body.
func try_cut(body: Node, point: Vector3) -> void:
	if _cut_cd > 0.0:
		return
	_cut_cd = HIT_COOLDOWN
	body.receive_cut(tip_speed, point, _swing_dir)
	cut_registered.emit(tip_speed, point)
