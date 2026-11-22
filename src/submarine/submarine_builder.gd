class_name SubmarineBuilder
extends RefCounted
## Procedural geometry for the fictional "Varg"-class diesel-electric AIP
## submarine: tiled body of revolution with a flattened casing, filleted sail
## with sail planes, X-form stern, pump-jet shroud with a visible rotor, and
## retractable masts. Forward is -Z; the hull axis lies on y = 0.

const L := 76.0
const R := 3.8
const BOW := 11.0
const TAIL := 27.0
const R_END := 0.85
const HUB := 1.7
const DECK_Y := R * 0.84
const SAIL_LE_S := 17.0
const SAIL_CHORD := 11.6
const SAIL_T := 2.3
const SAIL_TOP := R + 5.5
const SAIL_BASE := 1.2


static func hull_radius(s: float) -> float:
	if s <= 0.0:
		return 0.0
	if s < BOW:
		var x := s / BOW
		return R * pow(1.0 - pow(1.0 - x, 2.4), 1.0 / 2.4)
	if s < L - TAIL:
		return R
	if s <= L:
		var x2 := (s - (L - TAIL)) / TAIL
		return R_END + (R - R_END) * (1.0 - pow(x2, 2.15))
	if s <= L + HUB:
		var x3 := (s - L) / HUB
		return R_END * sqrt(maxf(0.0, 1.0 - x3 * x3))
	return 0.0


static func hull_point(u: float, v: float) -> Vector3:
	var s := u * (L + HUB)
	var r := hull_radius(s)
	var a := v * TAU
	var x := r * sin(a)
	var y := -r * cos(a)
	var flat_w := smoothstep(3.0, 10.0, s) * (1.0 - smoothstep(L - 32.0, L - 20.0, s))
	if y > DECK_Y:
		y = lerpf(y, DECK_Y + (y - DECK_Y) * 0.22, flat_w)
	return Vector3(x, y, s - L * 0.5)


static func hull_uv(u: float, v: float) -> Vector2:
	var s := u * (L + HUB)
	return Vector2(s, v * TAU * maxf(hull_radius(s), 0.5))


static func sail_point(u: float, v: float) -> Vector3:
	var sec := ParamMesh.section(v)
	var xc := sec.x
	var top_r := 0.55
	var side_top := SAIL_TOP - top_r
	var y: float
	var top_scale := 1.0
	if u <= 0.9:
		y = lerpf(SAIL_BASE, side_top, u / 0.9)
	else:
		var phi := (u - 0.9) / 0.1 * PI * 0.5
		y = side_top + top_r * sin(phi)
		top_scale = cos(phi)
	var above_deck := y - DECK_Y
	var fil := pow(clampf(1.0 - above_deck / 1.3, 0.0, 1.0), 2.0)
	var chord := SAIL_CHORD - maxf(above_deck, 0.0) * 0.14 + fil * 3.2
	var le := (SAIL_LE_S - L * 0.5) + maxf(above_deck, 0.0) * 0.1 - fil * 1.4
	var blunt := clampf(1.75 * sqrt(xc), 0.0, 1.0)
	var taper := 1.0 - 0.8 * smoothstep(0.42, 1.0, xc)
	var half_t := SAIL_T * 0.5 * blunt * taper * (1.0 + fil * 0.9) * top_scale
	return Vector3(sec.y * half_t, y, le + xc * chord)


static func sail_uv(u: float, v: float) -> Vector2:
	var p := sail_point(u, v)
	return Vector2(p.z + (0.0 if v < 0.5 else 40.0), p.y)


static func fin(root: Vector3, span_dir: Vector3, chord_dir: Vector3, span: float, c_root: float, c_tip: float, sweep: float, tr: float) -> Callable:
	var thick_dir := span_dir.cross(chord_dir).normalized()
	return func(u: float, v: float) -> Vector3:
		var sec := ParamMesh.section(v)
		var c := lerpf(c_root, c_tip, u)
		var tip := sqrt(maxf(0.0, 1.0 - pow(maxf(0.0, (u - 0.86) / 0.14), 2.0)))
		var t := ParamMesh.foil(sec.x) * tr * c * tip
		var lead := sweep * u + (1.0 - tip) * c * 0.12
		var cc := c * lerpf(1.0, 0.75, 1.0 - tip)
		return root + span_dir * (u * span) + chord_dir * (lead + sec.x * cc) + thick_dir * (t * sec.y)


static func fin_uv(u: float, v: float) -> Vector2:
	return Vector2(u * 4.0 + (0.0 if v < 0.5 else 13.0), v * 6.0)


static func duct_point(u: float, v: float) -> Vector3:
	var a := u * TAU
	var sec := ParamMesh.section(v)
	var chord := 3.7
	var z_le := L * 0.5 - 4.3
	var r_mean := lerpf(2.55, 2.32, sec.x)
	var t := ParamMesh.foil(sec.x) * 0.14 * chord
	var camber := 0.08 * chord * sin(PI * sec.x)
	var r := r_mean + sec.y * t + camber
	return Vector3(r * sin(a), -r * cos(a), z_le + sec.x * chord)


static func duct_uv(u: float, v: float) -> Vector2:
	return Vector2(v * 8.0, u * TAU * 2.5)


static func build_hull_mesh(hull_mat: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	ParamMesh.add_to(mesh, ParamMesh.surface(hull_point, hull_uv, 240, 72), hull_mat)
	ParamMesh.add_to(mesh, ParamMesh.surface(sail_point, sail_uv, 48, 64), hull_mat)
	# Sail planes.
	var sp_y := SAIL_TOP - 2.7
	var sp_z := (SAIL_LE_S - L * 0.5) + 1.35
	for side in [-1.0, 1.0]:
		var root := Vector3(side * 0.6, sp_y, sp_z)
		var f := fin(root, Vector3(side, 0.04, 0.0).normalized(), Vector3(0, 0, 1), 3.4, 2.9, 2.0, 0.55, 0.13)
		ParamMesh.add_to(mesh, ParamMesh.surface(f, fin_uv, 16, 28), hull_mat)
	# X-form stern control surfaces.
	var fin_le := L * 0.5 - 10.6
	for k in 4:
		var ang := deg_to_rad(45.0 + 90.0 * k)
		var span_dir := Vector3(sin(ang), -cos(ang), 0.0)
		var root2 := span_dir * 1.4 + Vector3(0, 0, fin_le + 0.6)
		var f2 := fin(root2, span_dir, Vector3(0, 0, 1), 2.55, 4.6, 2.9, 1.3, 0.12)
		ParamMesh.add_to(mesh, ParamMesh.surface(f2, fin_uv, 18, 28), hull_mat)
	ParamMesh.add_to(mesh, ParamMesh.surface(duct_point, duct_uv, 72, 28), hull_mat)
	# Fixed stator vanes inside the shroud.
	for k in 7:
		var ang2 := TAU * float(k) / 7.0 + 0.2
		var sd := Vector3(sin(ang2), -cos(ang2), 0.0)
		var hub_r := hull_radius(L - 3.3)
		var f3 := fin(sd * (hub_r - 0.1) + Vector3(0, 0, L * 0.5 - 3.9), sd, Vector3(0, 0, 1), 2.45 - hub_r + 0.15, 0.9, 0.8, 0.0, 0.1)
		ParamMesh.add_to(mesh, ParamMesh.surface(f3, fin_uv, 6, 14), hull_mat)
	return mesh


static func build_rotor_mesh(mat: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var hub_r := hull_radius(L - 2.0)
	for k in 9:
		var th := TAU * float(k) / 9.0
		var span_dir := Vector3(sin(th), -cos(th), 0.0)
		var tangent := Vector3(cos(th), sin(th), 0.0)
		var pitch := deg_to_rad(55.0)
		var chord_dir := (tangent * cos(pitch) + Vector3(0, 0, 1) * sin(pitch)).normalized()
		var root := span_dir * (hub_r - 0.15) - chord_dir * 0.45
		var f := fin(root, span_dir, chord_dir, 2.25 - hub_r + 0.12, 1.0, 0.75, 0.25, 0.07)
		ParamMesh.add_to(mesh, ParamMesh.surface(f, fin_uv, 10, 16), mat)
	return mesh


## Returns {name: [node, height]} for each retractable mast.
static func build_masts(parent: Node3D, metal: Material, glass: Material) -> Dictionary:
	var out := {}
	var top := SAIL_TOP - 0.25
	var defs := [
		["photonics", -19.6, 3.9, 0.17],
		["esm", -18.0, 4.4, 0.12],
		["radar", -16.4, 3.4, 0.13],
		["snorkel", -14.6, 3.2, 0.0],
		["comms", -12.6, 5.6, 0.05],
	]
	for d in defs:
		var mast := Node3D.new()
		mast.name = "Mast_" + String(d[0])
		var h := float(d[2])
		var z := float(d[1])
		mast.position = Vector3(0, top, z)
		parent.add_child(mast)
		var kind := String(d[0])
		if kind == "snorkel":
			_box(mast, Vector3(0.45, h, 0.75), Vector3(0, h * 0.5, 0), metal)
			_box(mast, Vector3(0.7, 0.55, 1.05), Vector3(0, h + 0.1, 0.1), metal)
			_box(mast, Vector3(0.72, 0.16, 0.9), Vector3(0, h + 0.42, 0.1), glass)
		else:
			_cyl(mast, float(d[3]), h, Vector3(0, h * 0.5, 0), metal)
			match kind:
				"photonics":
					_cyl(mast, 0.33, 0.8, Vector3(0, h + 0.35, 0), metal)
					_box(mast, Vector3(0.34, 0.22, 0.08), Vector3(0, h + 0.42, -0.3), glass)
					_box(mast, Vector3(0.16, 0.14, 0.08), Vector3(0.12, h + 0.16, -0.3), glass)
					_cyl(mast, 0.12, 0.12, Vector3(0, h + 0.81, 0), metal)
				"esm":
					var dome := MeshInstance3D.new()
					var sm := SphereMesh.new()
					sm.radius = 0.24
					sm.height = 0.38
					sm.material = metal
					dome.mesh = sm
					dome.position = Vector3(0, h + 0.12, 0)
					mast.add_child(dome)
					_cyl(mast, 0.3, 0.07, Vector3(0, h - 0.15, 0), metal)
					_cyl(mast, 0.04, 0.6, Vector3(0, h + 0.55, 0), metal)
				"radar":
					_box(mast, Vector3(1.25, 0.24, 0.12), Vector3(0, h + 0.1, 0), metal)
				"comms":
					_cyl(mast, 0.09, 0.4, Vector3(0, h - 0.2, 0), metal)
		out[kind] = [mast, h]
	return out


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 20
	cm.rings = 1
	cm.material = mat
	mi.mesh = cm
	mi.position = pos
	parent.add_child(mi)
	return mi
