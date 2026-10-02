extends RefCounted
## The story's run of duels: who you face, their numbers, the rank you hold, and which
## cutscenes play before and after each one (scenes.gd). main.gd walks through STAGES.

const START_RANK := 30
const TOP_RANK := 1

# A middling fighter; each opponent below overrides what makes them themselves.
const BASE := {
	"hp": 85.0, "windup": 0.46, "attack": 0.23, "recover": 0.6, "stagger": 0.7,
	"poise": Vector2(0.6, 1.3), "attack_prob": 0.7, "lines": ["a", "b", "c"], "dodge": 0.15, "parry_window": 0.18,
	"windup_jitter": 0.15, "feint": 0.25, "combo": 0.15, "punish": 0.4, "riposte": 0.3, "damage": 0.65,
	"armor": 2.0, "flinch_speed": 9.0, "parry": 0.3, "bind_press": 0.35, "bind_strength": 0.6,
	"bind_switch": Vector2(1.7, 2.7), "exit_cut": 0.45, "guard_track": 7.0, "speed": 2.5,
	"tabard": Color(0.55, 0.12, 0.10), "crest": false, "outfit": "knight",
}

# kicker (card header), the fighter's own values, the rank band it is worth (from -> to,
# 0 = none), cutscenes before and after.
const STAGES := [
	{"kicker": "순위전 · 30위 → 25위", "name": "평민 공훈생 태산",
		"about": "같은 공훈생. 느리고 크게 휘두르지만 칼이 맞물리면 힘이 셉니다.",
		"fighter": {"hp": 80.0, "windup": 0.58, "attack": 0.27, "recover": 0.7, "poise": Vector2(0.9, 1.6),
			"lines": ["c", "a"], "dodge": 0.0, "feint": 0.0, "combo": 0.0, "riposte": 0.1, "parry": 0.15,
			"bind_press": 0.5, "bind_strength": 0.95, "armor": 1.0, "speed": 2.3, "outfit": "taesan"},
		"rank": [30, 25], "pre": ["taesan_pre"], "post": ["taesan_post"]},
	{"kicker": "순위전 · 25위 → 18위", "name": "하급 귀족 레온",
		"about": "속임수를 많이 씁니다. 치켜든 쪽을 바꾸고, 쳐내기를 자주 시도합니다.",
		"fighter": {"hp": 80.0, "windup": 0.42, "attack": 0.21, "feint": 0.6, "parry": 0.4, "dodge": 0.2,
			"lines": ["a", "b"], "poise": Vector2(0.4, 1.0), "speed": 2.7, "armor": 1.0, "outfit": "leon"},
		"rank": [25, 18], "pre": ["leon_pre"], "post": ["leon_post"]},
	{"kicker": "순위전 · 18위 → 10위", "name": "기사 서혁",
		"about": "좌우로 번갈아 베고, 가끔 치켜든 쪽을 바꿔 속입니다. 함부로 휘두르면 받아칩니다.",
		"fighter": {"outfit": "knight"},
		"rank": [18, 10], "pre": ["report", "mujin_train", "seohyuk_pre"], "post": ["seohyuk_post"]},
	{"kicker": "순위전 · 10위 → 3위", "name": "대귀족 영애 세라핀",
		"about": "빠르고 정확합니다. 찌르기로 거리를 깨고 들어오며, 물러나면 쫓아옵니다.",
		"fighter": {"hp": 95.0, "windup": 0.40, "attack": 0.19, "lines": ["lunge", "a", "b"], "dodge": 0.3,
			"parry": 0.35, "combo": 0.3, "speed": 3.0, "armor": 1.5, "outfit": "woman_ranger"},
		"rank": [10, 3], "pre": ["serafin_pre"], "post": ["serafin_post"]},
	{"kicker": "순위전 · 3위 → 1위", "name": "공작가 공자 카이든",
		"about": "천재입니다. 칼이 내려오면 쳐내고 곧바로 반격합니다. 정직하게 휘두르면 읽힙니다.",
		"fighter": {"hp": 120.0, "windup": 0.40, "attack": 0.19, "recover": 0.45, "stagger": 0.55,
			"poise": Vector2(0.45, 1.0), "attack_prob": 0.8, "lines": ["a", "b", "c", "lunge"], "dodge": 0.25,
			"parry_window": 0.14, "windup_jitter": 0.2, "feint": 0.35, "combo": 0.35, "punish": 0.7, "riposte": 0.5,
			"damage": 0.72, "armor": 3.0, "flinch_speed": 11.0, "parry": 0.45, "bind_press": 0.5, "bind_strength": 0.8,
			"bind_switch": Vector2(1.3, 2.2), "exit_cut": 0.7, "guard_track": 12.0, "speed": 2.8, "outfit": "kaiden"},
		"rank": [3, 1], "pre": ["kaiden_pre"], "post": ["kaiden_post"]},
	{"kicker": "전쟁 · 북문", "name": "북방 병사",
		"about": "북방군 병사입니다. 갑옷이 단단해 얕게 베어서는 통하지 않습니다.",
		"fighter": {"hp": 90.0, "armor": 3.5, "lines": ["a", "b", "c"], "feint": 0.1, "outfit": "",
			"tabard": Color(0.12, 0.14, 0.30)},
		"rank": [0, 0], "pre": ["war_bell"], "post": [], "war": true},
	{"kicker": "전쟁 · 연무장", "name": "북방 정예병",
		"about": "정예병입니다. 빠른 연속 베기와 찌르기를 섞습니다.",
		"fighter": {"hp": 105.0, "armor": 4.0, "windup": 0.40, "attack": 0.20, "lines": ["a", "b", "c", "lunge"],
			"combo": 0.35, "parry": 0.4, "speed": 2.8, "outfit": "", "tabard": Color(0.12, 0.14, 0.30), "crest": true},
		"rank": [0, 0], "pre": ["war_mujin"], "post": [], "war": true},
	{"kicker": "졸업시험 · 적장", "name": "북방 적장 발도르",
		"about": "중장갑을 두른 노장입니다. 갑옷이 두꺼워 쳐내기와 힘싸움으로 흔들어야 합니다. 칼이 무겁고 느립니다.",
		"fighter": {"hp": 260.0, "armor": 5.5, "windup": 0.50, "attack": 0.24, "recover": 0.5, "stagger": 0.5,
			"lines": ["a", "b", "c", "lunge"], "combo": 0.4, "parry": 0.5, "riposte": 0.5, "punish": 0.6,
			"damage": 0.9, "flinch_speed": 15.0, "bind_press": 0.6, "bind_strength": 1.0, "guard_track": 10.0,
			"speed": 2.4, "outfit": "", "tabard": Color(0.10, 0.10, 0.28), "crest": true,
			# At half health the plate breaks off: lighter, faster, and it never stops.
			"phase2_at": 0.5, "phase2": {"armor": 1.5, "windup": 0.34, "attack": 0.17, "recover": 0.38,
				"stagger": 0.45, "speed": 3.4, "combo": 0.6, "feint": 0.3, "damage": 1.0, "flinch_speed": 10.0,
				"poise": Vector2(0.3, 0.8)}},
		"rank": [0, 0], "pre": ["baldor_pre"], "post": [], "war": true},
]


static func count() -> int:
	return STAGES.size()


## The full opponent dictionary for a stage: base numbers, then its own, then the card text.
static func tier(i: int) -> Dictionary:
	var s: Dictionary = STAGES[i]
	var t: Dictionary = BASE.duplicate()
	t.merge(s["fighter"], true)
	t["kicker"] = s["kicker"]
	t["name"] = (s["name"] as String)
	t["about"] = s["about"]
	return t


## The rank you hold after winning stage i.
static func rank_after_win(i: int, current: int) -> int:
	var band: Array = STAGES[i]["rank"]
	return band[1] if band[1] > 0 else current


## The rank after losing stage i: one place down each time, down to four below where the stage started.
static func rank_after_loss(i: int, current: int) -> int:
	var band: Array = STAGES[i]["rank"]
	if band[0] == 0:
		return current
	return mini(mini(current + 1, band[0] + 4), START_RANK)
