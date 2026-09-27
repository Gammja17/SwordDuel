extends Node3D
## The player's longsword: where it is, how fast it moves, and what happens to us when
## it meets the opponent's blade. Whether it touched anything is decided by combat.gd
## once per frame, after both fighters have moved.
##
## Two speeds of the tip matter:
##   - SWING speed: tip motion relative to our own body, i.e. the arms (the mouse).
##     It decides whether we are actually swinging, so walking or turning with a still
##     blade does nothing.
##   - WORLD speed: swing plus footwork. It sets how hard a cut lands (stepping into a
##     cut adds power) and, against the other blade, whether the contact is a clash.
## A real swing also needs travel (swing_arc): small wiggles, however fast, neither
## cut nor parry. Blades meeting fast -> see clash(); meeting slowly -> they lock in a
## bind, which combat.gd runs as a pushing contest.

signal cut_registered(strength: float, pos: Vector3)
signal clash_registered(pos: Vector3, result: String)  # see clash()

const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")
const Fx := preload("res://fx.gd")

const REACH := SwordMesh.REACH
const CUT_THRESHOLD := 3.0    # swing speed below which the blade doesn't cut
const CLASH_THRESHOLD := 4.0  # blade-vs-blade relative speed above this = clash, below = bind
const PARRY_SPEED := 2.5      # our own swing speed that turns meeting an attack into a parry
const CUT_ARC := 0.30         # net tip travel (m, over ARC_FRAMES) a cut needs
const PARRY_ARC := 0.15       # ... and a parry
const ARC_FRAMES := 11
const HIT_COOLDOWN := 0.35    # delay before the same swing can cut again
const CLASH_LOCK := 0.25      # after a clash the blade is bouncing; no cut/clash
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
var swing_arc := 0.0
var clash_lock := 0.0
var binding := false

var _tip_local_prev := Vector3.ZERO
var _swing_dir := Vector3.ZERO
var _edge_local := Vector3.RIGHT
var _has_prev := false
var _swing_cd := 0.0
var _cut_cd := 0.0
var _arc_hist: Array[Vector3] = []


func get_tip_speed() -> float:
	return tip_speed


func get_swing_speed() -> float:
	return swing_speed


func get_tip_pos() -> Vector3:
	return tip


func is_binding() -> bool:
	return binding


func can_cut() -> bool:
	return clash_lock <= 0.0 and swing_speed >= CUT_THRESHOLD and swing_arc >= CUT_ARC


func is_real_swing(min_speed: float, min_arc: float) -> bool:
	return swing_speed >= min_speed and swing_arc >= min_arc


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
	_arc_hist.append(tip_local)
	if _arc_hist.size() > ARC_FRAMES:
		_arc_hist.pop_front()
	swing_arc = (tip_local - _arc_hist[0]).length()

	clash_lock = maxf(clash_lock - delta, 0.0)
	_cut_cd -= delta

	global_transform = Transform3D(Armor.blade_basis(dir, body.global_transform.basis * _edge_local), grip_world)

	_swing_cd -= delta
	if swing_speed > SWING_SOUND_SPEED and swing_arc > CUT_ARC and _swing_cd <= 0.0:
		_swing_cd = 0.35
		Sfx.play("swing", tip, lerpf(-8.0, 0.0, clampf((swing_speed - 6.0) / 6.0, 0.0, 1.0)))


## combat.gd: our blade met theirs at speed. Returns what it was:
## "PARRIED" (they parried our cut), "PARRY!" (we swung into their cut or windup),
## "BLOCKED" (we only held the line against a cut coming down), "GUARD BROKEN" (a
## block or a parried cut that broke our guard) or "CLANG!" (anything else).
func clash(point: Vector3, opp: Node, opp_vel: Vector3) -> String:
	clash_lock = CLASH_LOCK
	binding = false

	var they_parried: bool = opp != null and opp.has_method("is_parrying") and opp.is_parrying()
	var attacked: bool = opp != null and opp.has_method("is_attacking") and opp.is_attacking()
	var striking: bool = opp != null and opp.has_method("is_striking") and opp.is_striking()
	# A parry: swinging into it, or pressing guard just before it lands.
	var p := get_parent()
	var timed: bool = p != null and p.has_method("is_parry_window") and p.is_parry_window()
	var parried := not they_parried and attacked and (is_real_swing(PARRY_SPEED, PARRY_ARC) or timed)
	var blocked := not they_parried and striking and not parried
	var result := "CLANG!"
	if they_parried:
		result = "PARRIED"
	elif parried:
		result = "PARRY!"
	elif blocked:
		result = "BLOCKED"

	if p is Node3D and p.has_method("deflect"):
		var right := (p as Node3D).global_transform.basis.x
		var h: float
		if attacked or they_parried:
			h = signf(opp_vel.dot(right))     # shoved the way their blade travels
		else:
			h = -signf(_swing_dir.dot(right)) # bounce back opposite our own swing
		if h == 0.0:
			h = 1.0
		if they_parried:
			if p.get_parried(h):
				result = "GUARD BROKEN"
		elif blocked:
			# A passive block knocks our guard open and fills the guard meter.
			if p.absorb_block(h):
				result = "GUARD BROKEN"
		else:
			p.deflect(Vector2(h * 0.30, 0.18), 0.18)
	clash_registered.emit(point, result)

	if opp != null and opp.has_method("on_blade_clashed"):
		opp.on_blade_clashed(point, parried, they_parried)

	var scene := get_tree().current_scene
	match result:
		"PARRIED":
			Sfx.play("parry", point, 2.0)
			Fx.sparks(scene, point, 1.1)
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
	return result


func release_bind() -> void:
	binding = false


## combat.gd: our swinging blade reached their body.
func try_cut(body: Node, point: Vector3) -> void:
	if _cut_cd > 0.0:
		return
	_cut_cd = HIT_COOLDOWN
	body.receive_cut(tip_speed, point, _swing_dir)
	cut_registered.emit(tip_speed, point)
