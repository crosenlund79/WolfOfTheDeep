class_name TubHud
extends Control
## The battle HUD: battle and bath timer, the rivals in this bath (portrait,
## hull, mood), your candy; along the bottom your hull and parts, depth,
## air, torpedoes, gadgets and the controls. Drawn, not built from widgets.

var battle: TubBattle
var career: TubCareer
var _msg := ""
var _msg_t := 0.0
var _msg_col := Color.WHITE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash(text: String, col: Color = Color.WHITE, dur: float = 2.2) -> void:
	_msg = text
	_msg_t = dur
	_msg_col = col


func _process(delta: float) -> void:
	_msg_t = maxf(_msg_t - delta, 0.0)
	if visible:
		queue_redraw()


func _draw() -> void:
	if battle == null:
		return
	var f := TubArt.font(true)
	var w := size.x
	# Top bar.
	var top := StyleBoxFlat.new()
	top.bg_color = Color(TubUi.CREAM.r, TubUi.CREAM.g, TubUi.CREAM.b, 0.95)
	top.set_corner_radius_all(22)
	top.border_color = TubUi.INK
	top.set_border_width_all(3)
	top.anti_aliasing = true
	draw_style_box(top, Rect2(16, 10, w - 32, 82))
	var left := maxf(battle.limit - battle.time, 0.0)
	draw_string(f, Vector2(40, 46), "BATTLE %d" % (career.battle_no + 1 if career else 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TubUi.INK)
	var cold := left < 60.0
	draw_string(f, Vector2(40, 76), ("The bath is getting cold! %d:%02d" if cold else "Bath cools in %d:%02d") % [int(left) / 60, int(left) % 60],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TubUi.RED if cold else TubUi.DIM)
	var x := 360.0
	for s in battle.ships:
		if s.is_player:
			continue
		var cap: TubCaptain = career.captain(s.id) if career else null
		TubUi.portrait(self, s.id, Vector2(x + 34, 51), 28.0, s.livery)
		draw_string(f, Vector2(x + 74, 40), s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TubUi.INK)
		var status := {"active": "", "sunk": "SUNK", "retreated": "RETREATED"}[s.state] as String
		if status == "":
			TubUi.bar(self, Rect2(x + 74, 50, 150, 14), s.hull_frac(), TubUi.health_color(s.hull_frac()))
			if cap:
				draw_string(f, Vector2(x + 74, 84), cap.attitude(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _mood_col(cap.attitude()))
		else:
			draw_string(f, Vector2(x + 74, 66), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TubUi.DIM)
		x += 300.0
	var candy := int(career.player["candy"]) if career else 0
	var ct := TubArt.texture("candy")
	var cs := "%d" % (candy + int(battle.ledger.get("player", 0)))
	var cw := f.get_string_size(cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	if ct:
		draw_texture_rect(ct, Rect2(w - 90 - cw, 34, 48, 28), false)
	draw_string(f, Vector2(w - 36 - cw, 62), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TubUi.PINK)
	# Bottom bar.
	var p := battle.player
	var by := size.y - 104.0
	draw_style_box(top, Rect2(16, by, w - 32, 94))
	draw_string(f, Vector2(40, by + 32), "LITTLE WOLF", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TubUi.TEAL)
	TubUi.bar(self, Rect2(40, by + 44, 260, 20), p.hull_frac(), TubUi.health_color(p.hull_frac()))
	draw_string(f, Vector2(48, by + 60), "HULL %d / %d" % [int(maxf(p.hull, 0.0)), p.max_hull], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TubUi.INK)
	var cx := 330.0
	for c in TubData.COMPONENTS:
		var v := p.c(c)
		draw_string(f, Vector2(cx, by + 34), String(TubData.COMPONENT_NAMES[c]).split(" ")[0].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TubUi.DIM)
		TubUi.bar(self, Rect2(cx, by + 42, 110, 12), v, TubUi.health_color(v))
		cx += 124.0
	draw_string(f, Vector2(330, by + 80), "Shield: %s     Decoys (G): %d" % ["ready" if p.shield else ("recharging" if p.has("shield") else "none"), p.decoys],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TubUi.INK)
	# Depth gauge.
	var gx := 860.0
	draw_string(f, Vector2(gx, by + 28), "DEPTH  (Q up / E down)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TubUi.DIM)
	for i in 3:
		var r := Rect2(gx + i * 104.0, by + 38, 96, 30)
		var on := p.depth == i
		var going := p.depth_t > 0.0 and p.depth_to == i
		var sb := StyleBoxFlat.new()
		sb.bg_color = [TubUi.SKY, Color(0.3, 0.6, 0.85), Color(0.15, 0.3, 0.55)][i] if (on or going) else Color(0.9, 0.92, 0.95)
		sb.set_corner_radius_all(12)
		sb.border_color = TubUi.INK if on else Color(0.6, 0.62, 0.7)
		sb.set_border_width_all(3 if on else 1)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		draw_string(f, r.position + Vector2(10, 21), TubData.DEPTHS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if (on or going) and i > 0 else TubUi.INK)
	if p.depth == 2 or p.air < 1.0:
		draw_string(f, Vector2(gx, by + 88), "AIR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TubUi.INK)
		TubUi.bar(self, Rect2(gx + 36, by + 76, 270, 12), p.air, TubUi.SKY if p.air > 0.3 else TubUi.RED)
	# Torpedoes.
	var tx := 1200.0
	draw_string(f, Vector2(tx, by + 28), "TORPEDOES  (SPACE)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TubUi.DIM)
	var tt := TubArt.texture("torpedo")
	var maxa := 8 + (4 if p.has("racks") else 0)
	for i in maxa:
		var tr := Rect2(tx + float(i % 6) * 40.0, by + 38 + float(i / 6) * 18.0, 36, 12)
		if tt:
			draw_texture_rect(tt, tr, false, Color(1, 1, 1, 1.0 if i < p.ammo else 0.18))
	if p.reload > 0.0:
		TubUi.bar(self, Rect2(tx, by + 80, 230, 8), 1.0 - p.reload / p.reload_time(), TubUi.SUN)
	draw_string(f, Vector2(w - 400, by + 34), "W/S throttle · A/D steer · SPACE fire", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TubUi.INK)
	draw_string(f, Vector2(w - 400, by + 58), "Q/E depth · G decoy · X (at the rim) retreat", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TubUi.INK)
	draw_string(f, Vector2(w - 400, by + 82), "TAB manage (pauses) · ESC menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TubUi.INK)
	# Centre message.
	if _msg_t > 0.0:
		var a := clampf(_msg_t / 0.4, 0.0, 1.0)
		var mw := f.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string_outline(f, Vector2((w - mw) * 0.5, 160), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 10, Color(TubUi.INK.r, TubUi.INK.g, TubUi.INK.b, a))
		draw_string(f, Vector2((w - mw) * 0.5, 160), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(_msg_col.r, _msg_col.g, _msg_col.b, a))
	if battle.retreat_hold > 0.0:
		var hw := f.get_string_size("THE HAND IS COMING...", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string_outline(f, Vector2((w - hw) * 0.5, 210), "THE HAND IS COMING...", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, TubUi.INK)
		draw_string(f, Vector2((w - hw) * 0.5, 210), "THE HAND IS COMING...", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TubUi.SUN)


static func _mood_col(m: String) -> Color:
	match m:
		"furious":
			return TubUi.RED
		"resentful":
			return Color(0.9, 0.5, 0.2)
		"friendly", "respectful":
			return TubUi.TEAL
	return TubUi.DIM
