extends Node2D
## Wolf of the Deep: Bathtub Edition. Menu -> harbour -> battle -> results ->
## harbour (poker club, repairs, upgrades) -> next battle. Composes the view,
## the HUD and the panels, reads the keyboard and keeps the career saved.

var career := TubCareer.new()
var battle: TubBattle
var view: TubView
var cam: Camera2D
var ui: CanvasLayer
var hud: TubHud
var manage: TubManage
var poker: TubPoker
var sound: TubSound
var state := "menu"                 # menu, harbour, battle, results, poker
var paused := false
var _panel: Control
var _pause: Control
var _toast: Label
var _toast_t := 0.0
var _over_t := 0.0
var _report := {}
var _capture: Array = []
var _capture_dir := ""
var _capture_frames := 0


func _ready() -> void:
	view = TubView.new()
	add_child(view)
	cam = Camera2D.new()
	cam.zoom = Vector2(0.92, 0.92)
	cam.position = Vector2(0, 12)
	add_child(cam)
	cam.make_current()
	ui = CanvasLayer.new()
	add_child(ui)
	hud = TubHud.new()
	hud.visible = false
	ui.add_child(hud)
	manage = TubManage.new()
	manage.career = career
	manage.closed.connect(_close_manage)
	manage.spent.connect(func(_w: String) -> void:
		sound.play("candy")
		if state != "battle":
			career.save())
	ui.add_child(manage)
	poker = TubPoker.new()
	poker.left.connect(_on_poker_left)
	ui.add_child(poker)
	_toast = TubUi.title("", 26, Color.WHITE)
	_toast.position = Vector2(0, 116)
	_toast.size = Vector2(1920, 40)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(_toast)
	sound = TubSound.new()
	add_child(sound)
	view.sound.connect(func(n: String, _p: Vector2) -> void: sound.play(n, -4.0))
	_parse_args()
	if _capture.is_empty():
		show_menu()
		sound.music(true)
	else:
		_next_shot()


func toast(text: String, dur: float = 3.5) -> void:
	_toast.move_to_front()
	_toast.text = text
	_toast_t = dur


func _clear_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null


## A quiet bath behind the menus: the little sub doing laps.
func _sandbox() -> void:
	var b := TubBattle.new()
	b.setup(TubCaptain.new_ship("sub"), 0, [], 5)
	b.sandbox = true
	b.player.pos = Vector2(-200, 160)
	battle = b
	view.captains = {}
	view.set_battle(b)


func show_menu() -> void:
	state = "menu"
	hud.visible = false
	manage.visible = false
	poker.visible = false
	_sandbox()
	_clear_panel()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	_panel = root
	var t := TubUi.title("WOLF OF THE DEEP", 92, Color(1.0, 0.86, 0.3))
	t.position = Vector2(0, 150)
	t.size = Vector2(1920, 110)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t)
	var st := TubUi.title("BATHTUB EDITION", 46, Color(0.55, 0.9, 1.0))
	st.position = Vector2(0, 262)
	st.size = Vector2(1920, 60)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(st)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.position = Vector2(760, 400)
	box.size = Vector2(400, 0)
	root.add_child(box)
	if career.has_save():
		var c := TubUi.button("Continue", TubUi.MINT, 28)
		c.pressed.connect(func() -> void:
			if career.load_file():
				show_harbour()
			else:
				toast("That save could not be read."))
		box.add_child(c)
	var n := TubUi.button("New Game", TubUi.SUN, 28)
	n.pressed.connect(func() -> void:
		career.new_game()
		career.save()
		show_harbour()
		toast("Your toy submarine, Little Wolf, is ready. 100 candy in your pocket. Five rivals in the bath."))
	box.add_child(n)
	var h := TubUi.button("How to play", TubUi.SKY, 24)
	h.pressed.connect(_how_to)
	box.add_child(h)
	var q := TubUi.button("Quit", TubUi.PINK, 24)
	q.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(q)
	var credit := TubUi.label("An experiment in fun. Saves are kept apart from the serious game. Font: Fredoka (SIL Open Font License).", 16, Color(1, 1, 1, 0.9), false)
	credit.position = Vector2(0, 1030)
	credit.size = Vector2(1920, 30)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(credit)


func _how_to() -> void:
	_clear_panel()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", TubUi.panel())
	p.position = Vector2(360, 120)
	p.size = Vector2(1200, 820)
	ui.add_child(p)
	_panel = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(TubUi.label("HOW TO PLAY", 34))
	var txt := TubUi.label("""You command Little Wolf, a toy submarine, in a bath full of rival captains.

DRIVE  W forward, S astern, A / D steer (Shift for half speed).
FIGHT  SPACE fires a torpedo straight ahead. Aim with the whole boat.
DEPTH  Q rises, E dives. Surface: fast, seen from afar, deck guns hit you. Periscope: quieter, can still fire. Deep: nearly invisible and slips under sponges, washcloths and torpedoes, but cannot fire, air runs out, and depth charges reach you.
GADGETS  G drops a decoy duckling (if you bought some). Hold X against the rim to be lifted out (a withdrawal).
PAUSE  TAB freezes the battle and opens your submarine, repairs, upgrades and the captains. ESC for the menu.

The bath: soap and the bottle block everything, the sponge floats (dive under it), the washcloth slows you, foam hides you, the drain pulls, and the tap pushes when it runs. Sink a toy and its captain's candy spills - grab it before it goes down the drain!

Candy pays for repairs, upgrades and poker stakes - for everyone. Rivals spend their own candy on their own boats, and remember who sank them.""", 18, TubUi.INK, false)
	txt.custom_minimum_size = Vector2(1150, 0)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(txt)
	var b := TubUi.button("Back", TubUi.SKY, 22)
	b.pressed.connect(show_menu)
	v.add_child(b)


func show_harbour() -> void:
	state = "harbour"
	paused = false
	hud.visible = false
	manage.battle = null
	if _pause:
		_pause.queue_free()
		_pause = null
	_sandbox()
	career.save()
	sound.music(true)
	_clear_panel()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	_panel = root
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", TubUi.panel())
	p.position = Vector2(120, 130)
	p.size = Vector2(760, 0)
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(TubUi.label("THE SOAP DISH HARBOUR", 34))
	var ship: Dictionary = career.player["ship"]
	var stats: Dictionary = career.player["stats"]
	v.add_child(TubUi.label("Little Wolf  ·  hull %d / %d  ·  %d candy" % [int(ship["hull"]), int(ship["max_hull"]), int(career.player["candy"])], 22, TubUi.TEAL))
	v.add_child(TubUi.label("Battles %d  ·  won %d  ·  toys sunk %d  ·  times sunk %d  ·  at the table %+d candy" % [int(stats["battles"]), int(stats["wins"]),
		int(stats["sinks"]), int(stats["sunk"]), int(stats["poker_net"])], 16, TubUi.DIM, false))
	var go := TubUi.button("Into the bath!  Battle %d" % (career.battle_no + 1), TubUi.MINT, 30)
	go.pressed.connect(start_battle)
	v.add_child(go)
	var pk := TubUi.button("The Captains' Poker Club", TubUi.PINK, 24)
	pk.pressed.connect(open_poker)
	v.add_child(pk)
	var rp := TubUi.button("Repairs  (%d candy for everything)" % TubEconomy.full_repair_cost(ship), TubUi.SUN, 22)
	rp.pressed.connect(func() -> void: open_manage("repairs"))
	v.add_child(rp)
	var up := TubUi.button("Upgrades", TubUi.SUN, 22)
	up.pressed.connect(func() -> void: open_manage("upgrades"))
	v.add_child(up)
	var cp := TubUi.button("The Captains", TubUi.SKY, 22)
	cp.pressed.connect(func() -> void: open_manage("captains"))
	v.add_child(cp)
	var mm := TubUi.button("Save and return to the menu", TubUi.SKY, 20)
	mm.pressed.connect(func() -> void:
		career.save()
		show_menu())
	v.add_child(mm)
	var ch := PanelContainer.new()
	ch.add_theme_stylebox_override("panel", TubUi.panel())
	ch.position = Vector2(940, 130)
	ch.size = Vector2(860, 0)
	root.add_child(ch)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	ch.add_child(cv)
	cv.add_child(TubUi.label("BATH-SIDE GOSSIP", 26))
	var lines: Array = career.chronicle.slice(maxi(career.chronicle.size() - 16, 0))
	lines.reverse()
	for e in lines:
		var l := TubUi.label(String(e["text"]), 16, TubUi.INK, false)
		l.custom_minimum_size = Vector2(800, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(l)


func open_manage(tab: String) -> void:
	manage.battle = battle if state == "battle" else null
	manage.move_to_front()
	manage.open(tab)


func _close_manage() -> void:
	manage.visible = false
	if state == "harbour":
		show_harbour()


func open_poker() -> void:
	state = "poker"
	_clear_panel()
	poker.move_to_front()
	poker.open(career)


func _on_poker_left(lines: Array) -> void:
	career.save()
	show_harbour()
	if not lines.is_empty():
		toast(" ".join(lines), 6.0)


func start_battle() -> void:
	_clear_panel()
	var refit := career.refit_due
	battle = career.start_battle()
	view.captains = career.captains
	view.set_battle(battle)
	hud.battle = battle
	hud.career = career
	hud.visible = true
	manage.battle = battle
	manage.patched = false
	state = "battle"
	paused = false
	_over_t = 0.0
	sound.play("whistle")
	hud.flash("BATTLE %d!  Sink them, outlast them, or slip away." % (career.battle_no + 1), TubUi.SUN, 3.0)
	if refit:
		toast("The rivals have spent their candy on their boats. See the gossip after the battle.", 4.0)


func _restart_battle() -> void:
	if not career.load_file(TubCareer.PREBATTLE_FILE):
		toast("No pre-battle snapshot to restart from.")
		return
	_close_pause()
	start_battle()
	toast("Battle restarted.")


func _physics_process(delta: float) -> void:
	if battle == null:
		return
	match state:
		"menu", "harbour", "poker":
			battle.player.throttle = 0.35
			battle.player.rudder = 0.22
			battle.step(delta)
		"battle":
			if paused or manage.visible:
				return
			_read_input(delta)
			battle.step(delta)
			for e in battle.events:
				if String(e["type"]) == "cant_fire" and String(e.get("why", "")) != "":
					hud.flash("CAN'T FIRE: " + String(e["why"]).to_upper(), TubUi.RED, 1.0)
				elif String(e["type"]) == "cleared":
					hud.flash("BATH CLEARED!" + ("  GRAB THE CANDY!" if bool(e.get("candy", false)) else ""), TubUi.SUN, 3.0)
				elif String(e["type"]) == "air":
					hud.flash("OUT OF AIR! RISING!", TubUi.RED, 2.0)
				elif String(e["type"]) == "cant_dive":
					hud.flash("NOT ENOUGH AIR TO DIVE", TubUi.RED, 1.5)
			if battle.over:
				_over_t += delta
				if _over_t > 2.0:
					show_results()


func _read_input(dt: float) -> void:
	var p := battle.player
	if not p.active():
		return
	var fwd := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var back := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var half := Input.is_key_pressed(KEY_SHIFT)
	p.throttle = (0.5 if half else 1.0) if fwd else (-0.5 if back else 0.0)
	var left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	p.rudder = (-1.0 if left else 0.0) + (1.0 if right else 0.0)
	if Input.is_key_pressed(KEY_SPACE):
		battle.player_fire()
	battle.player_retreat(dt, Input.is_key_pressed(KEY_X))


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if state == "poker" and poker.visible:
		poker.handle_key(k.keycode)
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_M:
		sound.toggle_music()
		return
	if state == "battle":
		match k.keycode:
			KEY_TAB:
				if manage.visible:
					manage.visible = false
				elif not paused:
					open_manage("sub")
			KEY_ESCAPE:
				if manage.visible:
					manage.visible = false
				elif paused:
					_close_pause()
				else:
					_open_pause()
			KEY_Q:
				battle.set_depth(battle.player, battle.player.depth - 1)
			KEY_E:
				battle.set_depth(battle.player, battle.player.depth + 1)
			KEY_G:
				if not battle.player_decoy():
					hud.flash("NO DECOYS", TubUi.RED, 1.0)
		get_viewport().set_input_as_handled()
	elif state == "harbour" and k.keycode in [KEY_TAB, KEY_ESCAPE] and manage.visible:
		_close_manage()
	elif state == "results" and k.keycode in [KEY_SPACE, KEY_ENTER]:
		show_harbour()


func _open_pause() -> void:
	paused = true
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", TubUi.panel())
	p.position = Vector2(760, 330)
	p.size = Vector2(400, 0)
	ui.add_child(p)
	_pause = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(TubUi.label("PAUSED", 34))
	for b in [["Resume  (ESC)", TubUi.MINT, _close_pause], ["Restart this battle", TubUi.SUN, _restart_battle],
			["Give up (withdraw)", TubUi.PINK, _give_up], ["Music on / off  (M)", TubUi.SKY, sound.toggle_music]]:
		var bt := TubUi.button(String(b[0]), b[1], 22)
		bt.pressed.connect(b[2])
		v.add_child(bt)


func _close_pause() -> void:
	paused = false
	if _pause:
		_pause.queue_free()
		_pause = null


func _give_up() -> void:
	_close_pause()
	battle.player.state = "retreated"
	battle.step(0.0)


func show_results() -> void:
	state = "results"
	hud.visible = false
	manage.visible = false
	_close_pause()
	_report = career.settle(battle)
	career.save()
	_clear_panel()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", TubUi.panel())
	p.position = Vector2(360, 150)
	p.size = Vector2(1200, 0)
	ui.add_child(p)
	_panel = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var res := String(_report["result"])
	var head: String = {"victory": "VICTORY!", "defeat": "GLUB GLUB... SUNK!", "withdrew": "LIFTED OUT", "draw": "THE BATH WENT COLD"}[res]
	v.add_child(TubUi.title(head, 54, {"victory": TubUi.SUN, "defeat": TubUi.RED, "withdrew": TubUi.SKY, "draw": TubUi.SKY}[res]))
	for l in _report["lines"]:
		var lb := TubUi.label(String(l), 19, TubUi.INK, false)
		lb.custom_minimum_size = Vector2(1150, 0)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lb)
	var earn: Dictionary = _report["earnings"]
	var rivals: Array[String] = []
	for id in earn.keys():
		if id == "player":
			continue
		var c: TubCaptain = career.captain(id)
		rivals.append("%s %+d (now %d)" % [c.short.capitalize(), int((earn[id] as Dictionary)["total"]), c.candy])
	v.add_child(TubUi.label("Rivals' candy from the battle: " + ", ".join(rivals), 17, TubUi.DIM, false))
	var b := TubUi.button("Back to the harbour  (SPACE)", TubUi.MINT, 24)
	b.pressed.connect(show_harbour)
	v.add_child(b)
	sound.play("candy" if res == "victory" else "bubble")


func _process(delta: float) -> void:
	_toast_t = maxf(_toast_t - delta, 0.0)
	_toast.visible = _toast_t > 0.0
	if not _capture.is_empty():
		_capture_step()


# --- screenshots for development (headless captures) -------------------------------
#   --capture=dir --shots=name:frames:tokens,...  tokens joined with '+':
#   menu, harbour, battle, sim=SECONDS, manage=TAB, poker, results, scene=N

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			_capture_dir = a.substr(10)
		elif a.begins_with("--shots="):
			for spec in a.substr(8).split(","):
				_capture.append(spec.split(":"))


func _next_shot() -> void:
	var spec: PackedStringArray = _capture[0]
	_capture_frames = int(spec[1]) if spec.size() > 1 else 30
	var tokens: PackedStringArray = spec[2].split("+") if spec.size() > 2 else PackedStringArray()
	for tok in tokens:
		var kv := tok.split("=")
		match kv[0]:
			"menu":
				show_menu()
			"newgame":
				career.save_dir = "user://bathtub_capture/"
				career.new_game(77)
			"harbour":
				show_harbour()
			"battle":
				start_battle()
			"sim":
				for _i in int(float(kv[1]) * 60.0):
					battle.player.throttle = 0.7
					battle.player.rudder = 0.15 * sin(battle.time * 0.5)
					if int(battle.time * 60.0) % 50 == 0:
						battle.player_fire()
					battle.step(1.0 / 60.0)
			"deep":
				battle.set_depth(battle.player, 2)
			"manage":
				open_manage(kv[1])
			"poker":
				open_poker()
			"sit":
				if poker.phase == "choose":
					poker._sit(TubPokerSession.STAKES[0])
				for _i in int(kv[1]) if kv.size() > 1 else 0:
					if poker.phase == "ai":
						poker._ai_step()
					elif poker.phase == "human":
						poker._on_button("call")
			"results":
				battle.over = true
				battle.result = "victory"
				show_results()


func _capture_step() -> void:
	_capture_frames -= 1
	if _capture_frames > 0:
		return
	var spec: PackedStringArray = _capture.pop_front()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_capture_dir, spec[0]])
	print("CAPTURED ", spec[0])
	if _capture.is_empty():
		get_tree().quit()
	else:
		_next_shot()
