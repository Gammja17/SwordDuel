extends CharacterBody3D
## Walking about the dormitory yard in first person: WASD to move, the mouse to look.
## (main.gd runs the hub: what can be talked to, and what the E key does.)

const SPEED := 3.6
const EYE := 1.62
const LOOK := 0.0025

var enabled := true
var cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.3
	cs.height = 1.7
	col.shape = cs
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)
	cam = Camera3D.new()
	cam.position = Vector3(0.0, EYE, 0.0)
	cam.fov = 74.0
	cam.near = 0.05
	add_child(cam)


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * LOOK
		_pitch = clampf(_pitch - mm.relative.y * LOOK, -1.1, 1.1)
		rotation.y = _yaw
		cam.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # (browsers only grant the lock from a click)


func face(yaw: float) -> void:
	_yaw = yaw
	rotation.y = yaw


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if enabled:
		if Input.is_action_pressed("move_forward"):
			dir.z -= 1.0
		if Input.is_action_pressed("move_back"):
			dir.z += 1.0
		if Input.is_action_pressed("move_left"):
			dir.x -= 1.0
		if Input.is_action_pressed("move_right"):
			dir.x += 1.0
	var v := global_transform.basis * dir.normalized() * SPEED
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
