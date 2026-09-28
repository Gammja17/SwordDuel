extends SkeletonModifier3D
## Runs after the arm IK: turns each hand to match its place on the sword's grip, so
## the fists close around the handle the way the blade is held instead of keeping
## whatever angle the animation gave the wrists.

var right_target: Node3D   # the right wrist's place on the sword
var left_target: Node3D


func _process_modification_with_delta(_delta: float) -> void:
	_apply()


func _process_modification() -> void:
	_apply()


func _apply() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var inv := sk.global_transform.basis.orthonormalized().inverse()
	for pair in [["RightHand", right_target], ["LeftHand", left_target]]:
		var t := pair[1] as Node3D
		var bone := sk.find_bone(pair[0])
		if t == null or bone < 0 or not t.is_inside_tree():
			continue
		var want := inv * t.global_transform.basis.orthonormalized()
		var parent := sk.get_bone_parent(bone)
		var parent_b := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var local_want := (parent_b.orthonormalized().inverse() * want).get_rotation_quaternion()
		sk.set_bone_pose_rotation(bone, local_want)
