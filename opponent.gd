extends CharacterBody3D
## A reactive AI duelist with a longsword.
##
## Loop: hold a guard at guard distance (just outside the player's resting reach),
## then step in with a telegraphed windup, cut along one of its lines, and step back
## out. How it fights is set by a tier (see main.gd): windup/attack speed, which lines
## it knows, how often it feints, chains a second cut, parries the player's cuts,
## presses into a bind, or punishes the player for stepping into range.
## Against it the player can:
##   - PARRY: swing into the cut           -> it staggers, wide open
##   - BLOCK: just hold the blade in line  -> no damage, but it keeps the pressure on
##   - back off early in the windup        -> the cut falls short
##   - win a BIND (combat.gd)              -> its blade is thrown aside
## Swinging carelessly into it gets parried and answered.

signal died
signal attack_whiffed   # a cut ended without landing (dodged, fell short)

enum State { IDLE, APPROACH, POISE, WINDUP, ATTACK, RECOVER, STAGGER, PARRY, BIND, DEAD }

const KnightScript := preload("res://knight.gd")
const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")
const Fx := preload("res://fx.gd")

const GRAVITY := 18.0
const POISE_RANGE := 2.0     # hold the guard here: just outside the player's resting reach
const ATTACK_RANGE := 1.5    # step in to here during the windup, then cut
const REACH := SwordMesh.REACH
const BLOCKED_FOLLOWUP := 0.25   # after being blocked (not parried), attack again this soon
const STEP_IN_SPEED := 3.0
const STEP_OUT_SPEED := 2.4
const PARRY_TIME := 0.32

# Poses are [grip, blade direction] in local space, -Z toward the player, right-side
# versions; the left side mirrors X. Each cut is [cocked, impact, follow-through]. At
# impact the blade is still on its own side (a cut from its right lands on the
# player's LEFT shoulder before it crosses the middle), so the player has to read the
# side to parry it; swinging the wrong way lets it through.
const NEUTRAL := [Vector3(0.22, 1.50, -0.12), Vector3(0.25, 1.0, 0.30)]   # blade up over the shoulder
const OPEN := [Vector3(0.25, 0.95, -0.20), Vector3(0.5, -0.6, -0.5)]      # blade low: practice target
const LINES := {
	"diag": [    # high diagonal cut onto the shoulder, then down across the body
		[Vector3(0.30, 1.55, -0.08), Vector3(0.45, 0.85, 0.35)],
		[Vector3(0.20, 1.48, -0.42), Vector3(0.06, -0.03, -1.0)],
		[Vector3(-0.14, 1.05, -0.40), Vector3(-0.72, -0.55, -0.42)],
	],
	"horiz": [   # level cut into the side at chest height
		[Vector3(0.34, 1.36, -0.05), Vector3(0.92, 0.12, 0.38)],
		[Vector3(0.24, 1.32, -0.42), Vector3(0.08, -0.02, -1.0)],
		[Vector3(-0.24, 1.30, -0.34), Vector3(-0.92, 0.0, -0.38)],
	],
	"thrust": [  # draw back, then drive the point straight in
		[Vector3(0.10, 1.28, 0.06), Vector3(0.04, 0.12, -1.0)],
		[Vector3(0.06, 1.31, -0.26), Vector3(0.02, 0.08, -1.0)],
		[Vector3(0.02, 1.34, -0.58), Vector3(0.0, 0.05, -1.0)],
	],
}

var hp := 100.0
var max_hp := 100.0
var display_name := ""

var _t := {}          # tier parameters
var _player: Node3D
var _sword            # the player's Sword (untyped: read dynamically)
var _drill := ""      # practice behaviour: "", "idle", "open", "attack", "bind"

var _state: int = State.IDLE
var _timer := 0.0
var _kind := "diag"
var _side := 1.0
var _windup_total := 0.0
var _feint_planned := false
var _feinted := false
var _in_combo := false
var _attack_hit := false
var _entry_checked := false
var _since_flinch := 99.0
var _push := Vector3.ZERO
var _parry_cd := 0.0
var _parry_side := 1.0
var _recent_cuts: Array[float] = []   # when the player's cuts landed on us (seconds)
var _overswing_cd := 0.0
var _clock := 0.0
var _wants_bind := false
var _bind_point_local := Vector3(0.0, 1.35, -1.0)

var _knight
var _grip := Vector3(0.22, 1.50, -0.12)
var _dir := Vector3(0.25, 1.0, 0.30).normalized()
var _edge := Vector3.RIGHT
var _path: Array = []
var _tip_local_prev := Vector3.ZERO
var _has_blade := false
var _step_dist := 0.0

# Blade state read by combat.gd, world space: the edge runs from base (front of the
# crossguard) to tip; prev_* are last frame's positions.
var blade_base := Vector3.ZERO
var blade_tip := Vector3.ZERO
var blade_prev_base := Vector3.ZERO
var blade_prev_tip := Vector3.ZERO
var blade_tip_vel := Vector3.ZERO


func _ready() -> void:
	collision_layer = 4       # opponent hurtbox
	collision_mask = 1 | 2    # arena (1) + player body (2)

	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.32
	cs.height = 1.70
	col.shape = cs
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)

	_knight = KnightScript.new()
	add_child(_knight)


func setup(player: Node3D, tier: Dictionary) -> void:
	_player = player
	_sword = player.sword if player != null else null
	_t = tier
	max_hp = float(tier.get("hp", 100.0))
	hp = max_hp
	display_name = String(tier.get("name", ""))
	_knight.build(tier.get("tabard", Color(0.3, 0.3, 0.45)), bool(tier.get("crest", false)))
	_update_blade(0.0)


## Starts fighting (main calls this when the duel begins).
func begin() -> void:
	_enter(State.APPROACH)


## Practice behaviour (main's hands-on practice): "idle" stands, "open" stands with the
## blade low, "attack" cuts slowly, "bind" closes in and waits to be bound.
func set_drill(mode: String) -> void:
	_drill = mode
	if mode == "idle" or mode == "open":
		_state = State.IDLE
	elif _state == State.IDLE:
		_enter(State.APPROACH)


func get_blade_vel() -> Vector3:
	return blade_tip_vel


## Winding up, or mid-cut and not yet landed (after landing, the follow-through that
## runs into the player's blade is not a blow they blocked).
func is_attacking() -> bool:
	return _state == State.WINDUP or (_state == State.ATTACK and not _attack_hit)


## Mid-cut and not yet landed: a blow the player can block (a windup can only be
## parried or bumped).
func is_striking() -> bool:
	return _state == State.ATTACK and not _attack_hit


func is_parrying() -> bool:
	return _state == State.PARRY


func is_dead() -> bool:
	return _state == State.DEAD


func is_open() -> bool:
	return _state == State.STAGGER or _state == State.RECOVER


func tier_value(key: String, fallback: Variant) -> Variant:
	return _t.get(key, fallback)


## combat.gd: our cut may land this frame.
func can_cut() -> bool:
	return is_striking()


## combat.gd: our cut reached the player.
func land_cut(target: Node, point: Vector3) -> void:
	_attack_hit = true
	# Its cuts are always fast; cap the speed so each tier's "damage" really sets how
	# many hits the player can take (roughly 6 / 5 / 4 from first to last).
	var speed := minf(blade_tip_vel.length(), 14.0)
	target.receive_cut(speed * float(_t.get("damage", 1.0)), point, blade_tip_vel.normalized())


## A cut from the player's sword landed.
func receive_cut(strength: float, pos: Vector3, swing_dir: Vector3) -> void:
	if _state == State.DEAD:
		return
	# Plate soaks light blows: only a fast, full cut does real damage.
	var armor := float(_t.get("armor", 1.5))
	hp = maxf(hp - clampf((strength - armor) * 2.8, 3.0, 34.0), 0.0)
	_recent_cuts.append(_clock)
	_knight.flash()
	Fx.cut_spray(get_tree().current_scene, pos, swing_dir)
	Sfx.play("cut", pos, 0.0)
	Sfx.play("hurt", pos, -5.0)
	if hp <= 0.0:
		_die()
		return
	# A short flinch from a strong cut if it wasn't mid-attack; not again right away,
	# so no stun-lock, and light blows don't stop it at all.
	if strength >= float(_t.get("flinch_speed", 7.0)) and not is_attacking() 			and _state != State.STAGGER and _state != State.BIND and _since_flinch > 1.2:
		_since_flinch = 0.0
		_enter(State.STAGGER)
		_timer = 0.3


## Our blade met the player's.
##   - we parried their cut: answer at once (riposte)
##   - they swung into our cut or windup (parry): we stagger, wide open
##   - they only held the line against our cut (block): come again quickly, or press
##     into a bind
##   - they cut into our guard: some fighters answer at once or bind
func on_blade_clashed(_pos: Vector3, player_parried: bool, i_parried: bool) -> void:
	if i_parried:
		_start_windup(0.5, 0.0)
	elif player_parried:
		_in_combo = false
		_enter(State.STAGGER)
		_push = global_transform.basis.z * 1.6   # knocked back a step
	elif is_striking():
		_in_combo = false
		if randf() < float(_t.get("bind_press", 0.0)):
			_wants_bind = true
		_enter(State.POISE)
		_timer = BLOCKED_FOLLOWUP
	elif not is_attacking() and _state != State.STAGGER and _drill == "":
		var r := randf()
		var riposte := float(_t.get("riposte", 0.0))
		if r < riposte:
			_start_windup(0.6, 0.0)
		elif r < riposte + float(_t.get("bind_press", 0.0)) * 0.5:
			_wants_bind = true


func guard_broken() -> void:
	if _state == State.DEAD:
		return
	_enter(State.STAGGER)
	_knight.flash()


# --- bind (combat.gd drives it) ------------------------------------------------------

func consume_bind_request() -> bool:
	var w := _wants_bind
	_wants_bind = false
	return w


func enter_bind() -> void:
	_wants_bind = false
	_in_combo = false
	_state = State.BIND


func set_bind_point(world_point: Vector3) -> void:
	_bind_point_local = to_local(world_point)


## The player won the bind: our blade is thrown aside.
func bind_lost(side: float) -> void:
	_side = side
	_enter(State.STAGGER)
	_timer = float(_t.get("stagger", 0.8)) + 0.15
	_push = global_transform.basis.z * 1.2


## We won the bind: the player's blade is shoved aside, cut straight from the bind.
func bind_won() -> void:
	_start_windup(0.3, 0.0)


## The bind came apart; if the player pulled out, some fighters cut after them.
func bind_released(player_pulled_out: bool) -> void:
	if player_pulled_out and randf() < float(_t.get("exit_cut", 0.0)):
		_start_windup(0.35, 0.0)
	else:
		_enter(State.POISE)
		_push = global_transform.basis.z * 0.8


# --- behaviour ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_since_flinch += delta
	_parry_cd -= delta
	_overswing_cd -= delta
	_clock += delta
	if _state == State.DEAD:
		velocity = Vector3(0.0, velocity.y - GRAVITY * delta, 0.0)
		move_and_slide()
		return
	if _player == null:
		_update_blade(delta)
		_knight.update_body(delta, 0.0)
		return

	_face_player()
	_run_state(delta)
	velocity += _push
	_push = _push.move_toward(Vector3.ZERO, 6.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var moving := Vector2(velocity.x, velocity.z).length()
	_knight.update_body(delta, moving)
	_step_dist += moving * delta
	if _step_dist > 0.75:
		_step_dist = 0.0
		Sfx.play("step", global_position, -9.0)
		Sfx.play("armor", global_position + Vector3(0, 1.0, 0), -14.0)
	_update_blade(delta)


func _face_player() -> void:
	var tp := _player.global_position
	tp.y = global_position.y
	if global_position.distance_to(tp) > 0.05:
		look_at(tp, Vector3.UP)


func _run_state(delta: float) -> void:
	_timer -= delta
	var dist := _horizontal_dist(_player.global_position)
	velocity.x = 0.0
	velocity.z = 0.0
	if not _player.get("alive"):
		_state = State.IDLE  # won: stand down, blade raised
		return

	_watch_for_player_cut()
	_watch_for_overswing()

	match _state:
		State.IDLE, State.BIND:
			pass
		State.APPROACH:
			if dist > POISE_RANGE:
				_move(float(_t.get("speed", 2.4)))
			else:
				_enter(State.POISE)
		State.POISE:
			if dist > POISE_RANGE + 0.35:
				_enter(State.APPROACH)
			elif dist < ATTACK_RANGE + 0.15:
				# The player stepped into range: some fighters strike first.
				if not _entry_checked:
					_entry_checked = true
					if _drill == "" and randf() < float(_t.get("punish", 0.0)):
						_start_windup(0.75, 0.0)
			else:
				_entry_checked = false
			# Too close to be comfortable (e.g. right after a blocked cut): ease back out.
			if _state == State.POISE and dist < POISE_RANGE - 0.3 and _timer > BLOCKED_FOLLOWUP:
				_move(-STEP_OUT_SPEED * 0.6)
			if _state == State.POISE and _timer <= 0.0:
				if _drill != "bind" and randf() < float(_t.get("attack_prob", 0.7)):
					_start_windup(1.0, 0.0)
				else:
					_timer = randf_range(0.4, 0.9)
		State.WINDUP:
			# Step in during the first part of the windup, then plant the feet for the
			# cut, so backing off at the right moment makes it fall short.
			if dist > ATTACK_RANGE and _timer > _windup_total * 0.4:
				_move(STEP_IN_SPEED)
			if _feint_planned and not _feinted and _timer < _windup_total * 0.45:
				# Feint: switch to the other side, which costs a moment.
				_feinted = true
				_side = -_side
				_timer += 0.2
			if _timer <= 0.0:
				_start_attack()
		State.ATTACK:
			if _timer <= 0.0:
				if not _in_combo and randf() < float(_t.get("combo", 0.0)):
					_in_combo = true
					_start_windup(0.55, -_side)
				else:
					_in_combo = false
					if not _attack_hit:
						attack_whiffed.emit()
					_enter(State.RECOVER)
		State.RECOVER:
			if dist < POISE_RANGE:
				_move(-STEP_OUT_SPEED)
			if _timer <= 0.0:
				_enter(State.POISE)
		State.STAGGER:
			if _timer <= 0.0:
				_enter(State.POISE)
		State.PARRY:
			if _timer <= 0.0:
				_enter(State.POISE)


## When the player's blade comes at us in a real swing, better fighters snap their
## guard across its path (a parry of our own). Decided once per swing.
func _watch_for_player_cut() -> void:
	if _sword == null or _parry_cd > 0.0 or _drill != "":
		return
	if not (_state == State.POISE or _state == State.RECOVER or _state == State.APPROACH):
		return
	if not _sword.is_real_swing(3.0, 0.18):
		return
	var chest := global_position + Vector3(0.0, 1.25, 0.0)
	var to_me: Vector3 = chest - _sword.tip
	if to_me.length() > 1.35 or _sword.tip_vel.dot(to_me) <= 0.0:
		return
	# It reads a rhythm: every cut it took in the last few seconds makes the next parry
	# likelier, so flailing gets caught.
	while not _recent_cuts.is_empty() and _clock - _recent_cuts[0] > 2.5:
		_recent_cuts.pop_front()
	var chance := float(_t.get("parry", 0.0)) + 0.22 * _recent_cuts.size()
	if _recent_cuts.size() > 0:
		chance = maxf(chance, 0.3)
	_parry_cd = 0.45
	if randf() < minf(chance, 0.9):
		var x: float = to_local(_sword.tip).x
		_parry_side = 1.0 if x >= 0.0 else -1.0
		_state = State.PARRY
		_timer = PARRY_TIME


## A long swing that carried the player's blade far off to one side leaves them open:
## good fighters cut into that opening at once.
func _watch_for_overswing() -> void:
	if _sword == null or _drill != "" or _overswing_cd > 0.0:
		return
	if not (_state == State.POISE or _state == State.APPROACH):
		return
	if _sword.swing_arc < 0.6:
		return
	var tip_local: Vector3 = to_local(_sword.tip)
	if absf(tip_local.x) < 0.75:
		return
	_overswing_cd = 0.9
	if randf() < float(_t.get("punish", 0.0)):
		_start_windup(0.6, 0.0)


func _enter(state: int) -> void:
	_state = state
	match state:
		State.POISE:
			var p: Vector2 = _t.get("poise", Vector2(0.6, 1.2))
			_timer = randf_range(p.x, p.y)
		State.ATTACK:
			_timer = float(_t.get("attack", 0.22))
		State.RECOVER:
			_timer = float(_t.get("recover", 0.55))
		State.STAGGER:
			_timer = float(_t.get("stagger", 0.9))


## side = 0 picks a random side; otherwise forces it (combos come from the other side).
func _start_windup(scale: float, side: float) -> void:
	var lines: Array = _t.get("lines", ["diag"])
	_kind = lines[randi() % lines.size()]
	_side = side if side != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	_windup_total = float(_t.get("windup", 0.4)) * scale
	_feint_planned = side == 0.0 and _kind != "thrust" and randf() < float(_t.get("feint", 0.0))
	_feinted = false
	_state = State.WINDUP
	_timer = _windup_total


func _start_attack() -> void:
	var line: Array = LINES[_kind]
	_path = [[_grip, _dir], _pose_of(line[1], _side), _pose_of(line[2], _side)]
	_attack_hit = false
	_enter(State.ATTACK)
	Sfx.play("swing", blade_tip, 0.0)


func _move(speed: float) -> void:
	var d := _player.global_position - global_position
	d.y = 0.0
	d = d.normalized() * speed
	velocity.x = d.x
	velocity.z = d.z


# --- blade posing ------------------------------------------------------------------

func _pose_of(p: Array, side: float) -> Array:
	var g: Vector3 = p[0]
	var d: Vector3 = p[1]
	return [Vector3(g.x * side, g.y, g.z), Vector3(d.x * side, d.y, d.z).normalized()]


func _target_pose() -> Array:
	match _state:
		State.WINDUP:
			var line: Array = LINES[_kind]
			return _pose_of(line[0], _side)
		State.STAGGER:
			return [Vector3(0.28 * _side, 1.10, -0.12), Vector3(0.95 * _side, -0.25, 0.15).normalized()]
		State.PARRY:
			# Blade snapped across the incoming cut, on the side it comes from.
			return [Vector3(0.14 * _parry_side, 1.22, -0.36), Vector3(0.6 * _parry_side, 0.75, -0.3).normalized()]
		State.BIND:
			var grip := Vector3(0.10, 1.25, -0.40)
			return [grip, (_bind_point_local - grip).normalized()]
		State.POISE, State.RECOVER:
			# Upright guard in front of the body, leaning toward the side of the player's
			# blade: a barrier over the high line, not a probe that reaches out to it.
			var s := 0.0
			if _sword != null:
				s = clampf(to_local(_sword.get_tip_pos()).x / 0.5, -1.0, 1.0)
			return [Vector3(0.08 + 0.16 * s, 1.00, -0.34), Vector3(0.28 * s, 1.0, -0.12).normalized()]
		_:
			if _drill == "open":
				return _pose_of(OPEN, 1.0)
			return _pose_of(NEUTRAL, 1.0)


func _attack_pose() -> Array:
	var t := clampf(1.0 - _timer / float(_t.get("attack", 0.22)), 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var a: Array = _path[0] if e < 0.5 else _path[1]
	var b: Array = _path[1] if e < 0.5 else _path[2]
	var u := e * 2.0 if e < 0.5 else e * 2.0 - 1.0
	var ga: Vector3 = a[0]
	var gb: Vector3 = b[0]
	return [ga.lerp(gb, u), _turn(a[1], b[1], u)]


func _lerp_rate() -> float:
	match _state:
		State.WINDUP:
			return 9.0
		State.POISE:
			return float(_t.get("guard_track", 6.0))
		State.RECOVER:
			# Bringing the guard back up after a cut: the brief window to punish.
			return float(_t.get("guard_track", 6.0)) * 0.55
		State.STAGGER:
			return 7.0
		State.PARRY:
			return 28.0
		State.BIND:
			return 20.0
		_:
			return 5.0


func _update_blade(delta: float) -> void:
	if _state == State.ATTACK and _path.size() == 3:
		var pose := _attack_pose()
		_grip = pose[0]
		_dir = pose[1]
	else:
		var target := _target_pose()
		var k := clampf(_lerp_rate() * delta, 0.0, 1.0) if delta > 0.0 else 1.0
		_grip = _grip.lerp(target[0], k)
		_dir = _turn(_dir, target[1], k)

	var tip_local := _grip + _dir * REACH
	var swing := tip_local - _tip_local_prev
	if swing.length() > 0.002:
		_edge = _edge.lerp(swing.normalized(), 0.35).normalized()
	_tip_local_prev = tip_local

	var blade_basis := Armor.blade_basis(_dir, _edge)
	_knight.pose_arms(_grip, blade_basis)

	var new_tip := to_global(tip_local)
	var new_base := to_global(_grip + _dir * SwordMesh.BLADE_START)
	if _has_blade and delta > 0.0:
		blade_tip_vel = (new_tip - blade_tip) / delta
		blade_prev_base = blade_base
		blade_prev_tip = blade_tip
	else:
		blade_prev_base = new_base
		blade_prev_tip = new_tip
	blade_base = new_base
	blade_tip = new_tip
	_has_blade = true


## Rotate direction a toward b by weight k (safe when they point opposite ways).
func _turn(a: Vector3, b: Vector3, k: float) -> Vector3:
	var r := a.slerp(b, k)
	if r.length() < 0.01:
		return b
	return r.normalized()


func _die() -> void:
	_state = State.DEAD
	collision_layer = 0
	_knight.collapse()
	Sfx.play("block", global_position + Vector3(0, 0.3, 0), -2.0)
	died.emit()


func _horizontal_dist(p: Vector3) -> float:
	var a := global_position
	a.y = 0.0
	p.y = 0.0
	return a.distance_to(p)
