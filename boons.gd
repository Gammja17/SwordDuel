extends RefCounted
## 기예: techniques the school's masters teach between duels. Each one bends a rule of the
## fight a little. Picked three at a time (one is kept), they add up over the story.
## `mods` are read by player.gd (mod("key")), sword.gd, opponent.gd and main.gd.

const ALL := [
	{"id": "eye", "name": "날카로운 눈", "text": "쳐내기를 받아낼 수 있는 시간이 0.05초 늘어납니다.",
		"mods": {"parry_window": 0.05}},
	{"id": "riposte_breath", "name": "반격의 숨", "text": "쳐내기에 성공하면 체력을 8 회복합니다.",
		"mods": {"parry_heal": 8.0}},
	{"id": "opening", "name": "무너진 자세", "text": "쳐낸 뒤 치명타를 넣을 수 있는 시간이 0.8초 늘어납니다.",
		"mods": {"crit_time": 0.8}},
	{"id": "hunter", "name": "사냥꾼의 눈", "text": "상대 체력이 10% 더 남았을 때부터 처형할 수 있습니다.",
		"mods": {"execute": 0.10}},
	{"id": "light_feet", "name": "가벼운 발", "text": "구르기로 맞지 않는 시간이 0.08초 늘어납니다.",
		"mods": {"dodge_i": 0.08}},
	{"id": "lungs", "name": "강인한 폐", "text": "숨이 40% 빨리 찹니다.",
		"mods": {"breath": 0.4}},
	{"id": "heavy", "name": "무거운 칼", "text": "베기의 위력이 15% 세집니다.",
		"mods": {"cut_power": 0.15}},
	{"id": "stance", "name": "굳센 자세", "text": "막을 때 자세 게이지가 20% 덜 찹니다.",
		"mods": {"block_posture": -0.2}},
]


static func get_boon(id: String) -> Dictionary:
	for b in ALL:
		if b["id"] == id:
			return b
	return {}


## `n` boons the player doesn't have yet, picked at random.
static func roll(owned: Array, n := 3) -> Array:
	var pool := ALL.filter(func(b): return not owned.has(b["id"]))
	pool.shuffle()
	return pool.slice(0, n)


## All the owned boons' effects added up.
static func mods_of(owned: Array) -> Dictionary:
	var sum := {}
	for id in owned:
		var b := get_boon(id)
		for k in b.get("mods", {}):
			sum[k] = float(sum.get(k, 0.0)) + float(b["mods"][k])
	return sum
