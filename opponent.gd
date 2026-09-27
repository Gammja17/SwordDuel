extends CharacterBody3D
## A reactive AI duelist with a longsword, played by the animated knight in
## knight_body.gd. Its blade is wherever the animation puts its right hand; combat.gd
## reads that every frame, so blades still really meet.
##
## Loop: circle at guard distance, then step in with a windup (the attack clip played
## slowly up to just before the strike), strike (the clip at speed), and step back out.
## How it fights is set by a tier (see main.gd): windup/attack speed, which attacks it
## knows, how often it feints, chains a second cut, parries or dodges the player's
## cuts, presses into a bind, or punishes the player for stepping into range.

signal died
signal attack_whiffed   # a cut ended without landing (dodged, fell short)

enum State { IDLE, APPROACH, POISE, WINDUP, ATTACK, RECOVER, STAGGER, PARRY, BIND, DEAD, DODGE }

const BodyScript := preload("res://knight_body.gd")
const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")
const Fx := preload("res://fx.gd")

const GRAVITY := 18.0
const POISE_RANGE := 2.0     # hold the guard here: just outside the player's resting reach
const ATTACK_RANGE := 1.5    # step in to here during the windup, then cut
const BLOCKED_FOLLOWUP := 0.25   # after being blocked (not parried), attack again this soon
const STEP_IN_SPEED := 3.0
const STEP_OUT_SPEED := 2.0   # the walk in reverse keeps its feet planted up to ~2 m/s
const CIRCLE_SPEED := 1.1
const PARRY_TIME := 0.32
const DODGE_TIME := 0.4
const DODGE_SPEED := 4.2
const STRIKE_LEAD := 0.09    # the strike segment starts this long before the fastest moment
const STRIKE_TAIL := 0.09

# Attack clips: [clip, seconds into the clip where the swing is fastest (measured)].
const ATTACKS := {
	"a": ["ual2/Sword_Regular_A", 0.25],
	"b": ["ual2/Sword_Regular_B", 0.27],
	"c": ["ual2/Sword_Regular_C", 0.65],
	"lunge": ["ual2/Sword_Dash", 0.33],
}

var hp := 100.0
var max_hp := 100.0
var display_name := ""

var _t := {}          # tier parameters
var _player: Node3D
var _sword            # the player's Sword (untyped: read dynamically)
var _drill := ""      # practice behaviour: "", "idle", "open", "attack", "bind"
var _body

var _state: int = State.IDLE
var _timer := 0.0
var _kind := "a"
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
var _recent_cuts: Array[float] = []
var _overswing_cd := 0.0
var _clock := 0.0
var _wants_bind := false
var _circle_dir := 1.0
var _circle_switch := 2.0
var _dodge_vel := Vector3.ZERO
var _dodge_dir_local := Vector3(0, 0, 1)
var _step_dist := 0.0
var _has_blade := false

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
	_body = BodyScript.new()
	add_child(_body)


func setup(player: Node3D, tier: Dictionary) -> void:
	_player = player
	_sword = player.sword if player != null else null
	_t = tier
	max_hp = float(tier.get("hp", 100.0))
	hp = max_hp
	display_name = String(tier.get("name", ""))
	_body.build(tier.get("tabard", Color(0.3, 0.3, 0.45)), bool(tier.get("crest", false)))
	refresh_blade(0.0)


## Starts fighting (main calls this when the duel begins).
func begin() -> void:
	_enter(State.APPROACH)


## Practice behaviour: "idle" stands on guard, "open" stands with the sword lowered,
## "attack" cuts slowly, "bind" closes in and waits to be bound.
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


## Mid-cut and not yet landed: a blow the player can block.
func is_striking() -> bool:
	return _state == State.ATTACK and not _attack_hit


func is_parrying() -> bool:
	return _state == State.PARRY


func is_dodging() -> bool:
	return _state == State.DODGE


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


## combat.gd, first thing each frame: where the animated sword is now.
func refresh_blade(delta: float) -> void:
	var t: Transform3D = _body.sword_transform()
	var new_tip := t * Vector3(0.0, 0.0, -SwordMesh.REACH)
	var new_base := t * Vector3(0.0, 0.0, -SwordMesh.BLADE_START)
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


## A cut from the player's sword landed.
func receive_cut(strength: float, pos: Vector3, swing_dir: Vector3) -> void:
	if _state == State.DEAD:
		return
	# Plate soaks light blows: only a fast, full cut does real damage.
	var armor := float(_t.get("armor", 1.5))
	hp = maxf(hp - clampf((strength - armor) * 2.8, 3.0, 34.0), 0.0)
	_recent_cuts.append(_clock)
	_body.flash()
	Fx.cut_spray(get_tree().current_scene, pos, swing_dir)
	Sfx.play("cut", pos, 0.0)
	Sfx.play("hurt", pos, -5.0)
	if hp <= 0.0:
		_die()
		return
	# A short flinch from a strong cut if it wasn't mid-attack; not again right away,
	# so no stun-lock, and light blows don't stop it at all.
	if strength >= float(_t.get("flinch_speed", 7.0)) and not is_attacking() \
			and _state != State.STAGGER and _state != State.BIND and _since_flinch > 1.2:
		_since_flinch = 0.0
		_state = State.STAGGER
		_timer = 0.35
		_body.act("Hit_Chest", 0.0, _body.clip_length("Hit_Chest"), 0.35, 0.05)


## Our blade met the player's.
##   - we parried their cut: answer at once (riposte)
##   - they swung into our cut or windup (parry): we stagger, wide open
##   - they only held the line against our cut (block): come again quickly, or bind
##   - they cut into our guard: some fighters answer at once or bind
func on_blade_clashed(_pos: Vector3, player_parried: bool, i_parried: bool) -> void:
	if i_parried:
		_start_windup(0.5)
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
			_start_windup(0.6)
		elif r < riposte + float(_t.get("bind_press", 0.0)) * 0.5:
			_wants_bind = true


func guard_broken() -> void:
	if _state == State.DEAD:
		return
	_enter(State.STAGGER)
	_body.flash()


# --- bind (combat.gd drives it) ------------------------------------------------------

func consume_bind_request() -> bool:
	var w := _wants_bind
	_wants_bind = false
	return w


func enter_bind() -> void:
	_wants_bind = false
	_in_combo = false
	_state = State.BIND
	_body.act("ual2/Sword_Block", 0.3, 0.3, 1.0, 0.12)   # hold the block pose


func set_bind_point(world_point: Vector3) -> void:
	# Hold the sword from our grip toward the crossing point.
	var hand: Transform3D = _body.sword_transform()
	var dir := (world_point - hand.origin).normalized()
	_body.hold_sword(Transform3D(Armor.blade_basis(dir, Vector3.UP.cross(dir)), hand.origin))


## The player won the bind: our blade is thrown aside.
func bind_lost(side: float) -> void:
	_body.release_sword()
	_side = side
	_enter(State.STAGGER)
	_timer = float(_t.get("stagger", 0.8)) + 0.15
	_push = global_transform.basis.z * 1.2


## We won the bind: the player's blade is shoved aside, cut straight from the bind.
func bind_won() -> void:
	_body.release_sword()
	_start_windup(0.3)


## The bind came apart; if the player pulled out, some fighters cut after them.
func bind_released(player_pulled_out: bool) -> void:
	_body.release_sword()
	if player_pulled_out and randf() < float(_t.get("exit_cut", 0.0)):
		_start_windup(0.35)
	else:
		_enter(State.POISE)
		_push = global_transform.basis.z * 0.8


# --- behaviour ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_since_flinch += delta
	_parry_cd -= delta
	_overswing_cd -= delta
	_clock += delta
	_body.update_body(delta)
	if _state == State.DEAD:
		velocity = Vector3(0.0, velocity.y - GRAVITY * delta, 0.0)
		move_and_slide()
		return
	if _player == null:
		_body.move(Vector2.ZERO)
		return

	_face_player()
	_run_state(delta)
	velocity += _push + _dodge_vel
	_push = _push.move_toward(Vector3.ZERO, 6.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_animate_locomotion()

	var moving := Vector2(velocity.x, velocity.z).length()
	_step_dist += moving * delta
	if _step_dist > 0.75:
		_step_dist = 0.0
		Sfx.play("step", global_position, -9.0)
		Sfx.play("armor", global_position + Vector3(0, 1.0, 0), -14.0)


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
	_dodge_vel = Vector3.ZERO
	if not _player.get("alive"):
		_state = State.IDLE  # won: stand down
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
						_start_windup(0.75)
			else:
				_entry_checked = false
			if _state == State.POISE:
				_circle(delta, dist)
			if _state == State.POISE and _timer <= 0.0:
				if _drill != "bind" and randf() < float(_t.get("attack_prob", 0.7)):
					_start_windup(1.0)
				else:
					_timer = randf_range(0.4, 0.9)
		State.WINDUP:
			# Step in during the first part of the windup, then plant the feet for the
			# cut, so backing off at the right moment makes it fall short.
			if dist > ATTACK_RANGE and _timer > _windup_total * 0.4:
				_move(STEP_IN_SPEED * (1.4 if _kind == "lunge" else 1.0))
			if _feint_planned and not _feinted and _timer < _windup_total * 0.45:
				_feint()
			if _timer <= 0.0:
				_start_attack()
		State.ATTACK:
			if _kind == "lunge":
				_move(2.5)
			if _timer <= 0.0:
				if not _in_combo and randf() < float(_t.get("combo", 0.0)):
					_in_combo = true
					_start_windup(0.55)
				else:
					_in_combo = false
					if not _attack_hit:
						attack_whiffed.emit()
					_enter(State.RECOVER)
					_body.act_speed(1.0)   # finish the follow-through at natural speed
		State.RECOVER:
			if dist < POISE_RANGE:
				_move(-STEP_OUT_SPEED)
			if _timer <= 0.0:
				_enter(State.POISE)
		State.STAGGER, State.PARRY:
			if _timer <= 0.0:
				_enter(State.POISE)
		State.DODGE:
			_dodge_vel = global_transform.basis * _dodge_dir_local * DODGE_SPEED * clampf(_timer / DODGE_TIME, 0.2, 1.0)
			if _timer <= 0.0:
				_enter(State.POISE)


## While holding guard it circles the player, now and then changing direction, and
## keeps its distance.
func _circle(delta: float, dist: float) -> void:
	_circle_switch -= delta
	if _circle_switch <= 0.0:
		_circle_switch = randf_range(1.2, 3.0)
		if randf() < 0.7:
			_circle_dir = -_circle_dir
	var v := global_transform.basis.x * _circle_dir * CIRCLE_SPEED
	if dist < POISE_RANGE - 0.3 and _timer > BLOCKED_FOLLOWUP:
		v += global_transform.basis.z * STEP_OUT_SPEED * 0.6   # too close: ease back out
	velocity.x = v.x
	velocity.z = v.z


## When the player's blade comes at us in a real swing, better fighters snap their
## guard across it (a parry) or step out of the way (a dodge). Decided once per swing.
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
	var parry := float(_t.get("parry", 0.0)) + 0.22 * _recent_cuts.size()
	if _recent_cuts.size() > 0:
		parry = maxf(parry, 0.3)
	parry = minf(parry, 0.9)
	var dodge := float(_t.get("dodge", 0.0))
	_parry_cd = 0.45
	var r := randf()
	if r < parry:
		_state = State.PARRY
		_timer = PARRY_TIME
		_body.act("ual2/Sword_Block", 0.0, 0.35, PARRY_TIME, 0.04)
	elif r < parry + dodge:
		_start_dodge()


func _start_dodge() -> void:
	_state = State.DODGE
	_timer = DODGE_TIME
	var pick := randi() % 3
	var clip: String = ["kay/Dodge_Backward", "kay/Dodge_Left", "kay/Dodge_Right"][pick]
	var dirs := [Vector3(0, 0, 1), Vector3(-1, 0, 0.4), Vector3(1, 0, 0.4)]
	_dodge_dir_local = (dirs[pick] as Vector3).normalized()
	_body.act(clip, 0.0, _body.clip_length(clip), DODGE_TIME, 0.05)


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
		_start_windup(0.6)


func _enter(state: int) -> void:
	_state = state
	if state == State.POISE or state == State.APPROACH:
		_body.release(0.25)   # back to stance and footwork
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
			_body.act("ual2/Hit_Knockback", 0.0, _body.clip_length("ual2/Hit_Knockback"), _timer, 0.08)


## Windup: the attack clip played slowly up to just before its strike.
func _start_windup(scale: float) -> void:
	var lines: Array = _t.get("lines", ["a"])
	_kind = lines[randi() % lines.size()]
	_side = 1.0 if randf() < 0.5 else -1.0
	# Better fighters vary their rhythm, so the cut can't be timed by counting.
	var jitter := float(_t.get("windup_jitter", 0.0))
	_windup_total = float(_t.get("windup", 0.4)) * scale * randf_range(1.0 - jitter, 1.0 + jitter)
	_feint_planned = scale >= 1.0 and lines.size() > 1 and randf() < float(_t.get("feint", 0.0))
	_feinted = false
	_state = State.WINDUP
	_timer = _windup_total
	var a: Array = ATTACKS[_kind]
	_body.act(a[0], 0.0, maxf(float(a[1]) - STRIKE_LEAD, 0.05), _windup_total, 0.15)


## Feint: switch to a different attack partway through the windup, which costs a moment.
func _feint() -> void:
	_feinted = true
	var lines: Array = _t.get("lines", ["a"])
	var other := _kind
	while other == _kind:
		other = lines[randi() % lines.size()]
	_kind = other
	_timer += 0.2
	var a: Array = ATTACKS[_kind]
	var until := maxf(float(a[1]) - STRIKE_LEAD, 0.05)
	_body.act(a[0], until * 0.4, until, _timer, 0.12)


## Strike: the same clip carries on from the windup (no cut in the motion), sped up so
## its fastest part takes this tier's attack time.
func _start_attack() -> void:
	_attack_hit = false
	_enter(State.ATTACK)
	_body.act_speed((STRIKE_LEAD + STRIKE_TAIL) / maxf(_timer, 0.05))
	Sfx.play("swing", blade_tip, 0.0)


## Legs follow the body's velocity every frame; the upper body keeps its guard up
## (lowered only for the practice target), and after a cut the follow-through fades
## back into footwork partway through the recovery.
func _animate_locomotion() -> void:
	var local := global_transform.basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	_body.move(Vector2(local.x, -local.z))
	_body.set_guard(0.0 if _drill == "open" else 1.0)
	if _state == State.RECOVER and _timer < float(_t.get("recover", 0.55)) * 0.6:
		_body.release(0.3)


func _move(speed: float) -> void:
	var d := _player.global_position - global_position
	d.y = 0.0
	d = d.normalized() * speed
	velocity.x = d.x
	velocity.z = d.z


func _die() -> void:
	_state = State.DEAD
	collision_layer = 0
	_body.collapse()
	Sfx.play("block", global_position + Vector3(0, 0.3, 0), -2.0)
	died.emit()


func _horizontal_dist(p: Vector3) -> float:
	var a := global_position
	a.y = 0.0
	p.y = 0.0
	return a.distance_to(p)
