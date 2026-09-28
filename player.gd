extends CharacterBody3D
## The duelist you play, seen through their own eyes.
## Locked on to the opponent: the body always faces it, W steps in, S steps back
## (slower) and A/D circle. The MOUSE moves the sword: it drags a target across a plane
## in front of you and the blade's point follows it with weight (limited acceleration
## and speed), both hands on the grip. A hard flick (or the left button) is a CUT: the
## sword is drawn back over the far shoulder and swung round in a big arc through the
## front, the body turning and stepping into it. The speed of the tip is what cuts
## (sword.gd).

signal hurt(amount: float)
signal died
signal lock_changed(locked: bool)
signal special_struck(kind: String)   # a critical thrust or an execution went in
signal execution_started

const SwordScript := preload("res://sword.gd")
const ArmScript := preload("res://arm.gd")
const Armor := preload("res://armor.gd")
const SwordMesh := preload("res://sword_mesh.gd")

const SPEED := 3.2          # stepping in (W)
const BACK_SPEED := 2.3     # stepping back (S): slower, so distance alone rarely saves you
const STRAFE_SPEED := 2.6   # circling while locked on (A/D)
const GRAVITY := 18.0

const EYE := Vector3(0.0, 1.62, 0.0)
# The hands follow the mouse across a wide area in front of the body (left to right as
# far as the arms reach, belt to face), bending in toward the chest at the edges. At
# rest the hilt sits at the bottom right of the view and the blade rises toward the
# opponent; the blade always points on out to where the mouse aims.
const HANDS_REST := Vector3(0.14, 1.26, -0.5)
const HANDS_SPAN := Vector2(0.42, 0.5)   # hand travel per metre of aim
const HANDS_REACH := 0.62                # at most this far from the right shoulder
const SHOULDER_R := Vector3(0.19, 1.40, 0.02)
const SHOULDER_L := Vector3(-0.19, 1.40, 0.02)
const UPPER_ARM := 0.33
const FOREARM := 0.31

# The blade's point is steered across a plane this far in front of the chest (far
# enough that a low aim still reaches forward rather than straight down).
const AIM_PLANE_Z := -1.3
const AIM_SENS := 0.0045
const AIM_MIN := Vector2(-1.25, 0.45)
const AIM_MAX := Vector2(1.25, 2.4)
const AIM_REST := Vector2(0.0, 1.45)   # point toward the opponent's face
# With the lock-on off, steering the blade past the edge of its range turns the body
# (sideways) or tilts the view (up and down): radians per metre of overshoot.
const EDGE_TURN := 1.0
const FREE_PITCH := 0.6
const FACE_RATE := 20.0   # how quickly the body swings round to the target when locked

# Cut: when the mouse target travels FLICK (summed over roughly the last tenth of a
# second), or on the left button, the sword leaves the mouse's hold for one big swing
# in that direction: drawn back over the far shoulder (CUT_DRAW), swung round in an arc
# about the shoulders from CUT_FROM to CUT_TO degrees, 0 being straight ahead
# (CUT_SWING), held in the follow-through (CUT_HOLD), then eased back to where the
# mouse holds it (CUT_RETURN). The torso, and so the view, turns with the arc and the
# body steps in. Right-click pulls out of it (a feint).
const FLICK := 0.3
const FLICK_DECAY := 12.0
const CUT_DRAW := 0.13
const CUT_HANG := 0.04     # a beat at the top of the draw before it lets go
const CUT_SWING := 0.15
const CUT_HOLD := 0.1
const CUT_RETURN := 0.22
const CUT_FROM := -125.0
const CUT_TO := 105.0
const CUT_OVER := 14.0     # the follow-through carries this much further and springs back
const CUT_PIVOT := Vector3(0.05, 1.32, -0.1)   # between the shoulders, a little forward
const CUT_TWIST := 0.42    # how far the shoulders and view turn each way (rad)
const CUT_STEP := 3.0      # step into the cut (m/s at its start, fading)
const CUT_GAP := 0.45      # a new cut can start this soon after one returns
const CUT_BREATH := 12.0   # below this much breath, there is no strength for a cut
const CUT_COST := 12.0     # breath a big swing costs (all of it: its parts aren't charged as swings)

# Special moves (E), played out as a short scene. A critical THRUST when the opponent
# is wide open (just parried, or its blade thrown aside in a bind); an EXECUTION when
# it is also nearly beaten: the left hand seizes it and the sword goes in. Phase times:
# step in and draw back, drive in, hold, pull out, back to guard.
const THRUST_TIMES := [0.2, 0.09, 0.42, 0.18, 0.22]
const EXECUTE_TIMES := [0.26, 0.12, 0.75, 0.24, 0.24]
const THRUST_DAMAGE := 30.0
const SPECIAL_REACH := 3.2                   # it must be at least this close to start one
const SPECIAL_CLOSE := {"thrust": 1.15, "execute": 0.8}   # where the step in stops

# Weight of the sword: the point chases the mouse on a spring whose acceleration and
# speed are capped. It keeps up with the hand, but a hard swing carries on a little
# past where the mouse stopped and can't reverse at once.
const AIM_STIFFNESS := 600.0
const AIM_DAMPING := 38.0
const AIM_MAX_ACCEL := 170.0
const AIM_MAX_SPEED := 14.0
const WHIP := 0.035  # a fast drag flings the point ahead of the hands, this far per m/s

# Breath: every full swing costs some. Out of breath, the sword feels heavy (slower to
# accelerate, lower top speed, so weaker cuts) until you stop swinging for a moment.
const BREATH_MAX := 100.0
const SWING_COST := 6.0
const BREATH_REGEN := 50.0          # per second
const BREATH_REGEN_DELAY := 0.4     # after the last swing
const TIRED_BELOW := 25.0

# Dodge (Space): a roll in the held direction (back if none), about 2.8 m, untouchable
# through its middle. The view drops toward the ground and tips the way it rolls.
const DODGE_SPEED := 9.0
const DODGE_TIME := 0.5
const DODGE_IFRAMES := Vector2(0.03, 0.33)   # untouchable between these times into the dodge
const DODGE_COST := 18.0
const DODGE_COOLDOWN := 0.75
const DODGE_DIP := 0.55      # how far the eyes (and the sword with them) drop mid-roll

# Right mouse: the blade leans toward the incoming blade (the mouse still steers it).
# Its first moments are a timed PARRY window; holding it after that is just a BLOCK
# (fills the guard meter). A press that parries nothing leaves no window for the next
# PARRY_LOCK seconds, so hammering the button only ever blocks.
const PARRY_WINDOW := 0.2
const PARRY_LOCK := 0.6
const GUARD_COST := 5.0
const GUARD_SNAP := 1.6	  # how much faster the blade moves while guarding
const GUARD_PULL := 0.3   # how far it leans from the mouse toward their blade

# Guard (posture): every plain BLOCK fills it; parries don't. When it fills, the guard
# breaks — blade knocked low, control sluggish — so blocking alone can't hold forever.
const POSTURE_MAX := 100.0
const BLOCK_POSTURE := 34.0           # three blocks in a row break the guard
const PARRIED_POSTURE := 25.0         # having our own cut parried also shakes us
const POSTURE_RECOVER_DELAY := 1.0    # seconds without blocking before it starts to drain
const POSTURE_RECOVER_RATE := 25.0    # per second

var sword: Node3D
var target: Node3D   # lock-on target, set by main
var locked := true   # the wheel click turns the lock-on off and on
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
var _deflect_damp := 1.0    # ... to this share of the mouse
var _guard_goal := Vector2.ZERO
var _guard_pull := 0.0
var _flick := Vector2.ZERO
var _recent := Vector2.ZERO   # the mouse's recent heading, for a left-click cut
var _prev_target := AIM_REST
var _cut_t := -1.0          # time into a cut; < 0 when not cutting
var _cut_side := Vector3.ZERO   # the way the cut goes (body space, across the view)
var _cut_start := []        # [grip, dir] the blade was at when the cut began
var _cut_back := []         # [grip, dir] the return starts from
var _cut_now := []          # [grip, dir] where the cut has the blade this frame
var _cut_twist := 0.0       # -1 drawn back .. +1 followed through (turns the view)
var _cut_kick := 0.0        # 1 at the height of the swing
var _cut_whoosh := false
var _cut_gap := 0.0
var _cut_drag := 0.0        # a cut biting into its target slows for a moment
var _punch := Vector2.ZERO  # the view jolted along a blow that landed
var _special := ""          # "thrust" / "execute" while one plays, else ""
var _sp_t := 0.0
var _sp_start := []         # [grip, dir] when it began
var _sp_struck := false
var _since_block := 0.0
var _since_swing := 0.0
var _swinging := false
var _dodge_t := -1.0		   # time into the current dodge; < 0 when not dodging
var _dodge_dir := Vector3.ZERO
var _dodge_cd := 0.0
var _last_dodge_ms := -100000
var _guard_held := false
var _parry_lock := 0.0      # a fresh press opens a parry window only once this runs out
var _since_guard := 99.0    # since the guard was last let go
var _parry_t := -1.0		   # time since the right button went down; < 0 when released
var _cam: Camera3D
var _arm_r
var _arm_l
var _pitch := 0.0
var _free_pitch := 0.0
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
	_cam.fov = 74.0
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
		steer(mm.relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Browsers only grant pointer lock from a click, and release it on ESC themselves.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		request_cut(_click_heading())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
		toggle_lock()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		press_guard(event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.is_echo() \
			and (event as InputEventKey).physical_keycode == KEY_SPACE:
		_try_dodge()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.is_echo() \
			and (event as InputEventKey).physical_keycode == KEY_E:
		try_special()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Mouse movement (pixels) steers the blade's point. With the lock-on off, whatever
## would carry it past the edge of its range turns the body or tilts the view instead.
func steer(relative: Vector2) -> void:
	var damp := _deflect_damp if _deflect_timer > 0.0 else 1.0
	var nx := _aim_target.x + relative.x * AIM_SENS * damp
	var ny := _aim_target.y - relative.y * AIM_SENS * damp
	if not locked:
		rotate_y(-(nx - clampf(nx, AIM_MIN.x, AIM_MAX.x)) * EDGE_TURN)
		_free_pitch = clampf(_free_pitch + (ny - clampf(ny, AIM_MIN.y, AIM_MAX.y)) * EDGE_TURN, -FREE_PITCH, FREE_PITCH)
	_aim_target.x = clampf(nx, AIM_MIN.x, AIM_MAX.x)
	_aim_target.y = clampf(ny, AIM_MIN.y, AIM_MAX.y)


func toggle_lock() -> void:
	locked = not locked
	_free_pitch = _pitch
	lock_changed.emit(locked)


## Called on a clash: kick the blade (it bounces) and damp control briefly.
func deflect(kick: Vector2, duration: float = 0.12, damp: float = 0.6) -> void:
	_aim = _clamp_aim(_aim + kick)
	_aim_target = _clamp_aim(_aim_target + kick)
	_aim_vel = kick * 4.0
	_deflect_timer = duration
	_deflect_damp = damp
	_abort_cut()
	add_trauma(0.18)


## We only BLOCKED a cut (held the line, didn't swing into it). Fills the guard meter;
## returns true if that broke the guard.
func absorb_block(h: float) -> bool:
	if _add_posture(BLOCK_POSTURE, h):
		return true
	deflect(Vector2(h * 0.45, 0.25), 0.25)    # knocked open, but still in the fight
	return false


## The opponent parried our cut: our blade is thrown wide. Returns true if the guard broke.
func get_parried(h: float) -> bool:
	if _add_posture(PARRIED_POSTURE, h):
		return true
	deflect(Vector2(h * 0.75, -0.35), 0.35, 0.45)
	add_trauma(0.2)
	return false


func _add_posture(amount: float, h: float) -> bool:
	posture += amount
	_since_block = 0.0
	if posture >= POSTURE_MAX:
		posture = 0.0
		deflect(Vector2(h * 0.8, -0.7), 0.9, 0.3)  # blade thrown low; slow to bring back
		add_trauma(0.35)
		return true
	return false


# --- bind (combat.gd drives it) -----------------------------------------------------

func enter_bind() -> void:
	_cut_t = -1.0
	_cut_twist = 0.0
	_cut_kick = 0.0
	in_bind = true
	_bind_push = 0.0
	_aim_vel = Vector2.ZERO


func exit_bind() -> void:
	in_bind = false
	_aim_target = _aim
	_prev_target = _aim_target


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
	return _special != "" or (_dodge_t >= DODGE_IFRAMES.x and _dodge_t <= DODGE_IFRAMES.y)


func is_guarding() -> bool:
	return _guard_held and not in_bind


## Right mouse down or up.
func press_guard(down: bool) -> void:
	if down and not in_bind:
		_guard_held = true
		_parry_t = 0.0 if _parry_lock <= 0.0 else 99.0   # 99: no window, just the guard
		_parry_lock = PARRY_LOCK
		_abort_cut()   # guarding pulls out of a cut (a feint)
		breath = maxf(breath - GUARD_COST, 0.0)
	elif not down:
		if _guard_held:
			_since_guard = 0.0
		_guard_held = false
		_parry_t = -1.0


## The blade is on guard, or still coming back from it: not a swing.
func blade_on_guard() -> bool:
	return is_guarding() or _since_guard < 0.25


## A parry landed: the next press may parry again at once.
func parry_landed() -> void:
	_parry_lock = 0.0


## The parry window is tighter against better fighters (their tier's parry_window).
func is_parry_window() -> bool:
	var window := PARRY_WINDOW
	if target != null and target.has_method("tier_value"):
		window = float(target.tier_value("parry_window", PARRY_WINDOW))
	return _parry_t >= 0.0 and _parry_t <= window


func dodged_within(ms: int) -> bool:
	return Time.get_ticks_msec() - _last_dodge_ms <= ms


func _try_dodge() -> void:
	if in_bind or _dodge_t >= 0.0 or _dodge_cd > 0.0 or breath < 5.0:
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
	_parry_lock -= delta
	_since_guard += delta
	if _parry_t >= 0.0:
		_parry_t += delta
	if _since_block > POSTURE_RECOVER_DELAY and posture > 0.0:
		posture = maxf(posture - POSTURE_RECOVER_RATE * delta, 0.0)

	if alive and (locked or in_bind):
		_face_target(delta)

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
	if _cut_t >= 0.0 and _cut_t < _swing_end() and input_dir.z <= 0.0:
		local.z -= CUT_STEP * (1.0 - _cut_t / _swing_end())   # step into the cut
	var move := global_transform.basis * local
	if _special != "":
		move = _special_step()
	if _dodge_t >= 0.0:
		# A dodge overrides walking: fast at first, easing off.
		_dodge_t += delta
		var k := 1.0 - clampf(_dodge_t / DODGE_TIME, 0.0, 1.0)
		move = global_transform.basis * _dodge_dir * DODGE_SPEED * (0.25 + 0.75 * k)
		if _dodge_t >= DODGE_TIME:
			_dodge_t = -1.0
			Sfx.play_flat("armor", -3.0)   # back on the feet
			add_trauma(0.12)
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
	_guard_pull = 0.0
	if _guard_held and not in_bind:
		_track_incoming_blade()
	if not in_bind and _special == "":
		_watch_flick(delta)
		if _cut_t < 0.0 or _cut_t >= _hold_end():
			_step_aim(delta)

	# Sword: the hands go where the mouse steers them and the blade points on to the
	# aim (see _held_pose). A cut takes over.
	var held := _held_pose()
	var pose := held
	if _special != "":
		pose = _special_pose(delta, held)
	elif _cut_t >= 0.0:
		pose = _cut_pose(delta, held)
	var grip: Vector3 = pose[0]
	var dir: Vector3 = pose[1]
	var dip := roll_offset()   # the whole upper body goes down with a roll
	grip = _within_reach(grip) - dip
	sword.drive(to_global(grip), global_transform.basis * dir, delta)
	var blade_basis := sword.transform.basis
	_arm_r.pose(SHOULDER_R - dip, grip, Vector3(0.7, -0.7, 0.1), blade_basis)
	var left_hand := grip - dir * SwordMesh.LEFT_HAND
	if _special == "execute" and _sp_t < _sp_end(3) and target != null:
		left_hand = to_local(_grab_point())   # the left hand has hold of them
	_arm_l.pose(SHOULDER_L - dip, left_hand, Vector3(-0.7, -0.7, 0.1), blade_basis)

	_update_camera(delta, moving)


## Each full swing (a real cut's speed and travel) costs breath once.
func _update_breath(delta: float) -> void:
	var swinging: bool = sword.is_real_swing(SwordScript.CUT_THRESHOLD, SwordScript.CUT_ARC)
	# (A big cut paid for itself when it began: its draw, swing and return are free.)
	if swinging and not _swinging and _cut_t < 0.0 and _cut_gap <= 0.0 and _special == "":
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


## While guarding, the blade leans toward the middle of the opponent's blade.
func _track_incoming_blade() -> void:
	if target == null or not target.has_method("get_blade_vel"):
		return
	var mid: Vector3 = (target.get("blade_base") + target.get("blade_tip")) * 0.5
	var local := to_local(mid)
	_guard_goal = _clamp_aim(Vector2(local.x, local.y))
	_guard_pull = GUARD_PULL


## The blade's point chases the mouse target with capped acceleration and speed.
func _step_aim(delta: float) -> void:
	var k := _strength()
	var goal := _aim_target.lerp(_guard_goal, _guard_pull)
	var acc := (goal - _aim) * AIM_STIFFNESS - _aim_vel * AIM_DAMPING
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


# --- cut --------------------------------------------------------------------------

## The blade where the mouse holds it: [grip, dir] in body space.
func _held_pose() -> Array:
	var off := Vector3(_aim.x * HANDS_SPAN.x, (_aim.y - AIM_REST.y) * HANDS_SPAN.y, 0.0)
	var grip := _within_reach(HANDS_REST + off + Vector3(0.0, 0.0, 0.5 * off.length_squared()))
	var whip := (Vector3(_aim_vel.x, _aim_vel.y, 0.0) * WHIP).limit_length(0.9)
	var aim_pt := Vector3(_aim.x, _aim.y, AIM_PLANE_Z) + whip
	return [grip, (aim_pt - grip).normalized()]


## The hands can't go further from the right shoulder than the arms reach.
func _within_reach(grip: Vector3) -> Vector3:
	var from_shoulder := grip - SHOULDER_R
	if from_shoulder.length() > HANDS_REACH:
		return SHOULDER_R + from_shoulder.normalized() * HANDS_REACH
	return grip


## Watches the mouse for a flick (and keeps its recent heading for left-click cuts).
func _watch_flick(delta: float) -> void:
	var moved := _aim_target - _prev_target
	_prev_target = _aim_target
	_cut_gap -= delta
	_recent = _recent * exp(-6.0 * delta) + moved
	if _cut_t >= 0.0:
		return
	_flick = _flick * exp(-FLICK_DECAY * delta) + moved
	if _flick.length() >= FLICK:
		request_cut(_flick)


## Start a cut toward `heading` (x right, y up, as the mouse moves the blade).
func request_cut(heading: Vector2) -> void:
	if _cut_t >= 0.0 or _cut_gap > 0.0 or _guard_held or in_bind or breath < CUT_BREATH \
			or _deflect_timer > 0.0 or not active or not alive or heading.length() < 0.001:
		return
	# Across the view, tipped a little downward: level cuts fall slightly, like real ones.
	_cut_side = (Vector3(heading.x, heading.y, 0.0).normalized() + Vector3(0.0, -0.2, 0.0)).normalized()
	_cut_start = _held_pose()
	_cut_t = 0.0
	_cut_whoosh = false
	breath = maxf(breath - CUT_COST, 0.0)
	_flick = Vector2.ZERO
	# When it is over, the blade rests on the side the cut went to.
	_aim_target = _clamp_aim(AIM_REST + Vector2(_cut_side.x, _cut_side.y) * 0.9)
	_prev_target = _aim_target
	add_trauma(0.06)


## Left click: cut the way the mouse was just moving; if it was still, cut from the
## side the blade is on across to the other (or straight down from the middle).
func _click_heading() -> Vector2:
	if _recent.length() > 0.05:
		return _recent
	if absf(_aim.x) > 0.3:
		return Vector2(-signf(_aim.x), -0.6)
	return Vector2(0.0, -1.0)


## A clash or a guard pulls out of the swing: ease back from wherever it got to.
func _abort_cut() -> void:
	if _cut_t >= 0.0 and _cut_t < _hold_end():
		_cut_back = _cut_now if not _cut_now.is_empty() else _held_pose()
		_cut_t = _hold_end()


## The blade on the arc at `deg` degrees (0 = straight ahead): [grip, dir]. The blade
## swings round the shoulders; the hands take their own path, from beside the head on
## the far side, out in front with the arms extended, to low on the near side, so they
## never come up in front of the eyes.
func _arc(deg: float) -> Array:
	var a := deg_to_rad(deg)
	var d := Vector3(0.0, 0.0, -1.0) * cos(a) + _cut_side * sin(a)
	# Drawn back, the blade is also raised (not for cuts that are already vertical).
	d += Vector3.UP * 0.55 * clampf(-sin(a), 0.0, 1.0) * (1.0 - absf(_cut_side.y))
	d = d.normalized()
	var u := clampf(inverse_lerp(CUT_FROM, CUT_TO, deg), 0.0, 1.05)
	var back := Vector3(-_cut_side.x, 0.0, 0.0)
	back = back.normalized() if back.length() > 0.2 else Vector3.RIGHT   # straight down: over the right shoulder
	var h0 := CUT_PIVOT + back * 0.4 + Vector3(0.0, -_cut_side.y * 0.36 + 0.16 * (1.0 - absf(_cut_side.y)), 0.16)
	var h1 := CUT_PIVOT + Vector3(0.0, 0.0, -0.7)
	var h2 := CUT_PIVOT + _cut_side * 0.5 + Vector3(0.0, -0.2, -0.3)
	return [h0.lerp(h1, u).lerp(h1.lerp(h2, u), u), d]


func _blend(a: Array, b: Array, t: float) -> Array:
	return [(a[0] as Vector3).lerp(b[0], t), (a[1] as Vector3).slerp(b[1], t).normalized()]


## Where the cut has the blade now, and how far the view turns with it.
func _cut_pose(delta: float, held: Array) -> Array:
	_cut_drag -= delta
	_cut_t += delta * (0.25 if _cut_drag > 0.0 else 1.0)
	var t := _cut_t
	var twist_from := sin(deg_to_rad(CUT_FROM))
	var out: Array
	_cut_kick = 0.0
	if t < CUT_DRAW:
		var p := 1.0 - pow(1.0 - t / CUT_DRAW, 3.0)
		out = _blend(_cut_start, _arc(CUT_FROM), p)
		_cut_twist = twist_from * p
		_cut_back = []
	elif t < CUT_DRAW + CUT_HANG:
		# Cocked: it draws back a touch further for a beat.
		var deg := CUT_FROM - 6.0 * sin(PI * (t - CUT_DRAW) / CUT_HANG)
		out = _arc(deg)
		_cut_twist = sin(deg_to_rad(deg))
	elif t < _swing_end():
		if not _cut_whoosh:
			_cut_whoosh = true
			Sfx.play_flat("swing", 3.0)
			sword.set("_swing_cd", 0.5)   # this one whoosh, not the blade's own as well
			add_trauma(0.1)
		# Heavy to start, then faster and faster right through the far side: a lash,
		# not an even circle.
		var p := (t - CUT_DRAW - CUT_HANG) / CUT_SWING
		var q := pow(p, 2.2)
		var deg := lerpf(CUT_FROM, CUT_TO, q)
		out = _arc(deg)
		_cut_twist = sin(deg_to_rad(deg))
		_cut_kick = sin(PI * 0.5 * p)
	elif t < _hold_end():
		# Follow-through: carries on past and springs back.
		var h := (t - _swing_end()) / CUT_HOLD
		_cut_kick = 1.0 - h
		var deg := CUT_TO + CUT_OVER * sin(PI * h)
		out = _arc(deg)
		_cut_twist = sin(deg_to_rad(deg))
	else:
		if _cut_back.is_empty():
			_cut_back = _arc(CUT_TO)
			_aim = _aim_target   # the held blade waits where the cut ended
			_aim_vel = Vector2.ZERO
		var p := clampf((t - _hold_end()) / CUT_RETURN, 0.0, 1.0)
		var q := p * p * (3.0 - 2.0 * p)
		out = _blend(_cut_back, held, q)
		_cut_twist = lerpf(_cut_twist, 0.0, q)
		if p >= 1.0:
			_cut_t = -1.0
			_cut_twist = 0.0
			_cut_gap = CUT_GAP
			_prev_target = _aim_target
			_flick = Vector2.ZERO
	_cut_now = out
	return out


## Main calls this when our cut lands (k: 0 a glancing blow .. 1 a full one): the view
## jolts along the swing, the hands feel it, and a big swing bites and slows a moment.
func impact(k: float) -> void:
	var v: Vector3 = global_transform.basis.inverse() * sword.tip_vel
	_punch = Vector2(v.x, v.y).normalized() * (0.03 + 0.05 * k)
	add_trauma(0.15 + 0.2 * k)
	if is_big_swing():
		_cut_drag = 0.05 + 0.04 * k


# --- special moves -----------------------------------------------------------------

## What E would do right now: "execute", "thrust" or "".
func special_available() -> String:
	if not active or not alive or in_bind or _special != "" or _dodge_t >= 0.0 or target == null \
			or not target.has_method("can_be_executed"):
		return ""
	var d := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	if d > SPECIAL_REACH:
		return ""
	if target.can_be_executed():
		return "execute"
	if target.critical_open():
		return "thrust"
	return ""


func try_special() -> void:
	var kind := special_available()
	if kind == "":
		return
	_special = kind
	_sp_t = 0.0
	_sp_struck = false
	_sp_start = _cut_now if _cut_t >= 0.0 and not _cut_now.is_empty() else _held_pose()
	_cut_t = -1.0
	_cut_twist = 0.0
	_cut_kick = 0.0
	_guard_held = false
	_parry_t = -1.0
	target.seize()
	Sfx.play_flat("armor", -2.0)
	if kind == "execute":
		execution_started.emit()


func in_special() -> bool:
	return _special != ""


## (seconds into the special move, when its blade goes in)
func special_clock() -> Vector2:
	return Vector2(_sp_t, _sp_end(1)) if _special != "" else Vector2.ZERO


## An execution's left hand still has hold of them.
func grab_active() -> bool:
	return _special == "execute" and _sp_t < _sp_end(3) and target != null


func grab_point() -> Vector3:
	return _grab_point()


## Our own arms and sword, hidden while an execution is shown from outside.
func set_first_person_visible(on: bool) -> void:
	sword.visible = on
	_arm_r.set_visible(on)
	_arm_l.set_visible(on)


## When phase i of the current special move ends (seconds into it).
func _sp_end(i: int) -> float:
	var times: Array = THRUST_TIMES if _special == "thrust" else EXECUTE_TIMES
	var t := 0.0
	for k in i + 1:
		t += float(times[k])
	return t


## Stepping in to close range during the first phase.
func _special_step() -> Vector3:
	if target == null or _sp_t >= _sp_end(0):
		return Vector3.ZERO
	var to := target.global_position - global_position
	to.y = 0.0
	var gap := to.length() - float(SPECIAL_CLOSE[_special])
	if gap <= 0.0:
		return Vector3.ZERO
	var left := maxf(_sp_end(0) - _sp_t, 0.05)
	return to.normalized() * minf(gap / left, 11.0)


## Where the left hand grabs them: the top of the chest, on the near side.
func _grab_point() -> Vector3:
	var to_me := (global_position - target.global_position)
	to_me.y = 0.0
	return target.global_position + Vector3(0.0, 1.32, 0.0) + to_me.normalized() * 0.2


## The sword through the special move: [grip, dir] in body space.
func _special_pose(delta: float, held: Array) -> Array:
	_sp_t += delta
	# Their chest where it is now (it sinks as they go down on their knees).
	var chest := Vector3(0, 1.2, -1.0)
	if target != null:
		chest = to_local(target.chest_point() if target.has_method("chest_point") else target.global_position + Vector3(0.0, 1.2, 0.0))
	var execute := _special == "execute"
	# Drawn back: for a thrust the hilt at the right hip, point on them; for an
	# execution high by the right shoulder (one hand; the other has hold of them).
	var wind := [Vector3(0.22, 1.18, 0.1), Vector3(-0.08, 0.05, -1.0).normalized()]
	if execute:
		wind = [Vector3(0.26, 1.42, 0.12), Vector3(-0.1, -0.2, -1.0).normalized()]
	var in_grip := Vector3(0.03, 1.28 if not execute else 1.2, -0.52 if not execute else -0.4)
	var stab := [in_grip, (chest - in_grip).normalized()]
	var out: Array
	_cut_kick = 0.0
	if _sp_t < _sp_end(0):
		var p := 1.0 - pow(1.0 - _sp_t / _sp_end(0), 3.0)
		out = _blend(_sp_start, wind, p)
	elif _sp_t < _sp_end(1):
		var p := (_sp_t - _sp_end(0)) / (_sp_end(1) - _sp_end(0))
		out = _blend(wind, stab, p * p)
		_cut_kick = p
	elif _sp_t < _sp_end(2):
		if not _sp_struck:
			_sp_struck = true
			_strike_home(stab)
		# Held in, leaning on it (an execution follows them down a little).
		var p := (_sp_t - _sp_end(1)) / (_sp_end(2) - _sp_end(1))
		var push := Vector3(0.0, -0.12 * p if execute else 0.0, -0.04 * sin(PI * minf(p * 2.0, 1.0)))
		if execute:
			# Following them down: the hilt drops and the point stays in their chest.
			var grip: Vector3 = stab[0] + Vector3(0.0, minf(chest.y - 1.2, 0.0) * 0.8, 0.0)
			out = [grip, (chest - grip).normalized()]
		else:
			out = [stab[0] + push, stab[1]]
		_cut_kick = 1.0 - p * 0.5
	elif _sp_t < _sp_end(3):
		var p := (_sp_t - _sp_end(2)) / (_sp_end(3) - _sp_end(2))
		if p < 0.2 and not execute and target != null:
			target.release_seized(2.2)   # shoved off the blade
		out = _blend(stab, [Vector3(0.16, 1.24, -0.3), stab[1]], p)
	else:
		var p := clampf((_sp_t - _sp_end(3)) / (_sp_end(4) - _sp_end(3)), 0.0, 1.0)
		var q := p * p * (3.0 - 2.0 * p)
		out = _blend([Vector3(0.16, 1.24, -0.3), stab[1]], held, q)
		if p >= 1.0:
			_special = ""
			_prev_target = _aim_target
			_flick = Vector2.ZERO
	return out


## The blade goes in.
func _strike_home(stab: Array) -> void:
	if target == null:
		return
	var point: Vector3 = to_global(stab[0] + (stab[1] as Vector3) * 0.7)
	var dir: Vector3 = global_transform.basis * (stab[1] as Vector3)
	var damage := float(target.hp) if _special == "execute" else THRUST_DAMAGE
	target.stabbed(damage, point, dir)
	add_trauma(0.45)
	_punch = Vector2(0.0, -0.06)
	special_struck.emit(_special)


## A committed cut is swinging (drawn back and let go, up to its follow-through).
func is_big_swing() -> bool:
	return _cut_t >= CUT_DRAW and _cut_t < _hold_end()


func _swing_end() -> float:
	return CUT_DRAW + CUT_HANG + CUT_SWING


func _hold_end() -> float:
	return _swing_end() + CUT_HOLD


## How far a roll has lowered the upper body (and the sword) right now, body space.
func roll_offset() -> Vector3:
	return Vector3(0.0, _dodge_dip(), 0.0)


## How far the roll has the eyes dropped right now.
func _dodge_dip() -> float:
	return DODGE_DIP * sin(PI * clampf(_dodge_t / DODGE_TIME, 0.0, 1.0)) if _dodge_t >= 0.0 else 0.0


## Turn to face the target (quickly, so switching the lock back on swings round
## instead of snapping).
func _face_target(delta: float) -> void:
	if target == null:
		return
	var to := target.global_position - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-FACE_RATE * delta))


func _update_camera(delta: float, moving: float) -> void:
	var look_pitch := _free_pitch
	if target != null and (locked or in_bind):
		var eye := to_global(EYE)
		var chest := target.global_position + Vector3(0.0, 1.2, 0.0)  # look a bit low: hands in frame
		var flat := Vector2(chest.x - eye.x, chest.z - eye.z).length()
		look_pitch = atan2(chest.y - eye.y, maxf(flat, 0.3))
	_pitch = lerp_angle(_pitch, look_pitch, clampf(delta * 6.0, 0.0, 1.0))

	# A little sway toward where the blade is, a walking bob, and impact shake. A cut
	# turns the shoulders and so the view with it, tips it the way the blade falls and
	# widens it for a moment.
	var sway_yaw := -_aim.x * deg_to_rad(8.0)
	# (Looking further down after a low blade, so it doesn't drop out of sight.)
	var sway_pitch := (_aim.y - AIM_REST.y) * deg_to_rad(10.0 if _aim.y > AIM_REST.y else 20.0)
	sway_yaw += -_cut_side.x * CUT_TWIST * _cut_twist
	sway_pitch += _cut_side.y * 0.2 * _cut_twist
	_cam.fov = 74.0 + 12.0 * _cut_kick
	# A blow that landed jolts the view along it.
	sway_yaw -= _punch.x
	sway_pitch += _punch.y
	_punch = _punch.move_toward(Vector2.ZERO, delta * 0.6)
	if _special != "":
		# A special move closes in: the view narrows onto them, and follows an
		# execution down as they sink.
		_cam.fov = 74.0 - 14.0 * _cut_kick
		if _special == "execute" and _sp_t > _sp_end(1):
			sway_pitch -= 0.25 * clampf((_sp_t - _sp_end(1)) / 0.6, 0.0, 1.0)
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	var shake := _trauma * _trauma
	var bob_amount := clampf(moving / SPEED, 0.0, 1.0)
	_bob += delta * moving * 2.6
	_cam.position = EYE + Vector3(cos(_bob) * 0.010 * bob_amount, absf(sin(_bob)) * 0.018 * bob_amount, 0.0) \
		+ Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * 0.03 * shake \
		+ Vector3(0.0, -0.07, -0.22) * _cut_kick   # leaning into the swing
	var roll := _cut_side.x * 0.15 * _cut_twist
	# The view leans into a fast drag of the blade.
	sway_yaw += clampf(-_aim_vel.x * 0.006, -0.07, 0.07)
	sway_pitch += clampf(_aim_vel.y * 0.004, -0.05, 0.05)
	roll += clampf(_aim_vel.x * 0.004, -0.05, 0.05)
	if _dodge_t >= 0.0:
		# Rolling: down toward the ground, tucked (looking down) and tipped the way it
		# goes, up again at the end.
		var s := sin(clampf(_dodge_t / DODGE_TIME, 0.0, 1.0) * PI)
		roll = -_dodge_dir.x * 0.5 * s
		sway_pitch -= 0.35 * s
		_cam.position.y -= _dodge_dip()
	_cam.rotation = Vector3(
		_pitch + sway_pitch + randf_range(-1.0, 1.0) * 0.03 * shake,
		sway_yaw + randf_range(-1.0, 1.0) * 0.03 * shake,
		roll + randf_range(-1.0, 1.0) * 0.02 * shake)
