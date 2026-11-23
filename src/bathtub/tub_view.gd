class_name TubView
extends Node2D
## Draws the bath: tiles, the porcelain tub, the water (shader), the tap and
## drain, soap, sponge, washcloth, bottle, foam, the toys and everything they
## fire, splashes and speech bubbles. Reads a TubBattle; owns only effects.

var battle: TubBattle
var captains := {}                  # id -> TubCaptain (names, lines, liveries)
var menu_mode := false              # an empty, peaceful bath behind the menus
var water: ColorRect
var _mat: ShaderMaterial
var _fx: Array[Dictionary] = []     # transient effects
var _trails := {}                   # ship id -> [{p, t, deep}]
var _bubbles := {}                  # ship id -> next bubble time
var _foam_shapes: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _say_rng := RandomNumberGenerator.new()
var _faucet := 0.0
var _backdrop: Node2D
signal sound(name: String, pos: Vector2)
signal said(id: String, text: String)

const RIM := 64.0
const INK := Color(0.18, 0.19, 0.26)


class Backdrop extends Node2D:
	var view: TubView
	func _draw() -> void:
		view._draw_room(self)


func _ready() -> void:
	var back := Backdrop.new()
	back.view = self
	back.show_behind_parent = true
	add_child(back)
	_backdrop = back
	water = ColorRect.new()
	water.position = -TubBattle.HALF
	water.size = TubBattle.HALF * 2.0
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://src/bathtub/tub_water.gdshader")
	_mat.set_shader_parameter("half_size", TubBattle.HALF)
	_mat.set_shader_parameter("corner", TubBattle.CORNER)
	_mat.set_shader_parameter("drain", TubBattle.DRAIN)
	_mat.set_shader_parameter("faucet", 0.0)
	water.material = _mat
	water.show_behind_parent = true
	add_child(water)
	_rng.seed = 11
	_say_rng.randomize()


func set_battle(b: TubBattle) -> void:
	battle = b
	_fx.clear()
	_trails.clear()
	_foam_shapes.clear()
	for f in b.foam:
		var parts: Array = []
		for i in 16:
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * float(f["r"]) * 0.75
			parts.append([Vector2(cos(a), sin(a)) * d, _rng.randf_range(10.0, 26.0), _rng.randf() * TAU])
		_foam_shapes.append(parts)


func _process(delta: float) -> void:
	_t += delta
	if battle:
		_faucet = move_toward(_faucet, 1.0 if battle.faucet_on else 0.0, delta * 2.0)
		_mat.set_shader_parameter("faucet", _faucet)
		_consume(battle.take_events())
		_track(delta)
	for e in _fx:
		e["t"] = float(e["t"]) + delta
	_fx = _fx.filter(func(e: Dictionary) -> bool: return float(e["t"]) < float(e["dur"]))
	queue_redraw()
	_backdrop.queue_redraw()


# --- events into effects ---------------------------------------------------------

func _fx_add(type: String, pos: Vector2, dur: float, extra: Dictionary = {}) -> void:
	var e := {"type": type, "pos": pos, "t": 0.0, "dur": dur}
	e.merge(extra)
	_fx.append(e)


func _consume(evs: Array[Dictionary]) -> void:
	for e in evs:
		var p: Vector2 = e.get("pos", Vector2.ZERO)
		match String(e["type"]):
			"launch":
				_fx_add("ring", p, 0.5, {"r": 22.0, "col": Color(1, 1, 1, 0.8)})
				sound.emit("bubble_launch", p)
			"boom":
				_fx_add("splash", p, 0.9, {"r": 60.0})
				_fx_add("droplets", p, 0.8, {"n": 12, "seed": _rng.randi()})
				sound.emit("toy_hit", p)
			"splash", "plop":
				_fx_add("ring", p, 0.6, {"r": 26.0, "col": Color(1, 1, 1, 0.7)})
				sound.emit("splash_small", p)
			"plink":
				_fx_add("ring", p, 0.3, {"r": 14.0, "col": Color(1, 0.9, 0.5, 0.9)})
				sound.emit("plink", p)
			"pew":
				sound.emit("pew", p)
			"depth_boom":
				_fx_add("dome", p, 1.0, {"r": TubBattle.CHARGE["r"]})
				sound.emit("depth_boom", p)
			"charge":
				sound.emit("plop", p)
			"ping":
				_fx_add("ping", p, 1.4, {"r": 480.0})
				sound.emit("ping", p)
			"squeak":
				_fx_add("squeak", p, 0.55, {"r": TubBattle.SQUEAK["r"]})
				sound.emit("squeak", p)
			"quack":
				_fx_add("label", p + Vector2(0, -50), 1.0, {"text": "QUACK!", "col": Color(1.0, 0.75, 0.1)})
				sound.emit("quack", p)
			"ram", "thud":
				_fx_add("ring", p, 0.4, {"r": 34.0, "col": Color(1, 1, 1, 0.9)})
				sound.emit("thud", p)
			"sunk":
				_fx_add("splash", p, 1.6, {"r": 90.0})
				_fx_add("droplets", p, 1.0, {"n": 18, "seed": _rng.randi()})
				if int(e.get("spill", 0)) > 0:
					_fx_add("label", p + Vector2(0, -40), 1.6, {"text": "%d candy spilled!" % int(e["spill"]), "col": Color(1.0, 0.45, 0.7)})
				sound.emit("sink", p)
			"candy":
				_fx_add("label", p + Vector2(0, -24), 1.2, {"text": "+%d" % int(e["amount"]), "col": Color(1.0, 0.45, 0.7)})
				sound.emit("candy", p)
			"drain":
				_fx_add("label", p + Vector2(0, -24), 1.2, {"text": "down the drain!", "col": Color(0.8, 0.9, 1.0)})
				sound.emit("gurgle", p)
			"shield_pop":
				_fx_add("ring", p, 0.5, {"r": 50.0, "col": Color(0.6, 0.9, 1.0, 0.9)})
				sound.emit("pop", p)
			"shield_up":
				sound.emit("bubble", p)
			"pop":
				sound.emit("pop", p)
			"diving", "rising":
				_fx_add("ring", p, 0.7, {"r": 40.0, "col": Color(0.85, 0.97, 1.0, 0.6)})
				sound.emit("dive" if String(e["type"]) == "diving" else "surface", p)
			"lifted":
				sound.emit("lift", p)
			"faucet":
				sound.emit("faucet", Vector2(TubBattle.FAUCET_X, 0))
			"decoy":
				sound.emit("squeak_small", p)
			"say":
				_speak(String(e["id"]), String(e["key"]))
			"over":
				sound.emit("whistle", Vector2.ZERO)


func _speak(id: String, key: String) -> void:
	var cap: TubCaptain = captains.get(id)
	if cap == null:
		return
	var text := cap.line(key, _say_rng)
	if text == "":
		return
	_fx_add("bubble", Vector2.ZERO, 3.2, {"id": id, "text": text})
	said.emit(id, text)


## Bubble trails behind moving toys.
func _track(delta: float) -> void:
	for s in battle.ships:
		if not s.active():
			continue
		var tr: Array = _trails.get(s.id, [])
		var next := float(_bubbles.get(s.id, 0.0))
		if _t >= next and absf(s.speed) > 10.0:
			_bubbles[s.id] = _t + 0.05
			tr.append({"p": s.pos - s.forward() * s.radius() * 0.9, "t": _t, "deep": s.depth})
		tr = tr.filter(func(b: Dictionary) -> bool: return _t - float(b["t"]) < 1.2)
		_trails[s.id] = tr
	for t in battle.torps:
		var pts: Array = t.get("pts", [])
		pts.append(t["pos"])
		if pts.size() > 18:
			pts.pop_front()
		t["pts"] = pts


# --- drawing ----------------------------------------------------------------------

func _draw() -> void:
	_draw_fixtures()
	if battle == null:
		return
	_draw_props_under()
	_draw_trails()
	for pk in battle.pickups:
		_tex("candy", (pk["pos"] as Vector2) + Vector2(0, sin(_t * 3.0 + float(pk["t"])) * 3.0), sin(_t * 2.0) * 0.3, 0.8)
	for d in battle.decoys:
		_tex("decoy", (d["pos"] as Vector2) + Vector2(0, sin(_t * 5.0) * 2.0), sin(_t * 3.0) * 0.4, 1.0)
	for ch in battle.charges:
		var k := clampf(float(ch["fuse"]) / float(TubBattle.CHARGE["fuse"]), 0.0, 1.0)
		_tex("charge", ch["pos"], _t, 0.6 + 0.5 * k, Color(1, 1, 1, 0.4 + 0.6 * k))
	for s in battle.ships:
		if s.depth >= 2 or (s.depth_t > 0.0 and s.depth_to == 2):
			_draw_ship(s)
	_draw_props_over_deep()
	for s in battle.ships:
		if not (s.depth >= 2 or (s.depth_t > 0.0 and s.depth_to == 2)):
			_draw_ship(s)
	for t in battle.torps:
		var v: Vector2 = t["vel"]
		_tex("torpedo", t["pos"], v.angle(), 0.8)
	for b in battle.pellets:
		draw_circle(b["pos"], 4.0, Color(0.25, 0.27, 0.3))
		draw_circle((b["pos"] as Vector2) + Vector2(-1.2, -1.2), 1.4, Color(1, 1, 1, 0.8))
	for w in battle.waves:
		var a := 1.0 - float(w["r"]) / float(TubBattle.SQUEAK["r"])
		draw_arc(w["pos"], float(w["r"]), 0.0, TAU, 48, Color(1.0, 0.9, 0.3, 0.8 * a), 6.0)
		draw_arc(w["pos"], float(w["r"]) - 10.0, 0.0, TAU, 48, Color(1, 1, 1, 0.6 * a), 3.0)
	_draw_foam()
	_draw_fx()


## Tiles and the porcelain tub, behind the water.
func _draw_room(ci: CanvasItem) -> void:
	# Bathroom tiles around the tub.
	var vp := Vector2(2200, 1300)
	ci.draw_rect(Rect2(-vp * 0.5, vp), Color(0.83, 0.92, 0.9))
	var tile := 96.0
	var x := -vp.x * 0.5
	while x < vp.x * 0.5:
		ci.draw_line(Vector2(x, -vp.y * 0.5), Vector2(x, vp.y * 0.5), Color(0.72, 0.84, 0.82), 3.0)
		x += tile
	var y := -vp.y * 0.5
	while y < vp.y * 0.5:
		ci.draw_line(Vector2(-vp.x * 0.5, y), Vector2(vp.x * 0.5, y), Color(0.72, 0.84, 0.82), 3.0)
		y += tile
	# The tub: a porcelain rim with a soft shadow.
	var outer := Rect2(-TubBattle.HALF - Vector2(RIM, RIM), (TubBattle.HALF + Vector2(RIM, RIM)) * 2.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.985, 0.99, 1.0)
	sb.set_corner_radius_all(int(TubBattle.CORNER + RIM))
	sb.shadow_color = Color(0.2, 0.3, 0.35, 0.35)
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0, 14)
	sb.anti_aliasing = true
	sb.border_color = Color(0.82, 0.86, 0.9)
	sb.set_border_width_all(3)
	ci.draw_style_box(sb, outer)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.9, 0.93, 0.96)
	inner.set_corner_radius_all(int(TubBattle.CORNER + 14.0))
	inner.anti_aliasing = true
	ci.draw_style_box(inner, Rect2(-TubBattle.HALF - Vector2(14, 14), (TubBattle.HALF + Vector2(14, 14)) * 2.0))
	# A gleam along the rim.
	var cc := -TubBattle.HALF + Vector2(TubBattle.CORNER, TubBattle.CORNER)
	ci.draw_arc(cc, TubBattle.CORNER + 40.0, PI * 1.05, PI * 1.45, 20, Color(1, 1, 1, 0.95), 7.0)
	ci.draw_line(Vector2(-500, -TubBattle.HALF.y - 40.0), Vector2(300, -TubBattle.HALF.y - 40.0), Color(1, 1, 1, 0.95), 6.0)


## The drain and the tap, over the water.
func _draw_fixtures() -> void:
	# The drain: a chrome grate.
	var dp := TubBattle.DRAIN
	draw_circle(dp, 30.0, Color(0.6, 0.65, 0.7))
	draw_circle(dp, 26.0, Color(0.85, 0.88, 0.92))
	draw_circle(dp, 20.0, Color(0.32, 0.36, 0.42))
	for i in 6:
		var a := TAU * float(i) / 6.0 + _t * 0.3
		draw_line(dp + Vector2(cos(a), sin(a)) * 4.0, dp + Vector2(cos(a), sin(a)) * 18.0, Color(0.85, 0.88, 0.92), 3.0)
	# The tap on the left rim.
	_tex("faucet", Vector2(-TubBattle.HALF.x - 18.0, 0.0), 0.0, 0.9)


func _tex(name: String, pos: Vector2, rot: float, scale: float, mod: Color = Color.WHITE, flip: bool = false) -> void:
	var t := TubArt.texture(name)
	if t == null:
		return
	draw_set_transform(pos, rot, Vector2(scale, scale * (-1.0 if flip else 1.0)))
	draw_texture(t, -t.get_size() * 0.5, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _obstacle(o: Dictionary, shadow: bool) -> void:
	var k := String(o["kind"])
	var art: String = {"soap": "soap", "bottle": "bottle", "sponge": "sponge", "cloth": "washcloth"}[k]
	var t := TubArt.texture(art)
	if t == null:
		return
	var half: Vector2 = o["half"]
	var sc := half * 2.0 / t.get_size()
	var p: Vector2 = o["pos"]
	if k == "sponge" or k == "cloth":
		p += Vector2(0, sin(_t * 1.3 + p.x * 0.01) * 2.0)
	if shadow:
		draw_set_transform(p + Vector2(7, 10), float(o["rot"]), sc)
		draw_texture(t, -t.get_size() * 0.5, Color(0, 0.1, 0.15, 0.25))
	else:
		draw_set_transform(p, float(o["rot"]), sc)
		draw_texture(t, -t.get_size() * 0.5, Color(1, 1, 1, 0.92) if k == "cloth" else Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_props_under() -> void:
	for o in battle.obstacles:
		if String(o["kind"]) in ["soap", "bottle"]:
			_obstacle(o, true)
			_obstacle(o, false)


## Floating things are drawn over anything deep beneath them.
func _draw_props_over_deep() -> void:
	for o in battle.obstacles:
		if String(o["kind"]) in ["sponge", "cloth"]:
			_obstacle(o, true)
			_obstacle(o, false)


func _draw_trails() -> void:
	for id in _trails.keys():
		for b in _trails[id]:
			var age := _t - float(b["t"])
			var deep := int(b["deep"])
			var col := Color(1, 1, 1, 0.55 * (1.0 - age / 1.2)) if deep == 0 else Color(0.8, 0.95, 1.0, 0.35 * (1.0 - age / 1.2))
			draw_circle(b["p"], 3.0 + age * 7.0, col)
	for t in battle.torps:
		var pts: Array = t.get("pts", [])
		for i in pts.size():
			var a := float(i) / maxf(float(pts.size()), 1.0)
			draw_circle(pts[i], 2.0 + a * 3.0, Color(1, 1, 1, 0.15 + 0.5 * a))


func _draw_ship(s: TubShip) -> void:
	var k: Dictionary = TubData.KINDS[s.kind]
	var sc := float(k["scale"])
	var alpha := 1.0
	var tint := Color.WHITE
	var d := float(s.depth)
	if s.depth_t > 0.0:
		d = lerpf(float(s.depth_to), float(s.depth), s.depth_t / TubShip.DEPTH_CHANGE)
	if s.kind == "sub":
		alpha = lerpf(1.0, 0.42, d / 2.0)
		tint = Color(1, 1, 1).lerp(Color(0.55, 0.78, 0.9), d / 2.0)
		sc *= lerpf(1.0, 0.88, d / 2.0)
	var rot := s.heading
	var pos := s.pos
	if s.state == "sunk":
		var k2 := clampf(s.sink_t / 2.5, 0.0, 1.0)
		if k2 >= 1.0:
			return
		alpha *= 1.0 - k2
		sc *= 1.0 - 0.35 * k2
		rot += k2 * 1.2
		tint = tint.lerp(Color(0.4, 0.6, 0.7), k2)
	elif s.state == "retreated":
		return
	if s.lifting > 0.0 or (s.is_player and battle.retreat_hold > 0.0):
		var up := clampf((s.lifting if not s.is_player else battle.retreat_hold) / 1.5, 0.0, 1.0)
		sc *= 1.0 + 0.4 * up
		pos += Vector2(0, -30.0 * up)
	if s.hit_flash > 0.0:
		tint = tint.lerp(Color(1.0, 0.4, 0.35), s.hit_flash * 3.0)
	var base := TubArt.texture(String(k["art"]))
	var liv := TubArt.texture(String(k["art"]) + "_livery") if s.kind != "sub" else null
	# Shadow and wake for anything on the surface.
	if d < 0.5 and base and s.state == "active":
		draw_set_transform(pos + Vector2(6, 9), rot, Vector2(sc, sc))
		draw_texture(base, -base.get_size() * 0.5, Color(0, 0.12, 0.18, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if absf(s.speed) > 30.0:
			var back := pos - s.forward() * s.radius()
			var side := s.forward().orthogonal() * (14.0 + absf(s.speed) * 0.06)
			draw_line(back, back - s.forward() * 26.0 + side, Color(1, 1, 1, 0.6), 3.0)
			draw_line(back, back - s.forward() * 26.0 - side, Color(1, 1, 1, 0.6), 3.0)
	var mod := Color(tint.r, tint.g, tint.b, alpha)
	draw_set_transform(pos, rot, Vector2(sc, sc))
	if s.kind == "duck" and liv:
		draw_texture(liv, -liv.get_size() * 0.5, Color(s.livery.r, s.livery.g, s.livery.b, alpha) * Color(tint.r, tint.g, tint.b, 1.0))
	if base:
		draw_texture(base, -base.get_size() * 0.5, mod)
	if s.kind != "duck" and liv:
		draw_texture(liv, -liv.get_size() * 0.5, Color(s.livery.r, s.livery.g, s.livery.b, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Bubble shield.
	if s.shield and s.state == "active":
		draw_arc(pos, s.radius() + 12.0, 0.0, TAU, 40, Color(0.6, 0.9, 1.0, 0.5 + 0.2 * sin(_t * 4.0)), 3.0)
	# Damage: a trickle of dark bubbles.
	if s.state == "active" and s.hull_frac() < 0.5:
		for i in 3:
			var ph := fmod(_t * 0.8 + float(i) * 0.33, 1.0)
			draw_circle(pos + Vector2(sin(float(i) * 2.0 + _t) * 8.0, -ph * 30.0), 3.0 + ph * 4.0, Color(0.35, 0.38, 0.42, 0.5 * (1.0 - ph)))
	if s.revealed_t > 0.0 and s.depth >= 1:
		draw_arc(pos, s.radius() + 18.0, 0.0, TAU, 32, Color(1.0, 0.4, 0.3, 0.5), 2.0)
	# Name and hull for rivals.
	if not s.is_player and s.state == "active":
		var f := TubArt.font(true)
		var label := s.name
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var top := pos + Vector2(0, -s.radius() - 30.0)
		draw_string_outline(f, top - Vector2(w * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(1, 1, 1, 0.9))
		draw_string(f, top - Vector2(w * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
		var bar := Rect2(top + Vector2(-30, 6), Vector2(60, 7))
		draw_rect(bar, Color(0, 0, 0, 0.35))
		draw_rect(Rect2(bar.position, Vector2(60.0 * s.hull_frac(), 7)), Color(0.4, 0.85, 0.4) if s.hull_frac() > 0.5 else Color(1.0, 0.55, 0.25))


func _draw_foam() -> void:
	for i in battle.foam.size():
		var f: Dictionary = battle.foam[i]
		var parts: Array = _foam_shapes[i] if i < _foam_shapes.size() else []
		for pt in parts:
			var off: Vector2 = pt[0]
			var r := float(pt[1]) * (1.0 + 0.06 * sin(_t * 2.0 + float(pt[2])))
			var c: Vector2 = (f["pos"] as Vector2) + off
			draw_circle(c, r, Color(1, 1, 1, 0.82))
			draw_arc(c, r, 0.0, TAU, 20, Color(0.75, 0.88, 0.95, 0.7), 1.5)
			draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.22, Color(1, 1, 1, 1))


func _draw_fx() -> void:
	var f := TubArt.font(true)
	for e in _fx:
		var k := float(e["t"]) / float(e["dur"])
		var p: Vector2 = e["pos"]
		match String(e["type"]):
			"ring":
				var col: Color = e["col"]
				draw_arc(p, float(e["r"]) * (0.4 + k), 0.0, TAU, 32, Color(col.r, col.g, col.b, col.a * (1.0 - k)), 3.0)
			"splash":
				draw_circle(p, float(e["r"]) * (0.3 + 0.7 * k), Color(1, 1, 1, 0.45 * (1.0 - k)))
				draw_arc(p, float(e["r"]) * (0.5 + k), 0.0, TAU, 40, Color(1, 1, 1, 0.8 * (1.0 - k)), 4.0)
			"droplets":
				var r := RandomNumberGenerator.new()
				r.seed = int(e["seed"])
				for i in int(e["n"]):
					var a := r.randf() * TAU
					var d := (30.0 + r.randf() * 50.0) * k
					draw_circle(p + Vector2(cos(a), sin(a)) * d, 4.0 * (1.0 - k) + 1.0, Color(0.9, 0.97, 1.0, 1.0 - k))
			"dome":
				draw_circle(p, float(e["r"]) * (0.2 + 0.8 * k), Color(0.95, 0.98, 1.0, 0.55 * (1.0 - k)))
				draw_arc(p, float(e["r"]) * (0.3 + 0.8 * k), 0.0, TAU, 40, Color(1, 1, 1, 0.9 * (1.0 - k)), 3.0)
			"ping":
				draw_arc(p, float(e["r"]) * k, 0.0, TAU, 64, Color(0.6, 0.95, 1.0, 0.7 * (1.0 - k)), 2.5)
			"squeak":
				var w := f.get_string_size("SQUEAK!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
				draw_string_outline(f, p + Vector2(-w * 0.5, -46.0 - 20.0 * k), "SQUEAK!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(1, 1, 1, 1.0 - k))
				draw_string(f, p + Vector2(-w * 0.5, -46.0 - 20.0 * k), "SQUEAK!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.6, 0.1, 1.0 - k))
			"label":
				var txt := String(e["text"])
				var w2 := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				var col2: Color = e["col"]
				draw_string_outline(f, p + Vector2(-w2 * 0.5, -24.0 * k), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(1, 1, 1, 1.0 - k * k))
				draw_string(f, p + Vector2(-w2 * 0.5, -24.0 * k), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(col2.r, col2.g, col2.b, 1.0 - k * k))
			"bubble":
				_draw_speech(e, f, k)


func _draw_speech(e: Dictionary, f: Font, k: float) -> void:
	var s: TubShip = null
	for sh in battle.ships:
		if sh.id == String(e["id"]):
			s = sh
	if s == null:
		return
	var txt := String(e["text"])
	var size := 17
	var w := minf(f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, 320.0)
	var lines := ceili(f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 320.0)
	var box := Rect2(s.pos + Vector2(-w * 0.5 - 12.0, -s.radius() - 88.0 - 22.0 * float(lines)), Vector2(w + 24.0, 18.0 + 22.0 * float(lines)))
	var a := 1.0 if k < 0.85 else (1.0 - k) / 0.15
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.95 * a)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(INK.r, INK.g, INK.b, a)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, box)
	var tip := Vector2(s.pos.x, box.end.y)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-8, -1), tip + Vector2(8, -1), tip + Vector2(0, 12)]), Color(1, 1, 1, 0.95 * a))
	draw_multiline_string(f, box.position + Vector2(12, 26), txt, HORIZONTAL_ALIGNMENT_LEFT, 320.0, size, -1, Color(INK.r, INK.g, INK.b, a))
