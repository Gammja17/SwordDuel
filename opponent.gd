extends CharacterBody3D
## A reactive AI duelist.
##
## Loop: hold an upright guard at guard distance (just outside the player's resting
## reach), then step in with a telegraphed windup, swing, and step back out to recover.
## Against it the player can:
##   - PARRY: swing into its attack       -> it staggers, wide open
##   - BLOCK: just hold the blade in line -> no damage, but it keeps the pressure on
##   - back off during the windup         -> the swing falls short
##   - beat the guard: it only covers the high line on the side of your blade, so go
##     low, switch sides faster than it follows, or bind and push through

enum State { APPROACH, POISE, WINDUP, ATTACK, RECOVER, STAGGER }

const SPEED := 2.6
const GRAVITY := 18.0
const POISE_RANGE := 1.55    # hold the guard here: just outside the player's resting reach
const ATTACK_RANGE := 1.15   # step in to here during the windup, then swing
const REACH := 0.9

const HAND_LOCAL := Vector3(0.22, 1.10, -0.10)
const NEUTRAL := Vector3(0.0, 1.20, -0.75)
# Cocked / follow-through poses for the two attack lines (local space, -Z faces player).
const COCK_R := Vector3(0.65, 1.75, -0.15)
const SWING_R := Vector3(-0.45, 0.80, -0.90)
const COCK_L := Vector3(-0.65, 1.75, -0.15)
const SWING_L := Vector3(0.45, 0.80, -0.90)

const WINDUP_TIME := 0.40
const ATTACK_TIME := 0.22
const RECOVER_TIME := 0.55
const STAGGER_TIME := 0.90
const BLOCKED_FOLLOWUP := 0.25   # after being blocked (not parried), attack again this soon

var hp := 100.0

var _player: Node3D
var _sword  # player's Sword (untyped for dynamic get_tip_pos)

var _state: int = State.APPROACH
var _timer := 0.0
var _from_right := true
var _attack_hit := false

var _holder: Node3D
var _area: Area3D
var _cur := Vector3.ZERO
var _has_cur := false

var _btip := Vector3.ZERO
var _btip_prev := Vector3.ZERO
var _btip_vel := Vector3.ZERO
var _has_btip := false

var _mat: StandardMaterial3D
var _base_color := Color(0.62, 0.30, 0.30)
var _flash := 0.0
var _blade_mat: StandardMaterial3D
var _blade_base := Color(0.80, 0.82, 0.88)
var _blade_flash := 0.0


func setup(player: Node3D) -> void:
	_player = player
	_sword = player.sword


func get_blade_vel() -> Vector3:
	return _btip_vel


func is_attacking() -> bool:
	return _state == State.WINDUP or _state == State.ATTACK


func _ready() -> void:
	collision_layer = 4       # opponent hurtbox — the player's blade looks for this
	collision_mask = 1 | 2    # floor (1) + player body (2)

	var mesh := MeshInstance3D.new()
	var caps := CapsuleMesh.new()
	caps.radius = 0.32
	caps.height = 1.70
	mesh.mesh = caps
	mesh.position = Vector3(0.0, 0.85, 0.0)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	mesh.material_override = _mat
	add_child(mesh)

	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.32
	cs.height = 1.70
	col.shape = cs
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)

	_holder = Node3D.new()
	_holder.name = "BladeHolder"
	add_child(_holder)

	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.035, REACH)
	blade.mesh = bm
	blade.position = Vector3(0.0, 0.0, -REACH * 0.5)
	_blade_mat = StandardMaterial3D.new()
	_blade_mat.albedo_color = _blade_base
	_blade_mat.metallic = 0.8
	_blade_mat.roughness = 0.25
	blade.material_override = _blade_mat
	_holder.add_child(blade)

	_area = Area3D.new()
	_area.collision_layer = 8      # blade
	_area.collision_mask = 2 | 8   # player body (2) to cut + blades (8) to be blocked by
	var acol := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(0.10, 0.10, REACH)
	acol.shape = abox
	acol.position = Vector3(0.0, 0.0, -REACH * 0.5)
	_area.add_child(acol)
	_holder.add_child(_area)


func receive_cut(strength: float, pos: Vector3, swing_dir: Vector3) -> void:
	hp = maxf(hp - clampf(strength * 3.0, 8.0, 45.0), 0.0)
	_flash = 1.0
	_spawn_cut_mark(pos, swing_dir, strength)


## Our blade met the player's. If we were attacking: a parry staggers us, a plain
## block only stops this swing and we come again quickly.
func on_blade_clashed(_pos: Vector3, parried: bool) -> void:
	_blade_flash = 1.0
	if not is_attacking():
		return
	if parried:
		_enter(State.STAGGER)
	else:
		_enter(State.POISE)
		_timer = BLOCKED_FOLLOWUP


func guard_broken() -> void:
	_enter(State.STAGGER)
	_flash = 1.0


func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 3.0, 0.0)
		_mat.albedo_color = _base_color.lerp(Color(1.0, 0.85, 0.20), _flash)
	if _blade_flash > 0.0:
		_blade_flash = maxf(_blade_flash - delta * 4.0, 0.0)
		_blade_mat.albedo_color = _blade_base.lerp(Color(1.0, 1.0, 0.85), _blade_flash)

	if _player == null:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_face_player()
	_run_state(delta)
	_apply_gravity_and_move(delta)
	_update_blade(delta)


func _face_player() -> void:
	var tp := _player.global_position
	tp.y = global_position.y
	if global_position.distance_to(tp) > 0.05:
		look_at(tp, Vector3.UP)


func _run_state(delta: float) -> void:
	_timer -= delta
	var dist := _horizontal_dist(_player.global_position)

	match _state:
		State.APPROACH:
			if dist > POISE_RANGE:
				_move_toward_player()
			else:
				_enter(State.POISE)
		State.POISE:
			_stand()
			if dist > POISE_RANGE + 0.4:
				_enter(State.APPROACH)
			elif _timer <= 0.0:
				if randf() < 0.7:
					_from_right = randf() < 0.5
					_enter(State.WINDUP)
				else:
					_timer = randf_range(0.4, 0.9)
		State.WINDUP:
			# Step in while cocking the blade: the advance is part of the telegraph.
			if dist > ATTACK_RANGE:
				_move_toward_player()
			else:
				_stand()
			if _timer <= 0.0:
				_attack_hit = false
				_enter(State.ATTACK)
		State.ATTACK:
			_stand()
			_try_hit_player()
			if _timer <= 0.0:
				_enter(State.RECOVER)
		State.RECOVER:
			# Drift back out to guard distance.
			if dist < POISE_RANGE:
				_move_away_from_player()
			else:
				_stand()
			if _timer <= 0.0:
				_enter(State.POISE)
		State.STAGGER:
			_stand()
			if _timer <= 0.0:
				_enter(State.POISE)


func _enter(state: int) -> void:
	_state = state
	match state:
		State.POISE:
			_timer = randf_range(0.5, 1.1)
		State.WINDUP:
			_timer = WINDUP_TIME
		State.ATTACK:
			_timer = ATTACK_TIME
		State.RECOVER:
			_timer = RECOVER_TIME
		State.STAGGER:
			_timer = STAGGER_TIME


func _move_toward_player() -> void:
	var dir := _player.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED


func _move_away_from_player() -> void:
	var dir := global_position - _player.global_position
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED


func _stand() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _apply_gravity_and_move(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


# --- blade posing ---
func _update_blade(delta: float) -> void:
	var hand := to_global(HAND_LOCAL)
	var target := _blade_target()
	if not _has_cur:
		_cur = target
		_has_cur = true
	else:
		_cur = _cur.lerp(target, clampf(_lerp_rate() * delta, 0.0, 1.0))
	_place_blade(hand, _cur)

	var tip := _holder.global_transform * Vector3(0.0, 0.0, -REACH)
	if _has_btip:
		_btip_vel = (tip - _btip_prev) / maxf(delta, 0.0001)
	_btip_prev = tip
	_btip = tip
	_has_btip = true


func _blade_target() -> Vector3:
	match _state:
		State.WINDUP:
			return to_global(COCK_R if _from_right else COCK_L)
		State.ATTACK:
			return to_global(SWING_R if _from_right else SWING_L)
		State.STAGGER:
			return to_global(Vector3(0.8 if _from_right else -0.8, 0.9, -0.2))
		State.APPROACH, State.RECOVER:
			return to_global(NEUTRAL)
		_:
			# POISE: blade upright in front of the body, leaning toward the side of the
			# player's blade — a barrier over the high line, not a probe that reaches
			# out to touch their blade.
			var threat := to_local(_sword.get_tip_pos())
			return to_global(Vector3(clampf(threat.x, -0.5, 0.5), 1.95, -0.35))


func _lerp_rate() -> float:
	match _state:
		State.ATTACK:
			return 22.0
		State.WINDUP:
			return 9.0
		State.POISE:
			return 6.0
		State.STAGGER:
			return 7.0
		_:
			return 5.0


func _place_blade(hand: Vector3, point: Vector3) -> void:
	var dir := point - hand
	if dir.length() < 0.001:
		dir = -global_transform.basis.z
	dir = dir.normalized()
	var t := Transform3D()
	t.origin = hand
	t.basis = _basis_pointing_along(dir)
	_holder.global_transform = t


func _try_hit_player() -> void:
	if _attack_hit:
		return
	if not _area.get_overlapping_areas().is_empty():
		return  # a blade is in the way — blocked
	for b in _area.get_overlapping_bodies():
		if b == _player and b.has_method("receive_cut"):
			b.receive_cut(_btip_vel.length(), _btip, _btip_vel.normalized())
			_attack_hit = true
			return


func _horizontal_dist(p: Vector3) -> float:
	var a := global_position
	a.y = 0.0
	p.y = 0.0
	return a.distance_to(p)


func _spawn_cut_mark(pos: Vector3, swing_dir: Vector3, strength: float) -> void:
	var mark := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var length := clampf(0.18 + strength * 0.03, 0.18, 0.75)
	bm.size = Vector3(0.02, 0.02, length)
	mark.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.90, 0.10, 0.10)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.20, 0.20)
	m.emission_energy_multiplier = 2.5
	mark.material_override = m
	add_child(mark)
	if swing_dir.length() > 0.01:
		mark.global_transform = Transform3D(_basis_pointing_along(swing_dir), pos)
	else:
		mark.global_position = pos
	get_tree().create_timer(2.0).timeout.connect(mark.queue_free)


func _basis_pointing_along(dir: Vector3) -> Basis:
	var z := -dir
	var up := Vector3.UP
	if absf(z.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)
