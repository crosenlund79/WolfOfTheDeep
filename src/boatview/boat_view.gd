class_name BoatView
extends Control
## Interior presentation: an illustrated, living cutaway of the whole boat.
## Every compartment is visible at once with the crew at their stations;
## clicking a compartment glides in to it, where its stations can be used.
## Drawn entirely in 2D (vector shapes), lit by the boat's own state: time of
## day, red lighting, alert, silent running, depth, the sea outside.

signal compartment_chosen(id: String)
signal hotspot(id: String)
signal talk(id: String)

# --- geometry (world units; about 60 per metre, compressed lengthwise) -------
const CY := 560.0
const R := 170.0
const X_STERN := 150.0
const X_TAPER := 400.0
const X_BOW0 := 1620.0
const X_BOW := 1800.0
const SHELL := 12.0
const DECK_Y := 622.0
const LOWER_Y := 716.0
const LADDER_X := 1104.0
const SAIL_X0 := 1030.0
const SAIL_X1 := 1236.0
const SAIL_TOP := 236.0
const CASING := CY - R - 16.0

const COMPS := {
	"engine": {"name": "ENGINE ROOM", "x0": 372.0, "x1": 640.0, "light": Color(1.0, 0.84, 0.55), "level": 0.85},
	"mess": {"name": "MESS & GALLEY", "x0": 650.0, "x1": 930.0, "light": Color(1.0, 0.78, 0.5), "level": 1.0},
	"control": {"name": "CONTROL ROOM", "x0": 940.0, "x1": 1300.0, "light": Color(0.86, 0.94, 1.0), "level": 0.95},
	"sonar": {"name": "SONAR ROOM", "x0": 1310.0, "x1": 1460.0, "light": Color(0.5, 1.0, 0.72), "level": 0.6},
	"cabin": {"name": "CAPTAIN'S CABIN", "x0": 1470.0, "x1": 1600.0, "light": Color(1.0, 0.76, 0.46), "level": 0.8},
	"torpedo": {"name": "TORPEDO ROOM", "x0": 1610.0, "x1": 1776.0, "light": Color(0.9, 0.93, 0.86), "level": 0.75},
}
const ORDER := ["engine", "mess", "control", "sonar", "cabin", "torpedo"]

const STYLES := {
	"miller": {"top": Color(0.14, 0.18, 0.28), "legs": Color(0.09, 0.1, 0.13), "skin": Color(0.88, 0.72, 0.62), "hair": Color(0.74, 0.74, 0.72), "w": 1.0, "h": 1.03, "epaulettes": true},
	"basse": {"top": Color(0.92, 0.92, 0.88), "legs": Color(0.17, 0.17, 0.19), "skin": Color(0.92, 0.67, 0.56), "hair": Color(0.12, 0.12, 0.13), "w": 1.3, "h": 0.98, "apron": true, "beanie": true, "beard": Color(0.4, 0.34, 0.3)},
	"freja": {"top": Color(0.16, 0.21, 0.32), "legs": Color(0.1, 0.11, 0.14), "skin": Color(0.95, 0.8, 0.72), "hair": Color(0.9, 0.79, 0.52), "w": 0.88, "h": 0.95, "headphones": true, "bun": true},
	"erik": {"top": Color(0.34, 0.36, 0.38), "legs": Color(0.3, 0.32, 0.34), "skin": Color(0.9, 0.72, 0.62), "hair": Color(0.52, 0.36, 0.22), "w": 1.12, "h": 1.07, "straps": Color(0.92, 0.46, 0.1), "beard": Color(0.5, 0.34, 0.22)},
	"maya": {"top": Color(0.15, 0.19, 0.29), "legs": Color(0.1, 0.11, 0.14), "skin": Color(0.88, 0.72, 0.58), "hair": Color(0.06, 0.05, 0.05), "w": 0.88, "h": 0.94, "ponytail": true},
	"captain": {"top": Color(0.1, 0.12, 0.17), "legs": Color(0.07, 0.08, 0.1), "skin": Color(0.88, 0.72, 0.62), "hair": Color(0.32, 0.25, 0.18), "w": 1.02, "h": 1.0, "cap": true, "epaulettes": true},
	"haugen": {"top": Color(0.22, 0.29, 0.38), "legs": Color(0.13, 0.15, 0.19), "skin": Color(0.9, 0.74, 0.64), "hair": Color(0.7, 0.55, 0.32), "w": 0.98, "h": 0.99},
	"rask": {"top": Color(0.22, 0.29, 0.38), "legs": Color(0.13, 0.15, 0.19), "skin": Color(0.86, 0.68, 0.56), "hair": Color(0.2, 0.15, 0.1), "w": 1.0, "h": 1.0},
	"dahl": {"top": Color(0.36, 0.37, 0.36), "legs": Color(0.3, 0.31, 0.31), "skin": Color(0.9, 0.73, 0.62), "hair": Color(0.82, 0.72, 0.5), "w": 1.05, "h": 0.98},
	"rating": {"top": Color(0.24, 0.3, 0.38), "legs": Color(0.14, 0.16, 0.2), "skin": Color(0.84, 0.68, 0.58), "hair": Color(0.28, 0.2, 0.14), "w": 1.0, "h": 0.98},
}

var sub: Submarine
var crew: Crew
var weather: Weather
var clock: GameClock
var audio: AudioManager
var encounter: Encounter
var area: ArcticArea
var rig_for_red := false
var captain_location := "control"
var captain_asleep := false
var poker_open := false

var focus_id := ""
var _scale := 1.0
var _offset := Vector2.ZERO
var _xf := Transform2D.IDENTITY
var _ready_xf := false
var _hover_comp := ""
var _hover_crew := ""
var _hover_spot := ""
var _sprites: Dictionary = {}
var _bubbles: Dictionary = {}
var _snow := PackedVector2Array()
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _bunks: Array[Vector2] = []
var _bunk_of: Dictionary = {}
var _snap := true


class Sprite:
	var id := ""
	var name := ""
	var style := "rating"
	var pos := Vector2.ZERO
	var target := Vector2.ZERO
	var pose := "stand"
	var target_pose := "stand"
	var face := 1.0
	var target_face := 1.0
	var act := ""
	var phase := 0.0
	var visible := true
	var comp := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 77
	for i in 180:
		_snow.append(Vector2(_rng.randf_range(-400.0, 2400.0), _rng.randf_range(-300.0, 1300.0)))
	for tier: float in [656.0, 702.0]:
		for bx: float in [700.0, 790.0, 880.0, 970.0, 1060.0]:
			_bunks.append(Vector2(bx, tier))


# --- public ---------------------------------------------------------------------

func focus_on(id: String) -> void:
	focus_id = id


func comp_name(id: String) -> String:
	return "WHOLE BOAT" if id == "" else String(COMPS[id]["name"])


func on_line(speaker: String, color: Color, text: String, _channel: String) -> void:
	var id := ""
	for k in crew.members:
		if (crew.members[k] as CrewMember).short == speaker:
			id = k
	if id == "":
		return
	var short := text if text.length() < 96 else text.substr(0, 92) + "..."
	_bubbles[id] = {"text": short, "color": color, "t": minf(2.6 + text.length() * 0.05, 9.0)}


func handle_key(event: InputEvent) -> bool:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return false
	if k.keycode == KEY_BACKSPACE:
		focus_id = ""
		return true
	if k.keycode == KEY_R:
		rig_for_red = not rig_for_red
		return true
	return false


# --- update -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		_snap = true
		return
	var dt := minf(delta, 0.1)
	_t += dt
	var snap := _snap
	_update_transform(dt, snap)
	_update_sprites(dt, snap)
	_snap = false
	for id in _bubbles.keys():
		_bubbles[id]["t"] = float(_bubbles[id]["t"]) - dt
		if float(_bubbles[id]["t"]) <= 0.0:
			_bubbles.erase(id)
	queue_redraw()


func _focus_rect(id: String) -> Rect2:
	if id == "":
		return Rect2(110.0, 120.0, 1740.0, 660.0)
	var c: Dictionary = COMPS[id]
	var x0 := float(c["x0"]) - 30.0
	var x1 := float(c["x1"]) + 30.0
	var top := 372.0 if id != "control" else 210.0
	return Rect2(x0, top, x1 - x0, 738.0 - top)


func _update_transform(dt: float, snap: bool) -> void:
	var vp := size
	var area_r := Rect2(78.0, 84.0, vp.x - 108.0, vp.y - 84.0 - 150.0)
	if captain_asleep:
		area_r = Rect2(78.0, 140.0, vp.x - 108.0, vp.y - 140.0 - 340.0)
	var r := _focus_rect(focus_id)
	var s := minf(area_r.size.x / r.size.x, area_r.size.y / r.size.y)
	var off := area_r.position + area_r.size * 0.5 - r.get_center() * s
	if snap or not _ready_xf:
		_scale = s
		_offset = off
		_ready_xf = true
	else:
		var k := 1.0 - exp(-dt * 5.0)
		_scale = lerpf(_scale, s, k)
		_offset = _offset.lerp(off, k)
	var pitch := clampf(sub.basis.get_euler().x * 0.5, -0.12, 0.12) if sub else 0.0
	var pivot := Vector2(1080.0, CY)
	_xf = Transform2D(0.0, _offset) * Transform2D(0.0, Vector2(_scale, _scale), 0.0, Vector2.ZERO) * Transform2D(-pitch, pivot) * Transform2D(0.0, -pivot)


# --- crew placement --------------------------------------------------------------

func _slot(id: String, loc: String, act: String, awake: bool) -> Dictionary:
	if not awake or loc == "bunks":
		return {"pos": _bunk_for(id), "pose": "lie", "face": 1.0, "comp": ""}
	match loc:
		"control":
			if act == "on sonar":
				var x := 1352.0
				if id != "freja" and _sonar_taken_by_freja():
					x = 1408.0
				return {"pos": Vector2(x, DECK_Y), "pose": "sit", "face": 1.0, "comp": "sonar", "act": "type"}
			match id:
				"miller":
					return {"pos": Vector2(1158.0, DECK_Y), "pose": "stand", "face": 1.0, "comp": "control", "act": "conn"}
				"maya":
					return {"pos": Vector2(1004.0, DECK_Y), "pose": "stand", "face": -1.0, "comp": "control", "act": "chart"}
				"rask":
					return {"pos": Vector2(1226.0, DECK_Y), "pose": "sit", "face": 1.0, "comp": "control", "act": "type"}
				"freja":
					return {"pos": Vector2(1352.0, DECK_Y), "pose": "sit", "face": 1.0, "comp": "sonar", "act": "type"}
				"haugen":
					return {"pos": Vector2(1408.0, DECK_Y), "pose": "sit", "face": 1.0, "comp": "sonar", "act": "type"}
			return {"pos": Vector2(1060.0 + float(id.hash() % 40), DECK_Y), "pose": "stand", "face": 1.0, "comp": "control", "act": "idle"}
		"mess":
			if id == "basse" and act in ["cooking", "securing the galley"]:
				return {"pos": Vector2(728.0, DECK_Y), "pose": "stand", "face": -1.0, "comp": "mess", "act": "cook"}
			return _mess_seat(id)
		"engine":
			if id == "erik":
				return {"pos": Vector2(598.0, DECK_Y), "pose": "stand", "face": 1.0, "comp": "engine", "act": "panel"}
			return {"pos": Vector2(470.0, DECK_Y), "pose": "stand", "face": -1.0, "comp": "engine", "act": "tool"}
	return {"pos": _bunk_for(id), "pose": "lie", "face": 1.0, "comp": ""}


func _sonar_taken_by_freja() -> bool:
	var f: CrewMember = crew.members.get("freja")
	return f != null and f.awake and f.location == "control" and f.activity == "on sonar"


const SEATS := [[772.0, 1.0], [890.0, -1.0], [748.0, 1.0], [914.0, -1.0], [796.0, 1.0], [866.0, -1.0]]


func _mess_seat(id: String) -> Dictionary:
	var ids: Array = []
	for k in crew.members:
		var m: CrewMember = crew.members[k]
		if m.awake and m.location == "mess" and not (k == "basse" and m.activity in ["cooking", "securing the galley"]):
			ids.append(k)
	if captain_location == "mess" and not captain_asleep:
		ids.append("captain")
	ids.sort()
	var i := maxi(ids.find(id), 0) % SEATS.size()
	var s: Array = SEATS[i]
	return {"pos": Vector2(float(s[0]), DECK_Y), "pose": "sit", "face": float(s[1]), "comp": "mess", "act": "cards" if poker_open else "eat"}


func _bunk_for(id: String) -> Vector2:
	if not _bunk_of.has(id):
		_bunk_of[id] = _bunks[_bunk_of.size() % _bunks.size()]
	return _bunk_of[id]


func _captain_slot() -> Dictionary:
	if captain_asleep:
		return {"pos": Vector2(1522.0, 578.0), "pose": "lie", "face": -1.0, "comp": "cabin"}
	match captain_location:
		"mess":
			return _mess_seat("captain")
		"cabin":
			return {"pos": Vector2(1560.0, DECK_Y), "pose": "sit", "face": 1.0, "comp": "cabin", "act": "write"}
		"engine":
			return {"pos": Vector2(540.0, DECK_Y), "pose": "stand", "face": 1.0, "comp": "engine", "act": "idle"}
	if focus_id == "sonar":
		return {"pos": Vector2(1326.0, DECK_Y), "pose": "stand", "face": 1.0, "comp": "sonar", "act": "idle"}
	if focus_id == "torpedo":
		return {"pos": Vector2(1640.0, DECK_Y), "pose": "stand", "face": 1.0, "comp": "torpedo", "act": "idle"}
	return {"pos": Vector2(1096.0, DECK_Y), "pose": "stand", "face": 1.0, "comp": "control", "act": "scope"}


func _extras() -> Array:
	var out: Array = []
	var h := clock.hours() if clock else 12.0
	out.append(["planes", "Planesman", {"pos": Vector2(1272.0, DECK_Y), "pose": "sit", "face": 1.0, "comp": "control", "act": "type"}])
	if h >= 7.0 and h < 22.0:
		out.append(["torpedoman", "Torpedoman", {"pos": Vector2(1690.0, DECK_Y), "pose": "stand", "face": 1.0, "comp": "torpedo", "act": "tool"}])
	else:
		out.append(["torpedoman", "Torpedoman", {"pos": _bunk_for("torpedoman"), "pose": "lie", "face": 1.0, "comp": ""}])
	out.append(["offwatch", "Off-watch rating", {"pos": _bunk_for("offwatch"), "pose": "lie", "face": -1.0, "comp": ""}])
	if sub and sub.is_surfaced():
		out.append(["lookout1", "Lookout", {"pos": Vector2(1078.0, SAIL_TOP), "pose": "stand", "face": 1.0, "comp": "bridge", "act": "binoculars"}])
		out.append(["lookout2", "Lookout", {"pos": Vector2(1176.0, SAIL_TOP), "pose": "stand", "face": -1.0, "comp": "bridge", "act": "binoculars"}])
	return out


func _update_sprites(dt: float, snap: bool) -> void:
	if crew == null:
		return
	var wanted: Dictionary = {}
	for k in crew.members:
		var m: CrewMember = crew.members[k]
		wanted[k] = [m.short.capitalize() + "  ·  " + m.rank, _slot(k, m.location, m.activity, m.awake)]
	wanted["captain"] = ["Captain", _captain_slot()]
	for e in _extras():
		wanted[e[0]] = [e[1], e[2]]
	for k in _sprites.keys():
		if not wanted.has(k):
			_sprites.erase(k)
	var speed := 95.0 * clampf((clock.scale() if clock else 1.0) / 4.0, 1.0, 8.0)
	if captain_asleep:
		speed = 95.0 * 30.0
	for k in wanted:
		var slot: Dictionary = wanted[k][1]
		var s: Sprite = _sprites.get(k)
		var tp: Vector2 = slot["pos"]
		if s == null:
			s = Sprite.new()
			s.id = k
			s.style = k if STYLES.has(k) else "rating"
			s.phase = _rng.randf() * 10.0
			s.pos = tp
			_sprites[k] = s
		s.name = String(wanted[k][0])
		s.target = tp
		s.target_pose = String(slot["pose"])
		s.target_face = float(slot["face"])
		s.act = String(slot.get("act", ""))
		s.comp = String(slot.get("comp", ""))
		if snap or slot["comp"] == "bridge":
			s.pos = tp
		_move(s, dt, speed * (3.0 if k == "captain" else 1.0))


func _floor_of(y: float) -> float:
	return DECK_Y if y < 640.0 else LOWER_Y


func _move(s: Sprite, dt: float, speed: float) -> void:
	var lie := s.target_pose == "lie"
	var goal_floor := LOWER_Y if (lie and s.target.y > 640.0) else DECK_Y
	if lie and s.target.y < 640.0:
		goal_floor = DECK_Y
	var cur_floor := _floor_of(s.pos.y) if s.pose != "lie" else (LOWER_Y if s.pos.y > 640.0 else DECK_Y)
	var arrived := s.pos.distance_to(s.target) < 1.0
	if arrived:
		s.pose = s.target_pose
		s.face = s.target_face
		return
	if s.pose == "lie":
		# Get up first: stand on the floor beneath the bunk.
		s.pos = Vector2(s.pos.x, cur_floor)
		s.pose = "walk"
	if absf(cur_floor - goal_floor) > 2.0:
		if absf(s.pos.x - LADDER_X) > 2.0:
			s.pose = "walk"
			s.face = signf(LADDER_X - s.pos.x)
			s.pos.x = move_toward(s.pos.x, LADDER_X, speed * dt)
		else:
			s.pose = "climb"
			s.pos.y = move_toward(s.pos.y, goal_floor, speed * 0.6 * dt)
		return
	var tx := s.target.x
	if absf(s.pos.x - tx) > 1.0:
		s.pose = "walk"
		s.face = signf(tx - s.pos.x)
		s.pos.x = move_toward(s.pos.x, tx, speed * dt)
		s.pos.y = goal_floor
		return
	# Over the spot: settle into the bunk / seat.
	s.pos = s.target
	s.pose = s.target_pose
	s.face = s.target_face


# --- lighting ------------------------------------------------------------------------

func _comp_light(id: String) -> Color:
	var c: Dictionary = COMPS[id]
	var col: Color = c["light"]
	var lv := float(c["level"])
	var night := clock != null and clock.is_night()
	if (rig_for_red or night) and id in ["control", "sonar"]:
		col = Color(1.0, 0.24, 0.16)
		lv *= 0.75
	elif night:
		lv *= 0.72
	if crew and crew.silent_running:
		lv *= 0.6
	if crew and crew.alert >= 2:
		var pulse := 0.5 + 0.5 * sin(_t * 3.2)
		col = col.lerp(Color(1.0, 0.18, 0.12), 0.55 + 0.25 * pulse)
	if id == "engine" and sub and sub.diesels_running:
		lv *= 1.0 + 0.08 * sin(_t * 23.0)
	return Color(col.r, col.g, col.b, lv)


func _lit(base: Color, light: Color, extra: float = 0.0) -> Color:
	var lv := light.a
	var k := 0.38 + 0.62 * lv + extra
	return Color(clampf(base.r * (0.55 + 0.45 * light.r) * k, 0.0, 1.0), clampf(base.g * (0.55 + 0.45 * light.g) * k, 0.0, 1.0), clampf(base.b * (0.55 + 0.45 * light.b) * k, 0.0, 1.0), base.a)


# --- geometry helpers -----------------------------------------------------------------

static func hull_r(x: float) -> float:
	if x <= X_STERN:
		return 0.0
	if x < X_TAPER:
		var u := (x - X_STERN) / (X_TAPER - X_STERN)
		return lerpf(24.0, R, pow(u, 0.62))
	if x <= X_BOW0:
		return R
	if x < X_BOW:
		var v := (x - X_BOW0) / (X_BOW - X_BOW0)
		return R * sqrt(maxf(1.0 - v * v, 0.0))
	return 0.0


static func ceil_y(x: float) -> float:
	return CY - hull_r(x) + SHELL


static func floor_low(x: float) -> float:
	return CY + hull_r(x) - SHELL


func _vgrad(pts: PackedVector2Array, top: Color, bottom: Color, y0: float, y1: float) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - y0) / maxf(y1 - y0, 1.0), 0.0, 1.0)))
	draw_polygon(pts, cols)


func _rect(r: Rect2, c: Color) -> void:
	draw_rect(r, c)


func _grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))


func _capsule(a: Vector2, b: Vector2, r: float, c: Color) -> void:
	draw_line(a, b, c, r * 2.0, true)
	draw_circle(a, r, c, true, -1.0, true)
	draw_circle(b, r, c, true, -1.0, true)


func _cone(apex: Vector2, top_w: float, bottom_w: float, length: float, c: Color) -> void:
	var clear := Color(c.r, c.g, c.b, 0.0)
	draw_polygon(PackedVector2Array([apex + Vector2(-top_w, 0), apex + Vector2(top_w, 0), apex + Vector2(bottom_w, length), apex + Vector2(-bottom_w, length)]), PackedColorArray([c, c, clear, clear]))


func _glow(p: Vector2, r: float, c: Color) -> void:
	for i in 6:
		var k := 1.0 - float(i) / 6.0
		draw_circle(p, r * k, Color(c.r, c.g, c.b, c.a * 0.22), true, -1.0, true)


func _comp_poly(x0: float, x1: float, y_floor: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, y_floor))
	pts.append(Vector2(x1, y_floor))
	var n := 10
	for i in range(n, -1, -1):
		var x := lerpf(x0, x1, float(i) / float(n))
		pts.append(Vector2(x, minf(ceil_y(x), y_floor - 4.0)))
	return pts


# --- drawing ---------------------------------------------------------------------------

func _draw() -> void:
	if sub == null:
		return
	draw_set_transform_matrix(_xf)
	_draw_sea()
	_draw_outer_hull()
	_draw_interior()
	_draw_people()
	_draw_foreground()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_screen_overlays()


func _surface_y() -> float:
	return CASING + 10.0 - (sub.depth - 2.05) * 26.0


func _day() -> float:
	return 1.0 - (weather.darkness() if weather else 0.0)


func _draw_sea() -> void:
	var inv := _xf.affine_inverse()
	var a := inv * Vector2.ZERO
	var b := inv * size
	var x0 := minf(a.x, b.x) - 200.0
	var x1 := maxf(a.x, b.x) + 200.0
	var y0 := minf(a.y, b.y) - 200.0
	var y1 := maxf(a.y, b.y) + 200.0
	var day := _day()
	var depth_dark := clampf(sub.depth / 160.0, 0.0, 1.0)
	var sea_top := Color(0.03, 0.09, 0.13).lerp(Color(0.1, 0.32, 0.38), day * (1.0 - depth_dark * 0.8))
	var sea_bot := Color(0.004, 0.012, 0.02).lerp(Color(0.02, 0.09, 0.12), day * (1.0 - depth_dark))
	var sy := _surface_y()
	var hs := float(weather.current.get("hs", 1.5)) if weather else 1.5
	if sy > y0:
		var sky_top: Color = weather.current.get("zenith", Color(0.2, 0.3, 0.45)) if weather else Color(0.2, 0.3, 0.45)
		var sky_bot: Color = weather.current.get("horizon", Color(0.5, 0.6, 0.7)) if weather else Color(0.5, 0.6, 0.7)
		_grad_rect(Rect2(x0, y0, x1 - x0, sy - y0 + 20.0), sky_top.lerp(Color(0.02, 0.03, 0.05), 0.2), sky_bot)
		if weather and float(weather.current.get("stars", 0.0)) > 0.2:
			for i in 60:
				var p := Vector2(fposmod(i * 197.0, 2400.0) - 300.0, y0 + fposmod(i * 71.0, maxf(sy - y0, 1.0)))
				draw_circle(p, 1.2, Color(1, 1, 1, 0.5 * float(weather.current.get("stars", 0.0))))
	_grad_rect(Rect2(x0, maxf(sy, y0), x1 - x0, y1 - maxf(sy, y0)), sea_top, sea_bot)
	# Light shafts from the surface on bright days.
	if day > 0.3 and sy > y0 - 400.0:
		for i in 7:
			var sx := 200.0 + i * 260.0 + sin(_t * 0.2 + i) * 30.0
			var clr := Color(0.7, 0.9, 1.0, 0.05 * day * (1.0 - depth_dark))
			draw_polygon(PackedVector2Array([Vector2(sx, sy), Vector2(sx + 70, sy), Vector2(sx + 250, sy + 700), Vector2(sx + 120, sy + 700)]), PackedColorArray([clr, clr, Color(clr, 0.0), Color(clr, 0.0)]))
	# The surface itself.
	if sy > y0 and sy < y1:
		var amp := clampf(hs * 3.0, 2.0, 16.0)
		var pts := PackedVector2Array()
		var x := x0
		while x <= x1:
			pts.append(Vector2(x, sy + sin(x * 0.012 + _t * 1.3) * amp + sin(x * 0.031 - _t * 0.8) * amp * 0.4))
			x += 18.0
		var under := pts.duplicate()
		under.append(Vector2(x1, sy + 60.0))
		under.append(Vector2(x0, sy + 60.0))
		draw_colored_polygon(under, Color(sea_top.lightened(0.15), 0.6))
		draw_polyline(pts, Color(0.85, 0.95, 1.0, 0.55), 2.0, true)
		if area and sub.global_position.z < area.ice_edge_z(sub.global_position.x) + 200.0:
			for i in 14:
				var fx := 200.0 + i * 120.0
				draw_colored_polygon(PackedVector2Array([Vector2(fx, sy - 6), Vector2(fx + 90, sy - 4), Vector2(fx + 80, sy + 14), Vector2(fx + 8, sy + 12)]), Color(0.86, 0.92, 0.95, 0.9))
	# Seabed when it is close.
	if area:
		var under_keel := area.seabed_depth(sub.global_position.x, sub.global_position.z) - sub.depth
		var by := CY + R + under_keel * 26.0
		if by < y1:
			var bed := PackedVector2Array()
			var x2 := x0
			while x2 <= x1:
				bed.append(Vector2(x2, by + sin(x2 * 0.01) * 14.0 + sin(x2 * 0.043) * 6.0))
				x2 += 24.0
			bed.append(Vector2(x1, y1))
			bed.append(Vector2(x0, y1))
			draw_colored_polygon(bed, Color(0.07, 0.07, 0.06).lerp(Color(0.18, 0.17, 0.13), day * 0.5))
	# Ice nearby: a keel looming in the gloom.
	if area:
		var near := area.ice_near(sub.global_position, 900.0)
		if not near.is_empty():
			var berg: Dictionary = near[0]["berg"]
			var rel: Vector3 = (berg["pos"] as Vector3) - sub.global_position
			var along := rel.dot(sub.forward())
			var bx := 1080.0 + clampf(along, -900.0, 900.0) * 0.9
			var keel := float(berg["keel"])
			var ky := clampf(sy + keel * 26.0, sy + 40.0, sy + 3000.0)
			var fade := clampf(1.0 - float(near[0]["dist"]) / 900.0, 0.15, 0.8)
			draw_colored_polygon(PackedVector2Array([Vector2(bx - 260, sy), Vector2(bx + 300, sy), Vector2(bx + 180, ky * 0.6 + sy * 0.4), Vector2(bx + 40, ky), Vector2(bx - 120, ky * 0.7 + sy * 0.3)]), Color(0.55, 0.75, 0.82, 0.25 * fade))
	# Marine snow drifting past.
	var drift := sub.speed * 18.0
	for p in _snow:
		var q := Vector2(fposmod(p.x - _t * drift, 2800.0) - 400.0, fposmod(p.y + _t * 6.0, 1600.0) - 300.0)
		if q.y > sy:
			draw_circle(q, 1.5, Color(0.75, 0.9, 0.9, 0.16 + 0.1 * day))
	# Bubbles from the screw.
	if sub.speed > 0.5 and not sub.is_surfaced():
		for i in 14:
			var u := fposmod(_t * 0.7 + i * 0.13, 1.0)
			var bpos := Vector2(132.0 - u * 220.0 + sin(i * 7.0) * 10.0, CY + sin(i * 3.1) * 40.0 - u * 90.0)
			draw_circle(bpos, 2.0 + u * 3.0, Color(0.8, 0.95, 1.0, 0.35 * (1.0 - u)), false, 1.2, true)


func _draw_outer_hull() -> void:
	var steel_top := Color(0.2, 0.24, 0.26).lerp(Color(0.32, 0.38, 0.4), _day() * 0.5)
	var steel_bot := Color(0.04, 0.05, 0.06)
	# Rudder and screw.
	draw_colored_polygon(PackedVector2Array([Vector2(250, CY - 30), Vector2(205, CY - 118), Vector2(168, CY - 118), Vector2(176, CY - 20)]), steel_top.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(250, CY + 30), Vector2(205, CY + 118), Vector2(168, CY + 118), Vector2(176, CY + 20)]), steel_bot.lightened(0.05))
	var blade := absf(sin(_t * sub.knots() * 0.8)) * 62.0 + 8.0
	draw_line(Vector2(134, CY - blade), Vector2(134, CY + blade), Color(0.35, 0.3, 0.2), 9.0, true)
	draw_circle(Vector2(140, CY), 10.0, Color(0.32, 0.28, 0.2), true, -1.0, true)
	# Casing (outer light hull) and the pressure hull silhouette.
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var x := X_STERN
	while x <= X_BOW:
		var r := hull_r(x)
		var cas := minf(CY - r, maxf(CASING, CY - r - 16.0)) if x > 300.0 and x < 1700.0 else CY - r
		top.append(Vector2(x, cas))
		bot.append(Vector2(x, CY + r))
		x += 10.0
	var outline := top.duplicate()
	bot.reverse()
	outline.append_array(bot)
	_vgrad(outline, steel_top, steel_bot, CASING, CY + R)
	draw_polyline(top, Color(0.55, 0.62, 0.64, 0.6), 2.0, true)
	# Sail, bridge and masts.
	var sail := PackedVector2Array([Vector2(SAIL_X0, CASING), Vector2(SAIL_X0 + 14, SAIL_TOP + 26), Vector2(SAIL_X0 + 40, SAIL_TOP), Vector2(SAIL_X1 - 30, SAIL_TOP), Vector2(SAIL_X1, CASING)])
	_vgrad(sail, steel_top.lightened(0.08), steel_top.darkened(0.3), SAIL_TOP, CASING)
	draw_polyline(PackedVector2Array([sail[0], sail[1], sail[2], sail[3], sail[4]]), Color(0.6, 0.66, 0.68, 0.5), 2.0, true)
	draw_line(Vector2(SAIL_X0 + 60, SAIL_TOP + 40), Vector2(SAIL_X0 + 120, SAIL_TOP + 40), steel_top.darkened(0.4), 6.0)
	var ext := sub.mast_extension()
	for m in [[1082.0, 6.0, 95.0, "radio"], [1124.0, 8.0, 118.0, "scope"], [1170.0, 10.0, 105.0, "snorkel"]]:
		var mx := float(m[0])
		var w := float(m[1])
		var h := float(m[2]) * ext
		if h > 2.0:
			draw_rect(Rect2(mx - w * 0.5, SAIL_TOP - h, w, h), Color(0.12, 0.13, 0.14))
			draw_rect(Rect2(mx - w * 0.5 - 2.0, SAIL_TOP - h - 8.0, w + 4.0, 10.0), Color(0.18, 0.19, 0.2))
			if m[3] == "snorkel" and sub.diesels_running and _surface_y() > SAIL_TOP - h - 40.0:
				for i in 5:
					var u := fposmod(_t * 0.5 + i * 0.2, 1.0)
					draw_circle(Vector2(mx - u * 60.0, SAIL_TOP - h - 16.0 - u * 40.0), 6.0 + u * 14.0, Color(0.5, 0.5, 0.5, 0.25 * (1.0 - u)), true, -1.0, true)
	# Bow sonar dome.
	var dome := PackedVector2Array()
	for i in 13:
		var aang := -PI * 0.5 + PI * float(i) / 12.0
		dome.append(Vector2(X_BOW - 70.0 + cos(aang) * 66.0, CY + sin(aang) * 110.0))
	draw_colored_polygon(dome, Color(0.16, 0.2, 0.2, 0.55))


func _draw_interior() -> void:
	var x0 := 372.0
	var x1 := 1776.0
	# The cut-away void inside the pressure hull.
	var inner := PackedVector2Array()
	var x := x0
	while x <= x1:
		inner.append(Vector2(x, ceil_y(x)))
		x += 12.0
	x = x1
	while x >= x0:
		inner.append(Vector2(x, floor_low(x)))
		x -= 12.0
	draw_colored_polygon(inner, Color(0.03, 0.035, 0.04))
	# Lower deck: battery, bunks, stores, weapons.
	_draw_lower()
	# Main deck compartments.
	for id in ORDER:
		_draw_comp_back(id)
	_draw_engine()
	_draw_mess()
	_draw_control()
	_draw_sonar()
	_draw_cabin()
	_draw_torpedo()
	# Overhead runs of pipe through the whole boat.
	for p in [[ -0.0, 5.0, Color(0.42, 0.44, 0.45)], [10.0, 3.0, Color(0.25, 0.42, 0.62)], [18.0, 2.5, Color(0.72, 0.58, 0.18)], [25.0, 4.0, Color(0.3, 0.32, 0.33)]]:
		var py := CY - R + SHELL + 14.0 + float(p[0])
		draw_line(Vector2(X_TAPER - 10.0, py), Vector2(X_BOW0, py), _lit(p[2], Color(0.9, 0.9, 0.9, 0.7)), float(p[1]), true)
	# Deck plates.
	_grad_rect(Rect2(x0, DECK_Y, x1 - x0, 7.0), Color(0.36, 0.37, 0.36), Color(0.14, 0.15, 0.15))
	var gx := x0
	while gx < x1:
		draw_line(Vector2(gx, DECK_Y + 1), Vector2(gx, DECK_Y + 6), Color(0.1, 0.1, 0.1), 1.0)
		gx += 14.0
	# Bulkheads, seen edge-on, each with an open watertight doorway.
	for bx: float in [646.0, 935.0, 1305.0, 1465.0, 1605.0]:
		var top := ceil_y(bx)
		var door_top := DECK_Y - 124.0
		var sill := DECK_Y - 12.0
		_grad_rect(Rect2(bx - 5.0, top, 10.0, door_top - top), Color(0.34, 0.36, 0.37), Color(0.2, 0.21, 0.22))
		_grad_rect(Rect2(bx - 5.0, sill, 10.0, floor_low(bx) - sill), Color(0.2, 0.21, 0.22), Color(0.1, 0.11, 0.12))
		# Door frame (an oval seen almost edge-on) and the open door leaf.
		var oval := PackedVector2Array()
		for k in 17:
			var a := -PI * 0.5 + PI * float(k) / 16.0
			oval.append(Vector2(bx + 5.0 + cos(a) * 9.0, (door_top + sill) * 0.5 + sin(a) * (sill - door_top) * 0.5))
		draw_polyline(oval, Color(0.55, 0.57, 0.55, 0.6), 2.0, true)
		draw_line(Vector2(bx - 5.0, door_top), Vector2(bx + 5.0, door_top), Color(0.6, 0.62, 0.6, 0.8), 3.0)
		draw_line(Vector2(bx - 5.0, sill), Vector2(bx + 5.0, sill), Color(0.6, 0.62, 0.6, 0.8), 3.0)
		draw_rect(Rect2(bx + 6.0, door_top + 6.0, 5.0, sill - door_top - 12.0), Color(0.26, 0.28, 0.29))
		draw_circle(Vector2(bx + 8.5, (door_top + sill) * 0.5), 3.0, Color(0.7, 0.22, 0.16), true, -1.0, true)
	# Ladder between decks.
	draw_line(Vector2(LADDER_X - 9, DECK_Y), Vector2(LADDER_X - 9, LOWER_Y), Color(0.55, 0.55, 0.52), 2.0, true)
	draw_line(Vector2(LADDER_X + 9, DECK_Y), Vector2(LADDER_X + 9, LOWER_Y), Color(0.55, 0.55, 0.52), 2.0, true)
	for i in 6:
		draw_line(Vector2(LADDER_X - 9, DECK_Y + 12 + i * 15), Vector2(LADDER_X + 9, DECK_Y + 12 + i * 15), Color(0.5, 0.5, 0.48), 2.0)
	# Flooding.
	if sub.flooding > 0.02:
		var wy := LOWER_Y - sub.flooding * 150.0
		var water := PackedVector2Array()
		var wx := x0
		while wx <= x1:
			water.append(Vector2(wx, minf(wy + sin(wx * 0.05 + _t * 3.0) * 3.0, floor_low(wx))))
			wx += 12.0
		wx = x1
		while wx >= x0:
			water.append(Vector2(wx, floor_low(wx)))
			wx -= 12.0
		draw_colored_polygon(water, Color(0.1, 0.3, 0.4, 0.6))


func _draw_comp_back(id: String) -> void:
	var c: Dictionary = COMPS[id]
	var x0 := float(c["x0"])
	var x1 := float(c["x1"])
	var light := _comp_light(id)
	var wall := Color(0.23, 0.26, 0.27)
	var poly := _comp_poly(x0, x1, DECK_Y)
	var top_y := ceil_y((x0 + x1) * 0.5)
	_vgrad(poly, _lit(wall, light, -0.05), _lit(wall.darkened(0.35), light, -0.1), top_y, DECK_Y)
	# Wall panels and frames.
	var px := x0 + 18.0
	while px < x1 - 8.0:
		draw_line(Vector2(px, maxf(ceil_y(px), top_y) + 30.0), Vector2(px, DECK_Y - 2.0), Color(0, 0, 0, 0.18), 2.0)
		px += 46.0
	draw_line(Vector2(x0, DECK_Y - 34.0), Vector2(x1, DECK_Y - 34.0), Color(0, 0, 0, 0.15), 3.0)
	# Ceiling lamps and their light.
	var n := maxi(1, int((x1 - x0) / 120.0))
	for i in n:
		var lx := lerpf(x0, x1, (float(i) + 0.5) / float(n))
		var ly := ceil_y(lx) + 34.0
		var lc := Color(light.r, light.g, light.b, 0.16 * light.a)
		_cone(Vector2(lx, ly + 4.0), 16.0, 70.0, DECK_Y - ly - 4.0, lc)
		draw_rect(Rect2(lx - 16.0, ly - 3.0, 32.0, 6.0), Color(light.r, light.g, light.b).lerp(Color.WHITE, 0.4) * Color(1, 1, 1, 0.5 + 0.5 * light.a))
		_glow(Vector2(lx, ly), 26.0, Color(light.r, light.g, light.b, 0.5 * light.a))


func _draw_lower() -> void:
	var light := Color(0.9, 0.85, 0.7, 0.45)
	# Battery: cells with a charge read-out.
	for i in 14:
		var bx := 400.0 + i * 17.0
		if bx > 630.0:
			break
		var top := maxf(DECK_Y + 30.0, ceil_y(bx))
		var bh := floor_low(bx) - top - 6.0
		if bh < 12.0:
			continue
		draw_rect(Rect2(bx, top, 13.0, bh), Color(0.12, 0.13, 0.12))
		var charge := clampf(sub.battery / 100.0, 0.0, 1.0)
		var bc := Color(0.3, 0.9, 0.45) if charge > 0.35 else (Color(1.0, 0.7, 0.2) if charge > 0.15 else Color(1.0, 0.25, 0.2))
		draw_rect(Rect2(bx + 3.0, top + bh * (1.0 - charge) + 2.0, 7.0, bh * charge - 4.0), Color(bc, 0.55))
	# Crew bunks: two tiers with curtains.
	for b in _bunks:
		draw_rect(Rect2(b.x - 40.0, b.y + 4.0, 80.0, 6.0), _lit(Color(0.32, 0.3, 0.28), light))
		draw_rect(Rect2(b.x - 38.0, b.y - 2.0, 76.0, 7.0), _lit(Color(0.22, 0.27, 0.38), light))
		draw_rect(Rect2(b.x + 26.0, b.y - 36.0, 14.0, 38.0), _lit(Color(0.35, 0.3, 0.22, 0.85), light))
	for bx in [655.0, 745.0, 835.0, 925.0, 1015.0, 1098.0]:
		draw_line(Vector2(bx, DECK_Y + 7.0), Vector2(bx, LOWER_Y), Color(0.2, 0.2, 0.2), 3.0)
	_glow(Vector2(880.0, DECK_Y + 24.0), 40.0, Color(1.0, 0.7, 0.4, 0.08))
	# Pumps and stores.
	for i in 4:
		var px := 1140.0 + i * 78.0
		draw_rect(Rect2(px, LOWER_Y - 44.0, 40.0, 44.0), _lit(Color(0.25, 0.32, 0.3), light))
		draw_circle(Vector2(px + 20.0, LOWER_Y - 52.0), 10.0, _lit(Color(0.5, 0.18, 0.14), light), true, -1.0, true)
	for i in 3:
		draw_rect(Rect2(1420.0 - i * 24.0, LOWER_Y - 22.0 - (i % 2) * 20.0, 22.0, 20.0), _lit(Color(0.4, 0.34, 0.24), light))
	# Spare weapons.
	for i in 2:
		var ty := DECK_Y + 36.0 + i * 32.0
		var tx1 := minf(1700.0, X_BOW0 + 40.0)
		_capsule(Vector2(1480.0, ty), Vector2(tx1, ty), 9.0, _lit(Color(0.2, 0.28, 0.2), light))


func _draw_engine() -> void:
	var light := _comp_light("engine")
	var shake := Vector2(sin(_t * 41.0), cos(_t * 37.0)) * (1.2 if sub.diesels_running else 0.0)
	for e in [[400.0, 520.0], [452.0, 560.0]]:
		var ex := float(e[0])
		var base := Rect2(ex + shake.x, DECK_Y - 70.0 + shake.y, 78.0, 70.0)
		if e[0] == 452.0:
			base = Rect2(530.0 + shake.x, DECK_Y - 64.0 + shake.y, 56.0, 64.0)
		_grad_rect(base, _lit(Color(0.42, 0.46, 0.4), light, 0.08), _lit(Color(0.18, 0.2, 0.18), light))
		for k in 4:
			draw_rect(Rect2(base.position.x + 6.0 + k * (base.size.x - 12.0) / 4.0, base.position.y - 12.0, (base.size.x - 20.0) / 4.0, 12.0), _lit(Color(0.35, 0.38, 0.34), light))
		draw_line(Vector2(base.position.x + base.size.x * 0.5, base.position.y - 12.0), Vector2(base.position.x + base.size.x * 0.5, ceil_y(base.position.x) + 30.0), _lit(Color(0.3, 0.3, 0.3), light), 8.0)
		if sub.diesels_running:
			_glow(Vector2(base.position.x + base.size.x * 0.5, base.position.y + 20.0), 30.0, Color(1.0, 0.6, 0.2, 0.25))
	# Control panel on the forward bulkhead.
	_grad_rect(Rect2(612.0, DECK_Y - 118.0, 26.0, 118.0), _lit(Color(0.3, 0.34, 0.32), light), _lit(Color(0.16, 0.18, 0.17), light))
	for g in 3:
		var gp := Vector2(625.0, DECK_Y - 100.0 + g * 26.0)
		draw_circle(gp, 8.0, Color(0.9, 0.9, 0.82), true, -1.0, true)
		var v: float = [sub.battery / 100.0, sub.speed / (18.0 * Submarine.KNOT), 1.0 if sub.diesels_running else 0.05][g]
		var ang := lerpf(PI * 0.8, PI * 2.2, clampf(float(v), 0.0, 1.0))
		draw_line(gp, gp + Vector2(cos(ang), sin(ang)) * 6.5, Color(0.8, 0.1, 0.05), 1.5, true)
	# Warning stripes.
	var sx := 392.0
	while sx < 600.0:
		draw_line(Vector2(sx, DECK_Y - 1.0), Vector2(sx + 8.0, DECK_Y - 1.0), Color(0.9, 0.7, 0.1, 0.7), 3.0)
		sx += 16.0


func _draw_mess() -> void:
	var light := _comp_light("mess")
	# Galley: stove, pots, cupboards, shelves.
	_grad_rect(Rect2(656.0, DECK_Y - 52.0, 60.0, 52.0), _lit(Color(0.62, 0.64, 0.64), light, 0.1), _lit(Color(0.3, 0.31, 0.31), light))
	draw_rect(Rect2(656.0, DECK_Y - 55.0, 60.0, 4.0), _lit(Color(0.75, 0.77, 0.78), light))
	_glow(Vector2(686.0, DECK_Y - 56.0), 18.0, Color(1.0, 0.4, 0.1, 0.35))
	draw_rect(Rect2(672.0, DECK_Y - 74.0, 28.0, 20.0), _lit(Color(0.55, 0.56, 0.58), light, 0.1))
	for i in 3:
		var u := fposmod(_t * 0.35 + i * 0.33, 1.0)
		draw_circle(Vector2(686.0 + sin(_t + i) * 6.0, DECK_Y - 80.0 - u * 50.0), 5.0 + u * 9.0, Color(1, 1, 1, 0.12 * (1.0 - u)), true, -1.0, true)
	_grad_rect(Rect2(656.0, DECK_Y - 150.0, 60.0, 40.0), _lit(Color(0.5, 0.42, 0.32), light), _lit(Color(0.36, 0.3, 0.22), light))
	for i in 5:
		draw_rect(Rect2(722.0 + i * 11.0, DECK_Y - 136.0, 8.0, 12.0), _lit(Color.from_hsv(0.08 * i, 0.5, 0.7), light))
	draw_line(Vector2(720.0, DECK_Y - 123.0), Vector2(782.0, DECK_Y - 123.0), _lit(Color(0.4, 0.32, 0.24), light), 3.0)
	# Coffee machine with its red light.
	draw_rect(Rect2(722.0, DECK_Y - 92.0, 22.0, 30.0), _lit(Color(0.12, 0.12, 0.12), light, 0.1))
	draw_circle(Vector2(740.0, DECK_Y - 84.0), 2.0, Color(1.0, 0.15, 0.08), true, -1.0, true)
	draw_rect(Rect2(718.0, DECK_Y - 62.0, 40.0, 4.0), _lit(Color(0.4, 0.33, 0.24), light))
	# Table, benches, and whatever is on the table.
	var wood := _lit(Color(0.46, 0.32, 0.2), light, 0.05)
	draw_rect(Rect2(792.0, DECK_Y - 48.0, 84.0, 6.0), wood)
	draw_rect(Rect2(830.0, DECK_Y - 42.0, 6.0, 42.0), _lit(Color(0.5, 0.52, 0.52), light))
	for bx: float in [742.0, 884.0]:
		draw_rect(Rect2(bx, DECK_Y - 30.0, 40.0, 6.0), _lit(Color(0.22, 0.3, 0.42), light))
		draw_rect(Rect2(bx + 4.0, DECK_Y - 24.0, 4.0, 24.0), _lit(Color(0.3, 0.3, 0.3), light))
		draw_rect(Rect2(bx + 32.0, DECK_Y - 24.0, 4.0, 24.0), _lit(Color(0.3, 0.3, 0.3), light))
	if poker_open:
		draw_rect(Rect2(800.0, DECK_Y - 51.0, 68.0, 3.0), Color(0.1, 0.4, 0.25))
		for i in 5:
			draw_rect(Rect2(812.0 + i * 9.0, DECK_Y - 55.0, 6.0, 4.0), Color(0.95, 0.95, 0.9))
		for i in 3:
			draw_circle(Vector2(808.0 + i * 24.0, DECK_Y - 53.0), 3.5, [Color(0.1, 0.1, 0.1), Color(0.45, 0.25, 0.12), Color(0.9, 0.75, 0.3)][i], true, -1.0, true)
	else:
		draw_rect(Rect2(806.0, DECK_Y - 56.0, 7.0, 8.0), Color(0.9, 0.9, 0.86))
		draw_rect(Rect2(850.0, DECK_Y - 55.0, 12.0, 3.0), Color(0.85, 0.85, 0.8))
	# Photos and the watch bill on the bulkhead.
	for i in 4:
		draw_rect(Rect2(846.0 + i * 14.0, DECK_Y - 132.0 + (i % 2) * 8.0, 10.0, 12.0), _lit(Color.from_hsv(0.1 + i * 0.2, 0.25, 0.75), light))
	draw_rect(Rect2(900.0, DECK_Y - 140.0, 22.0, 30.0), _lit(Color(0.92, 0.92, 0.88), light))


func _draw_control() -> void:
	var light := _comp_light("control")
	# Chart table (aft).
	_grad_rect(Rect2(950.0, DECK_Y - 54.0, 44.0, 54.0), _lit(Color(0.3, 0.33, 0.35), light), _lit(Color(0.15, 0.16, 0.17), light))
	draw_rect(Rect2(946.0, DECK_Y - 58.0, 52.0, 5.0), Color(0.9, 0.85, 0.7).lerp(Color(light.r, light.g, light.b), 0.3))
	_cone(Vector2(972.0, ceil_y(972.0) + 46.0), 6.0, 30.0, DECK_Y - 58.0 - ceil_y(972.0) - 46.0, Color(1.0, 0.95, 0.8, 0.18))
	# Periscope well through the deckhead, with the scope and handles.
	var scope_top := ceil_y(1124.0)
	var raised := sub.masts_up
	draw_rect(Rect2(1116.0, scope_top, 16.0, DECK_Y - 70.0 - scope_top), _lit(Color(0.25, 0.27, 0.28), light, 0.05))
	var eye_y := DECK_Y - 96.0 if raised else DECK_Y - 70.0
	draw_rect(Rect2(1110.0, eye_y, 28.0, 26.0), _lit(Color(0.2, 0.22, 0.23), light, 0.1))
	draw_line(Vector2(1104.0, eye_y + 14.0), Vector2(1144.0, eye_y + 14.0), _lit(Color(0.12, 0.12, 0.12), light), 4.0)
	draw_circle(Vector2(1124.0, DECK_Y - 2.0), 10.0, Color(0.05, 0.05, 0.05), true, -1.0, true)
	# Conn platform rail.
	draw_line(Vector2(1074.0, DECK_Y - 40.0), Vector2(1186.0, DECK_Y - 40.0), _lit(Color(0.6, 0.62, 0.6), light), 3.0, true)
	for rx: float in [1074.0, 1130.0, 1186.0]:
		draw_line(Vector2(rx, DECK_Y - 40.0), Vector2(rx, DECK_Y), _lit(Color(0.5, 0.52, 0.5), light), 2.0)
	# Ship control station forward: consoles, screens and depth gauges.
	_grad_rect(Rect2(1252.0, DECK_Y - 96.0, 46.0, 96.0), _lit(Color(0.24, 0.27, 0.3), light), _lit(Color(0.12, 0.13, 0.15), light))
	var amber := Color(1.0, 0.66, 0.2) if not (rig_for_red or clock.is_night()) else Color(1.0, 0.3, 0.15)
	draw_rect(Rect2(1258.0, DECK_Y - 86.0, 34.0, 22.0), Color(amber, 0.85))
	draw_rect(Rect2(1258.0, DECK_Y - 58.0, 34.0, 16.0), Color(0.3, 0.8, 1.0, 0.75))
	_glow(Vector2(1275.0, DECK_Y - 75.0), 36.0, Color(amber, 0.4))
	for g in 2:
		var gp := Vector2(1266.0 + g * 18.0, DECK_Y - 110.0)
		draw_circle(gp, 7.0, Color(0.88, 0.88, 0.82), true, -1.0, true)
		var ang := lerpf(PI * 0.8, PI * 2.2, clampf(sub.depth / 250.0 if g == 0 else sub.knots() / 20.0, 0.0, 1.0))
		draw_line(gp, gp + Vector2(cos(ang), sin(ang)) * 5.5, Color(0.85, 0.1, 0.05), 1.5, true)
	draw_rect(Rect2(1208.0, DECK_Y - 34.0, 34.0, 6.0), _lit(Color(0.2, 0.22, 0.26), light))
	# Plot screen on the aft bulkhead.
	draw_rect(Rect2(950.0, DECK_Y - 140.0, 40.0, 28.0), Color(0.08, 0.2, 0.25))
	draw_rect(Rect2(953.0, DECK_Y - 137.0, 34.0, 22.0), Color(0.2, 0.75, 0.9, 0.35))


func _draw_sonar() -> void:
	var light := _comp_light("sonar")
	var red := rig_for_red or clock.is_night()
	var scr := Color(0.35, 1.0, 0.6) if not red else Color(1.0, 0.3, 0.2)
	for i in 2:
		var cx := 1380.0 + i * 52.0
		_grad_rect(Rect2(cx, DECK_Y - 112.0, 34.0, 112.0), _lit(Color(0.2, 0.23, 0.25), light), _lit(Color(0.1, 0.11, 0.12), light))
		var sr := Rect2(cx + 4.0, DECK_Y - 102.0, 26.0, 34.0)
		draw_rect(sr, Color(0.02, 0.06, 0.04))
		for k in 9:
			var yy := sr.position.y + 2.0 + k * 3.6
			var off := fposmod(sin(k * 1.7 + floor(_t * 2.0) * 0.6 + i) * 9.0 + 13.0, 22.0)
			draw_line(Vector2(sr.position.x + off, yy), Vector2(sr.position.x + off + 2.0, yy), Color(scr, 0.9), 1.5)
			draw_line(Vector2(sr.position.x + 2.0, yy), Vector2(sr.end.x - 2.0, yy), Color(scr, 0.12), 1.0)
		_glow(sr.get_center(), 28.0, Color(scr, 0.22))
		draw_rect(Rect2(cx - 4.0, DECK_Y - 52.0, 38.0, 5.0), _lit(Color(0.25, 0.25, 0.27), light))
	draw_arc(Vector2(1330.0, DECK_Y - 120.0), 6.0, PI, TAU, 10, _lit(Color(0.2, 0.2, 0.2), light), 2.0, true)


func _draw_cabin() -> void:
	var light := _comp_light("cabin")
	# Bunk along the bulkhead, desk and lamp, logbook, photo, curtain.
	draw_rect(Rect2(1476.0, DECK_Y - 52.0, 84.0, 8.0), _lit(Color(0.45, 0.32, 0.2), light))
	draw_rect(Rect2(1478.0, DECK_Y - 60.0, 80.0, 9.0), _lit(Color(0.22, 0.27, 0.4), light))
	draw_rect(Rect2(1480.0, DECK_Y - 64.0, 16.0, 6.0), _lit(Color(0.88, 0.88, 0.85), light))
	draw_rect(Rect2(1476.0, DECK_Y - 44.0, 6.0, 44.0), _lit(Color(0.4, 0.29, 0.18), light))
	draw_rect(Rect2(1568.0, DECK_Y - 46.0, 30.0, 5.0), _lit(Color(0.45, 0.32, 0.2), light))
	draw_rect(Rect2(1592.0, DECK_Y - 41.0, 4.0, 41.0), _lit(Color(0.4, 0.29, 0.18), light))
	draw_rect(Rect2(1572.0, DECK_Y - 50.0, 12.0, 4.0), Color(0.35, 0.08, 0.06))
	draw_line(Vector2(1590.0, DECK_Y - 46.0), Vector2(1590.0, DECK_Y - 70.0), Color(0.2, 0.2, 0.2), 2.0)
	draw_rect(Rect2(1584.0, DECK_Y - 76.0, 12.0, 7.0), Color(1.0, 0.8, 0.5))
	_cone(Vector2(1590.0, DECK_Y - 69.0), 5.0, 26.0, 23.0, Color(1.0, 0.8, 0.5, 0.3))
	_glow(Vector2(1590.0, DECK_Y - 70.0), 30.0, Color(1.0, 0.75, 0.45, 0.45))
	draw_rect(Rect2(1500.0, DECK_Y - 120.0, 14.0, 10.0), _lit(Color(0.7, 0.62, 0.5), light))
	draw_rect(Rect2(1530.0, DECK_Y - 126.0, 40.0, 28.0), _lit(Color(0.85, 0.86, 0.8), light))
	draw_rect(Rect2(1534.0, DECK_Y - 122.0, 32.0, 20.0), _lit(Color(0.55, 0.7, 0.8), light))


func _draw_torpedo() -> void:
	var light := _comp_light("torpedo")
	# Tube doors on the bow bulkhead, racked weapons, loading rail.
	var ready := encounter == null or encounter.can_fire()
	for i in 4:
		var ty := DECK_Y - 120.0 + (i % 2) * 44.0
		var tx := 1736.0 + (i / 2) * 18.0
		if tx + 14.0 > X_BOW - 20.0:
			tx = 1730.0
		draw_circle(Vector2(tx, ty), 15.0, _lit(Color(0.36, 0.38, 0.36), light, 0.05), true, -1.0, true)
		draw_arc(Vector2(tx, ty), 15.0, 0.0, TAU, 24, _lit(Color(0.15, 0.15, 0.15), light), 2.0, true)
		draw_circle(Vector2(tx + 10.0, ty - 10.0), 2.5, Color(0.3, 1.0, 0.4) if ready else Color(1.0, 0.65, 0.15), true, -1.0, true)
	for i in 2:
		var ry := DECK_Y - 26.0 - i * 30.0
		_capsule(Vector2(1626.0, ry), Vector2(1712.0, ry), 9.0, _lit(Color(0.22, 0.3, 0.22), light, 0.05))
		draw_line(Vector2(1630.0, ry + 11.0), Vector2(1710.0, ry + 11.0), _lit(Color(0.45, 0.45, 0.42), light), 2.0)
	draw_line(Vector2(1615.0, ceil_y(1650.0) + 26.0), Vector2(1730.0, ceil_y(1720.0) + 26.0), _lit(Color(0.55, 0.5, 0.2), light), 3.0)


func _draw_foreground() -> void:
	# The cut edge of the pressure hull, with rivets.
	var edge := PackedVector2Array()
	var x := 372.0
	while x <= 1776.0:
		edge.append(Vector2(x, ceil_y(x) - 2.0))
		x += 8.0
	draw_polyline(edge, Color(0.55, 0.6, 0.6, 0.7), 3.0, true)
	var low := PackedVector2Array()
	x = 372.0
	while x <= 1776.0:
		low.append(Vector2(x, floor_low(x) + 2.0))
		x += 8.0
	draw_polyline(low, Color(0.35, 0.38, 0.38, 0.7), 3.0, true)
	x = 380.0
	while x < 1770.0:
		draw_circle(Vector2(x, ceil_y(x) - 6.0), 1.6, Color(0.7, 0.74, 0.72, 0.5))
		draw_circle(Vector2(x, floor_low(x) + 6.0), 1.6, Color(0.5, 0.54, 0.52, 0.5))
		x += 22.0
	draw_line(Vector2(372.0, ceil_y(372.0) - 2.0), Vector2(372.0, floor_low(372.0) + 2.0), Color(0.45, 0.48, 0.48, 0.8), 4.0, true)
	# Alert: a red wash over the whole interior.
	if crew and crew.alert >= 2:
		var a := 0.08 + 0.06 * (0.5 + 0.5 * sin(_t * 3.2))
		draw_colored_polygon(_comp_poly(372.0, 1776.0, LOWER_Y + 4.0), Color(1.0, 0.1, 0.05, a))
	# Everything but the focused compartment recedes a little.
	if focus_id != "":
		for id in ORDER:
			if id != focus_id:
				var c: Dictionary = COMPS[id]
				draw_colored_polygon(_comp_poly(float(c["x0"]) - 6.0, float(c["x1"]) + 6.0, DECK_Y), Color(0.0, 0.01, 0.02, 0.45))
	# Hover highlight.
	if _hover_comp != "" and _hover_spot == "" and _hover_crew == "":
		var hc: Dictionary = COMPS[_hover_comp]
		var hp := _comp_poly(float(hc["x0"]) + 2.0, float(hc["x1"]) - 2.0, DECK_Y - 2.0)
		hp.append(hp[0])
		draw_polyline(hp, Color(0.6, 0.9, 1.0, 0.55), 2.0 / _scale, true)


# --- people -----------------------------------------------------------------------------

func _draw_people() -> void:
	var order := _sprites.values()
	order.sort_custom(func(a: Sprite, b: Sprite) -> bool: return a.pos.y < b.pos.y)
	for s: Sprite in order:
		var light := _light_at(s.pos)
		var local := _xf * Transform2D(0.0, s.pos) * Transform2D(0.0, Vector2(s.face, 1.0), 0.0, Vector2.ZERO)
		draw_set_transform_matrix(local)
		_draw_person(s, light)
		if s.id == "basse" and audio and audio.singing():
			draw_set_transform_matrix(_xf * Transform2D(0.0, s.pos))
			for i in 3:
				var u := fposmod(_t * 0.45 + i * 0.33, 1.0)
				var np := Vector2(-10.0 + sin(_t * 2.0 + i * 2.0) * 10.0, -128.0 - u * 50.0)
				var nc := Color(1.0, 0.9, 0.6, 0.85 * (1.0 - u))
				draw_circle(np, 3.4, nc, true, -1.0, true)
				draw_line(np + Vector2(3.0, 0.0), np + Vector2(3.0, -12.0), nc, 1.4, true)
				draw_line(np + Vector2(3.0, -12.0), np + Vector2(8.0, -9.0), nc, 1.4, true)
	draw_set_transform_matrix(_xf)


func _light_at(p: Vector2) -> Color:
	if p.y > DECK_Y + 4.0:
		return Color(0.9, 0.82, 0.7, 0.4)
	if p.y < CASING:
		var day := _day()
		return Color(0.85, 0.9, 1.0, 0.4 + 0.6 * day)
	for id in ORDER:
		var c: Dictionary = COMPS[id]
		if p.x >= float(c["x0"]) and p.x <= float(c["x1"]):
			var l := _comp_light(id)
			if id == "sonar":
				# Faces lit by screens: keep them readable, not green.
				var n := Color(l.r, l.g, l.b).lerp(Color(0.85, 0.9, 0.9), 0.6)
				return Color(n.r, n.g, n.b, maxf(l.a, 0.6))
			return l
	return Color(0.8, 0.8, 0.8, 0.6)


func _draw_person(s: Sprite, light: Color) -> void:
	var st: Dictionary = STYLES.get(s.style, STYLES["rating"])
	var H := 112.0 * float(st["h"])
	var W := float(st["w"])
	var top_c := _lit(st["top"], light)
	var legs_c := _lit(st["legs"], light)
	var skin := _lit(st["skin"], light)
	var hair := _lit(st["hair"], light)
	var far := 0.72
	var t := _t + s.phase
	if s.pose == "lie":
		_draw_lying(s, st, H, W, top_c, skin, hair, light, t)
		return
	var breath := sin(t * 1.6) * 0.8
	var hip_y := -0.5 * H
	var sh_y := -0.8 * H + breath
	var head := Vector2(1.0, -0.9 * H + breath)
	var lean := 0.0
	var seated := s.pose == "sit"
	if seated:
		hip_y = -0.36 * H
		sh_y = hip_y - 0.32 * H + breath
		head = Vector2(2.0, sh_y - 0.11 * H)
	if s.act == "chart":
		lean = 7.0
	if s.act == "type" and seated:
		lean = 4.0
	head.x += lean
	# Legs.
	var leg_r := 4.6 * W
	if seated:
		var knee := Vector2(0.24 * H, hip_y - 2.0)
		_capsule(Vector2(-2.0, hip_y), knee, leg_r, legs_c.darkened(0.25))
		_capsule(knee, Vector2(knee.x + 2.0, -3.0), leg_r * 0.9, legs_c.darkened(0.25))
		_capsule(Vector2(2.0, hip_y), knee + Vector2(4.0, 0.0), leg_r, legs_c)
		_capsule(knee + Vector2(4.0, 0.0), Vector2(knee.x + 6.0, -3.0), leg_r * 0.9, legs_c)
		draw_rect(Rect2(knee.x + 2.0, -5.0, 12.0, 5.0), Color(0.05, 0.05, 0.05))
	else:
		var swing := 0.0
		if s.pose == "walk":
			swing = sin(t * 9.0) * 0.45
		elif s.pose == "climb":
			swing = sin(t * 6.0) * 0.25
		for leg in 2:
			var sgn := 1.0 if leg == 1 else -1.0
			var a := swing * sgn
			var foot := Vector2(sin(a) * -hip_y * 0.95, -3.0)
			var c := legs_c if leg == 1 else legs_c.darkened(1.0 - far)
			_capsule(Vector2(0.0, hip_y), Vector2(foot.x * 0.5 + 1.0, hip_y * 0.5), leg_r, c)
			_capsule(Vector2(foot.x * 0.5 + 1.0, hip_y * 0.5), foot, leg_r * 0.92, c)
			draw_rect(Rect2(foot.x - 3.0, -5.0, 13.0, 5.0), Color(0.05, 0.05, 0.05))
	# Far arm (behind the body).
	var shoulder := Vector2(lean * 0.6, sh_y + 5.0)
	_arm(s, st, shoulder + Vector2(-2.0, 0.0), H, W, top_c.darkened(1.0 - far), skin.darkened(0.25), t, true)
	# Torso (profile), with apron / straps / epaulettes.
	var depth_ch := 0.17 * H * W * 0.62
	var depth_hip := 0.15 * H * W * 0.62
	var belly := 4.0 * (W - 1.0) * 10.0 if W > 1.2 else 0.0
	var torso := PackedVector2Array([
		Vector2(-depth_hip * 0.55, hip_y), Vector2(depth_hip * 0.6 + belly * 0.4, hip_y),
		Vector2(depth_ch * 0.62 + belly, (hip_y + sh_y) * 0.5), Vector2(depth_ch * 0.5 + lean, sh_y + 4.0),
		Vector2(depth_ch * 0.2 + lean, sh_y - 1.0), Vector2(-depth_ch * 0.42 + lean, sh_y + 1.0),
		Vector2(-depth_ch * 0.6 + lean * 0.5, (hip_y + sh_y) * 0.5)])
	_vgrad(torso, top_c.lightened(0.08), top_c.darkened(0.15), sh_y, hip_y)
	var closed := torso.duplicate()
	closed.append(torso[0])
	draw_polyline(closed, top_c.darkened(0.3), 1.0, true)
	if st.get("apron", false):
		draw_colored_polygon(PackedVector2Array([Vector2(depth_hip * 0.2, hip_y + 18.0), Vector2(depth_hip * 0.75 + belly * 0.5, hip_y + 18.0), Vector2(depth_ch * 0.66 + belly, (hip_y + sh_y) * 0.5), Vector2(depth_ch * 0.4 + lean, sh_y + 10.0), Vector2(depth_ch * 0.1 + lean, sh_y + 10.0)]), _lit(Color(0.97, 0.97, 0.95), light, 0.05))
	if st.has("straps"):
		draw_line(Vector2(depth_ch * 0.3 + lean, sh_y + 2.0), Vector2(depth_hip * 0.4, hip_y), _lit(st["straps"], light), 3.0, true)
	if st.get("epaulettes", false):
		draw_line(Vector2(-depth_ch * 0.2 + lean, sh_y + 1.0), Vector2(depth_ch * 0.3 + lean, sh_y + 1.0), _lit(Color(0.75, 0.68, 0.4), light), 2.0, true)
	# Head and face.
	_draw_head(st, head, H, skin, hair, light, t, s)
	# Near arm.
	_arm(s, st, shoulder, H, W, top_c, skin, t, false)


func _arm(s: Sprite, st: Dictionary, shoulder: Vector2, H: float, W: float, sleeve: Color, skin: Color, t: float, is_far: bool) -> void:
	var r := 3.8 * W
	var up := 0.17 * H
	var lo := 0.16 * H
	var elbow := shoulder + Vector2(1.0, up)
	var hand := elbow + Vector2(2.0, lo)
	match s.act:
		"type":
			elbow = shoulder + Vector2(6.0, up * 0.85)
			hand = elbow + Vector2(lo * 0.95, -3.0 + sin(t * (14.0 if is_far else 11.0)) * 1.2)
		"cook":
			if not is_far:
				elbow = shoulder + Vector2(8.0, up * 0.8)
				hand = elbow + Vector2(lo * 0.8 + cos(t * 2.4) * 4.0, -6.0 + sin(t * 2.4) * 3.0)
		"chart":
			elbow = shoulder + Vector2(7.0, up * 0.8)
			hand = elbow + Vector2(lo * 0.9 + (sin(t * 1.3) * 3.0 if not is_far else 0.0), 6.0)
		"conn":
			if is_far:
				hand = shoulder + Vector2(-8.0, up + 4.0)
				elbow = shoulder + Vector2(-6.0, up * 0.6)
			else:
				elbow = shoulder + Vector2(-5.0, up * 0.8)
				hand = shoulder + Vector2(-9.0, up + 6.0)
		"scope":
			elbow = shoulder + Vector2(10.0, up * 0.25)
			hand = elbow + Vector2(9.0, -10.0)
		"binoculars":
			elbow = shoulder + Vector2(9.0, up * 0.4)
			hand = shoulder + Vector2(12.0, -10.0)
		"eat", "cards", "write":
			elbow = shoulder + Vector2(5.0, up * 0.85)
			var lift := maxf(sin(t * 0.9), 0.0) if not is_far and s.act == "eat" else 0.0
			hand = elbow + Vector2(lo * 0.8, -4.0 - lift * 18.0)
		"tool", "panel":
			elbow = shoulder + Vector2(7.0, up * 0.7)
			hand = elbow + Vector2(lo * 0.8, -8.0 + sin(t * 3.0) * 4.0)
		_:
			if s.pose == "walk":
				var a := sin(t * 9.0) * (0.5 if is_far else -0.5)
				elbow = shoulder + Vector2(sin(a) * up, cos(a) * up)
				hand = elbow + Vector2(sin(a) * lo + 3.0, cos(a) * lo)
			elif s.pose == "climb":
				elbow = shoulder + Vector2(5.0, -up * 0.6)
				hand = elbow + Vector2(2.0, -lo * 0.6 + sin(t * 6.0) * 4.0)
	_capsule(shoulder, elbow, r, sleeve)
	_capsule(elbow, hand, r * 0.9, sleeve)
	draw_circle(hand, r * 0.95, skin, true, -1.0, true)


func _draw_head(st: Dictionary, head: Vector2, H: float, skin: Color, hair: Color, light: Color, _t2: float, s: Sprite) -> void:
	var hr := 0.082 * H
	if st.has("ponytail"):
		_capsule(head + Vector2(-hr * 0.9, -hr * 0.3), head + Vector2(-hr * 1.5, hr * 0.9), hr * 0.32, hair)
	if st.get("bun", false):
		draw_circle(head + Vector2(-hr * 0.85, -hr * 0.55), hr * 0.42, hair, true, -1.0, true)
	draw_circle(head + Vector2(0.0, hr * 0.55), hr * 0.42, skin.darkened(0.1), true, -1.0, true)
	draw_circle(head, hr, skin, true, -1.0, true)
	# Nose and eye.
	draw_colored_polygon(PackedVector2Array([head + Vector2(hr * 0.9, -hr * 0.1), head + Vector2(hr * 1.25, hr * 0.28), head + Vector2(hr * 0.88, hr * 0.32)]), skin)
	draw_circle(head + Vector2(hr * 0.5, -hr * 0.12), maxf(hr * 0.1, 0.8), Color(0.08, 0.06, 0.05), true, -1.0, true)
	# Hair.
	draw_colored_polygon(PackedVector2Array([head + Vector2(-hr * 1.02, hr * 0.25), head + Vector2(-hr * 0.95, -hr * 0.55), head + Vector2(-hr * 0.4, -hr * 1.04), head + Vector2(hr * 0.45, -hr * 1.02), head + Vector2(hr * 0.92, -hr * 0.45), head + Vector2(hr * 0.35, -hr * 0.55), head + Vector2(-hr * 0.1, -hr * 0.3), head + Vector2(-hr * 0.35, hr * 0.15)]), hair)
	if st.has("beard"):
		draw_colored_polygon(PackedVector2Array([head + Vector2(-hr * 0.2, hr * 0.3), head + Vector2(hr * 0.95, hr * 0.35), head + Vector2(hr * 0.7, hr * 1.0), head + Vector2(hr * 0.05, hr * 1.12), head + Vector2(-hr * 0.45, hr * 0.7)]), _lit(st["beard"], light))
	if st.get("beanie", false):
		draw_colored_polygon(PackedVector2Array([head + Vector2(-hr * 1.08, -hr * 0.05), head + Vector2(-hr * 0.95, -hr * 0.85), head + Vector2(-hr * 0.2, -hr * 1.28), head + Vector2(hr * 0.6, -hr * 1.1), head + Vector2(hr * 1.06, -hr * 0.3), head + Vector2(hr * 1.04, -hr * 0.05)]), _lit(Color(0.1, 0.1, 0.12), light))
		draw_line(head + Vector2(-hr * 1.1, -hr * 0.1), head + Vector2(hr * 1.08, -hr * 0.1), _lit(Color(0.2, 0.2, 0.22), light), 2.5, true)
	if st.get("cap", false):
		draw_colored_polygon(PackedVector2Array([head + Vector2(-hr * 1.05, -hr * 0.4), head + Vector2(-hr * 1.0, -hr * 1.2), head + Vector2(hr * 0.9, -hr * 1.25), head + Vector2(hr * 1.0, -hr * 0.45)]), _lit(Color(0.08, 0.09, 0.12), light))
		draw_line(head + Vector2(hr * 0.6, -hr * 0.45), head + Vector2(hr * 1.75, -hr * 0.3), _lit(Color(0.05, 0.05, 0.06), light), 3.0, true)
		draw_line(head + Vector2(-hr * 0.9, -hr * 1.0), head + Vector2(hr * 0.8, -hr * 1.05), _lit(Color(0.75, 0.65, 0.35), light), 1.5, true)
	if st.get("headphones", false):
		draw_arc(head + Vector2(-hr * 0.1, 0.0), hr * 1.18, PI * 1.05, PI * 1.95, 12, _lit(Color(0.12, 0.12, 0.12), light), 2.5, true)
		draw_circle(head + Vector2(-hr * 0.15, hr * 0.05), hr * 0.42, _lit(Color(0.15, 0.15, 0.16), light), true, -1.0, true)
	else:
		draw_circle(head + Vector2(-hr * 0.15, hr * 0.05), hr * 0.2, skin.darkened(0.15), true, -1.0, true)
	if s.act == "scope" or s.act == "binoculars":
		draw_rect(Rect2(head.x + hr * 0.6, head.y - hr * 0.35, hr * 1.1, hr * 0.6), Color(0.08, 0.08, 0.09))


func _draw_lying(s: Sprite, st: Dictionary, H: float, W: float, top_c: Color, skin: Color, hair: Color, light: Color, t: float) -> void:
	# Lying along the bunk, head at the local -x end, under a blanket.
	var y := -6.0
	var len := H * 0.68
	var breath := sin(t * 1.2) * 1.2
	var blanket := _lit(Color(0.3, 0.33, 0.45) if s.id != "captain" else Color(0.38, 0.22, 0.18), light)
	draw_colored_polygon(PackedVector2Array([Vector2(-len * 0.42, y - 8.0 - breath), Vector2(len * 0.5, y - 6.0), Vector2(len * 0.52, y + 4.0), Vector2(-len * 0.45, y + 4.0)]), blanket)
	draw_polyline(PackedVector2Array([Vector2(-len * 0.42, y - 8.0 - breath), Vector2(len * 0.5, y - 6.0)]), blanket.lightened(0.15), 1.0, true)
	var head := Vector2(-len * 0.47, y - 5.0)
	var hr := 0.07 * H
	draw_circle(head, hr, skin, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-hr, -hr * 0.2), head + Vector2(-hr * 0.4, -hr), head + Vector2(hr * 0.3, -hr * 0.9), head + Vector2(hr * 0.2, -hr * 0.2)]), hair)
	if st.get("beanie", false):
		draw_circle(head + Vector2(-hr * 0.3, -hr * 0.5), hr * 0.75, _lit(Color(0.1, 0.1, 0.12), light), true, -1.0, true)
	if _scale > 2.0 and s.id != "":
		var u := fposmod(t * 0.4, 1.0)
		draw_string(UiStyle.display(), head + Vector2(4.0 + u * 8.0, -hr - 4.0 - u * 14.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.9, 1.0, 0.6 * (1.0 - u)))


# --- screen-space overlays (text, bubbles, depth ruler) ------------------------------

func _to_screen(p: Vector2) -> Vector2:
	return _xf * p


func _draw_screen_overlays() -> void:
	var f := UiStyle.display()
	var fm := UiStyle.mono()
	var zoomed := focus_id != ""
	# Compartment labels.
	for id in ORDER:
		var c: Dictionary = COMPS[id]
		var p := _to_screen(Vector2((float(c["x0"]) + float(c["x1"])) * 0.5, ceil_y((float(c["x0"]) + float(c["x1"])) * 0.5) + 16.0))
		if zoomed and id != focus_id:
			continue
		var here: bool = id == _captain_comp()
		var col := Color(0.75, 0.9, 1.0, 0.95) if here else Color(0.75, 0.82, 0.88, 0.7)
		var txt := String(c["name"])
		var fs := 13 if not zoomed else 20
		draw_string(f, p + Vector2(-200, fs * 0.5 + (4.0 if zoomed else 0.0)), txt, HORIZONTAL_ALIGNMENT_CENTER, 400, fs, col)
	# Hotspots when zoomed in.
	if zoomed:
		for hs in _hotspots():
			if String(hs[1]) != focus_id:
				continue
			var r: Rect2 = hs[2]
			var on := _hover_spot == String(hs[0])
			var sp := _to_screen(Vector2(r.get_center().x, r.position.y))
			var tag := String(hs[3])
			var col := Color(1.0, 0.86, 0.5, 1.0 if on else 0.75)
			var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
			var box := Rect2(sp + Vector2(-tw * 0.5, -30.0), Vector2(tw, 22.0))
			draw_rect(box, Color(0.02, 0.03, 0.04, 0.72 if on else 0.5))
			draw_rect(box, Color(col, 0.6 if on else 0.3), false, 1.0)
			draw_string(f, box.position + Vector2(9, 16), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
			if on:
				var sr := Rect2(_to_screen(r.position), r.size * _scale)
				draw_rect(sr, Color(1.0, 0.86, 0.5, 0.5), false, 2.0)
	# Speech bubbles.
	for id in _bubbles:
		var s: Sprite = _sprites.get(id)
		if s == null:
			continue
		var b: Dictionary = _bubbles[id]
		var a := clampf(float(b["t"]) * 1.5, 0.0, 1.0)
		var hp := _to_screen(s.pos + Vector2(0.0, -132.0 if s.pose != "lie" else -30.0))
		if hp.x < 0.0 or hp.x > size.x or hp.y < 0.0 or hp.y > size.y:
			continue
		var fs2 := 13 if not zoomed else 15
		var maxw := 300.0 if not zoomed else 380.0
		var tsz := f.get_multiline_string_size(String(b["text"]), HORIZONTAL_ALIGNMENT_LEFT, maxw, fs2)
		var box2 := Rect2(hp + Vector2(-tsz.x * 0.5 - 10.0, -tsz.y - 22.0), tsz + Vector2(20.0, 12.0))
		box2.position.x = clampf(box2.position.x, 8.0, size.x - box2.size.x - 8.0)
		draw_rect(box2, Color(0.96, 0.95, 0.9, 0.92 * a))
		draw_colored_polygon(PackedVector2Array([Vector2(hp.x - 6.0, box2.end.y), Vector2(hp.x + 6.0, box2.end.y), Vector2(hp.x, box2.end.y + 9.0)]), Color(0.96, 0.95, 0.9, 0.92 * a))
		draw_rect(Rect2(box2.position, Vector2(4.0, box2.size.y)), Color(b["color"], a))
		draw_multiline_string(f, box2.position + Vector2(12.0, fs2 + 3.0), String(b["text"]), HORIZONTAL_ALIGNMENT_LEFT, maxw, fs2, -1, Color(0.08, 0.08, 0.1, a))
	# Hover tooltip for people.
	if _hover_crew != "":
		var s2: Sprite = _sprites.get(_hover_crew)
		if s2:
			var mp := get_local_mouse_position()
			var info := s2.name
			var m: CrewMember = crew.members.get(s2.id)
			if m:
				info += "  ·  " + (m.activity if m.awake else "asleep")
			var w := f.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20.0
			var box3 := Rect2(mp + Vector2(16.0, -34.0), Vector2(w, 24.0))
			draw_rect(box3, Color(0.02, 0.03, 0.04, 0.85))
			draw_string(f, box3.position + Vector2(10, 17), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.9, 0.7))
	_draw_depth_ruler(fm)


func _captain_comp() -> String:
	var s: Sprite = _sprites.get("captain")
	return s.comp if s else ""


func _draw_depth_ruler(fm: Font) -> void:
	var x := 34.0
	var y0 := 110.0
	var y1 := size.y - 170.0
	var maxd := 300.0
	var to_y := func(d: float) -> float: return y0 + (y1 - y0) * clampf(d / maxd, 0.0, 1.0)
	draw_line(Vector2(x, y0), Vector2(x, y1), Color(0.6, 0.75, 0.85, 0.45), 2.0)
	for d in range(0, 301, 50):
		var yy: float = to_y.call(float(d))
		draw_line(Vector2(x - 5, yy), Vector2(x + 5, yy), Color(0.6, 0.75, 0.85, 0.5), 1.0)
		draw_string(fm, Vector2(x + 9, yy + 4), "%d" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.75, 0.85, 0.6))
	var ly: float = to_y.call(Submarine.LAYER_DEPTH)
	var dx := x - 12.0
	while dx < x + 30.0:
		draw_line(Vector2(dx, ly), Vector2(dx + 5, ly), Color(0.4, 0.9, 1.0, 0.6), 1.0)
		dx += 9.0
	draw_string(fm, Vector2(x + 9, ly - 4), "LAYER", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.9, 1.0, 0.7))
	var ty: float = to_y.call(Submarine.TEST_DEPTH)
	draw_line(Vector2(x - 8, ty), Vector2(x + 8, ty), Color(1.0, 0.6, 0.2, 0.8), 2.0)
	if area:
		var bed := area.seabed_depth(sub.global_position.x, sub.global_position.z)
		if bed < maxd:
			var by: float = to_y.call(bed)
			draw_rect(Rect2(x - 10, by, 20, y1 - by), Color(0.35, 0.28, 0.18, 0.5))
	var sy: float = to_y.call(maxf(sub.depth - 2.05, 0.0))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 14, sy - 6), Vector2(x - 4, sy), Vector2(x - 14, sy + 6)]), Color(1.0, 0.9, 0.6))
	var od: float = to_y.call(float(Submarine.DEPTH_MODES[sub.depth_mode]["depth"]))
	draw_arc(Vector2(x, od), 5.0, 0.0, TAU, 12, Color(1.0, 0.9, 0.6, 0.7), 1.5, true)
	draw_string(fm, Vector2(x - 26, y0 - 12), "DEPTH M", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.75, 0.85, 0.7))


# --- interaction -------------------------------------------------------------------

## [id, compartment, world rect, label]
func _hotspots() -> Array:
	return [
		["periscope", "control", Rect2(1100.0, DECK_Y - 110.0, 48.0, 110.0), "PERISCOPE"],
		["chart", "control", Rect2(944.0, DECK_Y - 64.0, 56.0, 64.0), "CHART TABLE"],
		["orders", "control", Rect2(1196.0, DECK_Y - 120.0, 104.0, 120.0), "SHIP CONTROL  ·  ORDERS"],
		["sonar_console", "sonar", Rect2(1376.0, DECK_Y - 116.0, 84.0, 116.0), "SONAR CONSOLES"],
		["cards", "mess", Rect2(790.0, DECK_Y - 62.0, 88.0, 62.0), "CARD TABLE"],
		["coffee", "mess", Rect2(716.0, DECK_Y - 96.0, 34.0, 40.0), "COFFEE"],
		["bunk", "cabin", Rect2(1474.0, DECK_Y - 70.0, 90.0, 30.0), "REST"],
		["logbook", "cabin", Rect2(1566.0, DECK_Y - 60.0, 32.0, 20.0), "PATROL LOG"],
		["engine_panel", "engine", Rect2(606.0, DECK_Y - 122.0, 34.0, 122.0), "ENGINEERING PANEL"],
		["tubes", "torpedo", Rect2(1712.0, DECK_Y - 140.0, 56.0, 90.0), "TUBES"],
		["outside", "control", Rect2(SAIL_X0, SAIL_TOP - 20.0, SAIL_X1 - SAIL_X0, CASING - SAIL_TOP + 20.0), "LOOK OUTSIDE"],
	]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		_update_hover(mb.position)
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if _hover_spot != "":
					hotspot.emit(_hover_spot)
				elif _hover_crew != "" and crew.members.has(_hover_crew):
					if (crew.members[_hover_crew] as CrewMember).awake:
						talk.emit(_hover_crew)
					else:
						_bubbles[_hover_crew] = {"text": "(asleep)", "color": Color(0.6, 0.7, 0.8), "t": 2.0}
				elif _hover_comp != "":
					compartment_chosen.emit(_hover_comp)
				accept_event()
			MOUSE_BUTTON_RIGHT:
				focus_id = ""
				accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				if focus_id == "" and _hover_comp != "":
					compartment_chosen.emit(_hover_comp)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				focus_id = ""
				accept_event()


func _update_hover(screen: Vector2) -> void:
	var w := _xf.affine_inverse() * screen
	_hover_comp = ""
	_hover_crew = ""
	_hover_spot = ""
	if w.y > CASING - 30.0 and w.y < CY + R:
		for id in ORDER:
			var c: Dictionary = COMPS[id]
			if w.x >= float(c["x0"]) - 5.0 and w.x <= float(c["x1"]) + 5.0:
				_hover_comp = id
	var best := 1e9
	for s: Sprite in _sprites.values():
		if not crew.members.has(s.id):
			continue
		var r := Rect2(s.pos.x - 16.0, s.pos.y - 118.0, 32.0, 118.0) if s.pose != "lie" else Rect2(s.pos.x - 45.0, s.pos.y - 22.0, 90.0, 26.0)
		if r.has_point(w):
			var d := absf(w.x - s.pos.x)
			if d < best:
				best = d
				_hover_crew = s.id
	for hs in _hotspots():
		var r2: Rect2 = hs[2]
		if (focus_id == String(hs[1]) or (focus_id == "" and hs[0] == "outside")) and r2.has_point(w):
			_hover_spot = String(hs[0])
	if _hover_spot != "" and _hover_crew != "":
		_hover_spot = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (_hover_spot != "" or _hover_crew != "" or (_hover_comp != "" and _hover_comp != focus_id)) else Control.CURSOR_ARROW
