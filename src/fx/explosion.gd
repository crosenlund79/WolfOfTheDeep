class_name Explosion
extends Node3D
## Underwater warhead detonation against a hull: a flash under the surface,
## a towering white water column, falling spray, mist, flying debris and a
## lingering cloud of smoke. Frees itself when finished.

var scale_factor := 1.0
var _flash: OmniLight3D
var _glow: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	var s := scale_factor
	# Water column: a narrow, fast plume that rises and collapses.
	_burst(1600, 5.5, Vector3(3.0, 1.0, 3.0) * s, Vector3.UP, 10.0, 22.0 * s, 50.0 * s, 2.0 * s, 7.0 * s, Color(0.94, 0.97, 1.0, 0.75), 0.92)
	# Wide spray skirt at the base.
	_burst(900, 3.5, Vector3(6.0, 0.5, 6.0) * s, Vector3.UP, 70.0, 6.0 * s, 18.0 * s, 1.5 * s, 4.0 * s, Color(0.9, 0.94, 0.97, 0.55), 0.95)
	# Drifting mist that lingers.
	_burst(300, 9.0, Vector3(12.0, 4.0, 12.0) * s, Vector3.UP, 40.0, 1.0, 4.0, 8.0 * s, 16.0 * s, Color(0.82, 0.86, 0.9, 0.18), 0.4)
	# Smoke rising from the wound.
	var smoke := _burst(220, 14.0, Vector3(4.0, 1.0, 4.0) * s, Vector3.UP, 25.0, 3.0, 9.0, 6.0 * s, 18.0 * s, Color(0.12, 0.11, 0.1, 0.5), 0.3)
	(smoke.process_material as ParticleProcessMaterial).gravity = Vector3(1.5, 1.2, 0.5)
	_debris(70 if s > 0.6 else 25)

	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.72, 0.4)
	_flash.light_energy = 60.0 * s
	_flash.omni_range = 160.0 * s
	_flash.position = Vector3(0, 4.0, 0)
	add_child(_flash)
	_glow = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 6.0 * s
	sm.height = 12.0 * s
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1.0, 0.8, 0.5, 0.9)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.7, 0.35)
	gm.emission_energy_multiplier = 8.0
	sm.material = gm
	_glow.mesh = sm
	_glow.position = Vector3(0, -2.0, 0)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)


func _process(delta: float) -> void:
	_t += delta
	var f := exp(-_t * 5.0)
	_flash.light_energy = 60.0 * scale_factor * f * (0.8 + 0.2 * sin(_t * 70.0))
	(_glow.mesh as SphereMesh).material.albedo_color.a = 0.9 * exp(-_t * 7.0)
	_glow.scale = Vector3.ONE * (1.0 + _t * 3.0)
	_glow.visible = _t < 0.8
	if _t > 16.0:
		queue_free()


func _burst(amount: int, life: float, box: Vector3, dir: Vector3, spread: float, vmin: float, vmax: float, smin: float, smax: float, color: Color, explosive: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = explosive
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-150, -30, -150), Vector3(300, 200, 300))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, -9.8, 0)
	pm.damping_min = 0.3
	pm.damping_max = 1.0
	pm.scale_min = 1.0
	pm.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, smin / maxf(smax, 0.01)))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ac := Curve.new()
	ac.add_point(Vector2(0.0, 1.0))
	ac.add_point(Vector2(0.6, 0.7))
	ac.add_point(Vector2(1.0, 0.0))
	var act := CurveTexture.new()
	act.curve = ac
	pm.alpha_curve = act
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(smax, smax)
	var qm := ShaderMaterial.new()
	qm.shader = load("res://src/fx/soft_particle.gdshader")
	qm.set_shader_parameter("tint", color)
	q.material = qm
	p.draw_pass_1 = q
	add_child(p)
	p.emitting = true
	return p


func _debris(amount: int) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 4.0
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-150, -30, -150), Vector3(300, 200, 300))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 12.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.scale_min = 0.3
	pm.scale_max = 1.4
	p.process_material = pm
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.15, 0.9)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.06)
	mat.roughness = 0.8
	bm.material = mat
	p.draw_pass_1 = bm
	add_child(p)
	p.emitting = true
