extends RefCounted
## The look of the duel: PBR materials built from the CC0 textures in
## assets/textures (plain colours if a texture is missing), and helpers for laying
## out body parts made of primitive meshes.

const TEX_DIR := "res://assets/textures/"

static var _cache := {}


static func tex(file: String) -> Texture2D:
	var path := TEX_DIR + file
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## A PBR material from a texture set (<set>_albedo/_normal/_rough/_metal.jpg).
static func pbr(set_name: String, tint: Color, metallic: float, roughness: float,
		uv_scale := Vector3.ONE, world_triplanar := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	var albedo := tex(set_name + "_albedo.jpg")
	if albedo:
		m.albedo_texture = albedo
	var normal := tex(set_name + "_normal.jpg")
	if normal:
		m.normal_enabled = true
		m.normal_texture = normal
	var rough := tex(set_name + "_rough.jpg")
	if rough:
		m.roughness_texture = rough
	m.roughness = roughness
	m.metallic = metallic
	var metal := tex(set_name + "_metal.jpg")
	if metal:
		m.metallic_texture = metal
	m.uv1_scale = uv_scale
	if world_triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
	return m


static func _cached(key: String, maker: Callable) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


static func steel() -> StandardMaterial3D:
	return _cached("steel", func(): return pbr("steel", Color(0.80, 0.81, 0.84), 1.0, 0.55, Vector3(2, 2, 2)))


static func dark_steel() -> StandardMaterial3D:
	return _cached("dark_steel", func(): return pbr("steel", Color(0.28, 0.28, 0.30), 1.0, 0.7, Vector3(2, 2, 2)))


static func blade() -> StandardMaterial3D:
	return _cached("blade", func():
		var m := pbr("steel", Color(0.90, 0.91, 0.93), 1.0, 0.32, Vector3(1, 6, 1))
		m.cull_mode = BaseMaterial3D.CULL_DISABLED  # procedural blade: see sword_mesh.gd
		return m)


static func leather() -> StandardMaterial3D:
	return _cached("leather", func(): return pbr("leather", Color(0.55, 0.40, 0.30), 0.0, 0.85, Vector3(2, 2, 2)))


static func cloth(color: Color) -> StandardMaterial3D:
	return _cached("cloth_" + color.to_html(), func(): return pbr("cloth", color, 0.0, 1.0, Vector3(3, 3, 3)))


static func wood() -> StandardMaterial3D:
	return _cached("wood", func(): return pbr("wood", Color(0.75, 0.68, 0.60), 0.0, 0.9, Vector3(1, 1, 1)))


static func floor_stone() -> StandardMaterial3D:
	return _cached("floor", func(): return pbr("floor", Color(0.92, 0.90, 0.88), 0.0, 1.0, Vector3(0.5, 0.5, 0.5), true))


static func wall_stone() -> StandardMaterial3D:
	return _cached("wall", func(): return pbr("wall", Color(0.85, 0.82, 0.78), 0.0, 1.0, Vector3(0.45, 0.45, 0.45), true))


static func visor_black() -> StandardMaterial3D:
	return _cached("visor", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.02, 0.02, 0.02)
		m.roughness = 1.0
		return m)


# --- primitive parts -------------------------------------------------------------

static func part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 16
	m.rings = 6
	return m


static func cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 16
	return m


static func sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Stretch-free placement of a Y-axis mesh (capsule/cylinder) between two points given
## in the PARENT's local space.
static func place_between(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.0001:
		return
	var y := d / length
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)


## Basis whose -Z points along dir and whose X (the blade's edges) lies as close to
## edge_hint as possible.
static func blade_basis(dir: Vector3, edge_hint: Vector3) -> Basis:
	var z := -dir.normalized()
	var x := edge_hint - z * edge_hint.dot(z)
	if x.length() < 0.001:
		x = Vector3.UP.cross(z)
		if x.length() < 0.001:
			x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)
