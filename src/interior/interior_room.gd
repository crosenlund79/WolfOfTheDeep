class_name InteriorRoom
extends Node3D
## Base for a first-person compartment: its own camera and lighting on the
## interior render layer, mouse look, a gentle roll with the boat, crew
## anchors, and clickable things (people and objects).

signal clicked(kind: String, what: String)

const LAYER := 1 << 1

var room_name := ""
var origin := Vector3.ZERO
var eye := Vector3(0, 1.65, 2.0)
var look_range := Vector2(2.4, 0.9)
var camera: Camera3D
var env: Environment
var root: Node3D
var active := false
var anchors: Dictionary = {}     # name -> [Vector3, yaw, seated]
var interactables: Array = []    # [Node3D, kind, what]
var sub: Submarine

var _look := Vector2.ZERO
var _t := 0.0
var _hover: Array = []


func _ready() -> void:
	root = Node3D.new()
	root.name = room_name
	root.position = origin
	add_child(root)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 60.0
	camera.cull_mask = LAYER
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.32)
	env.ambient_light_energy = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_length = 20.0
	env.volumetric_fog_albedo = Color(0.85, 0.85, 0.85)
	camera.environment = env
	root.add_child(camera)
	camera.position = eye
	build()
	root.visible = false


## Override: construct the compartment under `root`.
func build() -> void:
	pass


func set_active(v: bool) -> void:
	active = v
	root.visible = v
	if v:
		camera.make_current()


func advance(dt: float) -> void:
	_t += dt
	if not active:
		return
	var vp := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	var target := Vector2((m.x / vp.x - 0.5) * -look_range.x, (m.y / vp.y - 0.5) * -look_range.y)
	_look = _look.lerp(target, 1.0 - exp(-dt * 3.0))
	var e := sub.basis.get_euler() if sub else Vector3.ZERO
	camera.rotation = Vector3(_look.y + e.x * 0.3, _look.x, e.z * 0.3)
	camera.position = eye + Vector3(sin(_t * 0.4) * 0.012, sin(_t * 0.9) * 0.007, 0.0)
	_hover = _hovered()
	for item in interactables:
		var n: Node3D = item[0]
		if n is CrewFigure:
			(n as CrewFigure).show_label(not _hover.is_empty() and _hover[0] == n)


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not _hover.is_empty():
			clicked.emit(String(_hover[1]), String(_hover[2]))
			return true
	return false


func hovered_text() -> String:
	if _hover.is_empty():
		return ""
	return String(_hover[3]) if _hover.size() > 3 else ""


func _hovered() -> Array:
	var m := get_viewport().get_mouse_position()
	var dir := camera.project_ray_normal(m)
	var best: Array = []
	var best_a := 0.12
	for item in interactables:
		var n: Node3D = item[0]
		if not n.is_visible_in_tree():
			continue
		var p := n.global_position + (Vector3(0, 1.3, 0) if n is CrewFigure else Vector3.ZERO)
		var a := dir.angle_to(p - camera.global_position)
		if a < best_a:
			best_a = a
			best = item
	return best


func add_interactable(n: Node3D, kind: String, what: String, hint: String) -> void:
	interactables.append([n, kind, what, hint])


func clear_crew_interactables() -> void:
	interactables = interactables.filter(func(i: Array) -> bool: return String(i[1]) != "crew")


# --- building helpers ---------------------------------------------------------

func mat(c: Color, rough: float = 0.6, metal: float = 0.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func box(size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.layers = LAYER
	root.add_child(mi)
	return mi


func cyl(r: float, h: float, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO, segs: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.layers = LAYER
	root.add_child(mi)
	return mi


func lamp(pos: Vector3, color: Color, energy: float, range_m: float, shadows: bool = true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = shadows
	l.layers = LAYER
	l.light_cull_mask = LAYER
	l.light_volumetric_fog_energy = 0.6
	root.add_child(l)
	return l


func text3d(t: String, pos: Vector3, size: int, color: Color, rot_y: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = UiStyle.display()
	l.font_size = size
	l.pixel_size = 0.0025
	l.modulate = color
	l.position = pos
	l.rotation.y = rot_y
	l.layers = LAYER
	l.shaded = false
	root.add_child(l)
	return l


func shell(size: Vector3, wall: Color, floor_c: Color) -> void:
	box(Vector3(size.x, 0.1, size.z), Vector3(0, -0.05, 0), mat(floor_c, 0.5, 0.5))
	box(Vector3(size.x, 0.1, size.z), Vector3(0, size.y + 0.05, 0), mat(wall * 0.8, 0.8, 0.1))
	box(Vector3(0.1, size.y, size.z), Vector3(-size.x * 0.5, size.y * 0.5, 0), mat(wall, 0.7, 0.15))
	box(Vector3(0.1, size.y, size.z), Vector3(size.x * 0.5, size.y * 0.5, 0), mat(wall, 0.7, 0.15))
	box(Vector3(size.x, size.y, 0.1), Vector3(0, size.y * 0.5, -size.z * 0.5), mat(wall, 0.7, 0.15))
	box(Vector3(size.x, size.y, 0.1), Vector3(0, size.y * 0.5, size.z * 0.5), mat(wall, 0.7, 0.15))
	# Pipes along the deckhead.
	var pipe := mat(Color(0.55, 0.57, 0.58), 0.4, 0.6)
	for x in [-size.x * 0.4, size.x * 0.35]:
		cyl(0.06, size.z, Vector3(x, size.y - 0.15, 0), pipe, Vector3(PI * 0.5, 0, 0))
	cyl(0.09, size.z, Vector3(size.x * 0.1, size.y - 0.12, 0), mat(Color(0.1, 0.22, 0.45), 0.5, 0.2), Vector3(PI * 0.5, 0, 0))
