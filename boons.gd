extends RefCounted
## 기예: techniques the school's masters teach between duels. Each one bends a rule of the
## fight a little. Picked three at a time (one is kept), they add up over the story.
## `mods` are read by player.gd (mod("key")), sword.gd, opponent.gd and main.gd.

const MAX_SLOTS := 4   # only this many techniques can be carried; a new one pushes another out

# `rare` ones are stronger and always cost something (their text says what).
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
	{"id": "instinct", "name": "예리한 직감", "text": "쳐내기 받아낼 시간 +0.08초. 대신 숨이 20% 늦게 찹니다.",
		"mods": {"parry_window": 0.08, "breath": -0.2}},
	{"id": "tireless", "name": "쉬지 않는 칼", "text": "베기에 드는 숨이 절반입니다. 대신 받는 피해 +10%.",
		"mods": {"cut_cost": -0.5, "damage_taken": 0.10}},
	{"id": "bulwark", "name": "철벽", "text": "막을 때 자세 게이지가 절반만 찹니다. 대신 베기 위력 -10%.",
		"mods": {"block_posture": -0.5, "cut_power": -0.10}},
	{"id": "roller", "name": "굴러 피하는 자", "text": "구르기 무적 +0.15초. 대신 받는 피해 +10%.",
		"mods": {"dodge_i": 0.15, "damage_taken": 0.10}},
	{"id": "calm", "name": "고요한 마음", "text": "자세 게이지가 80% 빨리 회복됩니다. 대신 베기 위력 -8%.",
		"mods": {"posture_recover": 0.8, "cut_power": -0.08}},
	{"id": "thin_blade", "name": "얇은 날", "text": "쳐내기 시간 +0.04초, 베기 위력 +8%. 대신 막을 때 자세가 25% 더 찹니다.",
		"mods": {"parry_window": 0.04, "cut_power": 0.08, "block_posture": 0.25}},
	{"id": "conditioned", "name": "단련된 몸", "text": "받는 피해 -12%. 대신 숨이 15% 늦게 찹니다.",
		"mods": {"damage_taken": -0.12, "breath": -0.15}},
	{"id": "berserker", "name": "광전사", "text": "베기 위력 +30%. 대신 받는 피해 +30%.",
		"mods": {"cut_power": 0.30, "damage_taken": 0.30}, "rare": true},
	{"id": "shield_way", "name": "방패의 길", "text": "받는 피해 -25%. 대신 베기 위력 -15%.",
		"mods": {"damage_taken": -0.25, "cut_power": -0.15}, "rare": true},
	{"id": "patience", "name": "사냥꾼의 인내", "text": "처형 문턱 +20%, 치명타 시간 +0.5초. 대신 쳐내기 시간 -0.04초.",
		"mods": {"execute": 0.20, "crit_time": 0.5, "parry_window": -0.04}, "rare": true},
	{"id": "second_wind", "name": "회복의 호흡", "text": "쳐내면 체력 14 회복. 대신 받는 피해 +15%.",
		"mods": {"parry_heal": 14.0, "damage_taken": 0.15}, "rare": true},
	{"id": "blood_oath", "name": "피의 맹세", "text": "베기 위력 +25%. 대신 쳐낼 때마다 체력 4를 잃습니다.",
		"mods": {"cut_power": 0.25, "parry_heal": -4.0}, "rare": true},
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
