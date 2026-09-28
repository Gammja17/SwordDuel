extends SkeletonModifier3D
## Turns and leans the upper body after the animation: `yaw` radians about the up axis
## (+ toward its left) and `lean` radians forward, spread over the spine, chest and
## upper chest. The neck and head turn most of the way back, so it keeps looking at its
## opponent. The model faces +Z in skeleton space, so leaning forward tips toward +Z.

const CHAIN := ["Spine", "Chest", "UpperChest"]
const HEAD := ["Neck", "Head"]

var yaw := 0.0
var lean := 0.0


func _process_modification_with_delta(_delta: float) -> void:
	_apply()


func _process_modification() -> void:
	_apply()


func _apply() -> void:
	var sk := get_skeleton()
	if sk == null or (absf(yaw) < 0.001 and absf(lean) < 0.001):
		return
	var bones: Array[int] = []
	for b in CHAIN + HEAD:
		var i := sk.find_bone(b)
		if i < 0:
			return
		bones.append(i)
	var step := Basis(Vector3.UP, yaw / 3.0) * Basis(Vector3.RIGHT, lean / 3.0)
	var back := Basis(Vector3.UP, -yaw * 0.35) * Basis(Vector3.RIGHT, -lean * 0.3)
	# Old global rotations first; then each bone's new global is the turn so far times
	# its old one, and its local pose follows from its (new) parent.
	var old: Array[Basis] = []
	for i in bones:
		old.append(sk.get_bone_global_pose(i).basis)
	var parent := sk.get_bone_parent(bones[0])
	var parent_new := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var turn := Basis.IDENTITY
	for k in bones.size():
		turn = (step if k < CHAIN.size() else back) * turn
		var new_b := turn * old[k]
		sk.set_bone_pose_rotation(bones[k], (parent_new.inverse() * new_b).get_rotation_quaternion())
		parent_new = new_b
