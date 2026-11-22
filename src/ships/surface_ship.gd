class_name SurfaceShip
extends Node3D
## Staged surface traffic: a container ship and a frigate built from simple
## procedural shapes, riding the swell on straight courses. Cosmetic only.

enum Kind { MERCHANT, FRIGATE }

var kind := Kind.MERCHANT
var ocean: Ocean
var heading := 0.0
var speed := 6.0
var length := 180.0
var beam := 28.0
var draft := 8.0
var contact_name := "MERCHANT"

var _pitch := 0.0
var _roll := 0.0
var _heave := 0.0
var _body: Node3D
var _lights: Array[Node3D] = []
var _windows_mat: StandardMaterial3D
var _hull_mat: ShaderMaterial
var _super_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4242 if kind == Kind.MERCHANT else 9191
	_body = Node3D.new()
	add_child(_body)
	if kind == Kind.MERCHANT:
		length = 182.0
		beam = 30.0
		draft = 9.0
		contact_name = "MERCHANT  ·  CONTAINER"
		_build_merchant()
	else:
		length = 134.0
		beam = 17.5
		draft = 5.2
		contact_name = "WARSHIP  ·  FRIGATE"
		_build_frigate()


func place(pos: Vector3, p_heading: float, knots: float) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
	heading = p_heading
	speed = knots * 0.5144


func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, -cos(heading))


func advance(dt: float, around: Vector3) -> void:
	position += forward() * speed * dt
	# Keep the staged traffic in view: recycle ships that sail far away.
	var rel := position - around
	rel.y = 0.0
	if rel.length() > 9000.0:
		var back := -rel.normalized()
		position = around + back * 5000.0 + Vector3(-back.z, 0.0, back.x) * _rng.randf_range(-2500.0, 2500.0)
		position.y = 0.0
		heading = atan2(back.x, -back.z) + _rng.randf_range(-0.6, 0.6)
	if ocean:
		var f := forward()
		var r := Vector3(-f.z, 0.0, f.x)
		var hb := ocean.height_at(position.x + f.x * length * 0.4, position.z + f.z * length * 0.4)
		var hs := ocean.height_at(position.x - f.x * length * 0.4, position.z - f.z * length * 0.4)
		var hp := ocean.height_at(position.x - r.x * beam * 0.45, position.z - r.z * beam * 0.45)
		var hst := ocean.height_at(position.x + r.x * beam * 0.45, position.z + r.z * beam * 0.45)
		var k := 1.0 - exp(-dt * 1.5)
		_heave = lerpf(_heave, (hb + hs + hp + hst) * 0.25, k)
		_pitch = lerpf(_pitch, atan2(hb - hs, length * 0.8) * 0.8, k)
		_roll = lerpf(_roll, atan2(hp - hst, beam) * 0.8, k * 0.7)
	position.y = _heave
	basis = Basis(Vector3.UP, -heading) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.FORWARD, _roll)


var _night := false


func set_night(on: bool) -> void:
	if on == _night:
		return
	_night = on
	for l in _lights:
		l.visible = on
	if _windows_mat:
		_windows_mat.emission_energy_multiplier = 3.5 if on else 0.15


# --- construction -----------------------------------------------------------

func _ship_shader(color: Color, rough: float, heat: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/ships/ship.gdshader")
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("thermal_heat", heat)
	return m


func _hull_fn(l: float, b: float, depth: float, freeboard: float, bow_len: float, stern_len: float, flare: float, sheer: float) -> Callable:
	return func(u: float, v: float) -> Vector3:
		var s := u * l
		var half := b * 0.5
		var wf := 1.0
		if s < bow_len:
			wf = pow(sin(PI * 0.5 * s / bow_len), 0.75)
		elif s > l - stern_len:
			var x := (s - (l - stern_len)) / stern_len
			wf = 1.0 - 0.28 * x * x
		var a := v * TAU
		var cy := -cos(a)
		var sx := sin(a)
		var top := freeboard + sheer * pow(1.0 - minf(s / (l * 0.35), 1.0), 2.0)
		var y: float
		if cy > 0.0:
			y = lerpf(0.0, top, pow(cy, 0.35))
		else:
			y = -depth * pow(-cy, 0.45)
		var xs := signf(sx) * pow(absf(sx), 0.25)
		var hw := half * wf * (1.0 + flare * clampf(y / maxf(top, 0.1), 0.0, 1.0))
		if y < 0.0:
			hw *= lerpf(1.0, 0.85, pow(-y / depth, 3.0))
		# Cut the bow below the waterline into a raked stem.
		var z := -l * 0.5 + s
		if s < bow_len and y < 0.0:
			z += (-y / depth) * bow_len * 0.25 * (1.0 - s / bow_len)
		return Vector3(xs * hw, y, z)


func _add_hull(fn: Callable, mat: Material) -> void:
	var mesh := ArrayMesh.new()
	var uvf := func(u: float, v: float) -> Vector2: return Vector2(u * 30.0, v * 10.0)
	ParamMesh.add_to(mesh, ParamMesh.surface(fn, uvf, 120, 48), mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_body.add_child(mi)


func _box(size: Vector3, pos: Vector3, mat: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	_body.add_child(mi)
	return mi


func _prism(bottom: Vector2, top: Vector2, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	# Tapered block: a "stealth" superstructure with inward-sloping walls.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := [Vector3(-bottom.x, 0, -bottom.y), Vector3(bottom.x, 0, -bottom.y), Vector3(bottom.x, 0, bottom.y), Vector3(-bottom.x, 0, bottom.y)]
	var t := [Vector3(-top.x, height, -top.y), Vector3(top.x, height, -top.y), Vector3(top.x, height, top.y), Vector3(-top.x, height, top.y)]
	for i in 4:
		var j := (i + 1) % 4
		_tri(st, b[i], t[i], b[j])
		_tri(st, b[j], t[i], t[j])
	_tri(st, t[0], t[2], t[1])
	_tri(st, t[0], t[3], t[2])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	_body.add_child(mi)
	return mi


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(a.x + a.z, a.y))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x + b.z, b.y))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x + c.z, c.y))
	st.add_vertex(c)


func _cyl(r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	_body.add_child(mi)
	return mi


func _nav_light(pos: Vector3, color: Color, energy: float = 6.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	_body.add_child(holder)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 30.0
	sm.material = mat
	bulb.mesh = sm
	holder.add_child(bulb)
	var omni := OmniLight3D.new()
	omni.light_color = color
	omni.light_energy = energy
	omni.omni_range = 26.0
	omni.light_volumetric_fog_energy = 0.0
	holder.add_child(omni)
	holder.visible = false
	_lights.append(holder)


func _build_merchant() -> void:
	_hull_mat = _ship_shader(Color(0.06, 0.09, 0.14), 0.6, 0.25)
	_hull_mat.set_shader_parameter("boot_color", Color(0.32, 0.06, 0.05))
	_hull_mat.set_shader_parameter("boot_top", 0.6)
	_add_hull(_hull_fn(length, beam, draft, 13.0, 34.0, 18.0, 0.04, 4.0), _hull_mat)
	var white := _ship_shader(Color(0.78, 0.78, 0.76), 0.55, 0.3)
	var grey := _ship_shader(Color(0.32, 0.33, 0.34), 0.5, 0.3)
	# Accommodation block aft with bridge wings.
	var z_house := length * 0.5 - 28.0
	_box(Vector3(24.0, 22.0, 13.0), Vector3(0, 13.0 + 11.0, z_house), white)
	_box(Vector3(beam + 2.0, 1.2, 6.0), Vector3(0, 13.0 + 21.0, z_house - 3.0), white)
	_windows_mat = StandardMaterial3D.new()
	_windows_mat.albedo_color = Color(0.05, 0.06, 0.07)
	_windows_mat.emission_enabled = true
	_windows_mat.emission = Color(1.0, 0.82, 0.55)
	_windows_mat.emission_energy_multiplier = 0.15
	_windows_mat.roughness = 0.1
	for row in 5:
		_box(Vector3(24.3, 0.9, 12.0), Vector3(0, 16.5 + row * 3.6, z_house), _windows_mat)
	_box(Vector3(beam + 2.1, 1.3, 1.0), Vector3(0, 13.0 + 20.0, z_house - 6.2), _windows_mat)
	# Funnel.
	var funnel := _box(Vector3(6.0, 12.0, 8.0), Vector3(0, 13.0 + 26.0, z_house + 9.0), grey)
	funnel.set_meta("hot", true)
	_box(Vector3(6.1, 2.2, 8.1), Vector3(0, 13.0 + 30.0, z_house + 9.0), _ship_shader(Color(0.7, 0.12, 0.08), 0.5, 0.95))
	# Mast with radar.
	_cyl(0.35, 10.0, Vector3(0, 13.0 + 27.0, z_house - 2.0), grey)
	_box(Vector3(4.0, 0.4, 0.5), Vector3(0, 13.0 + 31.5, z_house - 2.0), grey)
	# Container stacks: one MultiMesh, per-instance colours.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(2.44, 2.55, 12.0)
	var cmat := ShaderMaterial.new()
	cmat.shader = load("res://src/ships/container.gdshader")
	box.material = cmat
	mm.mesh = box
	var palette := [Color(0.55, 0.12, 0.08), Color(0.12, 0.25, 0.45), Color(0.2, 0.36, 0.22), Color(0.62, 0.62, 0.6), Color(0.75, 0.42, 0.1), Color(0.42, 0.18, 0.12), Color(0.08, 0.32, 0.38), Color(0.6, 0.55, 0.18), Color(0.3, 0.3, 0.32)]
	var xforms: Array[Transform3D] = []
	var cols: Array[Color] = []
	var bays := 11
	for bay in bays:
		var z := -length * 0.5 + 34.0 + bay * 12.8
		if z > z_house - 9.0:
			continue
		var tiers := _rng.randi_range(3, 6)
		for row in 11:
			var x := (row - 5) * 2.5
			var t_here := tiers - (1 if absi(row - 5) == 5 and _rng.randf() < 0.5 else 0)
			for tier in t_here:
				xforms.append(Transform3D(Basis.IDENTITY, Vector3(x, 13.0 + 1.3 + tier * 2.6, z)))
				var c: Color = palette[_rng.randi_range(0, palette.size() - 1)]
				cols.append(c * _rng.randf_range(0.8, 1.1))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_body.add_child(mmi)
	# Forecastle and hatch-coaming details.
	_box(Vector3(beam * 0.7, 2.5, 14.0), Vector3(0, 14.5, -length * 0.5 + 18.0), grey)
	_nav_light(Vector3(0, 13.0 + 33.0, z_house - 2.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(0, 13.0 + 12.0, -length * 0.5 + 14.0), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(-beam * 0.5 - 1.0, 13.0 + 21.0, z_house - 3.0), Color(1.0, 0.1, 0.05))
	_nav_light(Vector3(beam * 0.5 + 1.0, 13.0 + 21.0, z_house - 3.0), Color(0.1, 1.0, 0.35))
	for i in 6:
		_nav_light(Vector3(_rng.randf_range(-10, 10), 13.0 + 16.0, -length * 0.5 + 30.0 + i * 22.0), Color(1.0, 0.75, 0.45), 3.0)


func _build_frigate() -> void:
	var haze := _ship_shader(Color(0.36, 0.38, 0.4), 0.55, 0.3)
	_hull_mat = _ship_shader(Color(0.34, 0.36, 0.38), 0.6, 0.25)
	_hull_mat.set_shader_parameter("boot_color", Color(0.08, 0.08, 0.09))
	_hull_mat.set_shader_parameter("boot_top", 0.4)
	_add_hull(_hull_fn(length, beam, draft, 8.0, 40.0, 10.0, 0.1, 3.5), _hull_mat)
	var dark := _ship_shader(Color(0.12, 0.13, 0.14), 0.5, 0.35)
	# Faceted superstructure.
	_prism(Vector2(7.4, 18.0), Vector2(6.2, 16.0), 6.5, Vector3(0, 8.0, 2.0), haze)
	_prism(Vector2(6.0, 9.0), Vector2(4.6, 7.0), 6.0, Vector3(0, 14.5, -6.0), haze)
	_prism(Vector2(3.6, 3.6), Vector2(1.8, 1.8), 12.0, Vector3(0, 20.5, -6.5), haze)
	_box(Vector3(9.0, 0.9, 1.0), Vector3(0, 19.6, -15.4), dark)
	# Hangar and flight deck aft.
	_prism(Vector2(6.8, 8.0), Vector2(6.2, 7.6), 6.2, Vector3(0, 8.0, 28.0), haze)
	# Funnel.
	var funnel := _prism(Vector2(2.6, 3.4), Vector2(2.0, 2.6), 5.5, Vector3(0, 14.5, 14.0), haze)
	funnel.set_meta("hot", true)
	_box(Vector3(3.2, 0.6, 4.4), Vector3(0, 20.0, 14.0), _ship_shader(Color(0.08, 0.08, 0.08), 0.5, 0.95))
	# Main gun.
	_prism(Vector2(2.2, 2.8), Vector2(1.4, 1.9), 1.8, Vector3(0, 8.4, -length * 0.5 + 34.0), haze)
	var barrel := _cyl(0.17, 7.0, Vector3(0, 9.4, -length * 0.5 + 29.0), dark)
	barrel.rotation.x = deg_to_rad(90.0)
	# Vertical-launch deck.
	_box(Vector3(6.0, 0.4, 8.0), Vector3(0, 8.2, -length * 0.5 + 44.0), dark)
	# Radar panels on the integrated mast.
	_cyl(0.25, 6.0, Vector3(0, 35.0, -6.5), dark)
	_box(Vector3(2.6, 0.35, 1.2), Vector3(0, 37.8, -6.5), dark)
	_nav_light(Vector3(0, 38.5, -6.5), Color(1.0, 0.95, 0.85))
	_nav_light(Vector3(-6.0, 15.0, -6.0), Color(1.0, 0.1, 0.05))
	_nav_light(Vector3(6.0, 15.0, -6.0), Color(0.1, 1.0, 0.35))
	_nav_light(Vector3(0, 10.0, length * 0.5 - 4.0), Color(1.0, 0.95, 0.85))
	# Hull number (fictional).
	for side in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.text = "361"
		lbl.font_size = 512
		lbl.pixel_size = 0.009
		lbl.modulate = Color(0.06, 0.06, 0.07)
		lbl.outline_size = 0
		lbl.shaded = true
		lbl.double_sided = false
		lbl.position = Vector3(side * (beam * 0.5 + 0.35), 4.5, -length * 0.5 + 24.0)
		lbl.rotation.y = side * PI * 0.5
		_body.add_child(lbl)
