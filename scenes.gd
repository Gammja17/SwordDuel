extends RefCounted
## Cutscene scripts (data for story_scene.gd). Positions are in the arena: the middle of
## the courtyard is the origin, +Z toward the player's start. Most scenes are two people
## talking (duo), shot over each other's shoulder; ENTRANCE and the endings are staged by hand.

const NAMES := {
	"rian": "리안", "doyun": "도윤", "taesan": "태산", "leon": "레온", "seohyuk": "서혁",
	"serafin": "세라핀", "kaiden": "카이든", "mujin": "무진", "baldor": "발도르", "soldier": "북방 병사",
}
const OUTFITS := {
	"rian": {"outfit": "player", "kit": "two"}, "doyun": {"outfit": "squire", "kit": "one"}, "taesan": {"outfit": "taesan", "kit": "two"},
	"leon": {"outfit": "leon", "kit": "one"}, "seohyuk": {"outfit": "knight", "kit": "shield"}, "serafin": {"outfit": "woman_ranger", "kit": "one"},
	"kaiden": {"outfit": "kaiden", "kit": "two"}, "mujin": {"outfit": "master", "kit": "two"},
	"baldor": {"outfit": "", "kit": "two", "tabard": Color(0.10, 0.10, 0.28), "crest": true},
	"soldier": {"outfit": "", "kit": "shield", "tabard": Color(0.12, 0.14, 0.30), "crest": false},
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
		# ----- 라이벌과의 첫 대면. 어느 학기, 어떤 순서로 만나도 읽히게 쓴다. -----
		"taesan_pre":
			return duo("taesan", [
				["", "공훈생 숙소 뒤편. 사내 하나가 맨몸으로 돌을 들었다 놓았다 하고 있었다."],
				["taesan", "새로 온 꼴찌지? 마구간 옆방."],
				["rian", "냄새가 나서 미안하게 됐군."],
				["taesan", "그 방, 내가 작년까지 쓰던 방이다. 냄새는 한 달이면 익숙해져."],
				["taesan", "붙어 보자. 네가 어디까지 버티는지 알아야 내가 안심이 돼."],
				["rian", "안심?"],
				["taesan", "곧 알게 돼. 칼부터 뽑아."]])
		"taesan_post":
			return duo("taesan", [
				["taesan", "……졌다. 이름이 뭐였지."],
				["rian", "리안."],
				["taesan", "리안. 기억해 두지. 이름이 기억되는 건 생각보다 큰일이거든."],
				{"cond": "school", "who": "taesan", "lines": [
					"느린 칼이군. 마음에 든다. 한 방이 있어.",
					"빠르기만 하군. 한 방은 어디 뒀냐.",
					"기다리는 놈이군. 나랑은 다르다."]},
				["taesan", "아직 네 위에 스물네 명이 있다. 으스대려면 그다음에 해라."]])
		"leon_pre":
			return duo("leon", [
				["", "새벽 연무장. 레온이 칼을 두 손으로 쥐고 서 있었다. 손끝이 하얗다."],
				["leon", "아, 안녕! 규칙대로 하자! 규칙대로! 나는 규칙이 아주 좋거든!"],
				["rian", "손이 떨리는데."],
				["leon", "떠는 게 아니라 몸 푸는 거야! 새벽이라 춥잖아!"],
				["leon", "……살살 해 줘. 부탁이야. 우리 집에 남은 칼이 나 하나뿐이거든."]])
		"leon_post":
			return duo("leon", [
				{"cond": "school", "who": "leon", "lines": [
					"그 칼, 땅 파는 데 쓰는 거 아냐? 아야…… 진짜 아팠어.",
					"빠르다고! 치사하게! 눈에 안 보이잖아!",
					"쳐내는 거 진짜 얄미워. 알고 있었는데도 당했어."]},
				["leon", "대신 하나 말해 줄게. 어제 복도에서 윗분들이 얘기하는 걸 들었어. 이번 졸업 배속은 전부 '선봉'이라고."],
				["rian", "선봉이면 최전선이잖아."],
				["leon", "난 못 들었어! 아무것도! 그리고 너도 못 들었어!"],
				["rian", "고마워."],
				["leon", "고맙다고 하지 마! 나 무서워진단 말이야!"]])
		"seohyuk_pre":
			return duo("seohyuk", [
				["seohyuk", "도전을 받겠네. 편히 칼을 뽑게."],
				["rian", "공손하군."],
				["seohyuk", "예의는 아버지께 배운 유일한 것이라서."],
				["seohyuk", "다만 이기는 법도 아버지께 배웠네. 봐주지 않겠네."]])
		"seohyuk_post":
			return duo("seohyuk", [
				["seohyuk", "……졌군. 자네 칼에는 가문의 칼과 다른 데가 있네."],
				["rian", "어떤 점이?"],
				["seohyuk", "이기고 싶어서 휘두르는 칼이 아니라 살아남으려고 휘두르는 칼이야. 나는 그런 칼을 휘둘러 본 적이 없네."],
				["seohyuk", "부럽다고 하면 실례겠지. 잊어 주게."]])
		"serafin_pre":
			return duo("serafin", [
				["", "횃불이 켜진 밤의 연무장. 담장 위에 구경꾼들이 줄지어 앉았다."],
				["serafin", "이 학교에서 칼을 든 여자는 나 하나라서 구경꾼이 많아."],
				["rian", "신경 쓰여?"],
				["serafin", "신경 쓰는 걸 들키는 게 싫어. 시작하자. 한 번에 끝낼게."]])
		"serafin_post":
			return duo("serafin", [
				["serafin", "……졌네. 인정할게."],
				["serafin", "입이 무거워 보이니 하나만 말해 두지. 우리 가문의 인장이 북쪽으로 가는 편지에 찍혀 있었어."],
				["rian", "왜 나한테 말해."],
				["serafin", "다른 사람한테 말하면 내 가문이 끝나. 너는 잃을 게 없고."],
				["rian", "위로로 들어도 돼?"],
				["serafin", "아니."]])
		"kaiden_pre":
			return duo("kaiden", [
				["", "안개 낀 한낮. 담장 위는 구경하러 온 학생들로 가득했다."],
				["kaiden", "수석 자리는 내 것이다. 평민이 그 아래까지 올라왔다니 신기하군."],
				["rian", "신기해할 시간에 칼을 뽑지."],
				["kaiden", "건방지군. 좋다. 내 칼이 가장 앞에 있다는 걸 보여 주마."]])
		"kaiden_post":
			return duo("kaiden", [
				["kaiden", "……내가 졌다."],
				["kaiden", "한 번은 우연일 수 있다. 다음에 다시 서겠다. 도망칠 생각 마라."],
				["rian", "도망은 네 쪽이 더 잘하게 생겼는데."],
				["kaiden", "……이름이 리안이었지. 잊지 않겠다."]])
		# ----- 기숙사 이벤트: 학기와 시험이 쌓이면 마당으로 돌아올 때 저절로 열린다. -----
		"mujin_train":
			return duo("mujin", [
				["", "첫 학기가 끝난 저녁. 무진이 연무장 끝에서 기다리고 있었다."],
				["mujin", "한 학기를 버텼군."],
				["rian", "버텼다기엔 쓰러진 횟수가 많았습니다."],
				["mujin", "쓰러진 횟수는 세지 마라. 일어난 횟수를 세라."],
				{"cond": "school", "who": "mujin", "lines": [
					"너는 무겁게 간다. 무거운 칼은 한 번만 맞아도 끝이다. 그 한 번을 아껴라.",
					"너는 가볍게 간다. 하지만 맞으면 아프다. 맞지 않는 법부터 익혀라.",
					"너는 기다리는 쪽이군. 쳐내는 칼은 가장 먼저 나가야 가장 늦게 맞는다."]},
				["mujin", "공훈생은 살아남는 법부터 배운다. 이기는 법은 그다음이다."],
				["rian", "왜 그 순서입니까."],
				["mujin", "곧 알게 된다. ……모르는 채로 졸업하는 편이 나을 수도 있다."]])
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
				{"cond": "doyun_trust", "who": "doyun", "lines": ["……이 빚은 칼로 갚겠네. 꼭.", "……그래. 그게 옳겠지. 나라도 그랬을 걸세."]}])
		"after_exam":
			return duo("leon", [
				["", "첫 시험 결과가 게시판에 붙었다. 학생들이 몰려 있다."],
				["leon", "봤어? 봤어?! 네 이름이 위로 올라갔어!"],
				["rian", "너는?"],
				["leon", "나는 그대로야. 그게 내 특기거든. 안 떨어지는 거."],
				["taesan", "위로 올라가다 보면 아래가 안 보이게 돼. 가끔 내려다봐라."],
				["leon", "태산, 무섭게 말하지 마! 격려처럼 안 들리잖아!"],
				["rian", "격려 맞아. 태산식 격려."]], {"taesan": Vector3(2.4, 0.0, -2.8)})
		"rumor":
			return duo("doyun", [
				["", "두 번째 시험이 끝난 저녁. 성문 쪽에서 말발굽 소리가 들렸다."],
				["doyun", "북쪽 국경에서 전령이 왔네. 공작 각하께 직접."],
				["kaiden", "아버지께는 내가 말씀드리겠다. 조용히 해라."],
				["doyun", "공자. 전쟁입니까?"],
				["kaiden", "……모른다. 아는 건 이번 졸업시험이 열리지 않을 수도 있다는 것뿐이다."],
				["rian", "그럼 수석은?"],
				["kaiden", "칼로 정해라. 전쟁이 오기 전에."]], {"kaiden": Vector3(2.6, 0.0, -2.6)})
		# ----- 전쟁 학기 -----
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
				["", "학기가 세 번 지났다. 게시판에 석차 시험 공고가 붙었다."],
				["mujin", "석차 시험이다. 상대는 정해져 있지 않다. 올라오는 순서대로 겨룬다."],
				["rian", "한 번 지면요?"],
				["mujin", "거기서 끝이다. 이긴 만큼 석차가 오르고, 오른 석차는 누구도 뺏지 못한다."],
				["mujin", "기억해라. 시험은 너를 재는 게 아니다. 학교가 너를 뭐라고 부를지 정하는 거다."]])
		"end_execute":
			return _ending("execute", flags)
		"end_spare":
			return _ending("spare", flags)
	return {}
