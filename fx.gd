extends RefCounted
## One-shot impact effects: steel sparks with a brief light flash where blades meet,
## and a small dark spray where a cut lands.

static var _spark_mat: StandardMaterial3D
static var _drop_mat: StandardMaterial3D


static func sparks(parent: Node, pos: Vector3, strength := 1.0) -> void:
	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.vertex_color_use_as_albedo = true
		_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(16 + 20 * strength)
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0 + 3.0 * strength
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.particle_flag_align_y = true
	var streak := BoxMesh.new()
	streak.size = Vector3(0.005, 0.045, 0.005)
	p.mesh = streak
	p.material_override = _spark_mat
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 2.5 * strength
	light.omni_range = 2.2
	parent.add_child(light)
	light.global_position = pos
	var tw := parent.get_tree().create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.14)
	tw.tween_callback(light.queue_free)
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## A gold bubble that swells and fades where the blades met (a parry).
static func shockwave(parent: Node, pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.2
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.4, 0.55)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos
	var tw := parent.get_tree().create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 5.0, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(m.queue_free)


static func cut_spray(parent: Node, pos: Vector3, dir: Vector3, amount := 1.0) -> void:
	if _drop_mat == null:
		_drop_mat = StandardMaterial3D.new()
		_drop_mat.albedo_color = Color(0.35, 0.02, 0.02)
		_drop_mat.roughness = 0.3
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(14 * amount)
	p.lifetime = 0.55
	p.explosiveness = 0.9
	p.direction = dir if dir.length() > 0.01 else Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.4 * sqrt(amount)
	p.gravity = Vector3(0.0, -9.8, 0.0)
	var drop := SphereMesh.new()
	drop.radius = 0.008
	drop.height = 0.016
	drop.radial_segments = 6
	drop.rings = 3
	p.mesh = drop
	p.material_override = _drop_mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
