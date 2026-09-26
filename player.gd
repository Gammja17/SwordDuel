extends CharacterBody3D
## The duelist you control.
## Locked on to the opponent: the body always faces it, W/S close in or back off and
## A/D circle around it. The MOUSE swings the sword: moving it rotates the blade around
## the hand pivot in a plane in front of the chest — swipe fast and the tip moves fast,
## which is what actually produces a cut (see sword.gd).

const SPEED := 4.5          # closing / opening distance (W/S)
const STRAFE_SPEED := 2.4   # circling while locked on (A/D): too slow to outrun a swing
const GRAVITY := 18.0

# Guard (posture): every plain BLOCK fills it; parries don't. When it fills, the guard
# breaks — blade knocked low, control sluggish — so blocking alone can't hold forever.
const POSTURE_MAX := 100.0
const BLOCK_POSTURE := 34.0           # three blocks in a row break the guard
const POSTURE_RECOVER_DELAY := 1.0    # seconds without blocking before it starts to drain
const POSTURE_RECOVER_RATE := 25.0    # per second

# Where the sword is gripped, in the player's local space (right hand, chest height).
const HAND_LOCAL := Vector3(0.28, 1.10, -0.10)
# The blade aims at a point on a plane this far in front of the chest.
const AIM_PLANE_Z := -0.85
const AIM_SENS := 0.0038
const AIM_MIN := Vector2(-0.9, 0.45)
const AIM_MAX := Vector2(0.9, 1.95)

const SwordScript := preload("res://sword.gd")

var sword: Node3D
var target: Node3D  # lock-on target, set by main

# Current aim point (x = left/right, y = up/down) on the plane in front of us.
var _aim := Vector2(0.0, 1.15)
# Brief window after a clash where the blade is bouncing and mouse control is damped.
var _deflect_timer := 0.0

var hp := 100.0
var hurt_flash := 0.0
var posture := 0.0
var _since_block := 0.0


func _ready() -> void:
	collision_layer = 2       # player hurtbox — the opponent's blade looks for this
	collision_mask = 1 | 4    # collide with floor (1) and the opponent's body (4)

	var body := MeshInstance3D.new()
	var caps := CapsuleMesh.new()
	caps.radius = 0.30
	caps.height = 1.70
	body.mesh = caps
	body.position = Vector3(0.0, 0.85, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.52, 0.80)
	body.material_override = mat
	add_child(body)

	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.30
	cs.height = 1.70
	col.shape = cs
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 2.30, 3.00)
	cam.rotation_degrees = Vector3(-22.0, 0.0, 0.0)
	add_child(cam)

	sword = SwordScript.new()
	sword.name = "Sword"
	add_child(sword)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var damp := 0.25 if _deflect_timer > 0.0 else 1.0
		_aim.x = clampf(_aim.x + mm.relative.x * AIM_SENS * damp, AIM_MIN.x, AIM_MAX.x)
		_aim.y = clampf(_aim.y - mm.relative.y * AIM_SENS * damp, AIM_MIN.y, AIM_MAX.y)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Browsers only grant pointer lock from a click, and release it on ESC themselves.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Called by the sword on a clash: kick the aim (blade bounces) and damp control briefly.
func deflect(kick: Vector2, duration: float = 0.18) -> void:
	_aim.x = clampf(_aim.x + kick.x, AIM_MIN.x, AIM_MAX.x)
	_aim.y = clampf(_aim.y + kick.y, AIM_MIN.y, AIM_MAX.y)
	_deflect_timer = duration


## Called by the sword when we only BLOCKED an attack (held the line, didn't swing into
## it). Fills the guard meter; returns true if that broke the guard.
func absorb_block(h: float) -> bool:
	posture += BLOCK_POSTURE
	_since_block = 0.0
	if posture >= POSTURE_MAX:
		posture = 0.0
		deflect(Vector2(h * 0.8, -0.7), 0.9)  # blade thrown low; slow to bring back
		return true
	deflect(Vector2(h * 0.45, 0.25), 0.35)    # knocked open, but still in the fight
	return false


## Called by the opponent's blade when a cut lands on us.
func receive_cut(strength: float, _pos: Vector3, _dir: Vector3) -> void:
	hp = maxf(hp - clampf(strength * 3.0, 8.0, 45.0), 0.0)
	hurt_flash = 1.0


func _physics_process(delta: float) -> void:
	if _deflect_timer > 0.0:
		_deflect_timer -= delta
	if hurt_flash > 0.0:
		hurt_flash = maxf(hurt_flash - delta * 2.0, 0.0)
	_since_block += delta
	if _since_block > POSTURE_RECOVER_DELAY and posture > 0.0:
		posture = maxf(posture - POSTURE_RECOVER_RATE * delta, 0.0)

	_face_target()

	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	# Relative to our facing: W/S toward/away from the target, A/D circle around it
	# (slower, as in a locked-on stance).
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

	# Feed the sword: grip point and the point it is aiming at, both in world space.
	var hand_world := to_global(HAND_LOCAL)
	var aim_world := to_global(Vector3(_aim.x, _aim.y, AIM_PLANE_Z))
	sword.drive(hand_world, aim_world, delta)


func _face_target() -> void:
	if target == null:
		return
	var tp := target.global_position
	tp.y = global_position.y
	if global_position.distance_to(tp) > 0.05:
		look_at(tp, Vector3.UP)
