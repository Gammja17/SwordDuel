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

# Where and when a duel is fought: the light, the haze, the weather. `mods` are added to the
# player's boon effects (boons.gd keys); `torch` multiplies the torches' light.
const PLACES := {
	"dusk": {"name": "해질녘의 연무장", "sun": Color(1.0, 0.80, 0.60), "sun_e": 1.25, "fog": Color(0.62, 0.55, 0.50),
		"fog_d": 0.008, "amb": 1.1, "bg": 1.0, "torch": 1.0, "note": ""},
	"dawn": {"name": "새벽 연무장", "sun": Color(0.78, 0.86, 1.0), "sun_e": 0.9, "fog": Color(0.66, 0.72, 0.82),
		"fog_d": 0.016, "amb": 0.9, "bg": 0.8, "torch": 1.2, "note": "안개가 옅게 깔려 있습니다."},
	"rain": {"name": "비 내리는 연무장", "sun": Color(0.65, 0.70, 0.80), "sun_e": 0.6, "fog": Color(0.45, 0.50, 0.55),
		"fog_d": 0.020, "amb": 0.7, "bg": 0.5, "torch": 1.2, "rain": true, "mods": {"breath": -0.25},
		"note": "젖은 바닥에서 숨이 늦게 찹니다."},
	"night": {"name": "밤의 연무장", "sun": Color(0.40, 0.50, 0.85), "sun_e": 0.25, "fog": Color(0.08, 0.09, 0.14),
		"fog_d": 0.018, "amb": 0.25, "bg": 0.15, "torch": 2.2, "note": "횃불에 의지해 싸웁니다. 칼이 잘 보이지 않습니다."},
	"overcast": {"name": "흐린 한낮의 연무장", "sun": Color(0.92, 0.92, 0.95), "sun_e": 1.0, "fog": Color(0.70, 0.70, 0.72),
		"fog_d": 0.006, "amb": 1.2, "bg": 1.0, "torch": 0.6, "note": "구경하는 학생들이 담장 위에 모였습니다."},
	"war": {"name": "불타는 연무장", "sun": Color(1.0, 0.42, 0.22), "sun_e": 0.7, "fog": Color(0.30, 0.15, 0.11),
		"fog_d": 0.024, "amb": 0.6, "bg": 0.45, "torch": 1.6, "note": "북방군이 성문을 넘었습니다."},
}

# kicker (card header), the fighter's own values, the rank band it is worth (from -> to,
# 0 = none), cutscenes before and after.
const STAGES := [
	{"kicker": "순위전 · 30위 → 25위", "name": "평민 공훈생 태산",
		"about": "같은 공훈생. 느리고 크게 휘두르지만 칼이 맞물리면 힘이 셉니다.",
		"fighter": {"hp": 80.0, "windup": 0.58, "attack": 0.27, "recover": 0.7, "poise": Vector2(0.9, 1.6),
			"lines": ["c", "a"], "dodge": 0.0, "feint": 0.0, "combo": 0.0, "riposte": 0.1, "parry": 0.15,
			"bind_press": 0.5, "bind_strength": 0.95, "armor": 1.0, "speed": 2.3, "outfit": "taesan"},
		"place": "dusk", "rank": [30, 25], "barks": {"start": ["태산: 덤벼라, 꼴찌.", "태산: 한 칸이 제일 비싸다."], "retry": ["태산: 또 왔나. 끈질기군.", "태산: 쓰러진 자리에서 일어나는 건 인정하지."], "parried": ["태산: ……제법인데.", "태산: 이 맛이군."]},
		"pre": ["taesan_pre"], "post": ["taesan_post"]},
	# --- 연전: a room of weak fighters taken one after another. Health carries over. ---
	{"kicker": "연전 · 수련장", "name": "수련장 연습병 무리",
		"about": "연습병 셋이 차례로 덤빕니다. 하나하나는 약하지만 체력은 이어지니 아껴 싸우세요.",
		"fighter": {}, "rank": [0, 0], "place": "dusk", "pre": [], "post": [],
		"barks": {"start": ["연습병: 차례로 간다!", "연습병: 꼴찌는 우리 몫이지!"], "retry": ["연습병: 또 왔네!", "연습병: 이번엔 셋 다 넘겨 보시지!"], "parried": ["연습병: 으악!", "연습병: 막았어?!"]},
		"wave": [
			{"name": "연습병 갑", "hp": 36.0, "windup": 0.56, "attack": 0.24, "recover": 0.6, "poise": Vector2(0.8, 1.5), "lines": ["c"],
				"dodge": 0.0, "feint": 0.0, "combo": 0.0, "riposte": 0.0, "parry": 0.0, "punish": 0.1, "damage": 0.5, "armor": 0.3, "speed": 2.3, "outfit": "recruit"},
			{"name": "연습병 을", "hp": 40.0, "windup": 0.5, "attack": 0.22, "recover": 0.55, "poise": Vector2(0.6, 1.2), "lines": ["a", "b"],
				"dodge": 0.0, "feint": 0.0, "combo": 0.0, "riposte": 0.1, "parry": 0.05, "punish": 0.2, "damage": 0.5, "armor": 0.4, "speed": 2.5, "outfit": "recruit"},
			{"name": "연습병 병", "hp": 46.0, "windup": 0.46, "attack": 0.22, "recover": 0.5, "poise": Vector2(0.5, 1.0), "lines": ["a", "b", "c"],
				"dodge": 0.05, "feint": 0.1, "combo": 0.1, "riposte": 0.15, "parry": 0.1, "punish": 0.3, "damage": 0.55, "armor": 0.6, "speed": 2.6, "outfit": "recruit"},
		]},
	{"kicker": "순위전 · 25위 → 18위", "name": "하급 귀족 레온",
		"about": "속임수를 많이 씁니다. 치켜든 쪽을 바꾸고, 쳐내기를 자주 시도합니다.",
		"fighter": {"hp": 80.0, "windup": 0.42, "attack": 0.21, "feint": 0.6, "parry": 0.4, "dodge": 0.2,
			"lines": ["a", "b"], "poise": Vector2(0.4, 1.0), "speed": 2.7, "armor": 1.0, "outfit": "leon"},
		"place": "dawn", "rank": [25, 18], "barks": {"start": ["레온: 규칙대로! 규칙대로!", "레온: 사, 살살 부탁해!"], "retry": ["레온: 또 이겨 줄게!", "레온: 이번엔 진짜 이길 수도 있어!"], "parried": ["레온: 아악, 그건 반칙!", "레온: 알고 있었어! 일부러야!"]},
		"pre": ["leon_pre"], "post": ["leon_post"]},
	{"kicker": "순위전 · 18위 → 10위", "name": "기사 서혁",
		"about": "좌우로 번갈아 베고, 가끔 치켜든 쪽을 바꿔 속입니다. 함부로 휘두르면 받아칩니다.",
		"fighter": {"outfit": "knight"},
		"place": "rain", "rank": [18, 10], "barks": {"start": ["서혁: 정정당당히.", "서혁: 빗길을 조심하게."], "retry": ["서혁: 다시 서게. 예를 갖추겠네.", "서혁: 졌다고 부끄러워 말게."], "parried": ["서혁: ……좋은 수다.", "서혁: 읽혔군."]},
		"pre": ["report", "mujin_train", "seohyuk_pre"], "post": ["seohyuk_post"]},
	{"kicker": "연전 · 귀족가 호위병", "name": "귀족가 호위병 둘",
		"about": "귀족 자제를 따라온 호위병 둘이 길을 막습니다. 갑옷이 단단하고 노련합니다.",
		"fighter": {}, "rank": [0, 0], "place": "rain", "pre": [], "post": [],
		"barks": {"start": ["호위병: 도련님께 가까이 오지 마라.", "호위병: 평민은 비켜라."], "retry": ["호위병: 또 나타났군.", "호위병: 질기구나."], "parried": ["호위병: 이놈!", "호위병: 감히!"]},
		"wave": [
			{"name": "호위병 갑", "hp": 58.0, "windup": 0.44, "attack": 0.21, "recover": 0.5, "poise": Vector2(0.5, 1.0), "lines": ["a", "b", "c"],
				"dodge": 0.1, "feint": 0.15, "combo": 0.15, "riposte": 0.25, "parry": 0.2, "punish": 0.4, "damage": 0.6, "armor": 1.6, "speed": 2.6, "outfit": "guard"},
			{"name": "호위병 을", "hp": 66.0, "windup": 0.42, "attack": 0.2, "recover": 0.48, "poise": Vector2(0.45, 0.9), "lines": ["a", "b", "c", "lunge"],
				"dodge": 0.15, "feint": 0.2, "combo": 0.2, "riposte": 0.3, "parry": 0.25, "punish": 0.5, "damage": 0.65, "armor": 2.0, "speed": 2.7, "outfit": "guard"},
		]},
	{"kicker": "순위전 · 10위 → 3위", "name": "대귀족 영애 세라핀",
		"about": "빠르고 정확합니다. 찌르기로 거리를 깨고 들어오며, 물러나면 쫓아옵니다.",
		"fighter": {"hp": 95.0, "windup": 0.40, "attack": 0.19, "lines": ["lunge", "a", "b"], "dodge": 0.3,
			"parry": 0.35, "combo": 0.3, "speed": 3.0, "armor": 1.5, "outfit": "woman_ranger"},
		"place": "night", "rank": [10, 3], "barks": {"start": ["세라핀: 숨 쉴 틈은 없을 거야.", "세라핀: 지켜보는 눈이 많아."], "retry": ["세라핀: 또? 질기네.", "세라핀: 같은 실수는 두 번 안 봐줘."], "parried": ["세라핀: 흥, 우연이야.", "세라핀: ……제법."]},
		"pre": ["serafin_pre"], "post": ["serafin_post"]},
	{"kicker": "순위전 · 3위 → 1위", "name": "공작가 공자 카이든",
		"about": "천재입니다. 칼이 내려오면 쳐내고 곧바로 반격합니다. 정직하게 휘두르면 읽힙니다.",
		"fighter": {"hp": 120.0, "windup": 0.40, "attack": 0.19, "recover": 0.45, "stagger": 0.55,
			"poise": Vector2(0.45, 1.0), "attack_prob": 0.8, "lines": ["a", "b", "c", "lunge"], "dodge": 0.25,
			"parry_window": 0.14, "windup_jitter": 0.2, "feint": 0.35, "combo": 0.35, "punish": 0.7, "riposte": 0.5,
			"damage": 0.72, "armor": 3.0, "flinch_speed": 11.0, "parry": 0.45, "bind_press": 0.5, "bind_strength": 0.8,
			"bind_switch": Vector2(1.3, 2.2), "exit_cut": 0.7, "guard_track": 12.0, "speed": 2.8, "outfit": "kaiden"},
		"place": "overcast", "rank": [3, 1], "barks": {"start": ["카이든: 수석은 내 것이다.", "카이든: 무릎 꿇을 준비는 됐나."], "retry": ["카이든: 또 쓰러지러 왔나.", "카이든: 평민의 끈기는 인정하지."], "parried": ["카이든: 이럴 리가!", "카이든: 우연이다!"]},
		"pre": ["kaiden_pre"], "post": ["kaiden_post"]},
	{"kicker": "전쟁 · 북문", "name": "북방 병사",
		"about": "북방군 병사입니다. 갑옷이 단단해 얕게 베어서는 통하지 않습니다.",
		"fighter": {"hp": 90.0, "armor": 3.5, "lines": ["a", "b", "c"], "feint": 0.1, "outfit": "",
			"tabard": Color(0.12, 0.14, 0.30)},
		"rank": [0, 0], "barks": {"start": ["북방 병사: 학생이잖아!", "북방 병사: 한 놈 더다!"], "retry": ["북방 병사: 또 일어났다!", "북방 병사: 끈질긴 애송이!"], "parried": ["북방 병사: 윽!", "북방 병사: 막았다고?"]},
		"pre": ["war_bell"], "post": [], "place": "war", "war": true},
	{"kicker": "전쟁 · 연무장", "name": "북방 정예병",
		"about": "정예병입니다. 빠른 연속 베기와 찌르기를 섞습니다.",
		"fighter": {"hp": 105.0, "armor": 4.0, "windup": 0.40, "attack": 0.20, "lines": ["a", "b", "c", "lunge"],
			"combo": 0.35, "parry": 0.4, "speed": 2.8, "outfit": "", "tabard": Color(0.12, 0.14, 0.30), "crest": true},
		"rank": [0, 0], "barks": {"start": ["정예병: 애송이가 길을 막는군.", "정예병: 이 문은 우리 것이다."], "retry": ["정예병: 아직 살아 있었나.", "정예병: 이번엔 끝내 주마."], "parried": ["정예병: 제법이군.", "정예병: 눈이 좋군."]},
		"pre": ["war_mujin"], "post": [], "place": "war", "war": true},
	{"kicker": "졸업시험 · 적장", "name": "북방 적장 발도르",
		"about": "중장갑을 두른 노장입니다. 갑옷이 두꺼워 쳐내기와 힘싸움으로 흔들어야 합니다. 칼이 무겁고 느립니다.",
		"fighter": {"hp": 260.0, "armor": 5.5, "windup": 0.50, "attack": 0.24, "recover": 0.5, "stagger": 0.5,
			"lines": ["a", "b", "c", "lunge"], "combo": 0.4, "parry": 0.5, "riposte": 0.5, "punish": 0.6,
			"damage": 0.9, "flinch_speed": 15.0, "bind_press": 0.6, "bind_strength": 1.0, "guard_track": 10.0,
			"speed": 2.4, "outfit": "", "tabard": Color(0.10, 0.10, 0.28), "crest": true, "yields": true,
			# At half health the plate breaks off: lighter, faster, and it never stops.
			"phase2_at": 0.5, "phase2": {"armor": 1.5, "windup": 0.34, "attack": 0.17, "recover": 0.38,
				"stagger": 0.45, "speed": 3.4, "combo": 0.6, "feint": 0.3, "damage": 1.0, "flinch_speed": 10.0,
				"poise": Vector2(0.3, 0.8)}},
		"rank": [0, 0], "barks": {"start": ["발도르: 칼에게 물어보아라.", "발도르: 네 아비와 같은 눈이군."], "retry": ["발도르: 일어나라. 네 아비도 그랬다.", "발도르: 아직 묻고 싶은 것이 남았나."], "parried": ["발도르: ……좋다.", "발도르: 그 손놀림, 어디서 봤더라."]},
		"pre": ["baldor_pre"], "post": [], "place": "war", "war": true},
]


# Bought in the dormitory's training hall with 수련 점수, kept across runs. `mods` are per level.
const UPGRADES := [
	{"id": "body", "name": "단련된 몸", "max": 3, "base": 30, "text": "받는 피해가 단계마다 4% 줄어듭니다.",
		"mods": {"damage_taken": -0.04}},
	{"id": "lungs", "name": "깊은 숨", "max": 3, "base": 30, "text": "숨이 단계마다 12% 빨리 찹니다.",
		"mods": {"breath": 0.12}},
	{"id": "eye", "name": "쳐내기 감각", "max": 3, "base": 40, "text": "쳐내기 받아낼 시간이 단계마다 0.02초 늘어납니다.",
		"mods": {"parry_window": 0.02}},
	{"id": "edge", "name": "칼 수련", "max": 3, "base": 40, "text": "베기 위력이 단계마다 4% 세집니다.",
		"mods": {"cut_power": 0.04}},
	{"id": "gift", "name": "스승의 선물", "max": 1, "base": 80, "text": "학기를 시작할 때 고른 유파의 기예 하나를 이미 익힌 채로 시작합니다.",
		"mods": {}},
]

# Said in the dormitory yard. `min`: the best stage reached so far; `flag`/`val`: a choice made.
const HUB_TALKS := [
	{"min": 0, "who": "도윤", "text": "첫 학기는 누구나 꼴찌에서 시작하네. 쓰러져도 부끄러운 일이 아니야. 일어나게."},
	{"min": 0, "who": "무진", "text": "공훈생은 살아남는 법부터 배운다. 쓰러진 날이 가장 많이 배우는 날이다."},
	{"min": 1, "who": "태산", "text": "한 칸 올랐다고 으스대지 마라. 한 칸이 제일 비싸다고 했잖아."},
	{"min": 2, "who": "레온", "text": "서혁이 네 얘기를 하더라. 칼이 이상하게 무겁다나. 칭찬이야, 아마."},
	{"min": 3, "who": "무진", "text": "네 칼이 이기는 법을 묻기 시작했군. 좋은 징조다. 위험한 징조이기도 하고."},
	{"min": 4, "who": "세라핀", "text": "카이든이 한밤에 혼자 칼을 휘두르는 걸 봤어. 너 때문이야. ……그 애가 그러는 건 처음 봐."},
	{"min": 5, "who": "도윤", "text": "북쪽에서 전쟁이 곧이라는 소문이 돌아. 졸업시험이 열리긴 할까."},
	{"min": 0, "who": "도윤", "text": "……나를 아직 믿지 못하겠지. 그래도 괜찮네. 칼로 갚을 날을 기다리겠네.", "flag": "doyun_trust", "val": 1},
	{"min": 0, "who": "도윤", "text": "자네가 나를 용서해 줘서 이 학교가 덜 춥네. 고맙네.", "flag": "doyun_trust", "val": 0},
]


static func upgrade_cost(u: Dictionary, level: int) -> int:
	if level >= int(u["max"]):
		return -1
	return int(u["base"]) * (level + 1)


static func count() -> int:
	return STAGES.size()


## The full opponent dictionary for a stage: base numbers, then its own, then the card text.
static func tier(i: int, k := 0) -> Dictionary:
	var s: Dictionary = STAGES[i]
	var t: Dictionary = BASE.duplicate()
	t.merge(s["fighter"], true)
	if s.has("wave"):
		t.merge(s["wave"][k], true)   # a wave room: the k-th fighter
	t["kicker"] = s["kicker"]
	t["name"] = (s["name"] as String) if not s.has("wave") else String(s["wave"][k]["name"])
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


static func place_of(i: int) -> Dictionary:
	return PLACES[STAGES[i].get("place", "dusk")]
