"""Watchstanders for the control room plates: posed realistic base meshes.

Bodies: "Human Base Meshes" bundle (Blender Foundation / Blender Studio,
realistic bodies by Dan Ulrich, CC0). Each figure gets a simple skeleton with
Blender's automatic weights, is posed at its station from a few joint targets,
and is dressed by body region (coverall, boots, cap or hair, skin) with a
cloth offset, collar, cuffs and a watch-cap brim so it reads as a person in
working clothes rather than a mannequin.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

BUNDLE = None
COLL = None
MAT = {}
_SRC = {}

# Rest-pose joints of the two base meshes (metres, facing -Y, +X = the figure's left).
JOINTS = {
    "male": {
        "root": (0, 0.01, 0.93), "spine": (0, 0.03, 1.06), "chest": (0, 0.02, 1.25), "neck": (0, 0.0, 1.43),
        "head": (0, -0.02, 1.51), "top": (0, -0.03, 1.68),
        "clav": (0.03, 0.0, 1.40), "shoulder": (0.175, 0.01, 1.34), "elbow": (0.287, 0.03, 1.07),
        "wrist": (0.372, 0.01, 0.87), "hand": (0.42, 0.0, 0.71),
        "hip": (0.095, 0.0, 0.88), "knee": (0.132, -0.01, 0.48), "ankle": (0.168, 0.05, 0.085), "toe": (0.19, -0.11, 0.02),
        "neckline": 1.425, "boot": 0.16, "head_c": (0, -0.03, 1.57), "neck_r": 0.068, "wrist_r": 0.04, "belt": (1.015, 1.055),
    },
    "female": {
        "root": (0, 0.01, 0.89), "spine": (0, 0.03, 1.02), "chest": (0, 0.02, 1.2), "neck": (0, 0.0, 1.38),
        "head": (0, -0.02, 1.46), "top": (0, -0.04, 1.64),
        "clav": (0.03, 0.0, 1.36), "shoulder": (0.165, 0.01, 1.3), "elbow": (0.248, 0.03, 1.04),
        "wrist": (0.33, 0.01, 0.855), "hand": (0.405, 0.0, 0.71),
        "hip": (0.09, 0.0, 0.85), "knee": (0.105, -0.01, 0.47), "ankle": (0.125, 0.04, 0.08), "toe": (0.14, -0.11, 0.02),
        "neckline": 1.385, "boot": 0.15, "head_c": (0, -0.035, 1.53), "neck_r": 0.06, "wrist_r": 0.035, "belt": (0.985, 1.02),
    },
}
for _k in JOINTS.values():
    _w, _h = Vector(_k["wrist"]), Vector(_k["hand"])
    _k["knuckle"] = tuple(_w.lerp(_h, 0.52))

# Bones: name, head joint, tail joint, parent.
BONES = [
    ("hips", "root", "spine", None), ("spine", "spine", "chest", "hips"), ("chest", "chest", "neck", "spine"),
    ("neck", "neck", "head", "chest"), ("head", "head", "top", "neck"),
]
for _s in ("L", "R"):
    BONES += [
        ("clav." + _s, "clav", "shoulder", "chest"), ("upper." + _s, "shoulder", "elbow", "clav." + _s),
        ("fore." + _s, "elbow", "wrist", "upper." + _s), ("hand." + _s, "wrist", "knuckle", "fore." + _s),
        ("fingers." + _s, "knuckle", "hand", "hand." + _s),
        ("thigh." + _s, "hip", "knee", "hips"), ("shin." + _s, "knee", "ankle", "thigh." + _s), ("foot." + _s, "ankle", "toe", "shin." + _s),
    ]
OFFSET_CHILDREN = ("clav", "thigh")


def _joint(kind, name, side):
    j = Vector(JOINTS[kind][name])
    if side == "R":
        j.x = -j.x
    return j


# Poses: joint targets in the figure's frame (facing -Y, origin on the deck under the seat).
# Only directions are taken from these; bone lengths stay those of the body.
# "palm" is the direction the palms should face; "curl" bends the fingers (radians).
SEATED_DESK = {  # seated at a console, forearms on the desk edge, hands at the keyboard
    "root": (0, 0.05, 0.64), "spine": (0, 0.03, 0.77), "chest": (0, -0.03, 0.95), "neck": (0, -0.1, 1.11),
    "head": (0, -0.15, 1.18), "top": (0, -0.2, 1.34),
    "clav": (0.03, -0.08, 1.08), "shoulder": (0.18, -0.08, 1.04), "elbow": (0.24, -0.2, 0.8),
    "wrist": (0.17, -0.45, 0.8), "hand": (0.13, -0.62, 0.78), "palm": (0.15, 0, -1), "curl": 0.7,
    "hip": (0.1, 0.03, 0.6), "knee": (0.13, -0.38, 0.55), "ankle": (0.16, -0.36, 0.09), "toe": (0.18, -0.52, 0.03),
}
SEATED_DESK_R = dict(SEATED_DESK)  # right hand on the trackball, left resting on the desk
SEATED_DESK_R.update({"elbow.R": (-0.25, -0.17, 0.82), "wrist.R": (-0.2, -0.43, 0.8), "hand.R": (-0.2, -0.6, 0.79),
                      "elbow.L": (0.27, -0.14, 0.83), "wrist.L": (0.2, -0.4, 0.81), "hand.L": (0.12, -0.53, 0.8),
                      "knee.L": (0.17, -0.37, 0.55), "ankle.L": (0.22, -0.3, 0.09), "toe.L": (0.26, -0.45, 0.03)})
SEATED_YOKE = {  # seated at ship control, hands on the yoke grips
    "root": (0, 0.06, 0.64), "spine": (0, 0.05, 0.77), "chest": (0, 0.01, 0.95), "neck": (0, -0.04, 1.12),
    "head": (0, -0.07, 1.19), "top": (0, -0.1, 1.36),
    "clav": (0.03, -0.03, 1.09), "shoulder": (0.18, -0.03, 1.05), "elbow": (0.24, -0.2, 0.86),
    "wrist": (0.16, -0.44, 0.94), "hand": (0.13, -0.58, 0.97), "palm": (-0.8, 0, -0.6), "curl": 1.3,
    "hip": (0.1, 0.03, 0.6), "knee": (0.14, -0.38, 0.55), "ankle": (0.15, -0.42, 0.09), "toe": (0.16, -0.58, 0.03),
}
STAND_WATCH = {  # standing watch, hands clasped behind the back, looking up at a monitor
    "root": (0, 0.0, 0.93), "spine": (0, 0.01, 1.06), "chest": (0, 0.0, 1.25), "neck": (0, -0.01, 1.43),
    "head": (0, -0.02, 1.51), "top": (0, 0.03, 1.67),
    "clav": (0.03, 0.0, 1.40), "shoulder": (0.175, 0.02, 1.34), "elbow": (0.21, 0.12, 1.1),
    "wrist": (0.09, 0.17, 0.97), "hand": (0.0, 0.17, 0.93), "palm": (0, 1, 0), "curl": 0.9,
    "hip": (0.1, 0.0, 0.88), "knee": (0.115, -0.01, 0.48), "ankle": (0.14, 0.03, 0.085), "toe": (0.17, -0.13, 0.02),
}
STAND_LEAN = {  # standing at a table, weight on the hands
    "root": (0, 0.1, 0.93), "spine": (0, 0.07, 1.06), "chest": (0, -0.0, 1.24), "neck": (0, -0.1, 1.4),
    "head": (0, -0.14, 1.47), "top": (0, -0.22, 1.63),
    "clav": (0.03, -0.08, 1.37), "shoulder": (0.18, -0.08, 1.33), "elbow": (0.25, -0.2, 1.1),
    "wrist": (0.24, -0.32, 0.95), "hand": (0.24, -0.5, 0.93), "palm": (0, 0, -1), "curl": 0.25,
    "hip": (0.1, 0.1, 0.88), "knee": (0.11, 0.07, 0.48), "ankle": (0.13, 0.1, 0.085), "toe": (0.15, -0.06, 0.02),
}


def init(bundle_path, coll, mats):
    global BUNDLE, COLL
    BUNDLE, COLL = bundle_path, coll
    MAT.update(mats)


def _source(kind):
    if kind not in _SRC:
        name = "GEO-body_%s_realistic" % kind
        with bpy.data.libraries.load(BUNDLE, link=False) as (src, dst):
            dst.objects = [name, name + ".eye.L", name + ".eye.R"]
        _SRC[kind] = dst.objects
    return _SRC[kind]


def _target(pose, name, side):
    key = name + "." + side if side else name
    if key in pose:
        return Vector(pose[key])
    if name == "knuckle":
        return _target(pose, "wrist", side).lerp(_target(pose, "hand", side), 0.52)
    j = Vector(pose[name])
    if side == "R":
        j.x = -j.x
    return j


def _hand_frame(kind, side):
    w, t = _joint(kind, "wrist", side), _joint(kind, "hand", side)
    axis = (t - w).normalized()
    spread = axis.cross(Vector((1, 0, 0))).normalized()
    palm = spread.cross(axis).normalized()
    if palm.x * (1 if side == "L" else -1) > 0:  # the palm faces the body in the A-pose
        palm = -palm
    return w, t, axis, spread, palm


def _region(kind, co, cap, long_hair):
    """Material slot for a rest-pose vertex: 0 coverall, 1 skin, 2 boots, 3 cap/hair, 4 belt."""
    J = JOINTS[kind]
    hc = Vector(J["head_c"])
    if co.z < J["boot"]:
        return 2
    if co.z > J["neckline"]:
        dy = co.y - hc.y
        if cap:
            lim = hc.z + 0.02 - 0.45 * dy
        else:
            lim = hc.z + 0.03 - 0.55 * dy - (0.1 if long_hair else 0.03) * max(0.0, dy / 0.1)
        return 3 if co.z > lim else 1
    if abs(co.x) > 0.2:
        side = "L" if co.x > 0 else "R"
        e, w = _joint(kind, "elbow", side), _joint(kind, "wrist", side)
        ax = w - e
        t = (co - e).dot(ax.normalized())
        perp = ((co - e) - ax.normalized() * t).length
        if ax.length - 0.012 < t < ax.length + 0.24 and perp < 0.11:
            return 1
    if J["belt"][0] < co.z < J["belt"][1]:
        return 4
    return 0


def _tidy_hands(kind, me, reg):
    """Bring the A-pose's splayed fingers together (relaxed hand)."""
    for side in ("L", "R"):
        w, t, axis, spread, palm = _hand_frame(kind, side)
        L = (t - w).length
        idx = [i for i, v in enumerate(me.vertices) if reg[i] == 1 and (v.co.x > 0) == (side == "L") and (v.co - w).dot(axis) > -0.02 and v.co.z < w.z + 0.03]
        if not idx:
            continue
        mid = [me.vertices[i].co for i in idx if 0.25 < (me.vertices[i].co - w).dot(axis) / L < 0.5]
        sc = sum((c - w).dot(spread) for c in mid) / max(len(mid), 1)
        pc = sum((c - w).dot(palm) for c in mid) / max(len(mid), 1)
        for i in idx:
            co = me.vertices[i].co
            tt = (co - w).dot(axis) / L
            k = min(max((tt - 0.3) / 0.35, 0.0), 1.0)
            if k <= 0:
                continue
            s = (co - w).dot(spread)
            p = (co - w).dot(palm)
            co -= spread * (s - sc) * 0.5 * k
            co -= palm * (p - pc) * 0.25 * k


def _pose(rig, arm, kind, pose):
    vl = bpy.context.view_layer
    rest = {bn: (Vector(arm.bones[bn].head_local), Vector(arm.bones[bn].tail_local)) for bn, *_ in BONES}
    newpos, rots = {}, {}
    for bn, h, t, par in BONES:
        side = bn.split(".")[1] if "." in bn else None
        rh, rt = rest[bn]
        rd = (rt - rh).normalized()
        if par is None:
            head = _target(pose, h, side)
        elif bn.split(".")[0] in OFFSET_CHILDREN:
            head = newpos[par][0] + rots[par] @ (rh - rest[par][0])
        else:
            head = newpos[par][1]
        if bn.startswith("fingers."):
            _, _, axis, spread, palm = _hand_frame(kind, side)
            c = float(pose.get("curl." + side, pose.get("curl", 0.5)))
            d = rots["hand." + side] @ (rd * math.cos(c) + palm * math.sin(c)).normalized()
        else:
            d = (_target(pose, t, side) - _target(pose, h, side)).normalized()
        q = rd.rotation_difference(d).to_matrix()
        if bn.startswith("hand.") and ("palm" in pose or "palm." + side in pose):
            _, _, axis, spread, palm = _hand_frame(kind, side)
            if "palm." + side in pose:
                want = Vector(pose["palm." + side])
            else:
                want = Vector(pose["palm"])
                if side == "R":
                    want.x = -want.x
            a = q @ palm
            a = (a - d * a.dot(d)).normalized()
            b = (want - d * want.dot(d)).normalized()
            ang = a.angle(b, 0.0)
            sign = 1.0 if d.dot(a.cross(b)) > 0 else -1.0
            q = Matrix.Rotation(sign * ang, 3, d) @ q
        rots[bn] = q
        newpos[bn] = (head, head + d * (rt - rh).length)
    for bn, *_ in BONES:
        pb = rig.pose.bones[bn]
        m = (rots[bn] @ arm.bones[bn].matrix_local.to_3x3()).to_4x4()
        m.translation = newpos[bn][0]
        pb.matrix = m
        vl.update()
    return newpos, rots


def figure(name, kind, pose, loc, yaw, cap=True, headset=False, hair=(0.08, 0.06, 0.045, 1), bun=False, scale=1.0,
           coverall=(0.045, 0.055, 0.075, 1)):
    body_src, eye_l, eye_r = _source(kind)
    body = body_src.copy()
    body.data = body_src.data.copy()
    body.name = name
    body.location = (0, 0, 0)
    body.rotation_euler = (0, 0, 0)
    body.scale = (1, 1, 1)
    for m in list(body.modifiers):
        if m.type == "MULTIRES":
            body.modifiers.remove(m)
    COLL.objects.link(body)
    me = body.data
    me.materials.clear()
    cover = MAT["coverall_fn"](name, coverall)
    headm = MAT["ballcap"] if cap == "ball" else (MAT["cap"] if cap else MAT["hair_fn"](name, hair))
    for mm in (cover, MAT["skin"], MAT["boots"], headm, MAT["belt"]):
        me.materials.append(mm)
    J = JOINTS[kind]
    reg = [_region(kind, v.co, cap, bun) for v in me.vertices]
    _tidy_hands(kind, me, reg)
    groups = {g: body.vertex_groups.new(name=g) for g in ("cloth", "boots", "headwear")}
    for i, r in enumerate(reg):
        if r in (0, 4):
            groups["cloth"].add([i], 1.0, "REPLACE")
        elif r == 2:
            groups["boots"].add([i], 1.0, "REPLACE")
        elif r == 3:
            # Feather the hairline: thin at the edge, full a couple of centimetres in.
            co = me.vertices[i].co
            hc = Vector(J["head_c"])
            dy = co.y - hc.y
            lim = hc.z + (0.02 - 0.45 * dy if cap else 0.03 - 0.55 * dy - (0.1 if bun else 0.03) * max(0.0, dy / 0.1))
            groups["headwear"].add([i], min(max((co.z - lim) / 0.025, 0.15), 1.0), "REPLACE")
    for p in me.polygons:
        rs = [reg[i] for i in p.vertices]
        p.material_index = max(set(rs), key=rs.count)
        p.use_smooth = True
    # Rig with automatic weights.
    arm = bpy.data.armatures.new(name + "_rig")
    rig = bpy.data.objects.new(name + "_rig", arm)
    COLL.objects.link(rig)
    vl = bpy.context.view_layer
    for o in vl.objects:
        o.select_set(False)
    vl.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for bn, h, t, par in BONES:
        side = bn.split(".")[1] if "." in bn else None
        eb = arm.edit_bones.new(bn)
        eb.head = _joint(kind, h, side)
        eb.tail = _joint(kind, t, side)
        if par:
            eb.parent = arm.edit_bones[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    body.select_set(True)
    rig.select_set(True)
    vl.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    am = [m for m in body.modifiers if m.type == "ARMATURE"][0]
    body.modifiers.move(body.modifiers.find(am.name), 0)
    # Clothing: smooth the anatomy away and offset the cloth; boots lose their toes.
    for grp, fac, it, off in (("cloth", 0.9, 14, 0.02), ("boots", 1.0, 30, 0.014), ("headwear", 0.3, 3, 0.016 if cap else 0.008)):
        sm = body.modifiers.new(grp + "_smooth", "SMOOTH")
        sm.vertex_group = grp
        sm.factor = fac
        sm.iterations = it
        dp = body.modifiers.new(grp + "_offset", "DISPLACE")
        dp.vertex_group = grp
        dp.strength = off
        dp.mid_level = 0.0
    sub = body.modifiers.new("sub", "SUBSURF")
    sub.levels = 0
    sub.render_levels = 2
    newpos, rots = _pose(rig, arm, kind, pose)
    # Head-attached pieces follow the head bone.
    hb = rig.pose.bones["head"]
    delta = hb.matrix @ arm.bones["head"].matrix_local.inverted()
    attach = []
    for e in (eye_l, eye_r):
        eo = e.copy()
        eo.data = e.data.copy()
        local = e.matrix_parent_inverse @ e.matrix_basis
        eo.parent = None
        eo.data.materials.clear()
        eo.data.materials.append(MAT["eye"])
        COLL.objects.link(eo)
        eo.name = name + "_eye"
        eo.matrix_world = delta @ local
        attach.append(eo)
    hc = Vector(J["head_c"])
    if cap == "ball":
        attach.append(_visor(name + "_visor", delta, hc, headm))
        band = _torus(name + "_capband", 0.091 if kind == "male" else 0.087, 0.006, headm)
        band.matrix_world = delta @ Matrix.Translation(hc + Vector((0, 0.008, 0.022))) @ Matrix.Rotation(-0.42, 4, "X") @ Matrix.Diagonal((1.0, 1.22, 1.0, 1.0))
        attach.append(band)
    elif cap:
        # Folded brim of the watch cap, along the cap's lower edge (lower at the back).
        brim = _torus(name + "_brim", 0.088 if kind == "male" else 0.084, 0.016, MAT["cap"])
        brim.matrix_world = delta @ Matrix.Translation(hc + Vector((0, 0.008, 0.024))) @ Matrix.Rotation(-0.42, 4, "X") @ Matrix.Diagonal((1.0, 1.2, 1.0, 1.0))
        attach.append(brim)
    if headset:
        attach += _headset(name, delta, hc)
    if bun:
        b = bpy.data.objects.new(name + "_bun", _sphere_mesh(name + "_bun", 0.04))
        COLL.objects.link(b)
        b.data.materials.append(headm)
        b.matrix_world = delta @ Matrix.Translation(hc + Vector((0, 0.105, -0.03))) @ Matrix.Diagonal((1.0, 0.8, 0.85, 1.0))
        attach.append(b)
    # Collar and cuffs hide the cloth / skin boundary.
    nb = rots["neck"]
    collar = _shell(name + "_collar", J["neck_r"] + 0.012, J["neck_r"] + 0.004, 0.05, cover)
    m = nb.to_4x4()
    m.translation = newpos["neck"][0] + nb @ Vector((0, 0.005, 0.0))
    collar.matrix_world = m @ Matrix.Diagonal((1.05, 1.15, 1.0, 1.0))
    attach.append(collar)
    for side in ("L", "R"):
        fb = "fore." + side
        d = (newpos[fb][1] - newpos[fb][0]).normalized()
        cuff = _shell(name + "_cuff" + side, J["wrist_r"] + 0.008, J["wrist_r"] + 0.004, 0.05, cover)
        m = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        m.translation = newpos[fb][1] - d * 0.03
        cuff.matrix_world = m @ Matrix.Diagonal((1.0, 1.25, 1.0, 1.0))
        attach.append(cuff)
    for a in attach:
        mw = a.matrix_world.copy()
        a.parent = rig
        a.matrix_parent_inverse = Matrix.Identity(4)
        a.matrix_world = mw
    rig.scale = (scale, scale, scale)
    rig.location = loc
    rig.rotation_euler = (0, 0, yaw)
    vl.update()
    return rig


def _link(name, me, mat):
    o = bpy.data.objects.new(name, me)
    COLL.objects.link(o)
    me.materials.append(mat)
    return o


def _sphere_mesh(name, r):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    return me


def _torus(name, R, r, mat):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    seg, ring = 36, 10
    verts = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        row = []
        for j in range(ring):
            b = 2 * math.pi * j / ring
            rr = R + r * math.cos(b)
            row.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), r * math.sin(b))))
        verts.append(row)
    for i in range(seg):
        for j in range(ring):
            bm.faces.new((verts[i][j], verts[(i + 1) % seg][j], verts[(i + 1) % seg][(j + 1) % ring], verts[i][(j + 1) % ring]))
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    return _link(name, me, mat)


def _shell(name, r_out, r_in, h, mat):
    """Short open tube along local Z (collar / cuff)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    seg = 28
    rings = []
    for (r, z) in ((r_in, -h / 2), (r_out, -h / 2), (r_out * 1.02, h / 2), (r_in * 1.02, h / 2)):
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)])
    for k in range(4):
        a, b = rings[k], rings[(k + 1) % 4]
        for i in range(seg):
            bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    o = _link(name, me, mat)
    o.modifiers.new("sub", "SUBSURF").render_levels = 1
    return o


def _cyl_mesh(name, r, h):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=r, radius2=r, depth=h)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = len(p.vertices) == 4
    return me


def _visor(name, delta, hc, mat):
    """Peak of a ball cap: a curved half-ellipse at the front of the crown, sloping slightly down."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rows = []
    n = 14
    for i in range(n + 1):
        a = math.radians(-78 + 156 * i / n)
        ca = math.cos(a)
        inner = Vector((0.088 * math.sin(a), -0.103 * ca, 0.0))
        out = Vector((0.45 * math.sin(a), -ca, 0.0)).normalized()
        L = 0.072 * max(ca, 0.0) ** 0.6
        outer = inner + out * L + Vector((0, 0, -0.014 * ca))
        rows.append([bm.verts.new(inner.lerp(outer, t) + Vector((0, 0, -0.006 * math.sin(math.pi * t)))) for t in (0.0, 0.5, 1.0)])
    for i in range(n):
        for j in range(2):
            bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    o = _link(name, me, mat)
    so = o.modifiers.new("thick", "SOLIDIFY")
    so.thickness = 0.005
    o.modifiers.new("sub", "SUBSURF").render_levels = 1
    o.matrix_world = delta @ Matrix.Translation(hc + Vector((0, 0.0, 0.052))) @ Matrix.Rotation(-0.12, 4, "X")
    return o


def _headset(name, delta, hc):
    out = []
    blk = MAT["black"]
    band = _torus(name + "_band", 0.1, 0.0065, blk)
    band.matrix_world = delta @ Matrix.Translation(hc + Vector((0, 0.0, 0.004))) @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Diagonal((1.12, 1.0, 1.0, 1.0))
    out.append(band)
    for side in (-1, 1):
        cup = _link(name + "_cup%d" % side, _cyl_mesh(name + "_cupm%d" % side, 0.036, 0.028), blk)
        cup.matrix_world = delta @ Matrix.Translation(hc + Vector((side * 0.09, 0.008, -0.012))) @ Matrix.Rotation(math.pi / 2, 4, "Y")
        bev = cup.modifiers.new("bev", "BEVEL")
        bev.width = 0.008
        bev.segments = 3
        out.append(cup)
    mic = _link(name + "_mic", _cyl_mesh(name + "_micm", 0.0035, 0.12), blk)
    mic.matrix_world = delta @ Matrix.Translation(hc + Vector((0.088, -0.06, -0.045))) @ Matrix.Rotation(1.25, 4, "X") @ Matrix.Rotation(0.3, 4, "Y")
    out.append(mic)
    return out
