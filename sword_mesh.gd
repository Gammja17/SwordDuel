extends RefCounted
## Builds a longsword from procedural meshes: a flat-diamond blade that narrows to a
## point, a crossguard that tapers toward flared tips, a leather grip for two hands
## between steel collars, and a wheel pommel.
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
	guard.mesh = _guard_mesh()
	guard.material_override = fitting_mat
	guard.position = Vector3(0.0, 0.0, -BLADE_START + 0.012)
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

	# Steel collars at both ends of the grip.
	for z in [-BLADE_START + 0.032, -BLADE_START + 0.024 + GRIP_LEN]:
		var collar := MeshInstance3D.new()
		var ccm := CylinderMesh.new()
		ccm.top_radius = 0.021
		ccm.bottom_radius = 0.021
		ccm.height = 0.014
		ccm.radial_segments = 12
		collar.mesh = ccm
		collar.material_override = fitting_mat
		collar.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		collar.position = Vector3(0.0, 0.0, z)
		root.add_child(collar)

	# Wheel pommel: a thick disc in the plane of the blade, with a small peen behind.
	var pommel_z := -BLADE_START + 0.028 + GRIP_LEN + 0.024
	var pommel := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.031
	pm.bottom_radius = 0.031
	pm.height = 0.024
	pm.radial_segments = 16
	pommel.mesh = pm
	pommel.material_override = fitting_mat
	pommel.position = Vector3(0.0, 0.0, pommel_z)
	root.add_child(pommel)
	var peen := MeshInstance3D.new()
	var pnm := CylinderMesh.new()
	pnm.top_radius = 0.006
	pnm.bottom_radius = 0.009
	pnm.height = 0.014
	pnm.radial_segments = 8
	peen.mesh = pnm
	peen.material_override = fitting_mat
	peen.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	peen.position = Vector3(0.0, 0.0, pommel_z + 0.036)
	root.add_child(peen)

	if not shadows:
		for c in root.get_children():
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Crossguard: an eight-sided bar along X, thick in the middle, thinning outward and
## flaring into small knobs at the tips, which bend slightly toward the blade (-Z).
static func _guard_mesh() -> ArrayMesh:
	const HALF := 0.13
	const BEND := 0.012
	const SIDES := 8
	var profile := [[0.0, 0.0125], [0.3, 0.0095], [0.78, 0.0068], [0.9, 0.0095], [0.97, 0.009], [1.0, 0.004]]
	var stations := []   # [x, radius], from one tip to the other
	for i in range(profile.size() - 1, 0, -1):
		stations.append([-float(profile[i][0]) * HALF, profile[i][1]])
	for i in profile.size():
		stations.append([float(profile[i][0]) * HALF, profile[i][1]])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in stations.size() - 1:
		var xa: float = stations[i][0]
		var xb: float = stations[i + 1][0]
		var ra: float = stations[i][1]
		var rb: float = stations[i + 1][1]
		var za := -BEND * pow(xa / HALF, 2.0)
		var zb := -BEND * pow(xb / HALF, 2.0)
		for k in SIDES:
			var a0 := TAU * k / SIDES
			var a1 := TAU * (k + 1) / SIDES
			var n0 := Vector3(0.0, cos(a0), sin(a0))
			var n1 := Vector3(0.0, cos(a1), sin(a1))
			var p00 := Vector3(xa, 0.0, za) + n0 * ra
			var p01 := Vector3(xa, 0.0, za) + n1 * ra
			var p10 := Vector3(xb, 0.0, zb) + n0 * rb
			var p11 := Vector3(xb, 0.0, zb) + n1 * rb
			# Both windings, so it shows whichever way the fitting material culls.
			for v in [[p00, n0], [p10, n0], [p11, n1], [p00, n0], [p11, n1], [p01, n1],
					[p00, n0], [p11, n1], [p10, n0], [p00, n0], [p01, n1], [p11, n1]]:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	return st.commit()


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
