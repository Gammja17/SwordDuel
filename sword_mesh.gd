extends RefCounted
## Builds a longsword from procedural meshes: a flat-diamond blade that narrows to a
## point, a crossguard, a leather grip for two hands and a pommel.
##
## Local frame: the origin is where the RIGHT hand grips (just behind the
## crossguard), the blade runs along -Z and its edges along X. The left hand grips
## LEFT_HAND behind the origin, toward the pommel.

const BLADE_START := 0.05             # right hand -> front of the crossguard
const BLADE_LEN := 0.91               # crossguard -> tip
const REACH := BLADE_START + BLADE_LEN  # right hand -> tip
const GRIP_LEN := 0.24                # crossguard -> pommel
const LEFT_HAND := 0.12               # right hand -> left hand, along the grip


static func build(blade_mat: Material, fitting_mat: Material, grip_mat: Material, shadows := true) -> Node3D:
	var root := Node3D.new()
	root.name = "SwordMesh"

	var blade := MeshInstance3D.new()
	blade.mesh = _blade_mesh()
	blade.material_override = blade_mat
	root.add_child(blade)

	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.25, 0.024, 0.028)
	guard.mesh = gm
	guard.material_override = fitting_mat
	guard.position = Vector3(0.0, 0.0, -BLADE_START + 0.014)
	root.add_child(guard)

	var grip := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.017
	cm.bottom_radius = 0.019
	cm.height = GRIP_LEN
	cm.radial_segments = 12
	grip.mesh = cm
	grip.material_override = grip_mat
	grip.rotation_degrees = Vector3(90.0, 0.0, 0.0)  # cylinder axis Y -> Z
	grip.position = Vector3(0.0, 0.0, -BLADE_START + 0.028 + GRIP_LEN * 0.5)
	root.add_child(grip)

	var pommel := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.028
	pm.height = 0.05
	pommel.mesh = pm
	pommel.material_override = fitting_mat
	pommel.position = Vector3(0.0, 0.0, -BLADE_START + 0.028 + GRIP_LEN + 0.02)
	root.add_child(pommel)

	if not shadows:
		for c in root.get_children():
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Blade with a flat-diamond cross-section: stations along the length give the
## half-width (edge to spine) and half-thickness, tapering to a single tip vertex.
static func _blade_mesh() -> ArrayMesh:
	var stations := [
		[0.00, 0.025, 0.0048],
		[0.50, 0.020, 0.0042],
		[0.86, 0.014, 0.0034],
		[1.00, 0.000, 0.0000],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(stations.size() - 1):
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		var ring_a := _ring(a[1], a[2], -BLADE_START - float(a[0]) * BLADE_LEN)
		var ring_b := _ring(b[1], b[2], -BLADE_START - float(b[0]) * BLADE_LEN)
		for k in 4:
			var k2 := (k + 1) % 4
			_face(st, [ring_a[k], ring_a[k2], ring_b[k2], ring_b[k]],
				[Vector2(k / 4.0, a[0]), Vector2(k2 / 4.0, a[0]), Vector2(k2 / 4.0, b[0]), Vector2(k / 4.0, b[0])])
	return st.commit()


static func _ring(half_w: float, half_t: float, z: float) -> Array:
	return [Vector3(half_w, 0.0, z), Vector3(0.0, half_t, z), Vector3(-half_w, 0.0, z), Vector3(0.0, -half_t, z)]


## One flat-shaded quad (two triangles) with an outward normal. The blade material is
## double-sided, so winding doesn't decide visibility; the normal is set explicitly.
static func _face(st: SurfaceTool, p: Array, uv: Array) -> void:
	var p0: Vector3 = p[0]
	var p1: Vector3 = p[1]
	var p3: Vector3 = p[3]
	var n := (p1 - p0).cross(p3 - p0)
	if n.length() < 1e-9:
		var p2: Vector3 = p[2]
		n = (p1 - p0).cross(p2 - p0)
	n = n.normalized()
	var centre := (p0 + p1 + p3) / 3.0
	if n.dot(Vector3(centre.x, centre.y, 0.0)) < 0.0:
		n = -n
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uv[idx])
		st.add_vertex(p[idx])
