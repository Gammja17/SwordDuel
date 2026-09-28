extends MeshInstance3D
## A fading ribbon behind a blade: the last few positions of its edge (base to tip),
## drawn only while the blade is really cutting. Lives in world space.

var color := Color(1.0, 1.0, 1.0, 0.35)
var length := 9     # samples kept
var substeps := 1   # samples per push: more keeps a fast, wide arc smooth
var _im := ImmediateMesh.new()
var _samples: Array = []   # [base, tip, strength 0..1]


func _init() -> void:
	top_level = true
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	material_override = m


## Called once per physics frame with the blade's world position and how strongly it
## is cutting (0 = not at all).
func push(base: Vector3, tip: Vector3, strength: float) -> void:
	if substeps > 1 and not _samples.is_empty():
		var last: Array = _samples[-1]
		for k in range(1, substeps):
			var u := float(k) / substeps
			_samples.append([(last[0] as Vector3).lerp(base, u), (last[1] as Vector3).lerp(tip, u),
				lerpf(last[2], strength, u)])
	_samples.append([base, tip, strength])
	while _samples.size() > length:
		_samples.pop_front()
	_im.clear_surfaces()
	var lit := false
	for s in _samples:
		if float(s[2]) > 0.0:
			lit = true
			break
	if not lit or _samples.size() < 2:
		return
	transform = Transform3D.IDENTITY   # top_level: this is world space
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _samples.size()
	for i in n:
		var s: Array = _samples[i]
		var fade := float(i) / float(n - 1)   # oldest 0, newest 1
		var a := color.a * float(s[2]) * fade
		# The part near the hilt barely shows; the tip end carries the streak.
		_im.surface_set_color(Color(color.r, color.g, color.b, a * 0.15))
		_im.surface_add_vertex((s[0] as Vector3).lerp(s[1], 0.35))
		_im.surface_set_color(Color(color.r, color.g, color.b, a))
		_im.surface_add_vertex(s[1])
	_im.surface_end()
