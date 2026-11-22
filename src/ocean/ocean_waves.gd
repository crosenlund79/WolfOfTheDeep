class_name OceanWaves
extends RefCounted
## Shared Gerstner wave set. The ocean shader and CPU-side cosmetic buoyancy
## evaluate exactly the same waves, so floating objects ride the visible swell.
## Wavelengths, directions and phases stay fixed; sea state only rescales
## amplitudes, so weather can blend smoothly without phase jumps.

const MAX_WAVES := 12
const GRAVITY := 9.81
const MAX_WAVELENGTH := 210.0
const MIN_WAVELENGTH := 2.2

var dir_x := PackedFloat32Array()
var dir_z := PackedFloat32Array()
var k := PackedFloat32Array()
var amp := PackedFloat32Array()
var omega := PackedFloat32Array()
var steep := PackedFloat32Array()
var phase := PackedFloat32Array()
var wavelength := PackedFloat32Array()
var _rand_weight := PackedFloat32Array()

var wind_angle := 0.0
var significant_height := 1.5


func _init(p_wind_angle: float = 0.6, seed_value: int = 1337) -> void:
	wind_angle = p_wind_angle
	dir_x.resize(MAX_WAVES)
	dir_z.resize(MAX_WAVES)
	k.resize(MAX_WAVES)
	amp.resize(MAX_WAVES)
	omega.resize(MAX_WAVES)
	steep.resize(MAX_WAVES)
	phase.resize(MAX_WAVES)
	wavelength.resize(MAX_WAVES)
	_rand_weight.resize(MAX_WAVES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in MAX_WAVES:
		var f := float(i) / float(MAX_WAVES - 1)
		var wl := MAX_WAVELENGTH * pow(MIN_WAVELENGTH / MAX_WAVELENGTH, f)
		# Long swell stays close to the wind; short chop spreads widely.
		var spread := lerpf(0.25, 1.25, f)
		var ang := wind_angle + rng.randf_range(-spread, spread)
		dir_x[i] = cos(ang)
		dir_z[i] = sin(ang)
		wavelength[i] = wl
		k[i] = TAU / wl
		omega[i] = sqrt(GRAVITY * k[i])
		phase[i] = rng.randf() * TAU
		_rand_weight[i] = rng.randf_range(0.65, 1.2)
	set_sea_state(1.5, 0.9, 0.75)


## hs: significant wave height in metres. spectrum: how strongly long swell
## dominates (higher = longer waves dominate). chop: summed Gerstner steepness.
func set_sea_state(hs: float, spectrum: float, chop: float) -> void:
	significant_height = hs
	var weights := PackedFloat32Array()
	weights.resize(MAX_WAVES)
	var sum_sq := 0.0
	# Peak of the spectrum shifts toward longer waves in heavier seas.
	var peak := lerpf(38.0, 150.0, clampf(hs / 8.0, 0.0, 1.0))
	for i in MAX_WAVES:
		var r := wavelength[i] / peak
		var w: float
		if r > 1.0:
			w = pow(1.0 / r, 2.2)
		else:
			w = pow(r, 1.0 / maxf(spectrum, 0.05))
		w *= _rand_weight[i]
		weights[i] = w
		sum_sq += w * w
	# Scale so the standard deviation of the summed surface equals hs / 4.
	var sigma := hs / 4.0
	var s := sigma / sqrt(maxf(sum_sq * 0.5, 1e-6))
	for i in MAX_WAVES:
		amp[i] = weights[i] * s
		var ka := k[i] * amp[i]
		steep[i] = clampf(chop / (ka * float(MAX_WAVES) + 1e-5), 0.0, 1.0)


func displacement(x: float, z: float, t: float) -> Vector3:
	var d := Vector3.ZERO
	for i in MAX_WAVES:
		var th := k[i] * (dir_x[i] * x + dir_z[i] * z) - omega[i] * t + phase[i]
		var c := cos(th)
		var qa := steep[i] * amp[i]
		d.x += qa * dir_x[i] * c
		d.z += qa * dir_z[i] * c
		d.y += amp[i] * sin(th)
	return d


## Surface height at world position (x, z), solving for horizontal displacement.
func height_at(x: float, z: float, t: float) -> float:
	var px := x
	var pz := z
	for _iter in 3:
		var d := displacement(px, pz, t)
		px = x - d.x
		pz = z - d.z
	return displacement(px, pz, t).y


func shader_wave_a() -> Array:
	var out: Array = []
	for i in MAX_WAVES:
		out.append(Vector4(dir_x[i], dir_z[i], k[i], amp[i]))
	return out


func shader_wave_b() -> Array:
	var out: Array = []
	for i in MAX_WAVES:
		out.append(Vector4(omega[i], steep[i], phase[i], 0.0))
	return out
