extends CharacterBody3D
## A reactive AI duelist with a longsword, played by the animated knight in
## knight_body.gd. Its sword moves between clean poses (sword_poses.gd) on timing
## curves, and the body follows it; combat.gd reads the blade every frame, so blades
## still really meet.
##
## Loop: circle at guard distance, then step in with a windup (the sword drawn back and
## held there a moment: the tell), strike (a fast arc through to the other side, with a
## small step), hold the follow-through, and come back to guard.
## How it fights is set by a tier (see main.gd): windup/attack speed, which attacks it
## knows, how often it feints, chains a second cut, parries or dodges the player's
## cuts, presses into a bind, or punishes the player for stepping into range.

signal died
signal yielded   # a fighter that yields (tier "yields") went down on its knees instead of dying
signal phase_changed   # it was hurt enough to change (its tier's "phase2")
signal telegraphed(kind: String)   # a move worth warning the player about (bash, smash)
signal bashed   # the shield bash landed
signal attack_whiffed   # a cut ended without landing (dodged, fell short)

enum State { IDLE, APPROACH, POISE, WINDUP, ATTACK, RECOVER, STAGGER, PARRY, BIND, DEAD, DODGE, HELD }

const BodyScript := preload("res://knight_body.gd")
const SwordMesh := preload("res://sword_mesh.gd")
const Fx := preload("res://fx.gd")
const Trail := preload("res://trail.gd")
const SwordPoses := preload("res://sword_poses.gd")

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
const WINDUP_DRAW := 0.55    # share of the windup spent drawing back; the rest is held
const CUT_ARC := 0.24        # how far the hands swing out in front mid-cut (m)
const STRIKE_STEP := 2.2     # a step into each cut (m/s, fading: about 0.4 m)
const BIND_GRIP := Vector3(0.04, -0.06, -0.34)
const EXECUTE_BELOW := 0.3   # share of health below which a reeling fighter can be executed

var hp := 100.0
var max_hp := 100.0
var display_name := ""

var _t := {}          # tier parameters
var _player: Node3D
var _sword            # the player's Sword (untyped: read dynamically)
var _drill := ""      # practice behaviour: "", "idle", "open", "attack", "bind"
var _body
var _trail

var _state: int = State.IDLE
var _timer := 0.0
var _kind := "a"
var _bash_pending := false
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

# The sword's pose and the move it is making (see _sword_to).
var _pose := {}
var _from := {}
var _to := {}
var _move_t := 0.0
var _move_len := 0.01
var _move_ease := ""
var _move_arc := 0.0
var _via := {}   # a pose the move passes through halfway, or empty
var _returning := false
var _crit_until := -1.0     # (clock) open to a critical thrust until then
var _recoil := 0.0          # 1 just after a blow landed: the torso snaps away from it
var _recoil_side := 1.0
var dmg_mult := 1.0   # the difficulty setting
var _phase2 := false
var _yielded := false
var _wobble := 0.0          # 1 right after being parried: the body sways, settling

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
	_trail = Trail.new()
	_trail.color = Color(1.0, 0.55, 0.42, 0.4)
	add_child(_trail)


func setup(player: Node3D, tier: Dictionary) -> void:
	_player = player
	_sword = player.sword if player != null else null
	_t = tier
	max_hp = float(tier.get("hp", 100.0))
	hp = max_hp
	display_name = String(tier.get("name", ""))
	_body.build(tier.get("tabard", Color(0.3, 0.3, 0.45)), bool(tier.get("crest", false)), String(tier.get("outfit", "")))
	_body.set_kit(String(tier.get("kit", "two")))
	_pose = SwordPoses.make("guard")
	_sword_to(_pose, 0.01)
	_update_sword(0.0)
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
		_sword_to(_rest_pose(), 0.35)
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
	# (A shield bash is not the blade: it can't be blocked or parried, only dodged.)
	return _state == State.ATTACK and not _attack_hit and _kind != "bash"


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
	target.receive_cut(speed * float(_t.get("damage", 1.0)) * dmg_mult * (1.45 if _kind == "smash" else 1.0), point, blade_tip_vel.normalized())


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
	if _trail != null:
		_trail.push(blade_base, blade_tip, 1.0 if is_striking() else 0.0)


## A cut from the player's sword landed.
func receive_cut(strength: float, pos: Vector3, swing_dir: Vector3) -> void:
	if _state == State.DEAD:
		return
	# Plate soaks light blows: only a fast, full cut does real damage.
	var armor := float(_t.get("armor", 1.5))
	hp = maxf(hp - clampf((strength - armor) * 2.8, 3.0, 34.0), 0.0)
	_recent_cuts.append(_clock)
	_body.flash()
	Fx.cut_spray(get_tree().current_scene, pos, swing_dir, clampf(strength / 6.0, 0.6, 1.8))
	Sfx.play("cut", pos, 0.0)
	Sfx.play("hurt", pos, -5.0)
	Sfx.play("armor", pos, -4.0)
	# Every blow rocks it: the torso snaps away from the cut and it gives ground.
	var side := to_local(pos).x
	_recoil_side = signf(side) if absf(side) > 0.02 else 1.0
	_recoil = clampf(0.4 + strength * 0.07, 0.4, 1.0)
	if not is_attacking() and _state != State.BIND:
		_push = global_transform.basis.z * (0.8 + strength * 0.12)
	if hp <= 0.0:
		if bool(_t.get("yields", false)) and not _yielded:
			_yield()
		else:
			_die()
		return
	_check_phase()
	# A short flinch from a strong cut if it wasn't mid-attack; not again right away,
	# so no stun-lock, and light blows don't stop it at all.
	if strength >= float(_t.get("flinch_speed", 7.0)) and not is_attacking() \
			and _state != State.STAGGER and _state != State.BIND and _since_flinch > 1.2:
		_since_flinch = 0.0
		_state = State.STAGGER
		_timer = 0.35
		_body.act("Hit_Chest", 0.0, _body.clip_length("Hit_Chest"), 0.35, 0.05)


## Some fighters change when hurt enough: new numbers, and the plate breaks off. It is
## left reeling for a moment.
func _check_phase() -> void:
	if _phase2 or not _t.has("phase2") or hp > max_hp * float(_t.get("phase2_at", 0.5)):
		return
	_phase2 = true
	_t = _t.duplicate()
	_t.merge(_t["phase2"], true)
	_in_combo = false
	_enter(State.STAGGER)
	_timer = 1.0
	_body.shed_armor()
	Sfx.play("block", global_position + Vector3(0.0, 1.2, 0.0), 4.0)
	Sfx.play("clash", global_position + Vector3(0.0, 1.2, 0.0), 0.0)
	phase_changed.emit()


## 방패 밀치기: the shield is driven into the player. A guard does not stop it (it is not
## a blade), but a roll or a step back does. Hit, they lose their footing and some health.
func _bash() -> void:
	_bash_pending = false
	_push = -global_transform.basis.z * 2.4
	Sfx.play("block", global_position + Vector3(0.0, 1.0, 0.0), 2.0)
	if _player == null or not is_instance_valid(_player) or _player.is_invulnerable():
		return
	var to: Vector3 = _player.global_position - global_position
	to.y = 0.0
	if to.length() > 1.9 or to.normalized().dot(-global_transform.basis.z) < 0.3:
		return   # too far or off to the side: it caught only air
	_attack_hit = true
	var side := 1.0 if to_local(_player.global_position).x >= 0.0 else -1.0
	_player.get_parried(side)   # the blade thrown wide, the guard shaken
	_player.receive_cut(3.5 * float(_t.get("damage", 1.0)) * dmg_mult, _player.global_position + Vector3(0.0, 1.2, 0.0), -global_transform.basis.z)
	bashed.emit()


## A blow that will break a block (the overhead smash).
func heavy_blow() -> bool:
	return _kind == "smash" and is_striking()


## Our blade met the player's.
##   - we parried their cut: answer at once (riposte)
##   - they swung into our cut or windup (parry): we stagger, wide open
##   - they only held the line against our cut (block): come again quickly, or bind
##   - they cut into our guard: some fighters answer at once or bind
func on_blade_clashed(pos: Vector3, player_parried: bool, i_parried: bool, blade_dir := Vector3.ZERO) -> void:
	if i_parried:
		_start_windup(0.65)
	elif player_parried:
		_in_combo = false
		_enter(State.STAGGER)
		var side := signf(global_transform.basis.x.dot(blade_dir))
		if side == 0.0:
			side = signf(to_local(pos).x)
		_knocked(side if side != 0.0 else 1.0)
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
			_start_windup(0.7)
		elif r < riposte + float(_t.get("bind_press", 0.0)) * 0.5:
			_wants_bind = true


## Parried: the blade is batted wide, the body reels back a step and sways before it
## finds its feet.
func _knocked(side: float) -> void:
	_recoil = 1.6
	_recoil_side = side
	_wobble = 1.0
	_push = global_transform.basis.z * 2.6   # about 55 cm (a critical is still in reach)
	_sword_to(SwordPoses.knocked(side), 0.1, "out")
	var clip := "ual2/Hit_Knockback"
	if _body.clip_length(clip) <= 0.0:
		clip = "Hit_Chest"
	_body.act(clip, 0.0, _body.clip_length(clip), _timer, 0.05)


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


func set_bind_point(world_point: Vector3) -> void:
	# Hold the sword from our grip toward the crossing point.
	var p := SwordPoses.aimed(BIND_GRIP, to_local(world_point) - _body.chest_anchor())
	_sword_to(p, 0.01)


## The player won the bind: our blade is thrown aside.
func bind_lost(side: float) -> void:
	_side = side
	_enter(State.STAGGER)
	_timer = float(_t.get("stagger", 0.8)) + 0.15
	_push = global_transform.basis.z * 1.2


## We won the bind: the player's blade is shoved aside, cut straight from the bind.
func bind_won() -> void:
	_start_windup(0.45)


## The bind came apart; if the player pulled out, some fighters cut after them.
func bind_released(player_pulled_out: bool) -> void:
	if player_pulled_out and randf() < float(_t.get("exit_cut", 0.0)):
		_start_windup(0.5)
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
	_update_sword(delta)

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
		State.IDLE, State.BIND, State.HELD:
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
			if _kind == "lunge" or _kind == "dart":
				_move(2.5)
			if _kind == "bash" and _bash_pending and _timer <= float(_t.get("attack", 0.22)) * 0.5:
				_bash()
			if _timer <= 0.0:
				_bash_pending = false
				if not _in_combo and (randf() < float(_t.get("combo", 0.0)) or (_kind == "dart" and randf() < 0.7)):
					_in_combo = true
					_start_windup(0.55)
				else:
					_in_combo = false
					if not _attack_hit:
						attack_whiffed.emit()
					_enter(State.RECOVER)
		State.RECOVER:
			if dist < POISE_RANGE:
				_move(-STEP_OUT_SPEED)
			# Hold the follow-through a moment, then bring the sword back to guard.
			var rec := float(_t.get("recover", 0.55))
			if not _returning and _timer < rec * 0.65:
				_returning = true
				_sword_to(_rest_pose(), rec * 0.55)
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
		# Snap the blade up across the side the cut comes from.
		var side := 1.0 if to_local(_sword.tip).x >= 0.0 else -1.0
		_sword_to(SwordPoses.parry(side), 0.07, "out")
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
		_start_windup(0.7)


func _enter(state: int) -> void:
	_state = state
	if state == State.POISE or state == State.APPROACH:
		_body.release(0.25)   # back to stance and footwork
		_sword_to(_rest_pose(), 0.3)
	match state:
		State.POISE:
			var p: Vector2 = _t.get("poise", Vector2(0.6, 1.2))
			_timer = randf_range(p.x, p.y)
		State.ATTACK:
			_timer = float(_t.get("attack", 0.22))
		State.RECOVER:
			_timer = float(_t.get("recover", 0.55))
			_returning = false
		State.STAGGER:
			_timer = float(_t.get("stagger", 0.9))
			_sword_to(SwordPoses.make("thrown"), 0.12, "out")
			_body.act("Hit_Chest", 0.0, _body.clip_length("Hit_Chest"), _timer, 0.08)


## The pose set a move uses: a dart is a short thrust.
func _pose_of(kind: String) -> String:
	return "lunge" if kind == "dart" else kind


## Windup: the sword drawn back for this cut, then held there until the strike.
func _start_windup(scale: float) -> void:
	var lines: Array = _t.get("lines", ["a"])
	if scale < 0.8 and lines.size() > 1:
		# A quick answer (riposte, punish) is a cut: a thrust needs a full draw back.
		lines = lines.filter(func(l): return not (l in ["lunge", "bash", "smash"]))
	_kind = lines[randi() % lines.size()]
	_side = 1.0 if randf() < 0.5 else -1.0
	# Better fighters vary their rhythm, so the cut can't be timed by counting.
	var jitter := float(_t.get("windup_jitter", 0.0))
	_windup_total = float(_t.get("windup", 0.4)) * scale * randf_range(1.0 - jitter, 1.0 + jitter)
	match _kind:
		"dart":
			_windup_total *= 0.55   # quick and light
		"smash":
			_windup_total *= 1.4    # a long, readable draw back
		"bash":
			_windup_total *= 1.1
	_feint_planned = scale >= 1.0 and lines.size() > 1 and randf() < float(_t.get("feint", 0.0))
	_feinted = false
	_state = State.WINDUP
	_timer = _windup_total
	_sword_to(SwordPoses.make("wind_" + _pose_of(_kind)), _windup_total * WINDUP_DRAW, "out")
	if _kind == "bash" or _kind == "smash":
		telegraphed.emit(_kind)


## Feint: switch to a different attack partway through the windup, which costs a moment.
func _feint() -> void:
	_feinted = true
	var lines: Array = _t.get("lines", ["a"])
	var other := _kind
	while other == _kind:
		other = lines[randi() % lines.size()]
	_kind = other
	_timer += 0.2
	_sword_to(SwordPoses.make("wind_" + _pose_of(_kind)), 0.2)


## Strike: from the held windup through to the far side in this tier's attack time,
## fastest in the middle, with a small step in.
func _start_attack() -> void:
	_attack_hit = false
	_enter(State.ATTACK)
	match _kind:
		"dart":
			_timer *= 0.8
		"smash":
			_timer *= 1.15
		"bash":
			_bash_pending = true
	_sword_to(SwordPoses.make("end_" + _pose_of(_kind)), _timer, "cut", CUT_ARC)
	if SwordPoses.POSES.has("mid_" + _pose_of(_kind)):
		_via = SwordPoses.make("mid_" + _pose_of(_kind))
	_push = -global_transform.basis.z * STRIKE_STEP
	Sfx.play("swing", blade_tip, 0.0)


## Start moving the sword from where it is now to `pose` over `seconds`. Ease "out"
## starts fast and settles (drawing back), "inout" speeds up and slows down, "cut" is
## inout weighted late, so the blade meets its target near the middle of the strike
## (the step in has already carried it forward).
func _sword_to(pose: Dictionary, seconds: float, ease := "inout", arc := 0.0) -> void:
	_from = _pose if not _pose.is_empty() else pose
	_to = pose
	_move_t = 0.0
	_move_len = maxf(seconds, 0.01)
	_move_ease = ease
	_move_arc = arc
	_via = {}


func _update_sword(delta: float) -> void:
	_move_t += delta
	var p := clampf(_move_t / _move_len, 0.0, 1.0)
	var q := p * p * (3.0 - 2.0 * p)
	if _move_ease == "out":
		q = 1.0 - pow(1.0 - p, 3.0)
	elif _move_ease == "cut":
		q = pow(q, 1.35)
	if _via.is_empty():
		_pose = SwordPoses.blend(_from, _to, q, _move_arc)
	elif q < 0.5:
		_pose = SwordPoses.blend(_from, _via, q * 2.0)
	else:
		_pose = SwordPoses.blend(_via, _to, q * 2.0 - 1.0)
	var shown := _pose
	if p >= 1.0 and (_state == State.POISE or _state == State.APPROACH or _state == State.IDLE):
		# A living guard: the point drifts a little with breathing.
		shown = _pose.duplicate()
		shown.grip = (_pose.grip as Vector3) + Vector3(sin(_clock * 1.7) * 0.01, sin(_clock * 2.3) * 0.012, 0.0)
	if _recoil > 0.0:
		# Rocked by a blow: leaning back and turned away from the side it came from.
		shown = shown.duplicate()
		shown.lean = float(shown.lean) - 0.45 * _recoil
		shown.yaw = float(shown.yaw) - 0.35 * _recoil * _recoil_side
		shown.grip = (shown.grip as Vector3) + Vector3(0.0, 0.05, 0.08) * _recoil
		_recoil = maxf(_recoil - delta * 4.0, 0.0)
	if _wobble > 0.0:
		# Reeling after a parry: swaying side to side, settling.
		shown = shown.duplicate()
		shown.yaw = float(shown.yaw) + sin(_clock * 18.0) * 0.28 * _wobble * _wobble
		shown.lean = float(shown.lean) + sin(_clock * 13.0) * 0.12 * _wobble
		_wobble = maxf(_wobble - delta * 1.3, 0.0)
	_body.pose(shown)


func _rest_pose() -> Dictionary:
	return SwordPoses.make("open" if _drill == "open" else "guard")


## Legs follow the body's velocity every frame; the upper body keeps its guard up
## (lowered only for the practice target), and after a cut the follow-through fades
## back into footwork partway through the recovery.
func _animate_locomotion() -> void:
	var local := global_transform.basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	_body.move(Vector2(local.x, -local.z))


func _move(speed: float) -> void:
	var d := _player.global_position - global_position
	d.y = 0.0
	d = d.normalized() * speed
	velocity.x = d.x
	velocity.z = d.z


# --- critical thrust and execution (the player's special moves drive these) -------

## After a parry or a won bind it is wide open for a moment: the player can drive in a
## critical thrust (E).
func open_critical(seconds: float) -> void:
	_crit_until = _clock + seconds


func critical_open() -> bool:
	return _state != State.DEAD and _state != State.HELD and _clock < _crit_until


## Nearly beaten and reeling: the player can grab it and finish it (E).
## The player's boon that lets them execute from further up (boons.gd).
func _execute_bonus() -> float:
	if _player != null and _player.has_method("mod"):
		return _player.mod("execute")
	return 0.0


func can_be_executed() -> bool:
	return _state != State.DEAD and _state != State.HELD and hp <= max_hp * (EXECUTE_BELOW + _execute_bonus()) \
		and (_state == State.STAGGER or critical_open())


## A special move has hold of it: it stands helpless, arms flung wide, until released.
func seize() -> void:
	_state = State.HELD
	_crit_until = -1.0
	_in_combo = false
	_wants_bind = false
	_dodge_vel = Vector3.ZERO
	var h: float = _body.clip_length("Hit_Chest") * 0.3
	_body.act("Hit_Chest", h, h, 1.0, 0.08)
	_sword_to(SwordPoses.make("thrown"), 0.15, "out")


## Run through: heavy damage, or death (on its knees).
func stabbed(damage: float, pos: Vector3, dir: Vector3) -> void:
	if _state == State.DEAD:
		return
	hp = maxf(hp - damage, 0.0)
	_recent_cuts.append(_clock)
	_body.flash()
	_recoil = 1.0
	_recoil_side = 0.0
	Fx.cut_spray(get_tree().current_scene, pos, -dir, 2.4)
	Sfx.play("cut", pos, 3.0)
	Sfx.play("hurt", pos, 0.0)
	Sfx.play("armor", pos, -2.0)
	if hp <= 0.0:
		_die(true)


## The middle of its chest right now (world), following the animation.
func chest_point() -> Vector3:
	return _body.to_global(_body.chest_anchor() + Vector3(0.0, -0.1, -0.08))


## Let go of it: shoved away, reeling.
func release_seized(push: float) -> void:
	if _state != State.HELD:
		return
	_enter(State.STAGGER)
	_push = global_transform.basis.z * push


func _die(on_knees := false) -> void:
	_state = State.DEAD
	collision_layer = 0
	_body.collapse(on_knees)
	Sfx.play("block", global_position + Vector3(0, 0.3, 0), -2.0)
	died.emit()


## Beaten, but not dead: it drops its sword and kneels. The player decides what happens.
func _yield() -> void:
	_yielded = true
	_state = State.DEAD
	_dodge_vel = Vector3.ZERO
	collision_layer = 0
	_body.collapse(true, false)
	Sfx.play("block", global_position + Vector3(0, 0.3, 0), -2.0)
	yielded.emit()


func is_yielded() -> bool:
	return _yielded


## The blow that ends a kneeling fighter.
func finish() -> void:
	var chest := chest_point()
	Fx.cut_spray(get_tree().current_scene, chest, global_transform.basis.z, 2.4)
	Sfx.play("cut", chest, 3.0)
	Sfx.play("hurt", chest, 0.0)
	_body.flash()
	_body.fall()


func _horizontal_dist(p: Vector3) -> float:
	var a := global_position
	a.y = 0.0
	p.y = 0.0
	return a.distance_to(p)
