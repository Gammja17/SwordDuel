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
			"walk": {"rian": Vector3(0.0, 0.0, 3.0)}, "dur": 3.2},
		{"cam": {"pos": Vector3(-1.3, 1.55, 4.6), "look": "doyun", "fov": 40.0},
			"clip": {"doyun": "Idle_Talking"},
			"line": ["도윤", "공훈생이군. 짐이 가벼운 걸 보니."]},
		{"cam": {"pos": Vector3(3.6, 1.5, 3.4), "look": "noble", "fov": 38.0},
			"face": {"doyun": "noble"}, "clip": {"doyun": "", "noble": "Idle_Talking"},
			"line": ["귀족 학생", "마구간 옆 방이라더니, 냄새가 먼저 오는군."]},
		{"cam": {"pos": Vector3(1.2, 1.6, -0.6), "look": "rian", "fov": 38.0},
			"face": {"doyun": "rian"}, "clip": {"noble": "", "doyun": ""},
			"line": ["리안", "냄새는 저쪽이 더 나는데. 향수가 코를 찌르네."]},
		{"cam": {"pos": Vector3(-1.0, 1.6, 3.8), "look": "doyun", "fov": 38.0},
			"clip": {"doyun": "Idle_Talking"},
			"line": ["도윤", "마음에 들었다. ……한 가지만 알아 두게."]},
		{"cam": {"pos": Vector3(-1.0, 1.6, 3.8), "look": "doyun", "fov": 34.0},
			"line": ["도윤", "석차 1위, 수석에게는 왕실 기록관의 열람권이 주어지네. 전사자 기록까지."]},
		{"cam": {"pos": Vector3(1.2, 1.6, -0.6), "look": "rian", "fov": 34.0},
			"clip": {"doyun": ""},
			"line": ["리안", "……안개 골짜기."]},
		{"cam": {"pos": Vector3(0.0, 1.5, 6.0), "look": "doyun", "fov": 50.0, "drift": Vector3(0.0, 0.0, -0.15)},
			"clip": {"doyun": "Idle_Talking"}, "walk": {"doyun": Vector3(0.0, 0.0, -1.5)},
			"line": ["도윤", "알고 왔군. 그럼 꼴찌부터 시작하세. 연무장으로."]},
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
		if l is Dictionary and l.has("choice"):
			beats.append(l)   # a choice keeps the camera where it was
		elif l is Dictionary:
			# a line that depends on an earlier choice: lines[i] is said for pick i
			var b := _line_beat(l["who"], other, l["lines"][0])
			var variants := []
			for text in l["lines"]:
				variants.append([NAMES[l["who"]], text])
			b["line_if"] = {"key": l["cond"], "lines": variants}
			beats.append(b)
		else:
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
	var cam_z := 3.9 if listener == "rian" else -3.9
	var cam_x := 1.0 if listener == "rian" else -1.0
	return {"cam": {"pos": Vector3(cam_x, 1.65, cam_z), "look": who, "fov": 36.0},
		"clip": {who: "Idle_Talking", listener: ""}, "line": [NAMES[who], text]}


## The graduation. Who stands in the courtyard depends on the choices made: Doyun if Rian
## forgave him (flags.doyun_trust == 0), Serafin if Rian followed her to the north gate
## (flags.serafin_gate == 0). `kind` is "execute" or "spare".
static func _ending(kind: String, flags: Dictionary) -> Dictionary:
	var doyun_here: bool = int(flags.get("doyun_trust", 0)) == 0
	var serafin_here: bool = int(flags.get("serafin_gate", 0)) == 0
	var actors := {
		"rian": _actor("rian", Vector3(0.0, 0.0, 1.5), "kaiden"),
		"kaiden": _actor("kaiden", Vector3(0.0, 0.0, -1.2), "rian"),
	}
	if doyun_here:
		actors["doyun"] = _actor("doyun", Vector3(-2.2, 0.0, 0.0), "rian")
	if serafin_here:
		actors["serafin"] = _actor("serafin", Vector3(2.2, 0.0, 0.0), "rian")
	var wide := {"pos": Vector3(0.0, 1.6, 5.2), "look": Vector3(0.0, 1.3, 0.0), "fov": 55.0, "drift": Vector3(0.0, 0.0, -0.1)}
	var beats := [
		{"cam": {"pos": Vector3(4.0, 1.8, 5.0), "look": Vector3(0.0, 1.2, 0.0), "fov": 50.0, "drift": Vector3(-0.2, 0.0, -0.1)}, "dur": 1.5},
	]
	var kaiden_line: String
	var doyun_line: String
	var serafin_line: String
	if kind == "execute":
		beats.append({"cam": wide, "line": ["", "칼이 떨어졌다. 발도르는 아무 말도 남기지 않았고, 안개 골짜기의 진실도 그와 함께 묻혔다."]})
		kaiden_line = "아버지는 그날 지휘관이셨다. 이제 아무도 그 이야기를 하지 않겠지. ……이상하게 마음이 편치 않군."
		doyun_line = "자네는 수석이 되었네. 영웅이야. ……그것으로 충분하다고, 나는 믿겠네."
		serafin_line = "북문은 막았어. 우리 가문이 한 일은, 내가 평생 갚겠다."
	else:
		beats.append({"cam": wide, "line": ["", "리안은 칼을 거두었다. 발도르는 무릎을 꿇은 채, 안개 골짜기에서 있었던 일을 있는 그대로 증언했다."]})
		kaiden_line = "아버지께 직접 묻겠다. 사실이라면 ……나는 그 자리에서 아버지와 맞서겠다."
		doyun_line = "귀족 의회가 자네의 수석 자격을 문제 삼을 걸세. 그래도 후회하지 않나."
		serafin_line = "증언대에 서겠어. 우리 가문의 인장이 찍힌 편지는 내가 가지고 있다."
	beats.append({"cam": {"pos": Vector3(0.7, 1.65, 3.2), "look": "kaiden", "fov": 42.0},
		"clip": {"kaiden": "Idle_Talking"}, "line": ["카이든", kaiden_line]})
	if doyun_here:
		beats.append({"cam": {"pos": Vector3(-0.8, 1.65, 2.0), "look": "doyun", "fov": 44.0},
			"clip": {"kaiden": "", "doyun": "Idle_Talking"}, "line": ["도윤", doyun_line]})
	else:
		beats.append({"cam": wide, "clip": {"kaiden": ""},
			"line": ["", "도윤은 후원자의 가문으로 돌아갔다. 그가 쓴 마지막 보고서에는 리안의 이름이 없었다고 한다."]})
	if serafin_here:
		beats.append({"cam": {"pos": Vector3(0.8, 1.65, 2.0), "look": "serafin", "fov": 44.0},
			"clip": {"serafin": "Idle_Talking", "doyun": ""} if doyun_here else {"serafin": "Idle_Talking"},
			"line": ["세라핀", serafin_line]})
	else:
		beats.append({"cam": wide, "line": ["", "세라핀의 가문은 북문 사건의 책임을 졌다. 그녀는 그날 밤 이후 학교에서 보이지 않았다."]})
	if kind == "execute":
		beats.append({"cam": wide, "clip": {"serafin": ""} if serafin_here else {},
			"line": ["", "리안은 수석으로 졸업했다. 그리고 공훈생 제도는 그대로 남았다."]})
	else:
		beats.append({"cam": wide, "clip": {"serafin": ""} if serafin_here else {},
			"line": ["", "공훈생 제도는 폐지되기 시작했다. 리안의 이름은 수석 명단에 오를 수도, 오르지 못할 수도 있었다."]})
	return {"actors": actors, "beats": beats}


static func get_scene(id: String, flags := {}) -> Dictionary:
	match id:
		"entrance":
			return ENTRANCE
		"taesan_pre":
			return duo("taesan", [
				["taesan", "꼴찌. 내 자리를 노린다고?"],
				["rian", "25위. 한 칸이면 돼."],
				["taesan", "한 칸이 제일 비싸다. 따라와."]])
		"taesan_post":
			return duo("taesan", [
				["taesan", "……안개 골짜기. 소문은 들었다."],
				["rian", "뭘 들었는데."],
				["taesan", "공훈생이 졸업하면 어디로 가는지. 아직 몰라도 된다."],
				{"cond": "school", "who": "taesan", "lines": [
					"느린 칼이군. 마음에 든다. 한 방이 있어.",
					"빠르기만 하군. 한 방은 어디 뒀냐.",
					"기다리는 놈이군. 나랑은 다르다."]},
				["taesan", "먼저 살아남아라. 칼은 그다음이다."]])
		"leon_pre":
			return duo("leon", [
				["leon", "싸우자는 건 아닌데! 규칙대로. 규칙대로 하자."],
				["rian", "떨고 있네."],
				["leon", "추워서야! 새벽이잖아!"]])
		"leon_post":
			return duo("leon", [
				{"cond": "school", "who": "leon", "lines": [
					"그 칼, 땅 파는 데 쓰는 거 아냐? 아야…… 진짜 아팠어.",
					"빠르다고! 치사하게! 눈에 안 보이잖아!",
					"쳐내는 거 진짜 얄미워. 알고 있었는데도 당했어."]},
				["leon", "대신 하나 말해 줄게. 윗분들이 졸업한 공훈생 얘기를 할 때 '선봉'이라고 하더라."],
				["rian", "선봉이면 최전선이잖아."],
				["leon", "난 못 들었어! 아무것도!"]])
		"report":
			return duo("doyun", [
				["", "도윤의 책상 위. 서류 맨 위 장에 리안의 이름이 적혀 있었다."],
				["rian", "네 글씨지."],
				["doyun", "……읽었나."],
				["rian", "내가 누구와 말하는지까지 적었더군."],
				["doyun", "사실만 적었네. 그게 내가 기사로 사는 값이야."],
				["rian", "칼 앞에서는 다 같다며."],
				["doyun", "거짓말이었네. 나도 믿고 싶었을 뿐이야."],
				{"choice": {"key": "doyun_trust", "prompt": "도윤은 고개를 숙이고 서 있다. 어떻게 하겠는가?",
					"options": ["용서한다. 그래도 첫날 길을 알려 준 사람이다.", "등을 돌린다. 이미 늦었다."]}},
				{"cond": "doyun_trust", "who": "doyun", "lines": ["……이 빚은 칼로 갚겠네. 꼭.", "……그래. 그게 옳겠지."]}])
		"mujin_train":
			return duo("mujin", [
				["mujin", "도윤이 서류를 쓴다는 건 알고 있었다. 나도 쓰던 쪽이었다."],
				["rian", "사범님이요?"],
				["mujin", "스무 해 전에 공훈생이었다. 열두 명 중 나 혼자 돌아왔지."],
				{"cond": "school", "who": "mujin", "lines": [
					"너는 무겁게 간다. 좋다. 무거운 칼은 한 번만 맞아도 끝이다. 그 한 번을 아껴라.",
					"너는 가볍게 간다. 좋다. 하지만 맞으면 아프다. 맞지 않는 법부터 배워라.",
					"너는 기다리는 쪽이군. 좋다. 쳐내는 칼은 가장 먼저 나가야 가장 늦게 맞는다."]},
				["mujin", "살아남는 법부터. 이기는 법은 그다음이다."]])
		"seohyuk_pre":
			return duo("seohyuk", [
				["seohyuk", "비 오는 날이군. 발이 미끄러울 것이니 조심하게."],
				["rian", "너는 그 선이 마음에 드나. 평민과 귀족 사이의 선."],
				["seohyuk", "마음에 드는 것과 지켜야 하는 것은 다르네. 아버지는 이기는 아들만 아들이라 하시지."]])
		"seohyuk_post":
			return duo("seohyuk", [
				["seohyuk", "……좋은 칼이다. 아버지께 보일 수 없는 게 아쉽군."],
				["seohyuk", "전쟁이 나면 나는 그분 밑에서 싸운다. 이기면 아들, 지면 수치지."],
				["rian", "그럼 오늘은 아들이 아니겠네."],
				["seohyuk", "……그렇군. 오랜만에 가벼워."]])
		"serafin_pre":
			return duo("serafin", [
				["serafin", "이 학교에서 칼을 든 여자는 나 하나. 그래서 나는 두 배로 이겨야 해."],
				["rian", "나는 신분이 걸림돌이야. 같은 처지겠네."],
				["serafin", "같은 처지라고 봐줄 줄 알았다면 잘못 짚었어."]])
		"serafin_post":
			return duo("serafin", [
				["serafin", "졌군. ……제법이야."],
				["serafin", "하나 알려 주지. 우리 가문의 인장이 북쪽으로 가는 편지에 찍혀 있었어."],
				["rian", "왜 나한테 말해."],
				["serafin", "너는 어차피 잃을 게 없잖아."]])
		"kaiden_pre":
			return duo("kaiden", [
				["", "안개 낀 한낮. 담장 위는 구경하러 온 학생들로 가득했다."],
				["kaiden", "수석은 내 것이다. 아버지가 그렇게 정하셨다."],
				["rian", "정해진 자리가 아니라 이기는 사람이 앉는 자리 아닌가."],
				["kaiden", "하! 입은 잘 놀리는군. 칼이 그만큼 따라오는지 보자."]])
		"kaiden_post":
			return duo("kaiden", [
				["kaiden", "……내가 졌다. 내가."],
				["kaiden", "아버지는 이런 날이 온다고 말씀하신 적이 없는데. 그분이 틀리신 건 처음이다."],
				["rian", "수석은 네 자리가 아니었나."],
				["kaiden", "졸업시험에서 다시 보자. 그때는 지지 않는다. ……리안."]])
		"war_bell":
			return duo("leon", [
				["", "졸업시험 전날 밤. 자정이 막 지났을 때, 회색성의 종이 미친 듯이 울렸다."],
				["leon", "종! 종을 쳤어! 북문으로 북방군이 들어오고 있어!"],
				["rian", "네가 쳤어?"],
				["leon", "다들 자는데 누군가는 해야 했잖아! 나는 겁쟁이지만 바보는 아니야!"],
				["leon", "세라핀이 북문으로 갔어! 자기 가문이 문을 열었다고, 혼자 막겠다고!"],
				{"choice": {"key": "serafin_gate", "prompt": "북문으로 달려가는 세라핀이 보인다.",
					"options": ["따라가 함께 문을 막는다.", "연무장을 지킨다. 여기에도 사람이 있다."]}}])
		"war_mujin":
			return duo("mujin", [
				["", "연무장 한가운데, 무진이 벽에 기대 앉아 있었다. 오른팔에서 피가 흐르고 있었다."],
				["rian", "사범님, 손이!"],
				["mujin", "이 손은 이제 칼을 못 잡는다. 스무 해 전에 못 지킨 걸 오늘도 못 지켰군."],
				["mujin", "하지만 너는 칼이 있다. 열두 명 중 하나가 아니라, 너로서 서라. 가라."]], {"soldier": Vector3(2.5, 0.0, -3.0)})
		"baldor_pre":
			return duo("baldor", [
				["", "불길 한복판에서 중장갑의 노기사가 걸어 나왔다."],
				["baldor", "철검관의 병아리가 마지막이군. 이름은."],
				["rian", "리안. 안개 골짜기에서 죽은 병사의 아들이다."],
				["baldor", "……그랬나. 네 아비는 항복했었다. 내가 받으려 했지."],
				["rian", "거짓말."],
				["baldor", "칼에게 물어보아라. 칼은 거짓을 말하지 못한다."]])
		"exam_open":
			return duo("mujin", [
				["", "학기가 세 번 지났다. 학교 게시판에 석차 시험 공고가 붙었다."],
				["mujin", "석차 시험이다. 상대는 정해져 있지 않다. 올라오는 순서대로 겨룬다."],
				["rian", "한 번 지면요?"],
				["mujin", "거기서 끝이다. 이긴 만큼 석차가 오르고, 오른 석차는 누구도 뺏지 못한다."],
				["mujin", "기억해라. 시험은 너를 재는 것이 아니라, 학교가 너를 부르는 이름을 정하는 것이다."]])
		"end_execute":
			return _ending("execute", flags)
		"end_spare":
			return _ending("spare", flags)
	return {}
