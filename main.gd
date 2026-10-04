extends Node2D
## いたちごっこ ― 全部コードで描く一発ネタミニゲーム

const W := 1280.0
const H := 720.0
const GY := 540.0        # 地面(足元)のY
const WALL_X := 640.0    # 柵・壁のX
const STOP_X := 470.0    # 敵が立ち止まる位置

const C_BROWN := Color(0.62, 0.40, 0.20)
const C_BROWN_D := Color(0.42, 0.26, 0.12)
const C_CREAM := Color(0.99, 0.91, 0.74)
const C_SKIN := Color(1.0, 0.86, 0.72)
const C_WOOD := Color(0.78, 0.58, 0.32)
const C_WOOD_D := Color(0.5, 0.33, 0.16)
const C_DIRT := Color(0.45, 0.30, 0.17)
const C_NAVY := Color(0.18, 0.25, 0.5)

const TURN_SETS := [
	["fence", "hole", "wire"],
	["camera", "trap", "sign"],
	["guard", "lock", "dog"],
]
const LABELS := {
	"fence": "柵を高くする",
	"hole": "穴を塞ぐ",
	"wire": "金網を張る",
	"camera": "監視カメラを設置",
	"trap": "罠を置く",
	"sign": "看板を立てる",
	"guard": "警備員を配置",
	"lock": "門に鍵をかける",
	"dog": "番犬を放つ",
	"perfect": "完璧な対策をする",
}
const OPENING := [
	"人は、終わりなき競争を「いたちごっこ」と呼ぶ。",
	"技術が進めば、それを破る技術が生まれる。",
	"対策が生まれれば、新たな突破法が生まれる。",
	"――これは、そういう話ではない。",
]

var font: Font
var bubble_sb: StyleBoxFlat
var btn_box: HBoxContainer

var t := 0.0
var state := "opening"   # opening / intro / choose / busy / final / end
var turn := 0
var breaches := 0
var stolen := 0
var shake := 0.0
var cover := 1.0         # 黒幕の濃さ
var skip_open := false
var end_ready := false
var open_alpha: Array[float] = [0.0, 0.0, 0.0, 0.0]
var title_a := 0.0
var end_a := 0.0
var hint_a := 0.0
var prompt_a := 0.0
var prompt_text := "どうする？"
var quiet_a := 0.0
var red_flash := false

# --- 主人公 ---
var hero_x := 745.0
var hero_y := 0.0
var hero_vis := 0.0
var hero_scale := 1.0
var hero_arm_l := 0.25
var hero_arm_r := 0.25
var hero_tool := ""
var hero_working := false
var hero_cross := false
var hero_shock := false
var hero_frozen := false
var hero_sweat := false
var hero_follow := true
var hero_look := 0.0

# --- 敵いたち ---
var e_x := -200.0
var e_y := 0.0
var e_lane := 0.0
var e_dir := 1.0
var e_rot := 0.0
var e_scale := 1.0
var e_alpha := 1.0
var e_walk := false
var e_front := false
var e_look_up := 0.0
var e_hat := false
var e_hat_dy := 0.0
var e_salute := false
var e_box := 0.0
var e_stilts := 0.0
var e_sleep := false
var e_cutter := false
var e_stick := 0.0
var e_fish := false
var e_veg := false

# --- 小道具 ---
var fence_vis := true
var fence_h := 70.0
var fence_lift := 0.0
var lock_p := 0.0
var wire := 0.0
var wire_cut := 0.0
var hole_a := 0.0
var hole_b := 0.0
var hole_c := 0.0
var mound_a := 0.0
var mound_x := 0.0
var cam_p := 0.0
var cam_track := false
var cam_cone := false
var cam_tx := 450.0
var trap_p := 0.0
var trap_door := 0.0
var trap_bait := true
var trap_x := 555.0
var sign_p := 0.0
var sign_flip := 0.0
var sign_x := 545.0
var guard_p := 0.0
var guard_x := 690.0
var guard_salute := false
var guard_look := 0.0
var dog_p := 0.0
var dog_x := 560.0
var dog_y := 0.0
var dog_dir := -1.0
var dog_roll := 0.0
var dog_happy := false
var wall_p := 0.0
var moat_p := 0.0
var barb_p := 0.0
var cams_p := 0.0
var guards_p := 0.0
var crowd_p := 0.0
var hero_scan := false
var parade_on := false
var allies: Array = []   # 味方(ターンをまたいで残る): {kind,x,suit,salute}
var alarm_p := 0.0

var bubbles: Array = []
var sfxs: Array = []
var parts: Array = []

# テスト用
var auto_test := false
var auto_pick := 0
var shot_dir := ""
var shot_n := 0


func _ready() -> void:
	font = load("res://fonts/NotoSansJP-Bold-subset.ttf")
	setup_audio()
	bubble_sb = StyleBoxFlat.new()
	bubble_sb.bg_color = Color.WHITE
	bubble_sb.border_color = Color(0.15, 0.1, 0.05)
	bubble_sb.set_border_width_all(3)
	bubble_sb.set_corner_radius_all(14)
	var ui := CanvasLayer.new()
	add_child(ui)
	btn_box = HBoxContainer.new()
	ui.add_child(btn_box)
	btn_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	btn_box.offset_top = -112.0
	btn_box.offset_bottom = -22.0
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 22)
	for a in OS.get_cmdline_user_args():
		if a == "auto":
			auto_test = true
			Engine.time_scale = 4.0
		elif a.begins_with("pick="):
			auto_pick = int(a.substr(5))
		elif a.begins_with("shots="):
			shot_dir = a.substr(6)
	reset_turn_state()
	if auto_test:
		run_opening()
	else:
		state = "start"
	if shot_dir != "":
		auto_shots()


func auto_shots() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	while true:
		await get_tree().create_timer(0.5).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%03d.png" % [shot_dir, shot_n])
		shot_n += 1


# ============================================================ 音

const SE_NAMES := ["pop", "yosh", "drill", "hammer", "thud", "dig", "knock", "boing", "get", "shock", "fanfare", "siren", "beep", "whoosh", "rumble", "splash", "bark", "chime", "munch", "squeak", "snip", "salute", "end", "wind"]
const SFX_MAP := [
	["ガガガ", "drill"], ["カンカン", "hammer"], ["ザクザク", "dig"], ["ザッザッザッ", "dig"],
	["ドスッ", "thud"], ["ガシャン", "thud"], ["バタン", "thud"], ["ガチャン", "thud"], ["ボコッ", "thud"], ["パサッ", "thud"],
	["コンコン", "knock"], ["つんつん", "knock"], ["ジャーン", "fanfare"], ["ゲット", "get"],
	["ピコ", "beep"], ["スーッ", "whoosh"], ["モコモコ", "whoosh"], ["ドドド", "rumble"], ["ザバーン", "splash"],
	["ワン", "bark"], ["ウーー", "siren"], ["ジャキ", "snip"], ["パチン", "snip"], ["ビシッ", "salute"], ["ザッ", "salute"],
	["ギギギ", "squeak"], ["ウィーン", "squeak"], ["ひょい", "boing"], ["ふわぁ", "boing"], ["くるっ", "boing"], ["ヘソ天", "boing"],
	["キラーン", "chime"], ["ペタペタ", "chime"], ["！", "chime"], ["もぐもぐ", "munch"], ["なでなで", "munch"], ["クンクン", "munch"],
	["ポンッ", "boing"], ["ぞろぞろ", "whoosh"], ["？", "pop"],
]
const PARADE := [[300.0, "guard"], [160.0, "worker"], [-160.0, "watcher"], [-310.0, "guard"], [-460.0, "worker"]]
var sounds := {}
var se_players: Array[AudioStreamPlayer] = []
var bgm_player: AudioStreamPlayer
var bgm_name := ""


func setup_audio() -> void:
	for n in SE_NAMES:
		sounds[n] = load("res://audio/se_%s.wav" % n)
	for n in ["main", "open", "final"]:
		var st: AudioStreamWAV = load("res://audio/bgm_%s.wav" % n).duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = st.data.size() / 2
		sounds["bgm_" + n] = st
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		se_players.append(p)
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)


func se(name: String, vol := 0.0) -> void:
	if not sounds.has(name):
		return
	for p in se_players:
		if not p.playing:
			p.stream = sounds[name]
			p.volume_db = vol
			p.play()
			return
	se_players[0].stream = sounds[name]
	se_players[0].volume_db = vol
	se_players[0].play()


func bgm(name: String, vol := -8.0) -> void:
	if bgm_name == name and bgm_player.playing:
		return
	bgm_name = name
	bgm_player.stream = sounds["bgm_" + name]
	bgm_player.volume_db = vol
	bgm_player.play()


func bgm_stop(fade := 0.0) -> void:
	bgm_name = ""
	if fade <= 0.0:
		bgm_player.stop()
		return
	var tw := create_tween()
	tw.tween_property(bgm_player, "volume_db", -60.0, fade)
	tw.tween_callback(bgm_player.stop)


func sfx_sound(text: String) -> String:
	for m in SFX_MAP:
		if text.contains(m[0]):
			return m[1]
	return ""


# ============================================================ 味方の増員

const ALLY_SLOT := {"worker": 835.0, "watcher": 895.0, "guard": 690.0}
const RECRUIT_LINES := {
	"worker": ["作業員を増員する。", "いたちに警戒されないよう、\nこれを着てくれ。"],
	"watcher": ["監視員も増やそう。", "いたちの目線で見張るんだ。\nこれを。"],
	"guard": ["警備員を配置する。", "いたちに警戒されないようにな。"],
}


func recruit(kind: String) -> void:
	var a := {"kind": kind, "x": 1060.0, "suit": false, "salute": false}
	allies.append(a)
	hero_say(RECRUIT_LINES[kind][0], 1.4)
	var tw := create_tween()
	tw.tween_method(func(v: float): a["x"] = v, 1060.0, ALLY_SLOT[kind], 1.0)
	await tw.finished
	await wait(0.3)
	hero_say(RECRUIT_LINES[kind][1], 2.0)
	await wait(1.6)
	a["suit"] = true
	puff(Vector2(a["x"], GY - 50.0), 12, Color(1, 1, 1, 0.9), 150.0)
	sfx("ポンッ！", Vector2(a["x"], GY - 150.0), 0.8, Color(1, 1, 1), 40)
	await wait(1.0)
	hero_say("うむ。", 0.9)
	await wait(0.7)


func ally_of(kind: String) -> Dictionary:
	for a in allies:
		if a["kind"] == kind:
			return a
	return {}


# ============================================================ 共通ヘルパ

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func go(props: Dictionary, dur: float, trans := Tween.TRANS_SINE, easing := Tween.EASE_IN_OUT) -> void:
	var tw := create_tween().set_parallel(true).set_trans(trans).set_ease(easing)
	for k in props:
		tw.tween_property(self, NodePath(str(k)), props[k], maxf(dur, 0.01))
	await tw.finished


func _hop_step(u: float, x0: float, x1: float, y0: float, y1: float, h: float) -> void:
	e_x = lerpf(x0, x1, u)
	e_y = lerpf(y0, y1, u) - 4.0 * h * u * (1.0 - u)


func hop(x1: float, h: float, dur: float, y1 := 0.0) -> void:
	e_dir = signf(x1 - e_x) if absf(x1 - e_x) > 1.0 else e_dir
	var tw := create_tween()
	tw.tween_method(_hop_step.bind(e_x, x1, e_y, y1, h), 0.0, 1.0, dur)
	await tw.finished
	puff(Vector2(e_x, GY + e_lane + y1), 6, C_DIRT, 60.0)


func _dog_hop_step(u: float, h: float) -> void:
	dog_y = -4.0 * h * u * (1.0 - u)


func walk_to(x: float, speed := 300.0) -> void:
	e_dir = signf(x - e_x) if absf(x - e_x) > 1.0 else e_dir
	e_walk = true
	await go({"e_x": x}, absf(x - e_x) / speed, Tween.TRANS_LINEAR)
	e_walk = false


func say(text: String, pos: Vector2, dur := 1.3) -> void:
	if not text.begins_with("♪"):
		se("pop", -8.0)
	bubbles.append({"text": text, "pos": pos, "t0": t, "dur": dur})


func hero_say(text: String, dur := 1.4) -> void:
	say(text, Vector2(hero_x, GY - 212.0 * hero_scale + hero_y), dur)


func enemy_say(text: String, dur := 1.3) -> void:
	say(text, Vector2(e_x + 24.0 * e_dir * e_scale, GY + e_lane + e_y - e_stilts - 92.0 * e_scale), dur)


func sfx(text: String, pos: Vector2, dur := 1.0, col := Color(1.0, 0.85, 0.15), size := 58) -> void:
	sfxs.append({"text": text, "pos": pos, "t0": t, "dur": dur, "col": col, "size": size})
	var snd := sfx_sound(text)
	if snd != "":
		se(snd)


func puff(pos: Vector2, n: int, col: Color, spread := 140.0) -> void:
	for i in n:
		var v := Vector2(randf_range(-1.0, 1.0), randf_range(-1.2, -0.3)) * spread
		parts.append({"p": pos, "v": v, "life": 0.0, "max": randf_range(0.4, 0.8), "col": col, "size": randf_range(3.0, 7.0)})


func set_idle_arms() -> void:
	hero_arm_l = 0.25
	hero_arm_r = 0.25


# ============================================================ シーン状態

func reset_turn_state() -> void:
	fence_vis = true
	fence_h = 70.0
	fence_lift = 0.0
	lock_p = 0.0
	wire = 0.0
	wire_cut = 0.0
	hole_a = 0.0
	hole_b = 0.0
	hole_c = 0.0
	mound_a = 0.0
	cam_p = 0.0
	cam_track = false
	cam_cone = false
	trap_p = 0.0
	trap_door = 0.0
	trap_bait = true
	sign_p = 0.0
	sign_flip = 0.0
	guard_p = 0.0
	guard_x = 690.0
	guard_salute = false
	dog_p = 0.0
	dog_x = 560.0
	dog_y = 0.0
	dog_dir = -1.0
	dog_roll = 0.0
	dog_happy = false
	wall_p = 0.0
	moat_p = 0.0
	barb_p = 0.0
	cams_p = 0.0
	guards_p = 0.0
	crowd_p = 0.0
	hero_scan = false
	parade_on = false
	alarm_p = 0.0
	red_flash = false
	hero_x = 745.0
	hero_y = 0.0
	hero_tool = ""
	hero_working = false
	hero_cross = false
	hero_shock = false
	hero_frozen = false
	hero_sweat = false
	hero_follow = true
	hero_look = 0.0
	set_idle_arms()
	e_x = -200.0
	e_y = 0.0
	e_lane = 0.0
	e_dir = 1.0
	e_rot = 0.0
	e_scale = 1.0
	e_alpha = 1.0
	e_walk = false
	e_front = false
	e_look_up = 0.0
	e_hat = false
	e_hat_dy = 0.0
	e_salute = false
	e_box = 0.0
	e_stilts = 0.0
	e_sleep = false
	e_cutter = false
	e_stick = 0.0
	e_fish = false
	e_veg = false
	shake = 0.0
	quiet_a = 0.0


func _process(delta: float) -> void:
	t += delta
	if hero_working:
		hero_arm_r = 1.9 + sin(t * 18.0) * 0.7
		hero_arm_l = 0.6 + sin(t * 18.0 + 1.5) * 0.3
	if hero_scan:
		hero_look = sin(t * 7.0)
	if hero_follow:
		hero_look = lerpf(hero_look, clampf((e_x - hero_x) / 300.0, -1.0, 1.0), 0.12)
	guard_look = lerpf(guard_look, clampf((e_x - guard_x) / 300.0, -1.0, 1.0), 0.15)
	if cam_track:
		cam_tx = e_x
	else:
		cam_tx = 450.0 + sin(t * 3.0) * 160.0
	if mound_a > 0.0:
		pass
	for p in parts:
		p["life"] += delta
		p["v"] += Vector2(0, 520.0) * delta
		p["p"] += p["v"] * delta
	parts = parts.filter(func(p): return p["life"] < p["max"])
	bubbles = bubbles.filter(func(b): return t - b["t0"] < b["dur"])
	sfxs = sfxs.filter(func(b): return t - b["t0"] < b["dur"])
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	queue_redraw()


func _unhandled_input(ev: InputEvent) -> void:
	var pressed := false
	if ev is InputEventMouseButton and ev.pressed:
		pressed = true
	elif ev is InputEventKey and ev.pressed and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER):
		pressed = true
	if not pressed:
		return
	if state == "start":
		state = "opening"
		run_opening()
	elif state == "opening":
		skip_open = true
	elif state == "end" and end_ready:
		get_tree().reload_current_scene()


# ============================================================ 進行

func dur(x: float) -> float:
	return 0.05 if skip_open else x


func run_opening() -> void:
	state = "opening"
	cover = 1.0
	bgm("open", -6.0)
	await wait(dur(0.8))
	for i in OPENING.size():
		if i == 3:
			await wait(dur(2.2))
		var tw := create_tween()
		var idx := i
		tw.tween_method(func(v: float): open_alpha[idx] = v, 0.0, 1.0, dur(1.4))
		await tw.finished
		await wait(dur(1.4))
	await wait(dur(1.6))
	var tw2 := create_tween()
	tw2.tween_method(func(v: float):
		for k in 4:
			open_alpha[k] = v, 1.0, 0.0, dur(1.0))
	await tw2.finished
	await wait(dur(0.5))
	bgm_stop(1.0)
	run_intro()


func run_intro() -> void:
	state = "intro"
	reset_turn_state()
	hero_vis = 0.0
	await go({"cover": 0.0}, 0.8)
	await wait(0.4)
	sfx("ジャーン！", Vector2(W * 0.5, 330.0), 1.4, Color(1.0, 0.9, 0.2), 80)
	shake = 5.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "hero_vis", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "title_a", 1.0, 0.6)
	await tw.finished
	shake = 0.0
	bgm("main")
	await wait(0.4)
	hero_say("いたち対策は、\nいたちになって考えるところから始まる。", 3.6)
	await wait(3.9)
	hero_say("だから、着ている。", 2.0)
	await go({"title_a": 0.0}, 1.4)
	await begin_turn()


func begin_turn() -> void:
	state = "busy"
	turn += 1
	reset_turn_state()
	hero_vis = 1.0
	await go({"cover": 0.0}, 0.4)
	e_x = -160.0
	await walk_to(STOP_X, 330.0)
	var lines := ["畑にお邪魔するぞ！", "また来たぞ！", "今日もいくぞ！", "……また来たぞ。"]
	enemy_say(lines[mini(turn - 1, 3)], 1.4)
	if turn == 4:
		hero_say("こうなったら……アレだ。", 1.6)
	await wait(1.0)
	var ids: Array = ["perfect"] if turn > TURN_SETS.size() else TURN_SETS[turn - 1]
	show_buttons(ids)


func show_buttons(ids: Array) -> void:
	state = "choose"
	prompt_text = "最後の手段！" if ids[0] == "perfect" else "どうする？"
	var tw := create_tween()
	tw.tween_property(self, "prompt_a", 1.0, 0.25)
	for id in ids:
		var b := Button.new()
		b.text = LABELS[id]
		b.custom_minimum_size = Vector2(340, 78)
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_color", Color(0.25, 0.14, 0.05))
		b.add_theme_color_override("font_hover_color", Color(0.25, 0.14, 0.05))
		b.add_theme_color_override("font_pressed_color", Color(0.25, 0.14, 0.05))
		var base_col := Color(1.0, 0.7, 0.65) if id == "perfect" else Color(0.99, 0.93, 0.72)
		b.add_theme_stylebox_override("normal", make_sb(base_col))
		b.add_theme_stylebox_override("hover", make_sb(base_col.lightened(0.35)))
		b.add_theme_stylebox_override("pressed", make_sb(base_col.darkened(0.15)))
		b.add_theme_stylebox_override("focus", make_sb(base_col.lightened(0.35)))
		b.pressed.connect(_on_pick.bind(id))
		btn_box.add_child(b)
	if auto_test:
		await wait(0.4)
		if state == "choose":
			_on_pick(ids[auto_pick % ids.size()])


func make_sb(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(0.45, 0.28, 0.12)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	return sb


func clear_buttons() -> void:
	for c in btn_box.get_children():
		c.queue_free()
	prompt_a = 0.0


func _on_pick(id: String) -> void:
	if state != "choose":
		return
	state = "busy"
	clear_buttons()
	await wait(0.2)
	if id != "perfect" and turn <= 3:
		await recruit(["worker", "watcher", "guard"][turn - 1])
	match id:
		"fence": await m_fence()
		"hole": await m_hole()
		"wire": await m_wire()
		"camera": await m_camera()
		"trap": await m_trap()
		"sign": await m_sign()
		"guard": await m_guard()
		"lock": await m_lock()
		"dog": await m_dog()
		"perfect":
			await m_perfect()
			return
	await finish_turn()


func yosh() -> void:
	hero_arm_l = 2.7
	hero_arm_r = 2.7
	var tw := create_tween()
	tw.tween_property(self, "hero_y", -36.0, 0.14).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "hero_y", 0.0, 0.14).set_ease(Tween.EASE_IN)
	se("yosh")
	hero_say("よし！", 0.9)
	sfx("キラーン", Vector2(hero_x + 70.0, GY - 190.0), 0.8, Color(1.0, 1.0, 0.6), 32)
	await wait(0.45)
	hero_cross = true
	await wait(0.65)


func finish_turn() -> void:
	e_front = true
	e_dir = 1.0
	await walk_to(960.0, 300.0)
	e_veg = true
	stolen += 1
	sfx("ゲット！", Vector2(960.0, GY - 150.0), 1.0, Color(0.6, 1.0, 0.4), 52)
	puff(Vector2(960.0, GY + 10.0), 8, Color(0.5, 0.8, 0.35), 100.0)
	enemy_say("いただき！", 1.2)
	hero_cross = false
	hero_shock = true
	hero_sweat = true
	hero_follow = true
	set_idle_arms()
	hero_arm_l = 2.2
	hero_arm_r = 2.2
	breaches += 1
	se("shock")
	hero_say("ぐぬぬ……！", 1.4)
	await go({"hero_y": -20.0}, 0.1)
	await go({"hero_y": 0.0}, 0.1)
	await wait(1.5)
	await go({"cover": 1.0}, 0.4)
	await begin_turn()


# ============================================================ 対策ごとの寸劇

func m_fence() -> void:
	hero_tool = "wrench"
	hero_working = true
	sfx("ガガガッ！", Vector2(WALL_X, GY - 300.0), 1.5)
	shake = 5.0
	await go({"fence_h": 230.0}, 1.4, Tween.TRANS_QUAD, Tween.EASE_IN)
	shake = 0.0
	hero_working = false
	hero_tool = ""
	set_idle_arms()
	puff(Vector2(WALL_X, GY), 8, Color(0.8, 0.8, 0.8), 100.0)
	await yosh()
	# 見上げて止まる
	e_look_up = 1.0
	await go({"e_rot": -0.3}, 0.3)
	enemy_say("……高い。", 1.2)
	await wait(1.4)
	enemy_say("……", 0.8)
	await wait(0.6)
	e_look_up = 0.0
	await go({"e_rot": 0.0}, 0.2)
	sfx("！", Vector2(e_x + 20.0, GY - 130.0), 0.6, Color(1.0, 0.4, 0.3), 60)
	await wait(0.4)
	await walk_to(-260.0, 420.0)
	hero_say("……諦めたか。", 1.6)
	await wait(2.6)
	# 竹馬で再登場
	e_stilts = 238.0
	e_dir = 1.0
	hero_say("！？", 1.0)
	e_walk = true
	await go({"e_x": 620.0}, 3.2, Tween.TRANS_LINEAR)
	enemy_say("よいしょ", 0.9)
	await go({"e_x": 860.0}, 1.2, Tween.TRANS_LINEAR)
	e_walk = false
	await go({"e_stilts": 0.0}, 0.25, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	puff(Vector2(e_x, GY), 8, C_DIRT, 90.0)


func m_hole() -> void:
	hero_say("むっ、ここに穴が！", 1.2)
	await go({"hole_a": 1.0}, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT)
	await wait(1.0)
	hero_tool = "shovel"
	hero_working = true
	sfx("ザクザク！", Vector2(WALL_X - 40.0, GY - 190.0), 1.4)
	for i in 5:
		puff(Vector2(585.0, GY + 4.0), 5, C_DIRT, 110.0)
		await wait(0.22)
	await go({"hole_a": 0.0}, 0.3)
	hero_working = false
	hero_tool = ""
	set_idle_arms()
	sfx("ペタペタ", Vector2(585.0, GY - 70.0), 0.8, Color(0.85, 0.85, 0.85), 40)
	await yosh()
	# 前足でコンコン確認
	await walk_to(535.0, 220.0)
	for i in 3:
		await go({"e_y": -14.0}, 0.09)
		await go({"e_y": 0.0}, 0.09)
	sfx("コンコン", Vector2(570.0, GY - 90.0), 0.9, Color(1.0, 1.0, 1.0), 40)
	enemy_say("……ふむ。", 1.0)
	await wait(1.2)
	# 横にちょこちょこ
	e_dir = -1.0
	e_walk = true
	await go({"e_x": 430.0}, 1.0, Tween.TRANS_LINEAR)
	e_walk = false
	e_dir = 1.0
	# 新しい穴を掘る
	e_rot = 0.4
	sfx("ザッザッザッ", Vector2(430.0, GY - 90.0), 1.2)
	hero_say("……？", 1.0)
	for i in 6:
		puff(Vector2(470.0, GY + 4.0), 5, C_DIRT, 140.0)
		hole_b = float(i + 1) / 6.0
		await wait(0.17)
	e_rot = 0.0
	# もぐる
	await go({"e_y": 40.0, "e_alpha": 0.0, "hole_b": 1.0}, 0.3)
	mound_a = 1.0
	mound_x = 440.0
	sfx("モコモコ……", Vector2(560.0, GY - 60.0), 1.5, Color(0.9, 0.7, 0.4), 40)
	hero_follow = false
	await go({"mound_x": 690.0}, 1.5, Tween.TRANS_LINEAR)
	hero_say("………？", 1.0)
	# ひょっこり
	mound_a = 0.0
	hole_c = 1.0
	e_x = 690.0
	puff(Vector2(690.0, GY), 10, C_DIRT, 160.0)
	sfx("ボコッ！", Vector2(690.0, GY - 130.0), 0.9)
	hero_follow = true
	e_alpha = 1.0
	await go({"e_y": 0.0}, 0.2, Tween.TRANS_BACK, Tween.EASE_OUT)
	hero_shock = true
	hero_cross = false
	hero_say("えっ", 0.9)
	enemy_say("やあ", 1.0)
	await wait(1.1)
	hero_shock = false


func m_wire() -> void:
	hero_tool = "hammer"
	hero_working = true
	fence_vis = false
	sfx("カンカンカン！", Vector2(WALL_X, GY - 250.0), 1.4)
	await go({"wire": 1.0}, 1.4)
	hero_working = false
	hero_tool = ""
	set_idle_arms()
	await yosh()
	await walk_to(570.0, 230.0)
	enemy_say("ほう……", 1.0)
	await wait(1.2)
	e_cutter = true
	sfx("ジャキッ", Vector2(e_x + 40.0, GY - 120.0), 0.8, Color(0.8, 0.9, 1.0), 40)
	await wait(0.8)
	hero_say("ちょ", 0.8)
	sfx("パチン！パチン！", Vector2(WALL_X - 20.0, GY - 190.0), 1.3, Color(1.0, 0.85, 0.15), 48)
	await go({"wire_cut": 1.0}, 1.2, Tween.TRANS_LINEAR)
	e_cutter = false
	await wait(0.3)
	await walk_to(860.0, 260.0)


func m_camera() -> void:
	sfx("ピコーン！", Vector2(585.0, GY - 330.0), 0.9, Color(1.0, 0.5, 0.5), 44)
	await go({"cam_p": 1.0}, 0.5, Tween.TRANS_BACK, Tween.EASE_OUT)
	cam_track = true
	cam_cone = true
	hero_say("これで丸見えだ！", 1.3)
	await wait(0.6)
	hero_arm_l = 2.7
	hero_arm_r = 2.7
	await wait(0.4)
	hero_cross = true
	hero_say("よし！", 0.9)
	await wait(0.6)
	# カメラに追われる
	await go({"e_x": 400.0}, 0.5)
	await go({"e_x": 520.0}, 0.5)
	e_look_up = 1.0
	await go({"e_rot": -0.2}, 0.2)
	enemy_say("……", 1.0)
	await wait(1.4)
	e_look_up = 0.0
	e_rot = 0.0
	# 段ボール
	e_dir = 1.0
	await go({"e_box": 1.0}, 0.35, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	sfx("パサッ", Vector2(e_x, GY - 150.0), 0.8, Color(0.95, 0.8, 0.5), 40)
	puff(Vector2(e_x, GY), 6, Color(0.9, 0.8, 0.6), 80.0)
	await wait(0.5)
	cam_track = false
	cam_cone = false
	sfx("？", Vector2(585.0, GY - 330.0), 1.2, Color(1.0, 0.4, 0.4), 60)
	hero_say("……あれ？ 消えた？", 1.6)
	await wait(1.4)
	# 箱だけが動く
	sfx("スーッ", Vector2(e_x + 40.0, GY - 150.0), 1.6, Color(0.9, 0.9, 0.9), 40)
	hero_follow = false
	await go({"e_x": 570.0}, 1.4, Tween.TRANS_LINEAR)
	await hop(740.0, 70.0, 0.7)
	hero_say("……気のせいか。", 1.6)
	await go({"e_x": 900.0}, 1.4, Tween.TRANS_LINEAR)
	await go({"e_box": 0.0}, 0.3)
	hero_follow = true


func m_trap() -> void:
	sfx("ガシャン！", Vector2(trap_x, GY - 130.0), 0.9)
	shake = 6.0
	await go({"trap_p": 1.0}, 0.35, Tween.TRANS_QUAD, Tween.EASE_IN)
	shake = 0.0
	puff(Vector2(trap_x, GY), 8, C_DIRT, 90.0)
	hero_say("餌付きの箱罠だ！", 1.3)
	await wait(1.0)
	await yosh()
	await walk_to(420.0, 220.0)
	enemy_say("ふむふむ", 1.0)
	await wait(1.2)
	# 棒で餌だけ取る
	await go({"e_stick": 1.0}, 0.5)
	sfx("つんつん", Vector2(520.0, GY - 90.0), 0.9, Color(1.0, 1.0, 1.0), 38)
	await wait(0.9)
	trap_bait = false
	e_fish = true
	sfx("ひょい！", Vector2(500.0, GY - 120.0), 0.8)
	await go({"e_stick": 0.0}, 0.3)
	await go({"trap_door": 1.0}, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN)
	sfx("バタン！", Vector2(trap_x, GY - 100.0), 0.9, Color(1.0, 0.5, 0.4), 48)
	hero_shock = true
	hero_say("餌だけ！？", 1.0)
	for i in 3:
		await go({"e_y": -8.0}, 0.1)
		await go({"e_y": 0.0}, 0.1)
	sfx("もぐもぐ", Vector2(e_x + 50.0, GY - 120.0), 1.0, Color(1.0, 0.9, 0.7), 34)
	await wait(0.8)
	e_fish = false
	hero_shock = false
	# 罠の上で寝る
	await walk_to(trap_x - 55.0, 200.0)
	await hop(trap_x + 5.0, 40.0, 0.5, -58.0)
	e_sleep = true
	hero_shock = true
	hero_say("そこで寝るな！", 1.4)
	await wait(2.4)
	hero_shock = false
	e_sleep = false
	sfx("ふわぁ", Vector2(trap_x, GY - 150.0), 1.0, Color(1.0, 1.0, 1.0), 36)
	await wait(1.0)
	await hop(830.0, 150.0, 1.0, 0.0)


func m_sign() -> void:
	sfx("ドスッ！", Vector2(sign_x, GY - 200.0), 0.9)
	shake = 5.0
	await go({"sign_p": 1.0}, 0.35, Tween.TRANS_QUAD, Tween.EASE_IN)
	shake = 0.0
	puff(Vector2(sign_x, GY), 8, C_DIRT, 90.0)
	hero_say("これで入れまい！", 1.3)
	await wait(1.0)
	await yosh()
	await walk_to(410.0, 220.0)
	e_look_up = 1.0
	enemy_say("ふむふむ……", 1.1)
	await wait(1.6)
	e_look_up = 0.0
	await go({"e_y": -10.0}, 0.1)
	await go({"e_y": 0.0}, 0.1)
	enemy_say("なるほど", 1.0)
	await wait(1.0)
	await walk_to(sign_x - 50.0, 200.0)
	sfx("くるっ", Vector2(sign_x, GY - 210.0), 0.9, Color(1.0, 1.0, 1.0), 38)
	await go({"sign_flip": 1.0}, 0.6)
	hero_shock = true
	hero_say("ええぇ！？", 1.0)
	enemy_say("ふふん", 1.0)
	await wait(1.4)
	hero_shock = false
	await hop(725.0, 110.0, 0.7)
	await walk_to(880.0, 240.0)


func m_guard() -> void:
	var g := ally_of("guard")
	e_front = false
	await yosh()
	await walk_to(470.0, 200.0)
	hero_say("止まれ！", 1.0)
	await wait(0.9)
	# 帽子をかぶる
	e_hat = true
	e_hat_dy = -90.0
	await go({"e_hat_dy": 0.0}, 0.3, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	sfx("ビシッ！", Vector2(e_x + 20.0, GY - 150.0), 1.0, Color(1.0, 1.0, 1.0), 48)
	e_salute = true
	g["salute"] = true
	await wait(1.4)
	hero_say("ご苦労様です！", 1.3)
	hero_shock = true
	await wait(0.8)
	sfx("ウィーン", Vector2(WALL_X, GY - 220.0), 1.4, Color(0.8, 0.9, 1.0), 40)
	await go({"fence_lift": 110.0}, 0.9)
	e_front = true
	await walk_to(960.0, 190.0)
	hero_say("なんで！？", 1.2)
	e_salute = false
	e_hat = false
	await wait(0.8)
	hero_shock = false
	g["salute"] = false


func m_lock() -> void:
	sfx("ガチャン！", Vector2(WALL_X, GY - 160.0), 0.9)
	await go({"lock_p": 1.0}, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT)
	hero_say("鍵をかけた。これで完璧だ！", 1.7)
	await wait(1.5)
	await yosh()
	await walk_to(555.0, 220.0)
	hero_cross = false
	for i in 2:
		await go({"e_y": -10.0}, 0.1)
		await go({"e_y": 0.0}, 0.1)
		sfx("コンコン", Vector2(e_x + 60.0, GY - 130.0), 0.6, Color(1.0, 1.0, 1.0), 38)
		await wait(0.35)
	enemy_say("ごめんくださーい", 1.6)
	await wait(1.2)
	hero_say("はーい！", 1.0)
	hero_arm_l = 2.0
	hero_arm_r = 2.0
	await wait(0.4)
	sfx("ギギギ……", Vector2(WALL_X, GY - 260.0), 1.4, Color(0.8, 0.8, 0.8), 40)
	await go({"fence_lift": 100.0}, 1.0)
	e_front = true
	await walk_to(880.0, 240.0)
	hero_say("……今の、いたち？", 1.6)
	set_idle_arms()
	await wait(1.4)


func m_dog() -> void:
	sfx("ワン！", Vector2(dog_x, GY - 150.0), 0.9)
	await go({"dog_p": 1.0}, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT)
	hero_say("番犬だ！ 噛みつくぞ！", 1.5)
	await wait(1.2)
	await yosh()
	await walk_to(400.0, 220.0)
	for i in 3:
		sfx("ワンワン！", Vector2(dog_x, GY - 140.0), 0.5, Color(1.0, 0.5, 0.4), 44)
		await go({"dog_y": -22.0}, 0.1)
		await go({"dog_y": 0.0}, 0.1)
		await wait(0.2)
	await wait(0.3)
	# 尻尾ぶんぶん
	dog_happy = true
	enemy_say("……", 1.0)
	await wait(1.0)
	await go({"dog_x": 470.0}, 0.5)
	sfx("クンクン", Vector2(dog_x, GY - 120.0), 1.0, Color(1.0, 1.0, 1.0), 36)
	await wait(1.0)
	await go({"dog_roll": 1.0}, 0.4)
	sfx("ヘソ天", Vector2(dog_x, GY - 110.0), 1.0, Color(1.0, 0.8, 0.9), 38)
	hero_shock = true
	hero_say("おい！", 0.9)
	await wait(0.8)
	sfx("♥なでなで♥", Vector2(dog_x, GY - 150.0), 1.4, Color(1.0, 0.5, 0.7), 44)
	for i in 4:
		puff(Vector2(dog_x, GY - 40.0), 2, Color(1.0, 0.5, 0.7), 80.0)
		await go({"e_y": -6.0}, 0.12)
		await go({"e_y": 0.0}, 0.12)
	hero_shock = false
	await go({"dog_roll": 0.0}, 0.3)
	dog_dir = 1.0
	# 一緒に侵入(犬が案内)
	e_dir = 1.0
	e_walk = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "e_x", 580.0, 0.7).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(self, "dog_x", 640.0, 0.7).set_trans(Tween.TRANS_LINEAR)
	await tw.finished
	e_walk = false
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_method(_hop_step.bind(e_x, 760.0, 0.0, 0.0, 90.0), 0.0, 1.0, 0.7)
	tw2.tween_property(self, "dog_x", 790.0, 0.7)
	tw2.tween_method(_dog_hop_step.bind(100.0), 0.0, 1.0, 0.7)
	await tw2.finished
	e_walk = true
	hero_say("そっちじゃない！", 1.2)
	var tw3 := create_tween().set_parallel(true)
	tw3.tween_property(self, "e_x", 900.0, 0.8).set_trans(Tween.TRANS_LINEAR)
	tw3.tween_property(self, "dog_x", 940.0, 0.8).set_trans(Tween.TRANS_LINEAR)
	await tw3.finished
	await wait(0.4)


# ---------------------------------------------------------- 完璧な対策

func m_perfect() -> void:
	state = "final"
	bgm("final", -6.0)
	hero_say("完璧な対策を、する。", 2.0)
	await wait(2.0)
	hero_arm_l = 2.6
	hero_arm_r = 2.6
	# 巨大な壁
	sfx("ドドドドド！", Vector2(WALL_X, GY - 420.0), 1.6, Color(1.0, 0.8, 0.2), 70)
	shake = 9.0
	await go({"wall_p": 1.0}, 1.4, Tween.TRANS_QUAD, Tween.EASE_IN)
	shake = 0.0
	puff(Vector2(WALL_X, GY), 14, Color(0.8, 0.8, 0.8), 160.0)
	await wait(0.3)
	# 堀
	sfx("ザバーン！", Vector2(520.0, GY - 60.0), 1.2, Color(0.5, 0.8, 1.0), 56)
	await go({"moat_p": 1.0}, 0.7)
	# 有刺鉄線
	sfx("ジャキジャキ", Vector2(WALL_X, GY - 430.0), 1.2, Color(0.8, 0.8, 0.8), 44)
	await go({"barb_p": 1.0}, 0.8, Tween.TRANS_LINEAR)
	# 監視カメラ大量
	sfx("ピコピコピコ！", Vector2(560.0, GY - 330.0), 1.2, Color(1.0, 0.5, 0.5), 48)
	cam_track = true
	cam_cone = false
	var tc := create_tween().set_parallel(true)
	tc.tween_property(self, "cam_p", 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tc.tween_property(self, "cams_p", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tc.finished
	# 警備員
	sfx("ザッ！ザッ！ザッ！", Vector2(340.0, GY - 200.0), 1.2, Color(0.7, 0.85, 1.0), 44)
	await go({"guards_p": 1.0}, 0.6, Tween.TRANS_BACK, Tween.EASE_OUT)
	hero_say("作業員も、監視員も、総動員だ。", 1.6)
	sfx("ぞろぞろ", Vector2(1010.0, GY - 190.0), 1.0, Color(0.9, 0.9, 0.9), 40)
	await go({"crowd_p": 1.0}, 0.6, Tween.TRANS_BACK, Tween.EASE_OUT)
	# 警報装置
	sfx("ウーーーッ！！", Vector2(900.0, GY - 330.0), 1.6, Color(1.0, 0.25, 0.2), 60)
	await go({"alarm_p": 1.0}, 0.4, Tween.TRANS_BACK, Tween.EASE_OUT)
	red_flash = true
	shake = 3.0
	await wait(1.6)
	red_flash = false
	shake = 0.0
	# 満足げに腕組み
	hero_cross = true
	hero_follow = false
	hero_look = 0.0
	await wait(0.6)
	hero_say("ふっ。", 1.2)
	await wait(1.0)
	# しばし静寂
	bgm_stop()
	se("wind", -6.0)
	await go({"quiet_a": 1.0}, 0.5)
	await wait(2.6)
	await go({"quiet_a": 0.0}, 0.4)
	# いたちの列が通る(本物が混ざっている)
	e_front = true
	e_lane = 108.0
	e_scale = 1.25
	e_x = -760.0
	e_dir = 1.0
	e_walk = true
	parade_on = true
	_whistle()
	_parade_reactions()
	await go({"e_x": 1900.0}, 9.0, Tween.TRANS_LINEAR)
	e_walk = false
	parade_on = false
	hero_scan = false
	hero_shock = false
	hero_look = 0.0
	hero_arm_l = 0.25
	hero_arm_r = 0.25
	await wait(0.8)
	# ゆっくり振り返って固まる
	await go({"hero_look": 1.0}, 1.8)
	await wait(0.5)
	hero_frozen = true
	hero_sweat = true
	hero_shock = true
	hero_say("……どれだ？", 2.6)
	await wait(3.0)
	await go({"cover": 1.0}, 1.5)
	await wait(0.5)
	state = "end"
	se("end")
	await go({"end_a": 1.0}, 1.6)
	await wait(1.2)
	end_ready = true
	await go({"hint_a": 1.0}, 0.8)
	if auto_test:
		print("AUTO: ending reached")
		get_tree().quit()


func _parade_reactions() -> void:
	await wait(2.4)
	hero_cross = false
	hero_follow = false
	hero_scan = true
	hero_shock = true
	hero_arm_l = 2.2
	hero_arm_r = 2.2
	hero_say("侵入者はどれだ！？", 1.8)
	await wait(2.2)
	hero_say("どれだ！？ どれだ！？", 1.8)
	await wait(2.4)
	hero_say("みんな同じに見える……！", 2.0)


func _whistle() -> void:
	while e_x < 1300.0:
		say("♪ ふんふふ～ん", Vector2(e_x + 30.0, GY + e_lane - 135.0), 0.9)
		await wait(0.9)


# ============================================================ 描画

func ell(c: Vector2, r: Vector2, col: Color, rot := 0.0, n := 26) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	draw_colored_polygon(pts, col)


func txt(s: String, pos: Vector2, size: int, col: Color, outline := true, center := true) -> void:
	var lines := s.split("\n")
	var y := pos.y
	for ln in lines:
		var sz := font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var p := Vector2(pos.x - (sz.x * 0.5 if center else 0.0), y)
		if outline:
			draw_string_outline(font, p, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0.12, 0.07, 0.03, col.a))
		draw_string(font, p, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += size * 1.2


func reset_tf() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	draw_world()
	if not e_front:
		draw_enemy()
	draw_hero()
	if e_front:
		if parade_on:
			for k in PARADE.size():
				draw_crawler(e_x + PARADE[k][0], e_lane, PARADE[k][1], k * 1.7, e_scale)
		draw_enemy()
	draw_particles()
	draw_hud()
	draw_texts()
	if red_flash:
		draw_rect(Rect2(-20, -20, W + 40, H + 40), Color(1, 0, 0, 0.12 + 0.12 * sin(t * 14.0)))
	draw_rect(Rect2(-20, -20, W + 40, H + 40), Color(0, 0, 0, cover))
	draw_overlay()


func draw_world() -> void:
	# 空
	for i in 24:
		var k := float(i) / 23.0
		draw_rect(Rect2(0, i * GY / 24.0, W, GY / 24.0 + 1.0), Color(0.55, 0.8, 1.0).lerp(Color(0.88, 0.96, 1.0), k))
	ell(Vector2(1090, 110), Vector2(62, 62), Color(1, 0.95, 0.6, 0.35))
	ell(Vector2(1090, 110), Vector2(44, 44), Color(1, 0.93, 0.45))
	for i in 3:
		var cx := fposmod(160.0 + i * 460.0 + t * 8.0, W + 300.0) - 150.0
		var cy := 90.0 + i * 38.0
		ell(Vector2(cx, cy), Vector2(60, 22), Color(1, 1, 1, 0.9))
		ell(Vector2(cx + 34, cy - 12), Vector2(40, 22), Color(1, 1, 1, 0.9))
		ell(Vector2(cx - 30, cy - 8), Vector2(34, 18), Color(1, 1, 1, 0.9))
	# 丘と木
	ell(Vector2(260, GY + 10), Vector2(560, 160), Color(0.56, 0.79, 0.46))
	ell(Vector2(980, GY + 10), Vector2(620, 200), Color(0.47, 0.72, 0.4))
	for tx in [90.0, 230.0, 400.0]:
		draw_rect(Rect2(tx - 6, GY - 70, 12, 70), Color(0.45, 0.3, 0.16))
		ell(Vector2(tx, GY - 92), Vector2(38, 34), Color(0.3, 0.6, 0.3))
	# 倉庫
	draw_rect(Rect2(1110, GY - 150, 150, 150), Color(0.86, 0.72, 0.52))
	draw_colored_polygon(PackedVector2Array([Vector2(1095, GY - 148), Vector2(1185, GY - 205), Vector2(1275, GY - 148)]), Color(0.75, 0.3, 0.25))
	draw_rect(Rect2(1150, GY - 100, 70, 100), Color(0.4, 0.26, 0.14))
	draw_line(Vector2(1185, GY - 100), Vector2(1185, GY), Color(0.25, 0.15, 0.08), 3.0)
	txt("倉庫", Vector2(1185, GY - 112), 22, Color(1, 1, 1), true)
	# 地面
	draw_rect(Rect2(0, GY, W, H - GY), Color(0.48, 0.73, 0.34))
	draw_rect(Rect2(0, GY, W, 6), Color(0.38, 0.6, 0.27))
	draw_rect(Rect2(0, GY + 150, W, H - GY - 150), Color(0.43, 0.67, 0.31))
	# 畑
	draw_rect(Rect2(880, GY + 2, 400, 90), Color(0.5, 0.34, 0.2))
	for r in 4:
		draw_line(Vector2(880, GY + 14 + r * 22), Vector2(1280, GY + 14 + r * 22), Color(0.4, 0.26, 0.15), 3.0)
	var idx := 0
	for row in 2:
		for col in 8:
			if idx >= stolen * 2:
				var cp := Vector2(905 + col * 48, GY + 24 + row * 40)
				ell(cp, Vector2(18, 15), Color(0.45, 0.78, 0.35))
				ell(cp + Vector2(0, -2), Vector2(11, 9), Color(0.7, 0.9, 0.5))
				draw_arc(cp, 12, 0.4, 2.6, 8, Color(0.3, 0.6, 0.25), 2.0)
			idx += 1
	# 穴・もぐら塚
	draw_hole(585.0, hole_a)
	draw_hole(445.0, hole_b)
	draw_hole(690.0, hole_c)
	if mound_a > 0.0:
		var mw := 1.0 + 0.2 * sin(t * 22.0)
		ell(Vector2(mound_x, GY + 4), Vector2(38, 14 * mw), C_DIRT)
		ell(Vector2(mound_x - 8, GY - 4), Vector2(18, 10 * mw), C_DIRT.lightened(0.15))
	# 堀
	if moat_p > 0.0:
		var mw2 := 160.0 * moat_p
		draw_rect(Rect2(WALL_X - 60 - mw2, GY + 6, mw2, 40), Color(0.22, 0.5, 0.78))
		for i in 6:
			var wx := WALL_X - 60 - mw2 + fposmod(i * 30.0 + t * 20.0, maxf(mw2 - 10.0, 1.0))
			draw_line(Vector2(wx, GY + 18 + (i % 3) * 10), Vector2(wx + 18, GY + 18 + (i % 3) * 10), Color(0.7, 0.9, 1.0), 3.0)
		draw_rect(Rect2(WALL_X - 60 - mw2, GY + 6, mw2, 5), Color(0.15, 0.3, 0.5))
	# 看板
	draw_signboard()
	# 柵
	draw_fence()
	draw_wire()
	draw_bigwall()
	# 箱罠・犬
	draw_trap()
	if dog_p > 0.0:
		draw_dog(dog_x, dog_dir, dog_roll, dog_y)
	# 警備員
	for a in allies:
		draw_person(a["x"], a["kind"], a["suit"], a["salute"], clampf((e_x - a["x"]) / 300.0, -1.0, 1.0), 1.0)
	if guards_p > 0.0:
		for gx in [300.0, 360.0, 420.0]:
			draw_person(gx, "guard", true, false, clampf((e_x - gx) / 300.0, -1.0, 1.0), guards_p)
	if crowd_p > 0.0:
		var ck := ["worker", "watcher", "guard"]
		for i in 3:
			var cx := 960.0 + i * 58.0
			draw_person(cx, ck[i], true, false, clampf((e_x - cx) / 300.0, -1.0, 1.0), crowd_p)
	# カメラ
	if cam_p > 0.0:
		draw_cam(Vector2(585, GY - 260), cam_p, true)
	if cams_p > 0.0:
		draw_cam(Vector2(WALL_X - 34, GY - 358), cams_p, false)
		draw_cam(Vector2(WALL_X + 34, GY - 358), cams_p, false)
		draw_cam(Vector2(500, GY - 200), cams_p, true)
		draw_cam(Vector2(1000, GY - 220), cams_p, true)
	# 警報
	if alarm_p > 0.0:
		draw_rect(Rect2(870, GY - 260 * alarm_p, 8, 260 * alarm_p), Color(0.35, 0.35, 0.4))
		var ap := Vector2(874, GY - 270 * alarm_p)
		ell(ap, Vector2(20, 16), Color(0.9, 0.15, 0.1) if int(t * 6.0) % 2 == 0 else Color(1.0, 0.6, 0.5))
		draw_rect(Rect2(ap.x - 22, ap.y + 8, 44, 8), Color(0.3, 0.3, 0.35))
		if red_flash:
			var a := t * 10.0
			draw_colored_polygon(PackedVector2Array([ap, ap + Vector2(cos(a - 0.3), sin(a - 0.3)) * 160.0, ap + Vector2(cos(a + 0.3), sin(a + 0.3)) * 160.0]), Color(1, 0.2, 0.1, 0.25))


func draw_hole(x: float, a: float) -> void:
	if a <= 0.0:
		return
	ell(Vector2(x, GY + 6), Vector2(44 * a, 13 * a), C_DIRT.lightened(0.2))
	ell(Vector2(x, GY + 8), Vector2(34 * a, 9 * a), Color(0.12, 0.07, 0.04))


func draw_fence() -> void:
	if not fence_vis or wall_p > 0.3:
		return
	var bot := GY - fence_lift
	var top := bot - fence_h
	ell(Vector2(WALL_X, GY + 4), Vector2(48, 8), Color(0, 0, 0, 0.15))
	for i in 3:
		var x := WALL_X - 33.0 + i * 23.0
		draw_rect(Rect2(x, top + 12, 21, fence_h - 12), C_WOOD)
		draw_colored_polygon(PackedVector2Array([Vector2(x, top + 12), Vector2(x + 10.5, top), Vector2(x + 21, top + 12)]), C_WOOD)
		draw_line(Vector2(x + 21, top + 12), Vector2(x + 21, bot), C_WOOD_D, 2.0)
	draw_rect(Rect2(WALL_X - 38, top + fence_h * 0.22, 76, 8), C_WOOD_D)
	draw_rect(Rect2(WALL_X - 38, top + fence_h * 0.72, 76, 8), C_WOOD_D)
	if lock_p > 0.0:
		var lc := Vector2(WALL_X, (top + bot) * 0.5 - 4.0)
		draw_set_transform(lc, sin(t * 3.0) * 0.08, Vector2(lock_p, lock_p))
		draw_arc(Vector2(0, -8), 11, PI, TAU, 12, Color(0.6, 0.6, 0.65), 5.0)
		draw_rect(Rect2(-15, -8, 30, 24), Color(0.95, 0.75, 0.15))
		draw_rect(Rect2(-15, -8, 30, 24), Color(0.5, 0.35, 0.05), false, 2.0)
		ell(Vector2(0, 2), Vector2(4, 4), Color(0.2, 0.12, 0.02))
		draw_rect(Rect2(-1.5, 3, 3, 8), Color(0.2, 0.12, 0.02))
		reset_tf()


func draw_wire() -> void:
	if wire <= 0.0:
		return
	var h := 190.0 * wire
	var xl := WALL_X - 40.0
	var xr := WALL_X + 40.0
	var top := GY - h
	var bottom := GY - 96.0 * wire_cut
	draw_line(Vector2(xl, GY), Vector2(xl, top - 6), Color(0.5, 0.52, 0.56), 6.0)
	draw_line(Vector2(xr, GY), Vector2(xr, top - 6), Color(0.5, 0.52, 0.56), 6.0)
	var mesh := Color(0.6, 0.65, 0.72)
	if bottom > top:
		var x := xl
		while x <= xr + 1.0:
			draw_line(Vector2(x, top), Vector2(x, bottom), mesh, 2.0)
			x += 13.3
		var y := top
		while y <= bottom + 0.5:
			draw_line(Vector2(xl, y), Vector2(xr, y), mesh, 2.0)
			y += 13.0
	if wire_cut > 0.0:
		for k in 5:
			var x2 := xl + 8.0 + k * 16.0
			draw_line(Vector2(x2, bottom), Vector2(x2 + (k - 2) * 3.0, bottom + 9), mesh, 2.0)


func draw_bigwall() -> void:
	if wall_p <= 0.0:
		return
	var hgt := 340.0 * wall_p
	var x0 := WALL_X - 52.0
	var w := 104.0
	draw_rect(Rect2(x0, GY - hgt, w, hgt), Color(0.66, 0.63, 0.62))
	var y := 0.0
	var row := 0
	while y < hgt:
		draw_line(Vector2(x0, GY - y), Vector2(x0 + w, GY - y), Color(0.45, 0.42, 0.42), 2.0)
		var off := 0.0 if row % 2 == 0 else 17.0
		var bx := x0 + off
		while bx < x0 + w:
			draw_line(Vector2(bx, GY - y), Vector2(bx, GY - y - 24.0), Color(0.45, 0.42, 0.42), 2.0)
			bx += 34.0
		y += 24.0
		row += 1
	draw_rect(Rect2(x0, GY - hgt, w, hgt), Color(0.3, 0.28, 0.28), false, 3.0)
	for i in 4:
		draw_rect(Rect2(x0 + i * 29.0, GY - hgt - 16.0, 20, 16), Color(0.66, 0.63, 0.62))
	if barb_p > 0.0:
		var by := GY - hgt - 28.0
		var n := int(14.0 * barb_p)
		var prev := Vector2(x0 - 8.0, by)
		for i in n:
			var p := Vector2(x0 - 8.0 + (i + 1) * 8.5, by + (-8.0 if i % 2 == 0 else 8.0))
			draw_line(prev, p, Color(0.25, 0.25, 0.3), 2.5)
			draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), Color(0.25, 0.25, 0.3), 2.0)
			draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), Color(0.25, 0.25, 0.3), 2.0)
			prev = p


func draw_trap() -> void:
	if trap_p <= 0.0:
		return
	var dy := -(1.0 - trap_p) * 520.0
	var cx := trap_x
	var top := GY - 56.0 + dy
	ell(Vector2(cx, GY + 4), Vector2(55, 8), Color(0, 0, 0, 0.15))
	draw_rect(Rect2(cx - 45, top, 90, 56), Color(0.7, 0.75, 0.82, 0.25))
	for i in 7:
		draw_line(Vector2(cx - 45 + i * 15.0, top), Vector2(cx - 45 + i * 15.0, top + 56), Color(0.45, 0.48, 0.52), 2.0)
	draw_rect(Rect2(cx - 45, top, 90, 56), Color(0.35, 0.38, 0.42), false, 3.0)
	draw_rect(Rect2(cx - 47, top - 4, 94, 8), Color(0.3, 0.32, 0.36))
	if trap_bait:
		ell(Vector2(cx + 8, GY - 14 + dy), Vector2(15, 7), Color(1.0, 0.55, 0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 20, GY - 14 + dy), Vector2(cx + 31, GY - 22 + dy), Vector2(cx + 31, GY - 6 + dy)]), Color(1.0, 0.55, 0.2))
	if trap_door > 0.0:
		draw_rect(Rect2(cx - 50, top, 8, 56 * trap_door), Color(0.25, 0.27, 0.3))


func draw_signboard() -> void:
	if sign_p <= 0.0:
		return
	var dy := -(1.0 - sign_p) * 520.0
	var x := sign_x
	draw_rect(Rect2(x - 5, GY - 140 + dy, 10, 140), C_WOOD_D)
	var sc := cos(sign_flip * PI)
	draw_set_transform(Vector2(x, GY - 105 + dy), 0.0, Vector2(maxf(absf(sc), 0.03), 1.0))
	if sc >= 0.0:
		draw_rect(Rect2(-64, -36, 128, 72), Color(1, 0.97, 0.9))
		draw_rect(Rect2(-64, -36, 128, 72), Color(0.8, 0.15, 0.1), false, 5.0)
		txt("いたち\n立入禁止", Vector2(0, -6), 26, Color(0.8, 0.1, 0.05), false)
	else:
		draw_rect(Rect2(-64, -36, 128, 72), Color(0.85, 1.0, 0.85))
		draw_rect(Rect2(-64, -36, 128, 72), Color(0.2, 0.6, 0.25), false, 5.0)
		txt("ようこそ！\nいたち歓迎", Vector2(0, -6), 26, Color(0.1, 0.5, 0.15), false)
	reset_tf()


func draw_cam(pos: Vector2, p: float, post: bool) -> void:
	if post:
		draw_line(Vector2(pos.x, GY), pos, Color(0.35, 0.37, 0.42), 8.0)
	var target := Vector2(cam_tx, GY + e_lane - 25.0)
	var ang := (target - pos).angle()
	if cam_cone:
		var perp := (target - pos).orthogonal().normalized() * 26.0
		draw_colored_polygon(PackedVector2Array([pos, target + perp, target - perp]), Color(1, 1, 0.4, 0.2))
	draw_set_transform(pos, ang, Vector2(p, p))
	draw_rect(Rect2(-20, -12, 42, 24), Color(0.28, 0.3, 0.34))
	draw_rect(Rect2(-20, -12, 42, 24), Color(0.12, 0.13, 0.16), false, 2.0)
	ell(Vector2(24, 0), Vector2(8, 11), Color(0.1, 0.12, 0.2))
	ell(Vector2(26, -3), Vector2(3, 4), Color(0.6, 0.8, 1.0))
	if int(t * 3.0) % 2 == 0:
		ell(Vector2(-11, -6), Vector2(3, 3), Color(1.0, 0.2, 0.15))
	reset_tf()
	ell(pos, Vector2(8 * p, 8 * p), Color(0.2, 0.22, 0.26))


func draw_person(x: float, kind: String, suit: bool, salute: bool, look: float, p: float) -> void:
	if p <= 0.0:
		return
	draw_set_transform(Vector2(x, GY), 0.0, Vector2(p, p))
	ell(Vector2(0, 3), Vector2(30, 6), Color(0, 0, 0, 0.15))
	var uni := C_NAVY
	if kind == "worker":
		uni = Color(0.95, 0.55, 0.12)
	elif kind == "watcher":
		uni = Color(0.35, 0.5, 0.45)
	var hy := -102.0
	if suit:
		ell(Vector2(24, -40), Vector2(8, 22), C_BROWN, 0.6)
		for sx in [-1.0, 1.0]:
			ell(Vector2(sx * 9, -17), Vector2(8, 17), C_BROWN)
			ell(Vector2(sx * 10, -4), Vector2(10, 5), C_CREAM)
		ell(Vector2(0, -58), Vector2(27, 32), C_BROWN)
		ell(Vector2(0, -55), Vector2(17, 22), C_CREAM)
		draw_line(Vector2(0, -78), Vector2(0, -36), Color(0.55, 0.55, 0.6), 2.0)
		draw_line(Vector2(-24, -76), Vector2(-30, -44), C_BROWN, 14.0)
		ell(Vector2(-30, -42), Vector2(7, 7), C_CREAM)
		if salute:
			draw_line(Vector2(24, -76), Vector2(36, -100), C_BROWN, 14.0)
			draw_line(Vector2(36, -100), Vector2(15, -112), C_BROWN, 12.0)
			ell(Vector2(13, -112), Vector2(7, 7), C_CREAM)
		else:
			draw_line(Vector2(24, -76), Vector2(30, -44), C_BROWN, 14.0)
			ell(Vector2(30, -42), Vector2(7, 7), C_CREAM)
		ell(Vector2(0, hy), Vector2(27, 25), C_BROWN)
		ell(Vector2(-19, hy - 20), Vector2(8, 10), C_BROWN, -0.3)
		ell(Vector2(19, hy - 20), Vector2(8, 10), C_BROWN, 0.3)
		ell(Vector2(-19, hy - 19), Vector2(4, 6), Color(1.0, 0.7, 0.72), -0.3)
		ell(Vector2(19, hy - 19), Vector2(4, 6), Color(1.0, 0.7, 0.72), 0.3)
		ell(Vector2(look * 2.0, hy + 3), Vector2(17, 17), C_SKIN)
	else:
		draw_rect(Rect2(-15, -34, 13, 34), uni.darkened(0.4))
		draw_rect(Rect2(2, -34, 13, 34), uni.darkened(0.4))
		draw_rect(Rect2(-17, -5, 16, 5), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(1, -5, 16, 5), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(-23, -84, 46, 54), uni)
		draw_rect(Rect2(-23, -48, 46, 6), Color(0.08, 0.08, 0.1))
		draw_line(Vector2(-23, -78), Vector2(-31, -44), uni, 11.0)
		ell(Vector2(-31, -42), Vector2(6, 6), C_SKIN)
		if salute:
			draw_line(Vector2(23, -78), Vector2(36, -102), uni, 11.0)
			draw_line(Vector2(36, -102), Vector2(14, -112), uni, 9.0)
			ell(Vector2(12, -112), Vector2(6, 6), C_SKIN)
		else:
			draw_line(Vector2(23, -78), Vector2(31, -44), uni, 11.0)
			ell(Vector2(31, -42), Vector2(6, 6), C_SKIN)
		ell(Vector2(0, hy), Vector2(18, 19), C_SKIN)
	for sx in [-1.0, 1.0]:
		ell(Vector2(sx * 7 + look * 3.0, hy + 1), Vector2(2.4, 3.2), Color(0.1, 0.07, 0.05))
	draw_arc(Vector2(look * 2.0, hy + 8), 5, 0.3, PI - 0.3, 8, Color(0.4, 0.15, 0.1), 2.0)
	match kind:
		"guard":
			ell(Vector2(0, hy - 14), Vector2(19, 8), C_NAVY)
			draw_rect(Rect2(-19, hy - 16, 38, 6), C_NAVY)
			draw_rect(Rect2(-6 + look * 6, hy - 11, 28, 4), Color(0.1, 0.12, 0.3))
			ell(Vector2(0, hy - 16), Vector2(3.5, 3.5), Color(1, 0.85, 0.2))
			draw_rect(Rect2(-12 + look * 3, hy - 3, 24, 7), Color(0.05, 0.05, 0.05))
		"worker":
			ell(Vector2(0, hy - 13), Vector2(20, 12), Color(1.0, 0.85, 0.1))
			draw_rect(Rect2(-24, hy - 8, 48, 5), Color(0.95, 0.75, 0.05))
			draw_rect(Rect2(-3, hy - 24, 6, 10), Color(0.95, 0.75, 0.05))
		"watcher":
			draw_arc(Vector2(0, hy - 2), 22, PI + 0.2, TAU - 0.2, 12, Color(0.2, 0.2, 0.25), 4.0)
			ell(Vector2(-22, hy + 2), Vector2(6, 8), Color(0.2, 0.2, 0.25))
			draw_line(Vector2(-22, hy + 8), Vector2(-10, hy + 14), Color(0.2, 0.2, 0.25), 3.0)
			ell(Vector2(-9, hy + 14), Vector2(3, 3), Color(0.9, 0.2, 0.2))
	reset_tf()


func draw_crawler(x: float, lane: float, kind: String, phase: float, sc: float) -> void:
	draw_set_transform(Vector2(x, GY + lane), 0.0, Vector2(sc, sc))
	var bob := -absf(sin(t * 16.0 + phase)) * 3.0
	ell(Vector2(0, 4), Vector2(62, 8), Color(0, 0, 0, 0.15))
	ell(Vector2(-80, -46 + bob), Vector2(36, 11), C_BROWN, -0.35 + sin(t * 5.0) * 0.06)
	for i in 4:
		var off := sin(t * 16.0 + phase + i * PI * 0.5) * 7.0
		ell(Vector2(-44.0 + i * 30.0 + off, -9), Vector2(8, 10), C_BROWN_D)
	ell(Vector2(0, -34 + bob), Vector2(68, 23), C_BROWN)
	ell(Vector2(6, -26 + bob), Vector2(52, 11), C_CREAM)
	ell(Vector2(70, -48 + bob), Vector2(27, 25), C_BROWN)
	ell(Vector2(56, -70 + bob), Vector2(8, 10), C_BROWN)
	ell(Vector2(84, -70 + bob), Vector2(8, 10), C_BROWN)
	ell(Vector2(73, -46 + bob), Vector2(19, 19), C_SKIN)
	ell(Vector2(80, -50 + bob), Vector2(2.6, 3.4), Color(0.1, 0.07, 0.05))
	ell(Vector2(67, -50 + bob), Vector2(2.6, 3.4), Color(0.1, 0.07, 0.05))
	draw_arc(Vector2(74, -40 + bob), 5, 0.3, PI - 0.3, 8, Color(0.4, 0.15, 0.1), 2.0)
	match kind:
		"guard":
			ell(Vector2(70, -68 + bob), Vector2(19, 8), C_NAVY)
			draw_rect(Rect2(66, -66 + bob, 28, 4), C_NAVY)
		"worker":
			ell(Vector2(70, -68 + bob), Vector2(20, 11), Color(1.0, 0.85, 0.1))
			draw_rect(Rect2(48, -64 + bob, 48, 4), Color(0.95, 0.75, 0.05))
		"watcher":
			draw_arc(Vector2(72, -50 + bob), 22, PI + 0.2, TAU - 0.2, 12, Color(0.2, 0.2, 0.25), 4.0)
			ell(Vector2(50, -48 + bob), Vector2(6, 8), Color(0.2, 0.2, 0.25))
	reset_tf()


func draw_dog(x: float, dir: float, roll: float, yoff: float) -> void:
	draw_set_transform(Vector2(x, GY - 28.0 + yoff), PI * roll, Vector2(dir, 1.0))
	var fur := Color(0.9, 0.72, 0.45)
	var fur_d := Color(0.6, 0.4, 0.22)
	for lx in [-26.0, -12.0, 14.0, 28.0]:
		draw_rect(Rect2(lx - 5, 8, 10, 22), fur)
	var wag := sin(t * (26.0 if dog_happy else 6.0)) * 12.0
	draw_line(Vector2(-36, -8), Vector2(-54, -28 + wag), fur, 8.0)
	ell(Vector2(0, 0), Vector2(40, 22), fur)
	ell(Vector2(-12, -8), Vector2(14, 10), fur_d)
	ell(Vector2(42, -14), Vector2(20, 18), fur)
	ell(Vector2(36, -28), Vector2(8, 14), fur_d, 0.3)
	ell(Vector2(56, -8), Vector2(11, 8), C_CREAM)
	ell(Vector2(65, -10), Vector2(4.5, 4), Color(0.1, 0.08, 0.06))
	ell(Vector2(47, -19), Vector2(3.5, 3.5), Color(0.1, 0.08, 0.06))
	if dog_happy:
		ell(Vector2(58, 1), Vector2(5, 7), Color(1.0, 0.5, 0.55))
	draw_line(Vector2(30, 2), Vector2(34, -22), Color(0.85, 0.15, 0.15), 5.0)
	reset_tf()


func ea(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * e_alpha)


func draw_enemy() -> void:
	if e_alpha <= 0.01:
		return
	var sc := e_scale
	var base := Vector2(e_x, GY + e_lane + e_y)
	var bob := -absf(sin(t * 16.0)) * 3.0 if e_walk else 0.0
	var lift := e_stilts
	# 影
	ell(Vector2(e_x, GY + e_lane + 4), Vector2(62 * sc, 8 * sc), Color(0, 0, 0, 0.15 * e_alpha))
	# 竹馬
	if lift > 0.0:
		draw_set_transform(base, 0.0, Vector2(e_dir * sc, sc))
		for k in 2:
			var sx := -36.0 + k * 78.0
			var ph := sin(t * 8.0 + k * PI) * 7.0 if e_walk else 0.0
			draw_line(Vector2(sx, -lift + 20), Vector2(sx - ph, -absf(ph) * 0.4), ea(C_WOOD_D), 12.0, true)
			draw_rect(Rect2(sx - 20, -lift * 0.3 - absf(ph) * 0.2, 40, 10), ea(C_WOOD))
	draw_set_transform(base + Vector2(0, -lift * sc), e_rot * e_dir, Vector2(e_dir * sc, sc))
	var br := ea(C_BROWN)
	var brd := ea(C_BROWN_D)
	var cr := ea(C_CREAM)
	# しっぽ
	ell(Vector2(-80, -46 + bob), Vector2(36, 11), br, -0.35 + sin(t * 5.0) * 0.06)
	ell(Vector2(-108, -56 + bob), Vector2(12, 8), brd, -0.35)
	# 足
	for i in 4:
		var lx := -44.0 + i * 30.0
		var off := sin(t * 16.0 + i * PI * 0.5) * 7.0 if e_walk else 0.0
		ell(Vector2(lx + off, -9), Vector2(8, 10), brd)
	# 体
	ell(Vector2(0, -34 + bob), Vector2(68, 23), br)
	ell(Vector2(6, -26 + bob), Vector2(52, 11), cr)
	# 頭
	ell(Vector2(70, -46 + bob), Vector2(26, 22), br)
	ell(Vector2(60, -67 + bob), Vector2(8, 10), br)
	ell(Vector2(80, -67 + bob), Vector2(8, 10), br)
	ell(Vector2(60, -66 + bob), Vector2(4, 6), ea(Color(1.0, 0.7, 0.7)))
	ell(Vector2(80, -66 + bob), Vector2(4, 6), ea(Color(1.0, 0.7, 0.7)))
	ell(Vector2(90, -41 + bob), Vector2(12, 10), cr)
	ell(Vector2(100, -43 + bob), Vector2(4.5, 4), ea(Color(0.1, 0.07, 0.05)))
	ell(Vector2(77, -50 + bob), Vector2(11, 8), brd)
	if e_sleep:
		draw_arc(Vector2(77, -50 + bob), 5, 0.2, PI - 0.2, 8, ea(Color(0.1, 0.07, 0.05)), 2.5)
	else:
		ell(Vector2(77, -51 + bob), Vector2(6, 6), ea(Color.WHITE))
		ell(Vector2(78.5, -51 - e_look_up * 3.0 + bob), Vector2(3.2, 3.5), ea(Color(0.05, 0.03, 0.02)))
	draw_line(Vector2(94, -40 + bob), Vector2(114, -46 + bob), ea(Color(0.3, 0.2, 0.1)), 1.5)
	draw_line(Vector2(94, -37 + bob), Vector2(114, -35 + bob), ea(Color(0.3, 0.2, 0.1)), 1.5)
	# 帽子
	if e_hat:
		var hy := e_hat_dy + bob
		ell(Vector2(70, -67 + hy), Vector2(22, 10), ea(C_NAVY))
		draw_rect(Rect2(50, -69 + hy, 40, 8), ea(C_NAVY))
		ell(Vector2(84, -61 + hy), Vector2(22, 4.5), ea(Color(0.1, 0.14, 0.3)))
		ell(Vector2(72, -68 + hy), Vector2(4, 4), ea(Color(1, 0.85, 0.2)))
	if e_salute:
		draw_line(Vector2(56, -26 + bob), Vector2(86, -60 + bob), brd, 9.0)
		ell(Vector2(88, -62 + bob), Vector2(6, 6), brd)
	if e_stick > 0.0:
		draw_line(Vector2(62, -26 + bob), Vector2(62 + 75.0 * e_stick, -24 - 5.0 * e_stick + bob), ea(C_WOOD_D), 5.0)
		ell(Vector2(62, -26 + bob), Vector2(6, 6), brd)
	if e_cutter:
		var sw := 0.12 + 0.3 * absf(sin(t * 20.0))
		var pv := Vector2(104, -34 + bob)
		draw_line(pv, pv + Vector2(24, 0).rotated(-sw), ea(Color(0.85, 0.9, 0.95)), 3.0)
		draw_line(pv, pv + Vector2(24, 0).rotated(sw), ea(Color(0.85, 0.9, 0.95)), 3.0)
		draw_line(pv, pv + Vector2(-14, 0).rotated(-sw), ea(Color(0.95, 0.5, 0.15)), 4.0)
		draw_line(pv, pv + Vector2(-14, 0).rotated(sw), ea(Color(0.95, 0.5, 0.15)), 4.0)
	if e_fish:
		ell(Vector2(104, -30 + bob), Vector2(14, 6), ea(Color(1.0, 0.55, 0.2)), 0.3)
		draw_colored_polygon(PackedVector2Array([Vector2(116, -28 + bob), Vector2(128, -36 + bob), Vector2(128, -20 + bob)]), ea(Color(1.0, 0.55, 0.2)))
	if e_veg:
		ell(Vector2(100, -28 + bob), Vector2(15, 13), ea(Color(0.45, 0.78, 0.35)))
		ell(Vector2(100, -29 + bob), Vector2(9, 8), ea(Color(0.7, 0.9, 0.5)))
	# 段ボール
	if e_box > 0.0:
		var by := -(1.0 - e_box) * 440.0
		draw_rect(Rect2(-98, -94 + by, 202, 94), ea(Color(0.82, 0.62, 0.36)))
		draw_rect(Rect2(-98, -94 + by, 202, 94), ea(Color(0.5, 0.35, 0.18)), false, 3.0)
		draw_rect(Rect2(-98, -94 + by, 202, 14), ea(Color(0.9, 0.72, 0.45)))
		draw_rect(Rect2(-8, -94 + by, 16, 94), ea(Color(0.9, 0.82, 0.6)))
		draw_rect(Rect2(52, -64 + by, 36, 9), ea(Color(0.1, 0.07, 0.05)))
		ell(Vector2(60, -59.5 + by), Vector2(3.5, 3.5), ea(Color.WHITE))
		ell(Vector2(76, -59.5 + by), Vector2(3.5, 3.5), ea(Color.WHITE))
		txt("みかん", Vector2(-44, -28 + by), 26, ea(Color(0.55, 0.3, 0.08)), false)
	reset_tf()
	if e_sleep:
		var zp := Vector2(e_x + 70.0 * e_dir * sc, GY + e_lane + e_y - lift - 100.0 * sc)
		txt("Zzz", zp + Vector2(0, sin(t * 3.0) * 6.0), 36, Color(1, 1, 1), true)


func draw_hero() -> void:
	if hero_vis <= 0.01:
		return
	var s := hero_vis * hero_scale
	var bob := sin(t * 3.0) * 2.0
	var fr := hero_frozen
	var tint := func(c: Color) -> Color:
		return c.lerp(Color(0.78, 0.82, 0.88), 0.75) if fr else c
	var br: Color = tint.call(C_BROWN)
	var brd: Color = tint.call(C_BROWN_D)
	var cr: Color = tint.call(C_CREAM)
	var sk: Color = tint.call(C_SKIN)
	ell(Vector2(hero_x, GY + 4), Vector2(60 * s, 9 * s), Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2(hero_x, GY + hero_y), 0.0, Vector2(s, s))
	# しっぽ
	ell(Vector2(62, -62 + bob), Vector2(16, 40), br, 0.6 + sin(t * 4.0) * 0.05)
	ell(Vector2(78, -92 + bob), Vector2(10, 14), brd, 0.6)
	# 足
	for sx in [-1.0, 1.0]:
		ell(Vector2(sx * 18, -24), Vector2(14, 24), br)
		ell(Vector2(sx * 21, -7), Vector2(18, 8), cr)
	# 体
	ell(Vector2(0, -88 + bob * 0.5), Vector2(50, 52), br)
	ell(Vector2(0, -82 + bob * 0.5), Vector2(32, 38), cr)
	# ファスナー
	draw_line(Vector2(0, -124 + bob * 0.5), Vector2(0, -48 + bob * 0.5), tint.call(Color(0.55, 0.55, 0.6)), 3.0)
	for i in 7:
		draw_line(Vector2(-4, -118 + i * 10.0 + bob * 0.5), Vector2(4, -118 + i * 10.0 + bob * 0.5), tint.call(Color(0.4, 0.4, 0.45)), 2.0)
	ell(Vector2(0, -120 + bob * 0.5), Vector2(5, 7), tint.call(Color(0.9, 0.8, 0.2)))
	# 腕
	var sh_l := Vector2(-42, -112 + bob * 0.5)
	var sh_r := Vector2(42, -112 + bob * 0.5)
	var hand_l := sh_l + Vector2(-sin(hero_arm_l), cos(hero_arm_l)) * 54.0
	var hand_r := sh_r + Vector2(sin(hero_arm_r), cos(hero_arm_r)) * 54.0
	if hero_cross:
		hand_l = Vector2(16, -92 + bob * 0.5)
		hand_r = Vector2(-16, -92 + bob * 0.5)
	draw_line(sh_l, hand_l, br, 24.0)
	draw_line(sh_r, hand_r, br, 24.0)
	ell(sh_l, Vector2(12, 12), br)
	ell(sh_r, Vector2(12, 12), br)
	ell(hand_l, Vector2(13, 13), cr)
	ell(hand_r, Vector2(13, 13), cr)
	# 道具
	if hero_tool != "":
		var d := (hand_r - sh_r).normalized()
		var n := d.orthogonal()
		var tip := hand_r + d * 56.0
		draw_line(hand_r - d * 10.0, tip, tint.call(C_WOOD_D), 7.0)
		match hero_tool:
			"wrench":
				ell(tip, Vector2(15, 12), tint.call(Color(0.7, 0.72, 0.78)), d.angle())
				ell(tip + d * 6.0, Vector2(6, 5), tint.call(Color(0.5, 0.78, 0.9)), d.angle())
			"hammer":
				draw_colored_polygon(PackedVector2Array([tip + n * 14 - d * 8, tip + n * 14 + d * 12, tip - n * 14 + d * 12, tip - n * 14 - d * 8]), tint.call(Color(0.5, 0.52, 0.58)))
			"shovel":
				ell(tip + d * 8.0, Vector2(13, 18), tint.call(Color(0.6, 0.62, 0.68)), d.angle())
	# 頭(フード)
	var hx := hero_look * 8.0
	var hy := -150.0 + bob + (-6.0 if hero_shock else 0.0)
	var hc := Vector2(hx, hy)
	var tilt := hero_look * 0.12
	ell(hc, Vector2(44, 41), br, tilt)
	ell(hc + Vector2(-32, -34), Vector2(14, 16), br, -0.3)
	ell(hc + Vector2(32, -34), Vector2(14, 16), br, 0.3)
	ell(hc + Vector2(-32, -33), Vector2(7, 9), tint.call(Color(1.0, 0.7, 0.72)), -0.3)
	ell(hc + Vector2(32, -33), Vector2(7, 9), tint.call(Color(1.0, 0.7, 0.72)), 0.3)
	ell(hc + Vector2(0, -34), Vector2(16, 7), cr)
	# 顔(中の人)
	ell(hc + Vector2(hero_look * 3.0, 7), Vector2(30, 29), sk)
	var ey := hc.y + 2.0
	for sx in [-1.0, 1.0]:
		var ex: float = hc.x + sx * 12.0 + hero_look * 8.0
		if hero_shock:
			ell(Vector2(ex, ey), Vector2(8, 10), tint.call(Color.WHITE))
			ell(Vector2(ex + hero_look * 3.0, ey), Vector2(2.5, 3), Color(0.1, 0.07, 0.05))
			draw_line(Vector2(ex - 7, ey - 15), Vector2(ex + 7, ey - 18 + sx * 2.0), brd, 2.5)
		else:
			ell(Vector2(ex, ey), Vector2(3.6, 5), Color(0.1, 0.07, 0.05))
		ell(Vector2(hc.x + sx * 20.0 + hero_look * 6.0, ey + 12), Vector2(6, 4), tint.call(Color(1.0, 0.65, 0.65, 0.7)))
	var mc := Vector2(hc.x + hero_look * 6.0, ey + 16)
	if hero_shock:
		ell(mc + Vector2(0, 3), Vector2(7, 9), Color(0.35, 0.1, 0.1))
	elif hero_cross:
		draw_arc(mc + Vector2(0, -2), 8, 0.2, PI - 0.2, 10, Color(0.4, 0.15, 0.1), 2.5)
	else:
		draw_arc(mc + Vector2(0, -3), 7, 0.3, PI - 0.3, 10, Color(0.4, 0.15, 0.1), 2.5)
	# ひげ(着ぐるみ)
	for sx in [-1.0, 1.0]:
		draw_line(hc + Vector2(sx * 38, 8), hc + Vector2(sx * 62, 3), brd, 2.0)
		draw_line(hc + Vector2(sx * 38, 14), hc + Vector2(sx * 62, 16), brd, 2.0)
	if hero_sweat:
		ell(hc + Vector2(40, -14 + sin(t * 6.0) * 2.0), Vector2(5, 8), Color(0.55, 0.8, 1.0))
	reset_tf()


func draw_particles() -> void:
	for p in parts:
		var k: float = 1.0 - p["life"] / p["max"]
		draw_circle(p["p"], p["size"] * k, p["col"])


func draw_hud() -> void:
	if state == "opening":
		return
	var label := "最終戦" if turn > TURN_SETS.size() else "第%d戦" % maxi(turn, 1)
	draw_rect(Rect2(20, 16, 150, 46), Color(0, 0, 0, 0.45))
	txt(label, Vector2(95, 50), 28, Color(1, 1, 1), false)
	draw_rect(Rect2(W - 300, 16, 280, 46), Color(0, 0, 0, 0.45))
	txt("突破された回数  %d" % breaches, Vector2(W - 160, 50), 26, Color(1.0, 0.85, 0.6), false)
	if prompt_a > 0.0:
		txt(prompt_text, Vector2(W * 0.5, 592), 28, Color(1, 1, 1, prompt_a), true)


func draw_texts() -> void:
	for b in bubbles:
		var age: float = t - b["t0"]
		var lines: PackedStringArray = String(b["text"]).split("\n")
		var wmax := 0.0
		for ln in lines:
			wmax = maxf(wmax, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x)
		var bw := wmax + 36.0
		var bh := lines.size() * 32.0 + 22.0
		var pos: Vector2 = b["pos"]
		pos.x = clampf(pos.x, bw * 0.5 + 12.0, W - bw * 0.5 - 12.0)
		pos.y = maxf(pos.y, bh + 30.0)
		var sc := clampf(age / 0.12, 0.0, 1.0)
		draw_set_transform(pos, 0.0, Vector2(sc, sc))
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -16), Vector2(10, -16), Vector2(0, 0)]), Color(0.15, 0.1, 0.05))
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -17), Vector2(7, -17), Vector2(0, -5)]), Color.WHITE)
		draw_style_box(bubble_sb, Rect2(-bw * 0.5, -bh - 14.0, bw, bh))
		var y := -bh - 14.0 + 31.0
		for ln in lines:
			var sz := font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
			draw_string(font, Vector2(-sz.x * 0.5, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.15, 0.1, 0.05))
			y += 32.0
		reset_tf()
	for f in sfxs:
		var age: float = t - f["t0"]
		var k := 1.0 + 0.45 * exp(-age * 9.0)
		var col: Color = f["col"]
		col.a = clampf((f["dur"] - age) / 0.25, 0.0, 1.0)
		draw_set_transform(f["pos"], -0.1, Vector2(k, k))
		txt(f["text"], Vector2.ZERO, f["size"], col, true)
		reset_tf()


func draw_overlay() -> void:
	# オープニング文
	if state == "opening":
		for i in OPENING.size():
			var col := Color(1, 1, 1, open_alpha[i])
			var sz := 38
			if i == 3:
				col = Color(1.0, 0.75, 0.45, open_alpha[i])
				sz = 44
			txt(OPENING[i], Vector2(W * 0.5, 230.0 + i * 78.0 + (30.0 if i == 3 else 0.0)), sz, col, false)
		if not skip_open:
			txt("クリックでスキップ", Vector2(W - 150, H - 24), 20, Color(1, 1, 1, 0.35), false)
	if state == "start":
		txt("いたちごっこ", Vector2(W * 0.5, 300.0), 90, Color(1, 0.95, 0.7), true)
		txt("クリックでスタート", Vector2(W * 0.5, 430.0), 32, Color(1, 1, 1, 0.55 + 0.45 * sin(t * 4.0)), false)
		txt("♪ 音が出ます", Vector2(W * 0.5, 490.0), 22, Color(1, 1, 1, 0.5), false)
	# タイトル
	if title_a > 0.0:
		txt("いたちごっこ", Vector2(W * 0.5, 190.0), 110, Color(1, 0.95, 0.7, title_a), true)
	# 静寂
	if quiet_a > 0.0:
		txt("…………", Vector2(W * 0.5, 130.0), 44, Color(1, 1, 1, 0.8 * quiet_a), true)
	# エンディング
	if end_a > 0.0:
		txt("いたちごっこは続く", Vector2(W * 0.5, 350.0), 72, Color(1, 1, 1, end_a), false)
	if hint_a > 0.0:
		txt("クリックでもう一度", Vector2(W * 0.5, 440.0), 26, Color(1, 1, 1, 0.6 * hint_a), false)
