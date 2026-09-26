extends CharacterBody3D
## The duelist you play, seen through their own eyes.
## Locked on to the opponent: the body always faces it, W/S close or open the distance
## and A/D circle. The MOUSE moves the sword: it steers the blade's point across a
## plane in front of you, both hands follow on the grip, and the speed of the tip is
## what cuts (see sword.gd).

signal hurt(amount: float)
signal died

const SwordScript := preload("res://sword.gd")
const ArmScript := preload("res://arm.gd")
const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")

const SPEED := 3.2          # closing / opening distance (W/S)
const STRAFE_SPEED := 2.0   # circling while locked on (A/D): too slow to outrun a swing
const GRAVITY := 18.0

const EYE := Vector3(0.0, 1.62, 0.0)
const CHEST := Vector3(0.0, 1.30, -0.05)
const GRIP_RADIUS := 0.36   # the hands travel on a sphere this far out from the chest
const SHOULDER_R := Vector3(0.19, 1.40, 0.02)
const SHOULDER_L := Vector3(-0.19, 1.40, 0.02)
const UPPER_ARM := 0.33
const FOREARM := 0.31

# The blade's point is steered across a plane this far in front of the chest.
const AIM_PLANE_Z := -0.9
const AIM_SENS := 0.0038
const AIM_MIN := Vector2(-0.85, 0.55)
const AIM_MAX := Vector2(0.85, 2.05)
const AIM_REST := Vector2(0.0, 1.45)   # point toward the opponent's face

# Guard (posture): every plain BLOCK fills it; parries don't. When it fills, the guard
# breaks — blade knocked low, control sluggish — so blocking alone can't hold forever.
const POSTURE_MAX := 100.0
const BLOCK_POSTURE := 34.0           # three blocks in a row break the guard
const POSTURE_RECOVER_DELAY := 1.0    # seconds without blocking before it starts to drain
const POSTURE_RECOVER_RATE := 25.0    # per second

var sword: Node3D
var target: Node3D   # lock-on target, set by main
var active := false  # main turns this on when the duel starts
var alive := true
var hp := 100.0
var hurt_flash := 0.0
var posture := 0.0

var _aim := AIM_REST
var _deflect_timer := 0.0   # after a clash the blade bounces and control is damped
var _since_block := 0.0
var _cam: Camera3D
var _arm_r
var _arm_l
var _pitch := 0.0
var _trauma := 0.0
var _bob := 0.0
var _step_dist := 0.0


func _ready() -> void:
	collision_layer = 2       # player hurtbox — the opponent's blade looks for this
	collision_mask = 1 | 4    # collide with the arena (1) and the opponent's body (4)

	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.30
	cs.height = 1.70
	col.shape = cs
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)

	_cam = Camera3D.new()
	_cam.position = EYE
	_cam.fov = 68.0
	_cam.near = 0.02
	add_child(_cam)
	_cam.current = true

	# Our own arms, in mail sleeves with plate forearms and gauntlets.
	_arm_r = ArmScript.new(self, UPPER_ARM, FOREARM, Armor.dark_steel(), Armor.steel(), Armor.dark_steel(), false)
	_arm_l = ArmScript.new(self, UPPER_ARM, FOREARM, Armor.dark_steel(), Armor.steel(), Armor.dark_steel(), false)

	sword = SwordScript.new()
	sword.name = "Sword"
	add_child(sword)


func camera() -> Camera3D:
	return _cam


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var damp := 0.25 if _deflect_timer > 0.0 else 1.0
		_aim.x = clampf(_aim.x + mm.relative.x * AIM_SENS * damp, AIM_MIN.x, AIM_MAX.x)
		_aim.y = clampf(_aim.y - mm.relative.y * AIM_SENS * damp, AIM_MIN.y, AIM_MAX.y)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Browsers only grant pointer lock from a click, and release it on ESC themselves.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Called by the sword on a clash: kick the aim (blade bounces) and damp control briefly.
func deflect(kick: Vector2, duration: float = 0.18) -> void:
	_aim.x = clampf(_aim.x + kick.x, AIM_MIN.x, AIM_MAX.x)
	_aim.y = clampf(_aim.y + kick.y, AIM_MIN.y, AIM_MAX.y)
	_deflect_timer = duration
	add_trauma(0.18)


## Called by the sword when we only BLOCKED an attack (held the line, didn't swing into
## it). Fills the guard meter; returns true if that broke the guard.
func absorb_block(h: float) -> bool:
	posture += BLOCK_POSTURE
	_since_block = 0.0
	if posture >= POSTURE_MAX:
		posture = 0.0
		deflect(Vector2(h * 0.8, -0.7), 0.9)  # blade thrown low; slow to bring back
		add_trauma(0.35)
		return true
	deflect(Vector2(h * 0.45, 0.25), 0.35)    # knocked open, but still in the fight
	return false


## Called by the opponent's blade when a cut lands on us.
func receive_cut(strength: float, _pos: Vector3, _dir: Vector3) -> void:
	if not alive:
		return
	var dmg := clampf(strength * 2.4, 6.0, 34.0)
	hp = maxf(hp - dmg, 0.0)
	hurt_flash = 1.0
	add_trauma(0.6)
	Sfx.play_flat("hurt", -3.0)
	Sfx.play_flat("cut", -2.0)
	hurt.emit(dmg)
	if hp <= 0.0:
		_die()


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _die() -> void:
	alive = false
	active = false
	died.emit()
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_cam, "position:y", 0.35, 0.9)
	tw.tween_property(_cam, "rotation:z", 0.55, 0.9)
	tw.tween_property(_cam, "rotation:x", _cam.rotation.x + 0.25, 0.9)


func _physics_process(delta: float) -> void:
	if _deflect_timer > 0.0:
		_deflect_timer -= delta
	if hurt_flash > 0.0:
		hurt_flash = maxf(hurt_flash - delta * 1.6, 0.0)
	_since_block += delta
	if _since_block > POSTURE_RECOVER_DELAY and posture > 0.0:
		posture = maxf(posture - POSTURE_RECOVER_RATE * delta, 0.0)

	if alive:
		_face_target()

	var input_dir := Vector3.ZERO
	if active:
		if Input.is_action_pressed("move_forward"):
			input_dir.z -= 1.0
		if Input.is_action_pressed("move_back"):
			input_dir.z += 1.0
		if Input.is_action_pressed("move_left"):
			input_dir.x -= 1.0
		if Input.is_action_pressed("move_right"):
			input_dir.x += 1.0
	# Relative to our facing: W/S toward/away from the target, A/D circle around it.
	var local := input_dir.normalized()
	local.x *= STRAFE_SPEED
	local.z *= SPEED
	var move := global_transform.basis * local
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var moving := Vector2(velocity.x, velocity.z).length()
	_step_dist += moving * delta
	if _step_dist > 0.8:
		_step_dist = 0.0
		Sfx.play("step", global_position, -14.0)

	if not alive:
		return

	# Sword: the point goes where the mouse steers it; the hands follow on a sphere
	# around the chest, so reaching high/wide also moves the arms.
	var aim_pt := Vector3(_aim.x, _aim.y, AIM_PLANE_Z)
	var grip := CHEST + (aim_pt - CHEST).normalized() * GRIP_RADIUS
	var dir := (aim_pt - grip).normalized()
	sword.drive(to_global(grip), global_transform.basis * dir, delta)
	var blade_basis := sword.transform.basis
	_arm_r.pose(SHOULDER_R, grip, Vector3(0.7, -0.7, 0.1), blade_basis)
	_arm_l.pose(SHOULDER_L, grip - dir * SwordMesh.LEFT_HAND, Vector3(-0.7, -0.7, 0.1), blade_basis)

	_update_camera(delta, moving)


func _face_target() -> void:
	if target == null:
		return
	var tp := target.global_position
	tp.y = global_position.y
	if global_position.distance_to(tp) > 0.05:
		look_at(tp, Vector3.UP)


func _update_camera(delta: float, moving: float) -> void:
	var look_pitch := 0.0
	if target != null:
		var eye := to_global(EYE)
		var chest := target.global_position + Vector3(0.0, 1.2, 0.0)  # look a bit low: hands in frame
		var flat := Vector2(chest.x - eye.x, chest.z - eye.z).length()
		look_pitch = atan2(chest.y - eye.y, maxf(flat, 0.3))
	_pitch = lerp_angle(_pitch, look_pitch, clampf(delta * 6.0, 0.0, 1.0))

	# A little sway toward where the blade is, a walking bob, and impact shake.
	var sway_yaw := -_aim.x * deg_to_rad(2.5)
	var sway_pitch := (_aim.y - AIM_REST.y) * deg_to_rad(2.5)
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	var shake := _trauma * _trauma
	var bob_amount := clampf(moving / SPEED, 0.0, 1.0)
	_bob += delta * moving * 2.6
	_cam.position = EYE + Vector3(cos(_bob) * 0.010 * bob_amount, absf(sin(_bob)) * 0.018 * bob_amount, 0.0) \
		+ Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * 0.03 * shake
	_cam.rotation = Vector3(
		_pitch + sway_pitch + randf_range(-1.0, 1.0) * 0.03 * shake,
		sway_yaw + randf_range(-1.0, 1.0) * 0.03 * shake,
		randf_range(-1.0, 1.0) * 0.02 * shake)
