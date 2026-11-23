class_name Weather
extends Node3D
## Owns the sky, sun/moon light, environment, rain and lightning, and blends
## smoothly between hand-tuned weather presets. Purely cosmetic.

signal lightning_struck(distance_km: float)
signal preset_changed(label: String)

const ORDER := ["dawn", "clear", "golden", "storm", "night"]

const PRESETS := {
	"dawn": {
		"label": "ATLANTIC DAWN  ·  SEA STATE 4",
		"sun_elev": 6.0, "sun_az": 78.0, "sun_color": Color(1.0, 0.64, 0.4), "sun_energy": 1.8,
		"zenith": Color(0.1, 0.15, 0.28), "horizon": Color(0.36, 0.4, 0.49), "horizon_sun": Color(1.0, 0.6, 0.42), "ground": Color(0.03, 0.04, 0.06),
		"sun_disk": 30.0, "sun_glow": 1.1, "moon": 0.0, "stars": 0.05,
		"clouds": 0.58, "cloud_soft": 0.2, "cloud_lit": Color(1.0, 0.6, 0.4), "cloud_amb": Color(0.34, 0.36, 0.45), "cloud_dark": Color(0.13, 0.14, 0.19),
		"fog_color": Color(0.42, 0.44, 0.5), "fog_density": 0.00014, "vol_fog": 0.0012,
		"hs": 2.6, "spectrum": 0.9, "chop": 0.82, "foam": 0.45,
		"deep": Color(0.01, 0.03, 0.05), "body": Color(0.03, 0.1, 0.13), "sss": Color(0.14, 0.42, 0.4), "sss_str": 1.0,
		"light_level": 0.62, "ambient": 0.8, "exposure": 1.05, "sky_energy": 1.0,
		"rain": 0.0, "lightning": 0.0, "bio": 0.0, "nav_lights": 1.0, "haze": 0.1,
	},
	"clear": {
		"label": "CLEAR MIDDAY  ·  SEA STATE 3",
		"sun_elev": 48.0, "sun_az": 205.0, "sun_color": Color(1.0, 0.96, 0.9), "sun_energy": 2.4,
		"zenith": Color(0.07, 0.24, 0.58), "horizon": Color(0.6, 0.74, 0.87), "horizon_sun": Color(0.74, 0.82, 0.9), "ground": Color(0.05, 0.08, 0.1),
		"sun_disk": 40.0, "sun_glow": 0.8, "moon": 0.0, "stars": 0.0,
		"clouds": 0.3, "cloud_soft": 0.16, "cloud_lit": Color(0.5, 0.48, 0.45), "cloud_amb": Color(0.88, 0.9, 0.95), "cloud_dark": Color(0.55, 0.6, 0.68),
		"fog_color": Color(0.66, 0.76, 0.86), "fog_density": 0.00012, "vol_fog": 0.0003,
		"hs": 1.5, "spectrum": 0.85, "chop": 0.7, "foam": 0.22,
		"deep": Color(0.005, 0.035, 0.07), "body": Color(0.02, 0.14, 0.18), "sss": Color(0.05, 0.5, 0.46), "sss_str": 1.0,
		"light_level": 1.0, "ambient": 1.0, "exposure": 0.9, "sky_energy": 1.0,
		"rain": 0.0, "lightning": 0.0, "bio": 0.0, "nav_lights": 0.0, "haze": 0.14,
	},
	"golden": {
		"label": "GOLDEN HOUR  ·  SEA STATE 3",
		"sun_elev": 3.5, "sun_az": 262.0, "sun_color": Color(1.0, 0.55, 0.25), "sun_energy": 2.0,
		"zenith": Color(0.14, 0.2, 0.4), "horizon": Color(0.48, 0.46, 0.58), "horizon_sun": Color(1.0, 0.56, 0.3), "ground": Color(0.04, 0.04, 0.06),
		"sun_disk": 26.0, "sun_glow": 1.3, "moon": 0.0, "stars": 0.0,
		"clouds": 0.42, "cloud_soft": 0.2, "cloud_lit": Color(1.0, 0.55, 0.3), "cloud_amb": Color(0.44, 0.38, 0.5), "cloud_dark": Color(0.2, 0.16, 0.22),
		"fog_color": Color(0.6, 0.52, 0.55), "fog_density": 0.0002, "vol_fog": 0.0008,
		"hs": 1.8, "spectrum": 0.9, "chop": 0.72, "foam": 0.25,
		"deep": Color(0.01, 0.03, 0.05), "body": Color(0.03, 0.1, 0.13), "sss": Color(0.18, 0.4, 0.34), "sss_str": 1.2,
		"light_level": 0.7, "ambient": 0.85, "exposure": 1.0, "sky_energy": 1.0,
		"rain": 0.0, "lightning": 0.0, "bio": 0.0, "nav_lights": 1.0, "haze": 0.1,
	},
	"storm": {
		"label": "NORTH ATLANTIC GALE  ·  SEA STATE 7",
		"sun_elev": 28.0, "sun_az": 150.0, "sun_color": Color(0.72, 0.78, 0.85), "sun_energy": 0.6,
		"zenith": Color(0.15, 0.17, 0.19), "horizon": Color(0.32, 0.35, 0.38), "horizon_sun": Color(0.4, 0.43, 0.46), "ground": Color(0.04, 0.05, 0.06),
		"sun_disk": 0.0, "sun_glow": 0.15, "moon": 0.0, "stars": 0.0,
		"clouds": 1.0, "cloud_soft": 0.3, "cloud_lit": Color(0.12, 0.13, 0.14), "cloud_amb": Color(0.34, 0.36, 0.4), "cloud_dark": Color(0.1, 0.11, 0.13),
		"fog_color": Color(0.27, 0.3, 0.33), "fog_density": 0.001, "vol_fog": 0.007,
		"hs": 7.5, "spectrum": 1.3, "chop": 0.95, "foam": 1.0,
		"deep": Color(0.012, 0.03, 0.036), "body": Color(0.035, 0.09, 0.095), "sss": Color(0.08, 0.26, 0.24), "sss_str": 0.8,
		"light_level": 0.45, "ambient": 0.7, "exposure": 1.25, "sky_energy": 1.0,
		"rain": 1.0, "lightning": 1.0, "bio": 0.0, "nav_lights": 1.0, "haze": 0.2,
	},
	"night": {
		"label": "MOONLIT NIGHT  ·  SEA STATE 3",
		"sun_elev": 16.0, "sun_az": 200.0, "sun_color": Color(0.6, 0.7, 0.95), "sun_energy": 0.4,
		"zenith": Color(0.005, 0.01, 0.025), "horizon": Color(0.03, 0.042, 0.07), "horizon_sun": Color(0.07, 0.09, 0.14), "ground": Color(0.005, 0.007, 0.012),
		"sun_disk": 0.0, "sun_glow": 0.0, "moon": 1.0, "stars": 1.0,
		"clouds": 0.38, "cloud_soft": 0.2, "cloud_lit": Color(0.05, 0.06, 0.08), "cloud_amb": Color(0.05, 0.06, 0.085), "cloud_dark": Color(0.012, 0.016, 0.025),
		"fog_color": Color(0.02, 0.03, 0.05), "fog_density": 0.00015, "vol_fog": 0.0008,
		"hs": 1.9, "spectrum": 0.9, "chop": 0.75, "foam": 0.3,
		"deep": Color(0.003, 0.008, 0.016), "body": Color(0.008, 0.025, 0.04), "sss": Color(0.03, 0.1, 0.12), "sss_str": 0.4,
		"light_level": 0.16, "ambient": 0.8, "exposure": 2.1, "sky_energy": 1.0,
		"rain": 0.0, "lightning": 0.0, "bio": 1.0, "nav_lights": 1.0, "haze": 0.1,
	},
}


## --- Arctic patrol mode: the clock drives sun and moon; palettes blend by sun
## elevation and a weather condition is layered on top. ---------------------
const ARCTIC_DAY := {
	"label": "", "sun_elev": 8.0, "sun_az": 180.0, "sun_color": Color(1.0, 0.86, 0.7), "sun_energy": 1.9,
	"zenith": Color(0.17, 0.29, 0.5), "horizon": Color(0.66, 0.72, 0.79), "horizon_sun": Color(0.96, 0.82, 0.66), "ground": Color(0.04, 0.06, 0.08),
	"sun_disk": 30.0, "sun_glow": 1.0, "moon": 0.0, "stars": 0.0,
	"clouds": 0.42, "cloud_soft": 0.2, "cloud_lit": Color(1.0, 0.84, 0.68), "cloud_amb": Color(0.72, 0.76, 0.82), "cloud_dark": Color(0.36, 0.4, 0.46),
	"fog_color": Color(0.62, 0.68, 0.74), "fog_density": 0.00011, "vol_fog": 0.0008,
	"hs": 1.6, "spectrum": 0.9, "chop": 0.72, "foam": 0.25,
	"deep": Color(0.006, 0.02, 0.032), "body": Color(0.018, 0.068, 0.088), "sss": Color(0.06, 0.3, 0.3), "sss_str": 0.9,
	"light_level": 0.8, "ambient": 0.9, "exposure": 1.0, "sky_energy": 1.0,
	"rain": 0.0, "lightning": 0.0, "bio": 0.0, "nav_lights": 0.0, "haze": 0.12, "snow": 0.0, "aurora": 0.0,
}
const ARCTIC_DUSK := {
	"label": "", "sun_elev": 0.0, "sun_az": 270.0, "sun_color": Color(1.0, 0.56, 0.3), "sun_energy": 1.5,
	"zenith": Color(0.12, 0.16, 0.32), "horizon": Color(0.44, 0.42, 0.53), "horizon_sun": Color(1.0, 0.54, 0.32), "ground": Color(0.03, 0.04, 0.06),
	"sun_disk": 26.0, "sun_glow": 1.3, "moon": 0.0, "stars": 0.15,
	"clouds": 0.45, "cloud_soft": 0.2, "cloud_lit": Color(1.0, 0.54, 0.32), "cloud_amb": Color(0.38, 0.36, 0.46), "cloud_dark": Color(0.15, 0.14, 0.2),
	"fog_color": Color(0.46, 0.43, 0.5), "fog_density": 0.00014, "vol_fog": 0.0009,
	"hs": 1.6, "spectrum": 0.9, "chop": 0.72, "foam": 0.25,
	"deep": Color(0.006, 0.016, 0.026), "body": Color(0.016, 0.05, 0.066), "sss": Color(0.14, 0.32, 0.3), "sss_str": 1.1,
	"light_level": 0.5, "ambient": 0.8, "exposure": 1.1, "sky_energy": 1.0,
	"rain": 0.0, "lightning": 0.0, "bio": 0.0, "nav_lights": 1.0, "haze": 0.1, "snow": 0.0, "aurora": 0.2,
}
const ARCTIC_NIGHT := {
	"label": "", "sun_elev": -15.0, "sun_az": 0.0, "sun_color": Color(0.6, 0.7, 0.95), "sun_energy": 0.32,
	"zenith": Color(0.005, 0.01, 0.024), "horizon": Color(0.03, 0.048, 0.08), "horizon_sun": Color(0.05, 0.072, 0.1), "ground": Color(0.005, 0.008, 0.013),
	"sun_disk": 0.0, "sun_glow": 0.0, "moon": 1.0, "stars": 1.0,
	"clouds": 0.36, "cloud_soft": 0.2, "cloud_lit": Color(0.05, 0.065, 0.08), "cloud_amb": Color(0.04, 0.05, 0.07), "cloud_dark": Color(0.01, 0.015, 0.022),
	"fog_color": Color(0.02, 0.03, 0.05), "fog_density": 0.00014, "vol_fog": 0.0008,
	"hs": 1.6, "spectrum": 0.9, "chop": 0.72, "foam": 0.25,
	"deep": Color(0.004, 0.011, 0.02), "body": Color(0.012, 0.032, 0.052), "sss": Color(0.03, 0.1, 0.12), "sss_str": 0.4,
	"light_level": 0.18, "ambient": 0.9, "exposure": 2.5, "sky_energy": 1.0,
	"rain": 0.0, "lightning": 0.0, "bio": 0.25, "nav_lights": 1.0, "haze": 0.1, "snow": 0.0, "aurora": 1.0,
}
## Weather layered on the time-of-day palette: "mul" scales, "set" overrides.
const CONDITIONS := {
	"clear": {"label": "CLEAR", "mul": {}, "set": {}},
	"overcast": {"label": "OVERCAST", "mul": {"sun_energy": 0.45, "light_level": 0.78, "fog_density": 2.5, "hs": 1.2, "exposure": 1.12, "sun_glow": 0.3},
		"set": {"clouds": 0.97, "cloud_soft": 0.3, "sun_disk": 0.0, "stars": 0.0, "aurora": 0.0, "moon": 0.0}},
	"fog": {"label": "SEA FOG", "mul": {"sun_energy": 0.3, "light_level": 0.72, "hs": 0.7, "sun_glow": 0.25},
		"set": {"fog_density": 0.0045, "vol_fog": 0.02, "clouds": 1.0, "sun_disk": 0.0, "stars": 0.0, "aurora": 0.0, "moon": 0.0, "haze": 0.45}},
	"snow": {"label": "SNOW", "mul": {"sun_energy": 0.3, "light_level": 0.62, "hs": 1.4, "exposure": 1.2, "sun_glow": 0.2},
		"set": {"snow": 1.0, "clouds": 1.0, "fog_density": 0.0012, "vol_fog": 0.008, "sun_disk": 0.0, "stars": 0.0, "aurora": 0.0, "moon": 0.0}},
	"gale": {"label": "GALE", "mul": {"sun_energy": 0.3, "light_level": 0.55, "exposure": 1.2, "sun_glow": 0.15},
		"set": {"hs": 6.0, "spectrum": 1.3, "chop": 0.95, "foam": 1.0, "snow": 0.55, "clouds": 1.0, "fog_density": 0.0009, "vol_fog": 0.01, "sun_disk": 0.0, "stars": 0.0, "aurora": 0.0, "moon": 0.0}},
}

var clock: GameClock
var arctic := false
var condition := "clear"
var _snow: GPUParticles3D
var _snow_mat: ShaderMaterial
var _moon_dir := Vector3(0.3, 0.4, 0.8)
var _real_sun_dir := Vector3.UP

var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var ocean: Ocean
var follow: Node3D

var current: Dictionary = {}
var preset_name := "dawn"
var underwater := false
var thermal := false
var underwater_depth := 0.0
var cloud_time := 0.0

var _from: Dictionary = {}
var _to: Dictionary = {}
var _blend := 1.0
var _blend_time := 6.0
var _lightning := 0.0
var _lightning_timer := 6.0
var _rain: GPUParticles3D
var _rain_mat: ShaderMaterial
var _ray_volume: FogVolume
var _ray_mat: ShaderMaterial


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "SunMoon"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 450.0
	sun.light_angular_distance = 0.6
	sun.shadow_blur = 1.2
	sun.light_volumetric_fog_energy = 1.0
	sun.light_cull_mask = 0xFFFFF & ~(1 << 1)
	add_child(sun)

	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://src/sky/sky.gdshader")
	sky_mat.set_shader_parameter("cloud_noise", _cloud_noise(1024, 0.0045, 6, 3))
	sky_mat.set_shader_parameter("cloud_detail", _cloud_noise(512, 0.012, 4, 9))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.55
	env.volumetric_fog_enabled = true
	env.volumetric_fog_length = 260.0
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_sky_affect = 0.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.02

	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_build_rain()
	_build_snow()
	_build_light_rays()

	current = PRESETS[preset_name].duplicate()
	_from = current.duplicate()
	_to = current.duplicate()
	_apply()


func set_preset(p_name: String, instant: bool = false) -> void:
	if not PRESETS.has(p_name):
		return
	preset_name = p_name
	_from = current.duplicate()
	_to = PRESETS[p_name].duplicate()
	_blend = 0.0
	_blend_time = 0.01 if instant else 7.0
	preset_changed.emit(String(_to["label"]))


func next_preset() -> void:
	var i := ORDER.find(preset_name)
	set_preset(ORDER[(i + 1) % ORDER.size()])


func label() -> String:
	return String(PRESETS[preset_name]["label"])


func is_night() -> bool:
	if arctic and clock:
		return clock.sun().x < -4.0
	return float(current.get("nav_lights", 0.0)) > 0.5 and float(current.get("light_level", 1.0)) < 0.3


func set_underwater(value: bool, depth: float) -> void:
	underwater = value
	underwater_depth = depth


func _process(delta: float) -> void:
	cloud_time += delta
	if arctic and clock:
		var target := _compose_arctic()
		var k := 1.0 - exp(-delta / 6.0)
		for key in target.keys():
			var a: Variant = current.get(key, target[key])
			var b: Variant = target[key]
			if b is float:
				current[key] = lerpf(float(a), float(b), k)
			elif b is Color:
				current[key] = (a as Color).lerp(b as Color, k)
			else:
				current[key] = b
		# The sun follows the clock directly (no smoothing).
		current["sun_elev"] = target["sun_elev"]
		current["sun_az"] = target["sun_az"]
	elif _blend < 1.0:
		_blend = minf(_blend + delta / _blend_time, 1.0)
		var t := smoothstep(0.0, 1.0, _blend)
		for key in _to.keys():
			var a: Variant = _from.get(key, _to[key])
			var b: Variant = _to[key]
			if b is float:
				current[key] = lerpf(float(a), float(b), t)
			elif b is Color:
				current[key] = (a as Color).lerp(b as Color, t)
			else:
				current[key] = b
	_update_lightning(delta)
	_apply()
	if follow:
		var fp := follow.global_position
		_rain.global_position = fp + Vector3(0.0, 18.0, 0.0)
		_ray_volume.global_position = fp
	_rain.emitting = float(current["rain"]) > 0.3 and not underwater
	_rain.amount_ratio = clampf(float(current["rain"]), 0.0, 1.0)
	var snow := float(current.get("snow", 0.0))
	_snow.emitting = snow > 0.15 and not underwater
	_snow.amount_ratio = clampf(snow, 0.0, 1.0)
	if follow:
		_snow.global_position = follow.global_position + Vector3(0.0, 12.0, 0.0)
	_snow_mat.set_shader_parameter("light_level", 0.25 + float(current["light_level"]) * 0.9)
	var wind := 1.5 + float(current["hs"]) * 1.4
	(_snow.process_material as ParticleProcessMaterial).gravity = Vector3(wind * 0.8, -1.6, wind * 0.3)


## Unit vector pointing from the scene toward the sun (or the moon at night).
func to_sun() -> Vector3:
	return sun.global_transform.basis.z


func _apply() -> void:
	var c := current
	var elev := deg_to_rad(float(c["sun_elev"]))
	var az := deg_to_rad(float(c["sun_az"]))
	# Direction toward the light (sun, or the moon at night).
	var to_light := Vector3(sin(az) * cos(elev), sin(elev), -cos(az) * cos(elev)).normalized()
	_real_sun_dir = to_light
	var light_scale := 1.0
	if arctic:
		var sun_el := float(c["sun_elev"])
		_moon_dir = Vector3(-sin(az) * 0.9, 0.36, cos(az) * 0.9).normalized()
		if sun_el > -3.0:
			light_scale = smoothstep(-3.0, 3.0, sun_el)
			# Keep the shadow-casting light a touch above the horizon.
			var e2 := deg_to_rad(maxf(sun_el, 1.5))
			to_light = Vector3(sin(az) * cos(e2), sin(e2), -cos(az) * cos(e2)).normalized()
		else:
			light_scale = smoothstep(-3.0, -9.0, sun_el)
			to_light = _moon_dir
	sun.global_transform = Transform3D(Basis.looking_at(-to_light, Vector3.UP if absf(to_light.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	var flash := _lightning
	sun.light_color = (c["sun_color"] as Color).lerp(Color(0.8, 0.85, 1.0), clampf(flash, 0.0, 1.0))
	sun.light_energy = float(c["sun_energy"]) * light_scale + flash * 2.5

	var moon_on := float(c["moon"])
	if arctic:
		sky_mat.set_shader_parameter("sun_dir", _real_sun_dir)
		sky_mat.set_shader_parameter("moon_dir", _moon_dir)
		sky_mat.set_shader_parameter("aurora", float(c.get("aurora", 0.0)))
	else:
		sky_mat.set_shader_parameter("sun_dir", to_light)
		sky_mat.set_shader_parameter("moon_dir", to_light if moon_on > 0.5 else Vector3(0.3, -0.5, 0.8))
		sky_mat.set_shader_parameter("aurora", 0.0)
	sky_mat.set_shader_parameter("moon_intensity", moon_on)
	sky_mat.set_shader_parameter("sun_color", c["sun_color"])
	sky_mat.set_shader_parameter("sun_disk", c["sun_disk"])
	sky_mat.set_shader_parameter("sun_glow", c["sun_glow"])
	sky_mat.set_shader_parameter("zenith_color", c["zenith"])
	sky_mat.set_shader_parameter("horizon_color", c["horizon"])
	sky_mat.set_shader_parameter("horizon_sun", c["horizon_sun"])
	sky_mat.set_shader_parameter("cloud_ambient", c["cloud_amb"])
	sky_mat.set_shader_parameter("ground_color", c["ground"])
	sky_mat.set_shader_parameter("cloud_coverage", c["clouds"])
	sky_mat.set_shader_parameter("cloud_softness", c["cloud_soft"])
	sky_mat.set_shader_parameter("cloud_lit", c["cloud_lit"])
	sky_mat.set_shader_parameter("cloud_dark", c["cloud_dark"])
	sky_mat.set_shader_parameter("star_intensity", c["stars"])
	sky_mat.set_shader_parameter("cloud_time", cloud_time * (1.0 + float(c["rain"]) * 2.5))
	sky_mat.set_shader_parameter("lightning", flash)
	sky_mat.set_shader_parameter("sky_energy", c["sky_energy"])
	sky_mat.set_shader_parameter("horizon_haze", c["haze"])

	env.tonemap_exposure = float(c["exposure"])
	env.ambient_light_energy = float(c["ambient"]) + flash * 0.8
	env.ambient_light_sky_contribution = 1.0

	if ocean:
		ocean.set_sea_state(float(c["hs"]), float(c["spectrum"]), float(c["chop"]))
		ocean.set_param("deep_color", c["deep"])
		ocean.set_param("body_color", c["body"])
		ocean.set_param("sss_color", c["sss"])
		ocean.set_param("sss_strength", c["sss_str"])
		ocean.set_param("light_level", float(c["light_level"]) + flash * 0.3)
		ocean.set_param("foam_amount", c["foam"])
		ocean.set_param("sun_dir", to_light)
		ocean.set_param("sun_color", (c["sun_color"] as Color) * clampf(float(c["sun_energy"]) / 2.0, 0.0, 1.2))
		ocean.set_param("bioluminescence", c["bio"])
		ocean.set_param("camera_underwater", 1.0 if underwater else 0.0)
		ocean.set_param("underwater_color", _underwater_color())
		ocean.set_param("detail_strength", lerpf(0.3, 0.6, clampf(float(c["hs"]) / 7.0, 0.0, 1.0)))

	var body := c["body"] as Color
	if underwater:
		var uw := _underwater_color()
		var depth_dark := exp(-underwater_depth * 0.018)
		env.fog_light_color = uw * depth_dark
		# Arctic water: a few tens of metres of visibility, less the deeper and
		# darker it gets.
		env.fog_density = lerpf(0.028, 0.05, smoothstep(10.0, 60.0, underwater_depth))
		env.fog_aerial_perspective = 0.0
		env.fog_sky_affect = 1.0
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0
		env.volumetric_fog_albedo = Color(body.r * 6.0, body.g * 6.0, body.b * 6.0).clamp()
		env.volumetric_fog_emission = uw * 0.35 * depth_dark
		env.volumetric_fog_length = 140.0
		env.volumetric_fog_anisotropy = 0.75
		env.glow_intensity = 0.7
		_ray_volume.visible = true
		_ray_mat.set_shader_parameter("sun_dir", to_light)
		_ray_mat.set_shader_parameter("time", cloud_time)
		_ray_mat.set_shader_parameter("strength", clampf(float(c["light_level"]) * 1.3, 0.05, 1.0))
		_ray_mat.set_shader_parameter("ray_color", Color(0.55, 0.85, 0.9).lerp(c["sun_color"] as Color, 0.25))
		_ray_mat.set_shader_parameter("ocean_time", ocean.ocean_time if ocean else 0.0)
	else:
		env.fog_light_color = c["fog_color"]
		env.fog_density = float(c["fog_density"]) * (1.0 + flash * 0.2)
		env.fog_aerial_perspective = 0.4
		env.fog_sky_affect = 0.0
		env.volumetric_fog_density = float(c["vol_fog"])
		env.volumetric_fog_albedo = (c["fog_color"] as Color).lerp(Color.WHITE, 0.3)
		env.volumetric_fog_emission = Color.BLACK
		env.volumetric_fog_length = 260.0
		env.volumetric_fog_anisotropy = 0.55
		env.glow_intensity = 0.55
		_ray_volume.visible = false
	if thermal:
		env.fog_light_color = Color(0.015, 0.015, 0.015)
		env.fog_density = float(c["fog_density"]) * 0.4
		env.volumetric_fog_density = 0.0
		env.ambient_light_energy = 0.0
		sun.light_energy = 0.0
		env.tonemap_exposure = 1.0
	_rain_mat.set_shader_parameter("brightness", float(c["light_level"]) * 0.55 + flash * 1.5)


func _underwater_color() -> Color:
	var body := current["body"] as Color
	var lvl := float(current["light_level"])
	return Color(body.r * 1.6, body.g * 2.4, body.b * 2.5) * (0.35 + lvl * 0.9)


func _update_lightning(delta: float) -> void:
	_lightning = maxf(_lightning - delta * 4.0, 0.0)
	if float(current.get("lightning", 0.0)) < 0.5:
		return
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(5.0, 14.0)
		_flash_sequence()


func _flash_sequence() -> void:
	sky_mat.set_shader_parameter("lightning_pos", Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)))
	var strikes := randi_range(1, 3)
	for i in strikes:
		_lightning = randf_range(0.6, 1.0)
		await get_tree().create_timer(randf_range(0.06, 0.18)).timeout
	lightning_struck.emit(randf_range(1.5, 6.0))


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 30000
	_rain.lifetime = 1.6
	_rain.preprocess = 1.0
	_rain.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 90, 120))
	_rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(45.0, 12.0, 45.0)
	pm.direction = Vector3(0.25, -1.0, 0.12)
	pm.spread = 4.0
	pm.initial_velocity_min = 26.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3(0, -9.8, 0)
	_rain.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.75)
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = load("res://src/fx/rain.gdshader")
	quad.material = _rain_mat
	_rain.draw_pass_1 = quad
	_rain.emitting = false
	add_child(_rain)


func _build_light_rays() -> void:
	_ray_volume = FogVolume.new()
	_ray_volume.name = "UnderwaterLightShafts"
	_ray_volume.size = Vector3(240.0, 160.0, 240.0)
	_ray_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_ray_mat = ShaderMaterial.new()
	_ray_mat.shader = load("res://src/fx/light_shafts.gdshader")
	_ray_mat.set_shader_parameter("noise_tex", _cloud_noise(256, 0.03, 3, 41))
	_ray_volume.material = _ray_mat
	_ray_volume.visible = false
	add_child(_ray_volume)


static func _cloud_noise(size: int, freq: float, octaves: int, seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = freq
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.55
	noise.seed = seed_value
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.normalize = true
	tex.noise = noise
	return tex


func set_condition(c: String) -> void:
	if CONDITIONS.has(c) and c != condition:
		condition = c
		preset_changed.emit(String(CONDITIONS[c]["label"]))


func condition_label() -> String:
	return String(CONDITIONS[condition]["label"]) if arctic else label()


## Rough meteorological visibility in metres (for sensors and lookouts).
func visibility_m() -> float:
	var vis := 3.0 / maxf(float(current.get("fog_density", 0.0002)), 0.00005)
	vis = minf(vis, 24000.0)
	return vis


## 0 = full daylight, 1 = dark night.
func darkness() -> float:
	if arctic and clock:
		return 1.0 - smoothstep(-9.0, 2.0, clock.sun().x)
	return 1.0 - clampf(float(current.get("light_level", 1.0)), 0.0, 1.0)


func _compose_arctic() -> Dictionary:
	var sun_v := clock.sun()
	var el := sun_v.x
	var out := {}
	var night_w := 1.0 - smoothstep(-10.0, -2.0, el)
	var day_w := smoothstep(0.5, 7.0, el)
	for key in ARCTIC_DAY.keys():
		var d: Variant = ARCTIC_DAY[key]
		var u: Variant = ARCTIC_DUSK[key]
		var n: Variant = ARCTIC_NIGHT[key]
		if d is float:
			var dusk_v := lerpf(float(n), float(u), 1.0 - night_w)
			out[key] = lerpf(dusk_v, float(d), day_w)
		elif d is Color:
			var dusk_c := (n as Color).lerp(u as Color, 1.0 - night_w)
			out[key] = dusk_c.lerp(d as Color, day_w)
		else:
			out[key] = d
	var cond: Dictionary = CONDITIONS[condition]
	for key in (cond["mul"] as Dictionary).keys():
		out[key] = float(out[key]) * float(cond["mul"][key])
	for key in (cond["set"] as Dictionary).keys():
		out[key] = cond["set"][key]
	if condition == "fog" or condition == "snow":
		var lvl := float(out["light_level"])
		out["fog_color"] = (out["horizon"] as Color).lerp(Color(0.78, 0.8, 0.83) * clampf(lvl * 1.1, 0.05, 1.0), 0.6)
		out["horizon"] = (out["horizon"] as Color).lerp(out["fog_color"] as Color, 0.6)
		out["horizon_sun"] = (out["horizon_sun"] as Color).lerp(out["fog_color"] as Color, 0.6)
	out["sun_elev"] = el
	out["sun_az"] = sun_v.y
	out["label"] = String(cond["label"])
	return out


func _build_snow() -> void:
	_snow = GPUParticles3D.new()
	_snow.name = "Snow"
	_snow.amount = 9000
	_snow.lifetime = 7.0
	_snow.preprocess = 4.0
	_snow.local_coords = false
	_snow.visibility_aabb = AABB(Vector3(-70, -60, -70), Vector3(140, 90, 140))
	_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(45.0, 14.0, 45.0)
	pm.direction = Vector3(0.3, -1.0, 0.1)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(2.0, -1.6, 0.6)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	_snow.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	_snow_mat = ShaderMaterial.new()
	_snow_mat.shader = load("res://src/fx/soft_particle.gdshader")
	_snow_mat.set_shader_parameter("tint", Color(0.95, 0.97, 1.0, 0.85))
	q.material = _snow_mat
	_snow.draw_pass_1 = q
	_snow.emitting = false
	add_child(_snow)
