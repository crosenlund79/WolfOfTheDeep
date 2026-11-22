class_name ParamMesh
extends RefCounted
## Builds smooth closed parametric surfaces for procedural hulls and foils.
## f(u, v) -> Vector3 position; v loops around a closed cross-section, u runs
## along the part. Normals use finite differences, oriented away from each
## cross-section's centroid, and triangle winding is made to match them.


static func surface(f: Callable, uvf: Callable, nu: int, nv: int) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var cols := nv + 1
	var last_dir := Vector3.ZERO
	for i in nu + 1:
		var u := float(i) / float(nu)
		var row: Array[Vector3] = []
		var centroid := Vector3.ZERO
		for j in nv + 1:
			var p: Vector3 = f.call(u, float(j) / float(nv))
			row.append(p)
			if j < nv:
				centroid += p
		centroid /= float(nv)
		for j in nv + 1:
			var v := float(j) / float(nv)
			var p := row[j]
			var n := _fd_normal(f, u, v)
			if n.length_squared() < 1e-10:
				n = _fd_normal(f, clampf(u + (0.01 if u < 0.5 else -0.01), 0.0, 1.0), v)
			var out := p - centroid
			if out.length_squared() > 1e-8:
				if n.dot(out) < 0.0:
					n = -n
			elif last_dir != Vector3.ZERO and n.dot(last_dir) < 0.0:
				n = -n
			if n.length_squared() < 1e-10:
				n = out.normalized() if out.length_squared() > 1e-8 else Vector3.UP
			n = n.normalized()
			verts.append(p)
			norms.append(n)
			uvs.append(uvf.call(u, v))
		last_dir = (row[0] - centroid).normalized()
	for i in nu:
		for j in nv:
			var a := i * cols + j
			var b := a + 1
			var c := a + cols
			var d := c + 1
			_tri(verts, norms, idx, a, c, b)
			_tri(verts, norms, idx, b, c, d)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


static func _tri(verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array, a: int, b: int, c: int) -> void:
	var pa := verts[a]
	var pb := verts[b]
	var pc := verts[c]
	var face := (pc - pa).cross(pb - pa)
	if face.length_squared() < 1e-12:
		return
	var nsum := norms[a] + norms[b] + norms[c]
	# Godot treats clockwise triangles as front-facing.
	if face.dot(nsum) >= 0.0:
		idx.append(a)
		idx.append(b)
		idx.append(c)
	else:
		idx.append(a)
		idx.append(c)
		idx.append(b)


static func _fd_normal(f: Callable, u: float, v: float) -> Vector3:
	var e := 0.0015
	var u0 := clampf(u - e, 0.0, 1.0)
	var u1 := clampf(u + e, 0.0, 1.0)
	var pu: Vector3 = f.call(u1, v) - f.call(u0, v)
	var pv: Vector3 = f.call(u, fposmod(v + e, 1.0)) - f.call(u, fposmod(v - e, 1.0))
	return pu.cross(pv)


static func add_to(mesh: ArrayMesh, arrays: Array, material: Material) -> void:
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


## Symmetric hydrofoil half-thickness (NACA 00xx family), x in [0, 1].
static func foil(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 5.0 * (0.2969 * sqrt(x) - 0.126 * x - 0.3516 * x * x + 0.2843 * x * x * x - 0.1036 * x * x * x * x)


## Cosine-spaced chord position around a closed section loop.
## Returns Vector2(x along chord 0..1, side -1/+1).
static func section(v: float) -> Vector2:
	if v < 0.5:
		var w := v / 0.5
		return Vector2(0.5 - 0.5 * cos(PI * w), 1.0)
	var w2 := (v - 0.5) / 0.5
	return Vector2(0.5 + 0.5 * cos(PI * w2), -1.0)
