extends RefCounted
## 전직: how the player carries a sword, picked at the start of every term. It shapes the base
## numbers, what is held in the left hand, and gives one move of its own (the Q key).
## It sits under the school (유파, schools.gd) and the techniques (기예, boons.gd).

const ORDER := ["two", "one", "shield"]

const ALL := {
	"two": {
		"name": "양손검", "tag": "한 방이 묵직하다",
		"text": "위력이 높고 휘두르기가 조금 느리다.",
		"ability": "내려찍기",
		"ability_text": "Q 내려찍기 — 위력 1.7배 (숨 20 · 7초)",
		"mods": {"cut_power": 0.10, "swing_speed": -0.05},
		"cooldown": 7.0,
	},
	"one": {
		"name": "한손검", "tag": "빠르고 파고든다",
		"text": "빠르고 가볍다. 위력은 낮다.",
		"ability": "돌진 찌르기",
		"ability_text": "Q 돌진 찌르기 — 거리를 단숨에 좁힘 (숨 20 · 5초)",
		"mods": {"swing_speed": 0.12, "move_speed": 0.06, "dodge_i": 0.03, "cut_power": -0.08},
		"cooldown": 5.0,
	},
	"shield": {
		"name": "한손검과 방패", "tag": "버티고 밀어낸다",
		"text": "막기가 단단하고 덜 맞는다. 위력은 낮다.",
		"ability": "방패 밀치기",
		"ability_text": "Q 방패 밀치기 — 상대를 비틀거리게 함 (숨 20 · 7초)",
		"mods": {"parry_window": 0.03, "block_posture": -0.30, "damage_taken": -0.06, "cut_power": -0.10, "parry_heal": 2.0},
		"cooldown": 7.0,
	},
}


static func mods_for(kit: String) -> Dictionary:
	if ALL.has(kit):
		return ALL[kit]["mods"]
	return {}
