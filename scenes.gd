extends RefCounted
## Cutscene scripts (data for story_scene.gd). Positions are in the arena: the middle of
## the courtyard is the origin, +Z toward the player's start. Most scenes are two people
## talking (duo), shot over each other's shoulder; ENTRANCE and the endings are staged by hand.

const NAMES := {
	"rian": "리안", "doyun": "도윤", "taesan": "태산", "leon": "레온", "seohyuk": "서혁",
	"serafin": "세라핀", "kaiden": "카이든", "mujin": "무진", "baldor": "발도르", "soldier": "북방 병사",
}
const OUTFITS := {
	"rian": {"outfit": "player"}, "doyun": {"outfit": "squire"}, "taesan": {"outfit": "taesan"},
	"leon": {"outfit": "leon"}, "seohyuk": {"outfit": "knight"}, "serafin": {"outfit": "woman_ranger"},
	"kaiden": {"outfit": "kaiden"}, "mujin": {"outfit": "master"},
	"baldor": {"outfit": "", "tabard": Color(0.10, 0.10, 0.28), "crest": true},
	"soldier": {"outfit": "", "tabard": Color(0.12, 0.14, 0.30), "crest": false},
}

## Day one: Rian walks in, and the squire Doyun shows the new charity student around
## while a noble boy sneers.
const ENTRANCE := {
	"actors": {
		"rian": {"outfit": "player", "at": Vector3(0.0, 0.0, 7.0), "look": Vector3(0.0, 0.0, 0.0)},
		"doyun": {"outfit": "squire", "at": Vector3(0.0, 0.0, 0.5), "look": "rian"},
		"noble": {"outfit": "knight", "at": Vector3(3.2, 0.0, 2.2), "look": "rian"},
	},
	"beats": [
		{"cam": {"pos": Vector3(-2.2, 1.7, 8.6), "look": Vector3(0.0, 1.3, 2.0), "fov": 52.0, "drift": Vector3(0.12, 0.0, -0.1)},
			"walk": {"rian": Vector3(0.0, 0.0, 3.0)}, "dur": 3.4},
		{"cam": {"pos": Vector3(-1.3, 1.55, 4.6), "look": "doyun", "fov": 46.0},
			"clip": {"doyun": "Idle_Talking_Loop"},
			"line": ["도윤", "자네가 이번 공훈생인가. 먼 길 왔군. 철검관에 온 걸 환영하네."]},
		{"cam": {"pos": Vector3(3.0, 1.5, 2.6), "look": "noble", "fov": 44.0},
			"face": {"doyun": "noble"}, "clip": {"doyun": "", "noble": "Idle_Talking_Loop"},
			"line": ["귀족 학생", "마구간 옆 방이라더니, 정말 냄새가 따라오는군. 평민이 칼을 잡는다고 기사가 되나?"]},
		{"cam": {"pos": Vector3(-0.8, 1.6, 3.4), "look": "doyun", "fov": 40.0},
			"face": {"doyun": "rian"}, "clip": {"noble": "", "doyun": "Idle_Talking_Loop"},
			"line": ["도윤", "칼 앞에서는 다 같네. ……적어도 나는 그렇게 믿고 싶고."]},
		{"cam": {"pos": Vector3(0.0, 1.5, 6.0), "look": "doyun", "fov": 50.0, "drift": Vector3(0.0, 0.0, -0.15)},
			"clip": {"doyun": ""}, "walk": {"doyun": Vector3(0.0, 0.0, -1.5)},
			"line": ["도윤", "연무장으로 가세. 기본기부터 보겠네."]},
	],
}


## Two people face to face; each line is [who, text] (who: "rian" or `other`; "" is narration).
static func duo(other: String, lines: Array, extra := {}) -> Dictionary:
	var actors := {
		"rian": _actor("rian", Vector3(0.0, 0.0, 1.2), other),
		other: _actor(other, Vector3(0.0, 0.0, -1.2), "rian"),
	}
	for id in extra:
		actors[id] = _actor(id, extra[id], "rian")
	var beats := [{"cam": {"pos": Vector3(4.2, 1.9, 3.8), "look": Vector3(0.0, 1.2, 0.0), "fov": 48.0,
		"drift": Vector3(-0.25, 0.0, -0.1)}, "dur": 1.6}]
	for l in lines:
		beats.append(_line_beat(l[0], other, l[1]))
	return {"actors": actors, "beats": beats}


static func _actor(id: String, at: Vector3, look: Variant) -> Dictionary:
	var a: Dictionary = (OUTFITS[id] as Dictionary).duplicate()
	a["at"] = at
	a["look"] = look
	return a


## One line, shot over the shoulder of whoever is listening.
static func _line_beat(who: String, other: String, text: String) -> Dictionary:
	if who == "":
		return {"cam": {"pos": Vector3(0.0, 1.6, 5.0), "look": Vector3(0.0, 1.3, 0.0), "fov": 55.0,
			"drift": Vector3(0.0, 0.0, -0.12)}, "clip": {"rian": "", other: ""}, "line": ["", text]}
	var listener := "rian" if who == other else other
	var cam_z := 2.9 if listener == "rian" else -2.9
	var cam_x := 0.7 if listener == "rian" else -0.7
	return {"cam": {"pos": Vector3(cam_x, 1.65, cam_z), "look": who, "fov": 42.0},
		"clip": {who: "Idle_Talking_Loop", listener: ""}, "line": [NAMES[who], text]}


static func get_scene(id: String) -> Dictionary:
	match id:
		"entrance":
			return ENTRANCE
		"taesan_pre":
			return duo("taesan", [
				["taesan", "꼴찌가 내 윗자리를 노린다고? 따라와."],
				["taesan", "여기서는 이긴 놈만 이름이 남는다. 졌다고 울지 마라."]])
		"taesan_post":
			return duo("taesan", [
				["taesan", "……살아남는 법부터 배워. 칼질은 그다음이다."],
				["rian", "무슨 말이야?"],
				["taesan", "곧 알게 돼. 모르는 편이 낫긴 하지만."]])
		"leon_pre":
			return duo("leon", [
				["leon", "아, 아니, 싸우자는 건 아니고. 규칙대로 하자는 거지. 규칙대로."],
				["leon", "다치게는 하지 마. 우리 가문에 남은 칼이 나 하나뿐이거든."]])
		"leon_post":
			return duo("leon", [
				["leon", "이, 일러둘 게 있어. 윗분들이 공훈생 얘기를 할 때 '선봉'이라고 하더라."],
				["leon", "난 아무것도 못 들었어! 진짜로!"]])
		"report":
			return duo("doyun", [
				["rian", "이 서류, 네 글씨지."],
				["doyun", "……읽었나."],
				["rian", "나에 대해 뭘 적었어."],
				["doyun", "사실만 적었네. 그게 내가 기사로 사는 값이야."],
				["rian", "칼 앞에서는 다 같다며."],
				["doyun", "그 말은 거짓이었네. 미안하다."]])
		"mujin_train":
			return duo("mujin", [
				["mujin", "도윤이 보고서를 쓴다는 건 알고 있었다. 나도 한때 그런 서류의 주인공이었지."],
				["mujin", "공훈생은 살아남는 법만 배운다. 이기는 법은 그다음이다."],
				["rian", "왜 저에게 그걸 가르치십니까."],
				["mujin", "열두 명이 입학했다. 나 혼자 돌아왔다. 이유는 그것뿐이다."]])
		"seohyuk_pre":
			return duo("seohyuk", [
				["seohyuk", "나는 평민이라고 얕보지 않는다. 다만 선을 지킬 뿐이지."],
				["seohyuk", "아버지는 이기는 기사만 아들이라 부르신다. 봐주지 않겠다."]])
		"seohyuk_post":
			return duo("seohyuk", [
				["seohyuk", "……좋은 칼이다. 아버지께 보여 드릴 수 없는 것이 아쉽군."]])
		"serafin_pre":
			return duo("serafin", [
				["serafin", "이 학교에서 칼을 든 여자는 나 하나. 그래서 나는 두 배로 이겨야 하지."],
				["serafin", "칼은 태어날 때 이미 정해진다고들 해. 아니라고 증명해 보겠어?"]])
		"serafin_post":
			return duo("serafin", [
				["serafin", "졌군. 하나 알려 주지. 우리 가문의 인장이 북쪽으로 가는 편지에 찍혀 있었어."],
				["serafin", "내가 아는 건 그뿐이야. 믿든 말든 네 몫이고."]])
		"kaiden_pre":
			return duo("kaiden", [
				["kaiden", "수석은 내 것이다. 아버지가 그렇게 정하셨고, 나도 그럴 자격이 있다."],
				["kaiden", "평민, 네 칼이 어디까지 오르는지 보자."]])
		"kaiden_post":
			return duo("kaiden", [
				["kaiden", "내가 졌다. ……아버지께서는 이런 일을 말씀하신 적이 없는데."],
				["kaiden", "졸업시험에서 다시 보자. 그때는 지지 않는다."]])
		"war_bell":
			return duo("leon", [
				["leon", "종! 종을 쳤어! 북쪽 성문으로 북방군이 들어오고 있어!"],
				["rian", "네가 종을 쳤나?"],
				["leon", "다, 다들 자는데 누군가는 해야 했으니까! 난 겁쟁이지만 바보는 아니야!"],
				["", "졸업시험 전날 밤, 연무장에 불길이 올랐다."]])
		"war_mujin":
			return duo("mujin", [
				["mujin", "왔나. 졸업시험은 취소됐다. 대신 이게 시험이다."],
				["mujin", "내 오른손은 이제 칼을 잡지 못한다. 네가 끝내라."]], {"soldier": Vector3(2.5, 0.0, -3.0)})
		"baldor_pre":
			return duo("baldor", [
				["baldor", "철검관의 병아리가 마지막이군. 이름은."],
				["rian", "리안. 안개 골짜기에서 죽은 병사의 아들이다."],
				["baldor", "……그랬나. 네 아비는 항복했었다. 내가 받으려 했지. 죽인 것은 우리가 아니다."],
				["rian", "거짓말."],
				["baldor", "칼에게 물어보아라. 칼은 거짓을 말하지 못하니까."]])
		"end_execute":
			return {"actors": {
					"rian": _actor("rian", Vector3(0.0, 0.0, 1.5), "kaiden"),
					"kaiden": _actor("kaiden", Vector3(0.0, 0.0, -1.2), "rian"),
					"doyun": _actor("doyun", Vector3(-2.2, 0.0, 0.0), "rian"),
				},
				"beats": [
					{"cam": {"pos": Vector3(4.0, 1.8, 5.0), "look": Vector3(0.0, 1.2, 0.0), "fov": 50.0, "drift": Vector3(-0.2, 0.0, -0.1)}, "dur": 1.5},
					{"cam": {"pos": Vector3(0.0, 1.6, 5.0), "look": Vector3(0.0, 1.3, 0.0), "fov": 55.0},
						"line": ["", "칼이 떨어졌다. 발도르는 아무 말도 남기지 않았고, 안개 골짜기의 진실도 그와 함께 묻혔다."]},
					{"cam": {"pos": Vector3(0.7, 1.65, 3.2), "look": "kaiden", "fov": 42.0},
						"clip": {"kaiden": "Idle_Talking_Loop"},
						"line": ["카이든", "아버지는 그날 지휘관이셨다. 이제 아무도 그 이야기를 하지 않겠지. ……이상하게 마음이 편치 않군."]},
					{"cam": {"pos": Vector3(-0.8, 1.65, 2.0), "look": "doyun", "fov": 44.0},
						"clip": {"kaiden": "", "doyun": "Idle_Talking_Loop"},
						"line": ["도윤", "자네는 수석이 되었네. 영웅이야. ……그것으로 충분하다고, 나는 믿겠네."]},
					{"cam": {"pos": Vector3(0.0, 1.6, 5.5), "look": Vector3(0.0, 1.3, 0.0), "fov": 55.0, "drift": Vector3(0.0, 0.0, -0.1)},
						"clip": {"doyun": ""}, "line": ["", "리안은 수석으로 졸업했다. 그리고 공훈생 제도는 그대로 남았다."]},
				]}
		"end_spare":
			return {"actors": {
					"rian": _actor("rian", Vector3(0.0, 0.0, 1.5), "kaiden"),
					"kaiden": _actor("kaiden", Vector3(0.0, 0.0, -1.2), "rian"),
					"doyun": _actor("doyun", Vector3(-2.2, 0.0, 0.0), "rian"),
				},
				"beats": [
					{"cam": {"pos": Vector3(4.0, 1.8, 5.0), "look": Vector3(0.0, 1.2, 0.0), "fov": 50.0, "drift": Vector3(-0.2, 0.0, -0.1)}, "dur": 1.5},
					{"cam": {"pos": Vector3(0.0, 1.6, 5.0), "look": Vector3(0.0, 1.3, 0.0), "fov": 55.0},
						"line": ["", "리안은 칼을 거두었다. 발도르는 무릎을 꿇은 채, 안개 골짜기에서 있었던 일을 있는 그대로 증언했다."]},
					{"cam": {"pos": Vector3(0.7, 1.65, 3.2), "look": "kaiden", "fov": 42.0},
						"clip": {"kaiden": "Idle_Talking_Loop"},
						"line": ["카이든", "아버지께 물어보겠다. 직접. 만약 사실이라면 ……나는 그 자리에서 아버지와 맞서겠다."]},
					{"cam": {"pos": Vector3(-0.8, 1.65, 2.0), "look": "doyun", "fov": 44.0},
						"clip": {"kaiden": "", "doyun": "Idle_Talking_Loop"},
						"line": ["도윤", "귀족 의회가 자네의 수석 자격을 문제 삼을 걸세. 그래도 후회하지 않나."]},
					{"cam": {"pos": Vector3(0.0, 1.6, 5.5), "look": Vector3(0.0, 1.3, 0.0), "fov": 55.0, "drift": Vector3(0.0, 0.0, -0.1)},
						"clip": {"doyun": ""}, "line": ["", "공훈생 제도는 폐지되기 시작했다. 리안의 이름은 수석 명단에 오를 수도, 오르지 못할 수도 있었다."]},
				]}
	return {}
