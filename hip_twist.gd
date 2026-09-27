extends SkeletonModifier3D
## Lets one forward walk cycle serve every direction: after the animation has posed the
## skeleton, the hips (and so the legs) turn toward the direction of travel by `twist`
## radians, and the spine and chest turn back by half each, so the upper body keeps
## facing the opponent. Rotations are about the skeleton's up axis.

var twist := 0.0


func _process_modification_with_delta(_delta: float) -> void:
	_apply()


func _process_modification() -> void:
	_apply()


func _apply() -> void:
	var sk := get_skeleton()
	if sk == null or absf(twist) < 0.001:
		return
	var hips := sk.find_bone("Hips")
	var spine := sk.find_bone("Spine")
	var chest := sk.find_bone("Chest")
	if hips < 0 or spine < 0 or chest < 0:
		return
	var parent := sk.get_bone_parent(hips)
	var parent_b := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var hips_b := sk.get_bone_global_pose(hips).basis
	var spine_b := sk.get_bone_global_pose(spine).basis
	var chest_b := sk.get_bone_global_pose(chest).basis

	var hips_new := Basis(Vector3.UP, twist) * hips_b
	var spine_new := Basis(Vector3.UP, twist * 0.5) * spine_b
	var chest_new := chest_b
	sk.set_bone_pose_rotation(hips, (parent_b.inverse() * hips_new).get_rotation_quaternion())
	sk.set_bone_pose_rotation(spine, (hips_new.inverse() * spine_new).get_rotation_quaternion())
	sk.set_bone_pose_rotation(chest, (spine_new.inverse() * chest_new).get_rotation_quaternion())
