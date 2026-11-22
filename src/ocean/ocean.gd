class_name Ocean
extends MeshInstance3D
## Camera-following polar ocean grid (dense near the viewer, kilometres to the
## horizon) driven by the shared OceanWaves set.

const RINGS := 300
const SEGMENTS := 400
const RADIUS := 26000.0
const EXP_K := 7.0

var waves := OceanWaves.new(0.55)
var ocean_time := 0.0
var follow: Node3D
var material: ShaderMaterial
var extra_materials: Array[ShaderMaterial] = []

var _hs := 1.5
var _spectrum := 0.9
var _chop := 0.75


func _ready() -> void:
	mesh = _build_mesh()
	material = ShaderMaterial.new()
	material.shader = load("res://src/ocean/ocean.gdshader")
	material.set_shader_parameter("normal_a", _noise_normal(512, 0.018, 7, 11))
	material.set_shader_parameter("normal_b", _noise_normal(512, 0.035, 5, 23))
	material.set_shader_parameter("foam_tex", _foam_texture())
	var r0 := RADIUS / (exp(EXP_K) - 1.0)
	material.set_shader_parameter("lod_r0", r0)
	material.set_shader_parameter("lod_k", EXP_K / float(RINGS))
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-RADIUS, -60.0, -RADIUS), Vector3(RADIUS * 2.0, 120.0, RADIUS * 2.0))
	_push_waves()


func set_sea_state(hs: float, spectrum: float, chop: float) -> void:
	if is_equal_approx(hs, _hs) and is_equal_approx(spectrum, _spectrum) and is_equal_approx(chop, _chop):
		return
	_hs = hs
	_spectrum = spectrum
	_chop = chop
	waves.set_sea_state(hs, spectrum, chop)
	_push_waves()


func _push_waves() -> void:
	var a := waves.shader_wave_a()
	var b := waves.shader_wave_b()
	var mats: Array[ShaderMaterial] = [material]
	mats.append_array(extra_materials)
	for m in mats:
		m.set_shader_parameter("wave_a", a)
		m.set_shader_parameter("wave_b", b)
		m.set_shader_parameter("wave_scale", maxf(_hs * 0.5, 0.2))
	material.set_shader_parameter("wind_dir", Vector2(cos(waves.wind_angle), sin(waves.wind_angle)))


func register_material(m: ShaderMaterial) -> void:
	extra_materials.append(m)
	_push_waves()


func advance(dt: float) -> void:
	ocean_time += dt
	material.set_shader_parameter("ocean_time", ocean_time)
	for m in extra_materials:
		m.set_shader_parameter("ocean_time", ocean_time)
	if follow:
		var p := follow.global_position
		global_position = Vector3(snappedf(p.x, 0.5), 0.0, snappedf(p.z, 0.5))


func height_at(x: float, z: float) -> float:
	return waves.height_at(x, z, ocean_time)


func set_param(param_name: String, value: Variant) -> void:
	material.set_shader_parameter(param_name, value)


func _build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	var r0 := RADIUS / (exp(EXP_K) - 1.0)
	for ri in range(1, RINGS + 1):
		var r := r0 * (exp(EXP_K * float(ri) / float(RINGS)) - 1.0)
		for si in SEGMENTS:
			var a := TAU * float(si) / float(SEGMENTS)
			verts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for si in SEGMENTS:
		idx.append(0)
		idx.append(1 + si)
		idx.append(1 + (si + 1) % SEGMENTS)
	for ri in range(0, RINGS - 1):
		var inner := 1 + ri * SEGMENTS
		var outer := inner + SEGMENTS
		for si in SEGMENTS:
			var sn := (si + 1) % SEGMENTS
			idx.append(inner + si)
			idx.append(outer + si)
			idx.append(outer + sn)
			idx.append(inner + si)
			idx.append(outer + sn)
			idx.append(inner + sn)
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _noise_normal(size: int, freq: float, octaves: int, seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = freq
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.seed = seed_value
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 3.2
	tex.generate_mipmaps = true
	tex.noise = noise
	return tex


static func _foam_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.03
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.seed = 5
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	return tex
