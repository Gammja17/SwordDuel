extends RefCounted
## 기예: techniques the school's masters teach between duels. Each one bends a rule of the
## fight, and most cost something. Carried at most MAX_SLOTS at a time. Each belongs to a
## school (유파, see schools.gd) or to none; a build that leans on one school resonates.
## `mods` are read by player.gd (mod("key")), sword.gd, opponent.gd and main.gd.

const MAX_SLOTS := 4   # only this many techniques can be carried; a new one pushes another out
const MAX_LEVEL := 2   # training (수련) makes one stronger, once

# `rare` ones are stronger and always cost something (their text says what).
const ALL := [
	# --- 중검 (heavy, slow, strong) ---
	{"id": "heavy", "school": "heavy", "name": "무거운 칼", "text": "베기의 위력이 15% 세집니다.",
		"mods": {"cut_power": 0.15}},
	{"id": "mountain", "school": "heavy", "name": "산을 베는 칼", "text": "베기 위력 +20%. 대신 휘두르기가 15% 느려집니다.",
		"mods": {"cut_power": 0.20, "swing_speed": -0.15}},
	{"id": "stand_firm", "school": "heavy", "name": "버티는 몸", "text": "받는 피해 -20%. 대신 걸음이 8% 느려집니다.",
		"mods": {"damage_taken": -0.20, "move_speed": -0.08}},
	{"id": "smash", "school": "heavy", "name": "내려찍기", "text": "치명타 시간 +0.6초. 대신 휘두르기가 10% 느려집니다.",
		"mods": {"crit_time": 0.6, "swing_speed": -0.10}},
	{"id": "hunter", "school": "heavy", "name": "사냥꾼의 눈", "text": "상대 체력이 10% 더 남았을 때부터 처형할 수 있습니다.",
		"mods": {"execute": 0.10}},
	{"id": "conditioned", "school": "heavy", "name": "단련된 몸", "text": "받는 피해 -12%. 대신 숨이 15% 늦게 찹니다.",
		"mods": {"damage_taken": -0.12, "breath": -0.15}},
	{"id": "berserker", "school": "heavy", "name": "광전사", "text": "베기 위력 +30%. 대신 받는 피해 +30%.",
		"mods": {"cut_power": 0.30, "damage_taken": 0.30}, "rare": true},
	{"id": "patience", "school": "heavy", "name": "사냥꾼의 인내", "text": "처형 문턱 +20%, 치명타 시간 +0.5초. 대신 쳐내기 시간 -0.04초.",
		"mods": {"execute": 0.20, "crit_time": 0.5, "parry_window": -0.04}, "rare": true},
	{"id": "blood_oath", "school": "heavy", "name": "피의 맹세", "text": "베기 위력 +25%. 대신 쳐낼 때마다 체력 4를 잃습니다.",
		"mods": {"cut_power": 0.25, "parry_heal": -4.0}, "rare": true},
	# --- 쾌검 (swift, light, weak) ---
	{"id": "light_feet", "school": "swift", "name": "가벼운 발", "text": "구르기로 맞지 않는 시간이 0.08초 늘어납니다.",
		"mods": {"dodge_i": 0.08}},
	{"id": "lungs", "school": "swift", "name": "강인한 폐", "text": "숨이 40% 빨리 찹니다.",
		"mods": {"breath": 0.4}},
	{"id": "wind_cut", "school": "swift", "name": "바람 가르기", "text": "휘두르기가 25% 빨라집니다. 대신 베기 위력 -10%.",
		"mods": {"swing_speed": 0.25, "cut_power": -0.10}},
	{"id": "shadow_step", "school": "swift", "name": "그림자 걸음", "text": "걸음 +20%, 구르기 무적 +0.06초. 대신 받는 피해 +10%.",
		"mods": {"move_speed": 0.20, "dodge_i": 0.06, "damage_taken": 0.10}},
	{"id": "flurry", "school": "swift", "name": "연속 베기", "text": "베기 숨 소모 -30%, 휘두르기 +15%. 대신 베기 위력 -10%.",
		"mods": {"cut_cost": -0.30, "swing_speed": 0.15, "cut_power": -0.10}},
	{"id": "tireless", "school": "swift", "name": "쉬지 않는 칼", "text": "베기에 드는 숨이 절반입니다. 대신 받는 피해 +10%.",
		"mods": {"cut_cost": -0.5, "damage_taken": 0.10}},
	{"id": "roller", "school": "swift", "name": "굴러 피하는 자", "text": "구르기 무적 +0.15초. 대신 받는 피해 +10%.",
		"mods": {"dodge_i": 0.15, "damage_taken": 0.10}},
	{"id": "thin_blade", "school": "swift", "name": "얇은 날", "text": "쳐내기 시간 +0.04초, 베기 위력 +8%. 대신 막을 때 자세가 25% 더 찹니다.",
		"mods": {"parry_window": 0.04, "cut_power": 0.08, "block_posture": 0.25}},
	# --- 방어 (guard, wait and counter) ---
	{"id": "eye", "school": "guard", "name": "날카로운 눈", "text": "쳐내기를 받아낼 수 있는 시간이 0.05초 늘어납니다.",
		"mods": {"parry_window": 0.05}},
	{"id": "riposte_breath", "school": "guard", "name": "반격의 숨", "text": "쳐내기에 성공하면 체력을 8 회복합니다.",
		"mods": {"parry_heal": 8.0}},
	{"id": "stance", "school": "guard", "name": "굳센 자세", "text": "막을 때 자세 게이지가 20% 덜 찹니다.",
		"mods": {"block_posture": -0.2}},
	{"id": "counter_hand", "school": "guard", "name": "맞받아치는 손", "text": "쳐내기 시간 +0.06초, 쳐내면 체력 +4. 대신 베기 위력 -5%.",
		"mods": {"parry_window": 0.06, "parry_heal": 4.0, "cut_power": -0.05}},
	{"id": "stiff_arm", "school": "guard", "name": "굳은 팔", "text": "막을 때 자세 게이지 -35%. 대신 걸음이 8% 느려집니다.",
		"mods": {"block_posture": -0.35, "move_speed": -0.08}},
	{"id": "opening", "school": "guard", "name": "무너진 자세", "text": "쳐낸 뒤 치명타를 넣을 수 있는 시간이 0.8초 늘어납니다.",
		"mods": {"crit_time": 0.8}},
	{"id": "instinct", "school": "guard", "name": "예리한 직감", "text": "쳐내기 받아낼 시간 +0.08초. 대신 숨이 20% 늦게 찹니다.",
		"mods": {"parry_window": 0.08, "breath": -0.2}},
	{"id": "bulwark", "school": "guard", "name": "철벽", "text": "막을 때 자세 게이지가 절반만 찹니다. 대신 베기 위력 -10%.",
		"mods": {"block_posture": -0.5, "cut_power": -0.10}},
	{"id": "calm", "school": "guard", "name": "고요한 마음", "text": "자세 게이지가 80% 빨리 회복됩니다. 대신 베기 위력 -8%.",
		"mods": {"posture_recover": 0.8, "cut_power": -0.08}},
	{"id": "shield_way", "school": "guard", "name": "방패의 길", "text": "받는 피해 -25%. 대신 베기 위력 -15%.",
		"mods": {"damage_taken": -0.25, "cut_power": -0.15}, "rare": true},
	{"id": "second_wind", "school": "guard", "name": "회복의 호흡", "text": "쳐내면 체력 14 회복. 대신 받는 피해 +15%.",
		"mods": {"parry_heal": 14.0, "damage_taken": 0.15}, "rare": true},
]


static func get_boon(id: String) -> Dictionary:
	for b in ALL:
		if b["id"] == id:
			return b
	return {}


## `n` boons the player doesn't have yet. When a school is chosen, at least two of the three
## come from it (so a build keeps getting fed), the rest from any school. `rare_only` offers
## only the strong ones (the reward for a duel of vengeance).
static func roll(owned: Array, school := "", n := 3, rare_only := false) -> Array:
	var pool := ALL.filter(func(b): return not owned.has(b["id"]) and (not rare_only or b.get("rare", false)))
	pool.shuffle()
	var picked := []
	if school != "":
		for b in pool:
			if picked.size() >= 2:
				break
			if b["school"] == school:
				picked.append(b)
	for b in pool:
		if picked.size() >= n:
			break
		if not picked.has(b):
			picked.append(b)
	picked.shuffle()
	return picked


## All the owned boons' effects added up; `levels` (id -> 1..MAX_LEVEL) makes trained ones
## half again as strong.
static func mods_of(owned: Array, levels := {}) -> Dictionary:
	var sum := {}
	for id in owned:
		var b := get_boon(id)
		var k := 1.0 + 0.5 * float(int(levels.get(id, 1)) - 1)
		for key in b.get("mods", {}):
			sum[key] = float(sum.get(key, 0.0)) + float(b["mods"][key]) * k
	return sum


## How many owned boons belong to `school`.
static func count_school(owned: Array, school: String) -> int:
	var c := 0
	for id in owned:
		if get_boon(id).get("school", "") == school:
			c += 1
	return c
