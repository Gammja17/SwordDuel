extends RefCounted
## 유파: the way of fighting a run is built around. Picked once, before the first duel. It
## sets a base (slow and strong, quick and weak, or patient), feeds you its techniques
## (boons.gd), and resonates when you hold enough of them.

const ALL := {
	"heavy": {
		"name": "중검", "tag": "느리고 묵직하다",
		"text": "한 번에 크게 벤다. 느리지만 잘 버틴다.",
		"mods": {"swing_speed": -0.30, "cut_power": 0.35, "move_speed": -0.12, "damage_taken": -0.10},
		"res2": {"cut_power": 0.10}, "res3": {"cut_power": 0.15, "damage_taken": -0.10},
		"res_text": "2개: 베기 +10%   3개 이상: 베기 +25%, 받는 피해 -10%",
	},
	"swift": {
		"name": "쾌검", "tag": "빠르고 가볍다",
		"text": "빠르고 숨이 오래 간다. 한 방은 약하다.",
		"mods": {"swing_speed": 0.35, "cut_power": -0.25, "move_speed": 0.15, "dodge_i": 0.04, "damage_taken": 0.15},
		"res2": {"swing_speed": 0.10}, "res3": {"swing_speed": 0.10, "move_speed": 0.10},
		"res_text": "2개: 휘두르기 +10%   3개 이상: 휘두르기 +20%, 걸음 +10%",
	},
	"guard": {
		"name": "방어", "tag": "기다렸다 되받는다",
		"text": "막고 쳐내는 데 능하다. 한번 쳐내면 흐름을 쥔다.",
		"mods": {"parry_window": 0.05, "block_posture": -0.25, "cut_power": -0.12, "parry_heal": 3.0},
		"res2": {"parry_heal": 3.0}, "res3": {"parry_window": 0.04, "block_posture": -0.15},
		"res_text": "2개: 쳐내면 체력 +3   3개 이상: 쳐내기 시간 +0.04초, 막기 자세 -15%",
	},
}

const ORDER := ["heavy", "swift", "guard"]


## The school's base effects plus its resonance for how many of its techniques are held.
static func mods_for(school: String, owned_in_school: int) -> Dictionary:
	if school == "" or not ALL.has(school):
		return {}
	var s: Dictionary = ALL[school]
	var m: Dictionary = (s["mods"] as Dictionary).duplicate()
	for tier in [["res2", 2], ["res3", 3]]:   # the bonuses add up
		if owned_in_school >= int(tier[1]):
			for k in s[tier[0]]:
				m[k] = float(m.get(k, 0.0)) + float(s[tier[0]][k])
	return m
