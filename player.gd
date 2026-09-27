extends CharacterBody3D
## The duelist you play, seen through their own eyes.
## Locked on to the opponent: the body always faces it, W steps in, S steps back
## (slower) and A/D circle. The MOUSE moves the sword: it drags a target across a plane
## in front of you and the blade's point follows it with weight (limited acceleration
## and speed), both hands on the grip. The speed of the tip is what cuts (sword.gd).

signal hurt(amount: float)
signal died

const SwordScript := preload("res://sword.gd")
const ArmScript := preload("res://arm.gd")
const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")

const SPEED := 3.2          # stepping in (W)
const BACK_SPEED := 2.1     # stepping back (S): slower, so distance alone rarely saves you
const STRAFE_SPEED := 2.0   # circling while locked on (A/D)
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

# Weight of the sword: the point chases the mouse on a spring whose acceleration and
# speed are capped. A real cut needs a wind-up, and a hard swing can't reverse at once.
const AIM_STIFFNESS := 220.0
const AIM_DAMPING := 25.0
const AIM_MAX_ACCEL := 55.0
const AIM_MAX_SPEED := 7.5

# Breath: every full swing costs some. Out of breath, the sword feels heavy (slower to
# accelerate, lower top speed, so weaker cuts) until you stop swinging for a moment.
const BREATH_MAX := 100.0
const SWING_COST := 22.0
const BREATH_REGEN := 35.0          # per second
const BREATH_REGEN_DELAY := 0.5     # after the last swing
const TIRED_BELOW := 35.0

# Dodge (Space): a quick step in the held direction (back if none), briefly untouchable.
const DODGE_SPEED := 6.5
const DODGE_TIME := 0.3
const DODGE_IFRAMES := Vector2(0.02, 0.22)   # untouchable between these times into the dodge
const DODGE_COST := 25.0
const DODGE_COOLDOWN := 0.55

# Right mouse: the blade snaps toward the incoming blade. Its first moments are a timed
# PARRY window; holding it after that is just a BLOCK (fills the guard meter).
const PARRY_WINDOW := 0.2
const GUARD_COST := 6.0
const GUARD_SNAP := 2.2	  # how much faster the blade moves while guarding

# Guard (posture): every plain BLOCK fills it; parries don't. When it fills, the guard
# breaks — blade knocked low, control sluggish — so blocking alone can't hold forever.
const POSTURE_MAX := 100.0
const BLOCK_POSTURE := 34.0           # three blocks in a row break the guard
const PARRIED_POSTURE := 25.0         # having our own cut parried also shakes us
const POSTURE_RECOVER_DELAY := 1.0    # seconds without blocking before it starts to drain
const POSTURE_RECOVER_RATE := 25.0    # per second

var sword: Node3D
var target: Node3D   # lock-on target, set by main
var active := false  # main turns this on when the duel starts
var practice := false  # in the practice bout, hits are shown but cost no health
var alive := true
var hp := 100.0
var hurt_flash := 0.0
var posture := 0.0
var breath := BREATH_MAX
var in_bind := false

var _aim := AIM_REST
var _aim_target := AIM_REST
var _aim_vel := Vector2.ZERO
var _bind_push := 0.0
var _deflect_timer := 0.0   # after a clash the blade bounces and control is damped
var _since_block := 0.0
var _since_swing := 0.0
var _swinging := false
var _dodge_t := -1.0		   # time into the current dodge; < 0 when not dodging
var _dodge_dir := Vector3.ZERO
var _dodge_cd := 0.0
var _last_dodge_ms := -100000
var _guard_held := false
var _parry_t := -1.0		   # time since the right button went down; < 0 when released
var _cam: Camera3D
var _arm_r
var _arm_l
var _pitch := 0.0
var _trauma := 0.0
var _bob := 0.0
var _step_dist := 0.0


func _ready() -> void:
	collision_layer = 2       # player hurtbox
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

	# Our own arms: mail sleeves, plate forearms, gauntlets.
	_arm_r = ArmScript.new(self, UPPER_ARM, FOREARM, Armor.mail(), Armor.steel(), Armor.dark_steel(), false)
	_arm_l = ArmScript.new(self, UPPER_ARM, FOREARM, Armor.mail(), Armor.steel(), Armor.dark_steel(), false)

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
		if in_bind:
			_bind_push += mm.relative.x * AIM_SENS   # sideways pressure on the locked blades
			return
		var damp := 0.25 if _deflect_timer > 0.0 else 1.0
		_aim_target.x = clampf(_aim_target.x + mm.relative.x * AIM_SENS * damp, AIM_MIN.x, AIM_MAX.x)
		_aim_target.y = clampf(_aim_target.y - mm.relative.y * AIM_SENS * damp, AIM_MIN.y, AIM_MAX.y)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Browsers only grant pointer lock from a click, and release it on ESC themselves.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and not in_bind:
			_guard_held = true
			_parry_t = 0.0
			breath = maxf(breath - GUARD_COST, 0.0)
		elif not event.pressed:
			_guard_held = false
			_parry_t = -1.0
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.is_echo() \
			and (event as InputEventKey).physical_keycode == KEY_SPACE:
		_try_dodge()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Called on a clash: kick the blade (it bounces) and damp control briefly.
func deflect(kick: Vector2, duration: float = 0.18) -> void:
	_aim = _clamp_aim(_aim + kick)
	_aim_target = _clamp_aim(_aim_target + kick)
	_aim_vel = kick * 4.0
	_deflect_timer = duration
	add_trauma(0.18)


## We only BLOCKED a cut (held the line, didn't swing into it). Fills the guard meter;
## returns true if that broke the guard.
func absorb_block(h: float) -> bool:
	if _add_posture(BLOCK_POSTURE, h):
		return true
	deflect(Vector2(h * 0.45, 0.25), 0.35)    # knocked open, but still in the fight
	return false


## The opponent parried our cut: our blade is thrown wide. Returns true if the guard broke.
func get_parried(h: float) -> bool:
	if _add_posture(PARRIED_POSTURE, h):
		return true
	deflect(Vector2(h * 0.75, -0.35), 0.5)
	add_trauma(0.2)
	return false


func _add_posture(amount: float, h: float) -> bool:
	posture += amount
	_since_block = 0.0
	if posture >= POSTURE_MAX:
		posture = 0.0
		deflect(Vector2(h * 0.8, -0.7), 0.9)  # blade thrown low; slow to bring back
		add_trauma(0.35)
		return true
	return false


# --- bind (combat.gd drives it) -----------------------------------------------------

func enter_bind() -> void:
	in_bind = true
	_bind_push = 0.0
	_aim_vel = Vector2.ZERO


func exit_bind() -> void:
	in_bind = false
	_aim_target = _aim


## Sideways mouse pressure since the last call (aim units, + = to our right).
func take_bind_push() -> float:
	var p := _bind_push
	_bind_push = 0.0
	return p


## While bound, the blade is held where the two swords cross.
func hold_blade_at(aim: Vector2) -> void:
	_aim = _clamp_aim(_aim.lerp(aim, 0.4))
	_aim_target = _aim


func wants_disengage() -> bool:
	return active and Input.is_action_pressed("move_back")


func is_invulnerable() -> bool:
	return _dodge_t >= DODGE_IFRAMES.x and _dodge_t <= DODGE_IFRAMES.y


func is_guarding() -> bool:
	return _guard_held and not in_bind


## The parry window is tighter against better fighters (their tier's parry_window).
func is_parry_window() -> bool:
	var window := PARRY_WINDOW
	if target != null and target.has_method("tier_value"):
		window = float(target.tier_value("parry_window", PARRY_WINDOW))
	return _parry_t >= 0.0 and _parry_t <= window


func dodged_within(ms: int) -> bool:
	return Time.get_ticks_msec() - _last_dodge_ms <= ms


func _try_dodge() -> void:
	if in_bind or _dodge_t >= 0.0 or _dodge_cd > 0.0 or breath < 10.0:
		return
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir.z -= 1.0
	if Input.is_action_pressed("move_back"):
		dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		dir.x += 1.0
	if dir == Vector3.ZERO:
		dir = Vector3(0.0, 0.0, 1.0)   # no direction held: hop back
	_dodge_dir = dir.normalized()
	_dodge_t = 0.0
	_dodge_cd = DODGE_COOLDOWN
	_last_dodge_ms = Time.get_ticks_msec()
	breath = maxf(breath - DODGE_COST, 0.0)
	Sfx.play_flat("step", -4.0)
	Sfx.play_flat("armor", -8.0)


## Called by the opponent's blade when a cut lands on us.
func receive_cut(strength: float, _pos: Vector3, _dir: Vector3) -> void:
	if not alive:
		return
	var dmg := clampf(strength * 2.4, 6.0, 34.0)
	if not practice:
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
	in_bind = false
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
	_dodge_cd -= delta
	if _parry_t >= 0.0:
		_parry_t += delta
	if _since_block > POSTURE_RECOVER_DELAY and posture > 0.0:
		posture = maxf(posture - POSTURE_RECOVER_RATE * delta, 0.0)

	if alive:
		_face_target()

	var input_dir := Vector3.ZERO
	if active and not in_bind:
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
	local.z *= SPEED if local.z < 0.0 else BACK_SPEED
	var move := global_transform.basis * local
	if _dodge_t >= 0.0:
		# A dodge overrides walking: fast at first, easing off.
		_dodge_t += delta
		var k := 1.0 - clampf(_dodge_t / DODGE_TIME, 0.0, 1.0)
		move = global_transform.basis * _dodge_dir * DODGE_SPEED * (0.35 + 0.65 * k)
		if _dodge_t >= DODGE_TIME:
			_dodge_t = -1.0
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

	_update_breath(delta)
	if _guard_held and not in_bind:
		_track_incoming_blade()
	if not in_bind:
		_step_aim(delta)

	# Sword: the point goes where it has been steered; the hands follow on a sphere
	# around the chest, so reaching high/wide also moves the arms.
	var aim_pt := Vector3(_aim.x, _aim.y, AIM_PLANE_Z)
	var grip := CHEST + (aim_pt - CHEST).normalized() * GRIP_RADIUS
	var dir := (aim_pt - grip).normalized()
	sword.drive(to_global(grip), global_transform.basis * dir, delta)
	var blade_basis := sword.transform.basis
	_arm_r.pose(SHOULDER_R, grip, Vector3(0.7, -0.7, 0.1), blade_basis)
	_arm_l.pose(SHOULDER_L, grip - dir * SwordMesh.LEFT_HAND, Vector3(-0.7, -0.7, 0.1), blade_basis)

	_update_camera(delta, moving)


## Each full swing (a real cut's speed and travel) costs breath once.
func _update_breath(delta: float) -> void:
	var swinging: bool = sword.is_real_swing(SwordScript.CUT_THRESHOLD, SwordScript.CUT_ARC)
	if swinging and not _swinging:
		breath = maxf(breath - SWING_COST, 0.0)
	if swinging or sword.swing_speed > 2.0:
		_since_swing = 0.0
	else:
		_since_swing += delta
	_swinging = swinging
	if _since_swing > BREATH_REGEN_DELAY:
		breath = minf(breath + BREATH_REGEN * delta, BREATH_MAX)


## How heavy the sword feels: 1 when rested, down to 0.5 when out of breath; guarding
## snaps the blade faster.
func _strength() -> float:
	var k := 1.0 if breath >= TIRED_BELOW else lerpf(0.5, 1.0, breath / TIRED_BELOW)
	return k * (GUARD_SNAP if _guard_held else 1.0)


## While guarding, the blade goes to meet the opponent's blade: aim at its middle.
func _track_incoming_blade() -> void:
	if target == null or not target.has_method("get_blade_vel"):
		return
	var mid: Vector3 = (target.get("blade_base") + target.get("blade_tip")) * 0.5
	var local := to_local(mid)
	_aim_target = _clamp_aim(Vector2(local.x, local.y))


## The blade's point chases the mouse target with capped acceleration and speed.
func _step_aim(delta: float) -> void:
	var k := _strength()
	var acc := (_aim_target - _aim) * AIM_STIFFNESS - _aim_vel * AIM_DAMPING
	if acc.length() > AIM_MAX_ACCEL * k:
		acc = acc.normalized() * AIM_MAX_ACCEL * k
	_aim_vel += acc * delta
	if _aim_vel.length() > AIM_MAX_SPEED * k:
		_aim_vel = _aim_vel.normalized() * AIM_MAX_SPEED * k
	var next := _aim + _aim_vel * delta
	var clamped := _clamp_aim(next)
	if clamped.x != next.x:
		_aim_vel.x = 0.0
	if clamped.y != next.y:
		_aim_vel.y = 0.0
	_aim = clamped


func _clamp_aim(a: Vector2) -> Vector2:
	return Vector2(clampf(a.x, AIM_MIN.x, AIM_MAX.x), clampf(a.y, AIM_MIN.y, AIM_MAX.y))


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
	var roll := 0.0
	if _dodge_t >= 0.0:
		roll = -_dodge_dir.x * 0.12 * sin(clampf(_dodge_t / DODGE_TIME, 0.0, 1.0) * PI)
		_cam.position.y -= 0.08 * sin(clampf(_dodge_t / DODGE_TIME, 0.0, 1.0) * PI)
	_cam.rotation = Vector3(
		_pitch + sway_pitch + randf_range(-1.0, 1.0) * 0.03 * shake,
		sway_yaw + randf_range(-1.0, 1.0) * 0.03 * shake,
		roll + randf_range(-1.0, 1.0) * 0.02 * shake)
