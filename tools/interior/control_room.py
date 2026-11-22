"""Control room (Mission 004C visual pilot): modelled and path-traced in Blender.

Run with Blender's Python module (pip install bpy==5.3.0):
  python control_room.py --out <dir> --tex <textures dir> --screens <dir>
         [--quality preview|final] [--views command,wide,sonar,nav] [--light normal,red]

Outputs per view: <view>_<light>.jpg (background plate), <view>_maskA.png /
<view>_maskB.png (where each live display is visible), and views.json with the
projected grids of live displays, indicator lamps and hotspots. The game
composites live displays and small animated details over the plates.

Units are metres. X = athwartships (starboard +), Y = fore-aft (forward +),
Z = up. Deck at Z = 0.
"""
import argparse
import json
import math
import os
import random
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--tex", required=True)
ap.add_argument("--screens", required=True)
ap.add_argument("--quality", default="preview")
ap.add_argument("--views", default="command,wide,sonar,nav")
ap.add_argument("--light", default="normal,red")
ap.add_argument("--res", default="")
ap.add_argument("--nomask", action="store_true")
args = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
os.makedirs(args.out, exist_ok=True)
rnd = random.Random(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
FONT_B = bpy.data.fonts.load("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
FONT_M = bpy.data.fonts.load("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf")

HULL_R = 3.3
AXIS_Z = 1.25
DECKHEAD = 2.35
Y0, Y1 = -4.0, 4.0


def hull_half_width(z):
    return math.sqrt(max(HULL_R ** 2 - (z - AXIS_Z) ** 2, 0.0))


# --------------------------------------------------------------------------- #
# Materials
# --------------------------------------------------------------------------- #

def _socket(node, name, typ, out=False):
    socks = node.outputs if out else node.inputs
    for s in socks:
        if s.name == name and s.type == typ and s.enabled:
            return s
    for s in socks:
        if s.name == name and s.type == typ:
            return s
    raise KeyError(name)


def _mix(nt, a, b, fac, blend="MIX"):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    if isinstance(fac, float):
        m.inputs[0].default_value = fac
    else:
        nt.links.new(fac, m.inputs[0])
    for sock, val in ((_socket(m, "A", "RGBA"), a), (_socket(m, "B", "RGBA"), b)):
        if isinstance(val, tuple):
            sock.default_value = val
        else:
            nt.links.new(val, sock)
    return _socket(m, "Result", "RGBA", out=True)


MATS = {}


def paint(name, color, rough=0.5, metallic=0.0, var=0.08, grime=0.35, scale=6.0, coat=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    bsdf = n["Principled BSDF"]
    tc = n.new("ShaderNodeTexCoord")
    noise = n.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 8.0
    l.new(tc.outputs["Object"], noise.inputs["Vector"])
    ramp = n.new("ShaderNodeMapRange")
    ramp.inputs["To Min"].default_value = 1.0 - var
    ramp.inputs["To Max"].default_value = 1.0 + var * 0.5
    l.new(noise.outputs["Fac"], ramp.inputs["Value"])
    # multiply base colour by the variation factor
    mul = n.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    _socket(mul, "A", "RGBA").default_value = color
    comb = n.new("ShaderNodeCombineColor")
    l.new(ramp.outputs["Result"], comb.inputs[0])
    l.new(ramp.outputs["Result"], comb.inputs[1])
    l.new(ramp.outputs["Result"], comb.inputs[2])
    l.new(comb.outputs["Color"], _socket(mul, "B", "RGBA"))
    base = _socket(mul, "Result", "RGBA", out=True)
    if grime > 0.0:
        ao = n.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.12
        inv = n.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        l.new(ao.outputs["AO"], inv.inputs[1])
        fac = n.new("ShaderNodeMath")
        fac.operation = "MULTIPLY"
        fac.inputs[1].default_value = grime
        l.new(inv.outputs[0], fac.inputs[0])
        dark = (color[0] * 0.35, color[1] * 0.33, color[2] * 0.3, 1.0)
        base = _mix(nt, base, dark, fac.outputs[0])
    l.new(base, bsdf.inputs["Base Color"])
    rn = n.new("ShaderNodeTexNoise")
    rn.inputs["Scale"].default_value = scale * 3.0
    l.new(tc.outputs["Object"], rn.inputs["Vector"])
    rr = n.new("ShaderNodeMapRange")
    rr.inputs["To Min"].default_value = max(rough - 0.12, 0.02)
    rr.inputs["To Max"].default_value = min(rough + 0.12, 1.0)
    l.new(rn.outputs["Fac"], rr.inputs["Value"])
    l.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = metallic
    if coat > 0.0:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.08
    MATS[name] = m
    return m


def textured(name, tex_color, tex_normal, tex_rough, tint, uv_scale=1.0, normal_strength=0.8, rough_scale=1.0, metallic=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    bsdf = n["Principled BSDF"]
    tc = n.new("ShaderNodeTexCoord")
    mp = n.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (uv_scale, uv_scale, uv_scale)
    l.new(tc.outputs["Object"], mp.inputs["Vector"])

    def img(path, noncolor):
        t = n.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(path)
        if noncolor:
            t.image.colorspace_settings.name = "Non-Color"
        t.projection = "BOX"
        t.projection_blend = 0.3
        l.new(mp.outputs["Vector"], t.inputs["Vector"])
        return t

    if tex_color:
        c = img(tex_color, False)
        hsv = n.new("ShaderNodeHueSaturation")
        hsv.inputs["Saturation"].default_value = 0.15
        l.new(c.outputs["Color"], hsv.inputs["Color"])
        tinted = _mix(nt, hsv.outputs["Color"], tint, 1.0, "MULTIPLY")
        l.new(tinted, bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = tint
    if tex_normal:
        t = img(tex_normal, True)
        nm = n.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = normal_strength
        l.new(t.outputs["Color"], nm.inputs["Color"])
        l.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if tex_rough:
        t = img(tex_rough, True)
        mr = n.new("ShaderNodeMath")
        mr.operation = "MULTIPLY"
        mr.inputs[1].default_value = rough_scale
        l.new(t.outputs["Color"], mr.inputs[0])
        l.new(mr.outputs[0], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = metallic
    MATS[name] = m
    return m


def panels(name, color, rough=0.62):
    """Painted insulation panels: brick-pattern seams and fasteners."""
    m = paint(name, color, rough, grime=0.45, scale=3.0)
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    bsdf = n["Principled BSDF"]
    tc = n.new("ShaderNodeTexCoord")
    br = n.new("ShaderNodeTexBrick")
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.006
    br.inputs["Brick Width"].default_value = 1.2
    br.inputs["Row Height"].default_value = 0.6
    br.offset = 0.0
    br.inputs["Color1"].default_value = (1, 1, 1, 1)
    br.inputs["Color2"].default_value = (0.92, 0.93, 0.92, 1)
    br.inputs["Mortar"].default_value = (0.25, 0.25, 0.25, 1)
    mp = n.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (math.pi / 2, 0, 0)
    l.new(tc.outputs["Object"], mp.inputs["Vector"])
    l.new(mp.outputs["Vector"], br.inputs["Vector"])
    old = bsdf.inputs["Base Color"].links[0].from_socket
    mixed = _mix(nt, old, br.outputs["Color"], 1.0, "MULTIPLY")
    l.new(mixed, bsdf.inputs["Base Color"])
    bump = n.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    l.new(br.outputs["Fac"], bump.inputs["Height"])
    l.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def emissive(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    b.inputs["Emission Color"].default_value = color
    b.inputs["Emission Strength"].default_value = strength
    b.inputs["Roughness"].default_value = 0.3
    return m


SCREEN_MATS = []


def screen_mat(name, image_path, strength=1.6, tint=(1, 1, 1, 1)):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    b = n["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.005, 0.006, 0.007, 1)
    b.inputs["Roughness"].default_value = 0.08
    b.inputs["Coat Weight"].default_value = 0.6
    b.inputs["Coat Roughness"].default_value = 0.04
    t = n.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(image_path)
    uv = n.new("ShaderNodeTexCoord")
    l.new(uv.outputs["UV"], t.inputs["Vector"])
    col = _mix(nt, t.outputs["Color"], tint, 1.0, "MULTIPLY")
    l.new(col, b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = strength
    m["base_strength"] = strength
    SCREEN_MATS.append(m)
    return m


TEX = args.tex
M = {
    "hull": panels("hull_insulation", (0.5, 0.55, 0.51, 1)),
    "frame": paint("frames", (0.5, 0.53, 0.5, 1), 0.55, grime=0.5),
    "deckhead": paint("deckhead", (0.58, 0.6, 0.57, 1), 0.65, grime=0.55, scale=2.0),
    "console": paint("console_grey", (0.1, 0.115, 0.13, 1), 0.38, grime=0.3, scale=10.0),
    "console_lt": paint("console_light", (0.24, 0.27, 0.28, 1), 0.42, grime=0.35, scale=10.0),
    "scope": paint("scope_dark", (0.11, 0.12, 0.12, 1), 0.4, grime=0.3, scale=12.0),
    "panel": paint("panel_green", (0.33, 0.38, 0.35, 1), 0.5, grime=0.4, scale=8.0),
    "black": paint("black_plastic", (0.025, 0.027, 0.03, 1), 0.38, grime=0.15, scale=20.0),
    "rubber_blk": paint("rubber_black", (0.02, 0.02, 0.02, 1), 0.75, grime=0.0),
    "steel": paint("steel", (0.62, 0.63, 0.64, 1), 0.28, metallic=1.0, grime=0.25, scale=14.0),
    "chrome": paint("chrome", (0.8, 0.8, 0.8, 1), 0.12, metallic=1.0, grime=0.1, scale=20.0),
    "brass": paint("brass", (0.62, 0.48, 0.26, 1), 0.3, metallic=1.0, grime=0.2),
    "red": paint("red_paint", (0.5, 0.05, 0.04, 1), 0.4, grime=0.3),
    "yellow": paint("safety_yellow", (0.7, 0.52, 0.04, 1), 0.5, grime=0.35),
    "white": paint("white_paint", (0.75, 0.76, 0.74, 1), 0.5, grime=0.25),
    "pipe_grey": paint("pipe_grey", (0.42, 0.44, 0.44, 1), 0.45, grime=0.35),
    "pipe_white": paint("pipe_white", (0.7, 0.71, 0.69, 1), 0.45, grime=0.3),
    "band_green": paint("band_green", (0.07, 0.3, 0.12, 1), 0.45, grime=0.1),
    "band_blue": paint("band_blue", (0.06, 0.16, 0.42, 1), 0.45, grime=0.1),
    "band_yellow": paint("band_yellow", (0.7, 0.5, 0.05, 1), 0.45, grime=0.1),
    "band_brown": paint("band_brown", (0.28, 0.14, 0.06, 1), 0.45, grime=0.1),
    "cable": paint("cable", (0.04, 0.045, 0.05, 1), 0.55, grime=0.0, scale=30.0),
    "cable_grey": paint("cable_grey", (0.24, 0.25, 0.26, 1), 0.55, grime=0.0, scale=30.0),
    "glass": emissive("diffuser", (1.0, 0.92, 0.8, 1), 1.6),
    "deck": textured("deck_rubber", os.path.join(TEX, "Rubber004/Rubber004_1K-JPG_Color.jpg"), os.path.join(TEX, "Rubber004/Rubber004_1K-JPG_NormalGL.jpg"), os.path.join(TEX, "Rubber004/Rubber004_1K-JPG_Roughness.jpg"), (0.55, 0.57, 0.56, 1), uv_scale=0.7, normal_strength=0.5),
    "tread": textured("tread_plate", None, os.path.join(TEX, "metal_plate_nor_gl_2k.jpg"), os.path.join(TEX, "metal_plate_rough_2k.jpg"), (0.3, 0.31, 0.31, 1), uv_scale=1.4, normal_strength=1.0, rough_scale=0.8, metallic=0.6),
    "seat": textured("seat_vinyl", None, os.path.join(TEX, "Leather037/Leather037_1K-JPG_NormalGL.jpg"), os.path.join(TEX, "Leather037/Leather037_1K-JPG_Roughness.jpg"), (0.03, 0.035, 0.04, 1), uv_scale=3.0, normal_strength=0.6, rough_scale=0.9),
    "label": paint("label_plate", (0.02, 0.02, 0.02, 1), 0.35, grime=0.0),
    "label_txt": paint("label_text", (0.8, 0.8, 0.76, 1), 0.5, grime=0.0),
    "stencil": paint("stencil", (0.08, 0.09, 0.09, 1), 0.6, grime=0.0),
    "board": paint("board_white", (0.82, 0.83, 0.8, 1), 0.3, grime=0.1),
    "cork": paint("mug", (0.55, 0.58, 0.6, 1), 0.3, grime=0.1),
    "fabric": paint("fabric_navy", (0.03, 0.04, 0.07, 1), 0.85, grime=0.0, scale=40.0),
}

# --------------------------------------------------------------------------- #
# Geometry helpers
# --------------------------------------------------------------------------- #

COLL = bpy.data.collections.new("room")
scene.collection.children.link(COLL)


def _obj(name, mesh, mat):
    o = bpy.data.objects.new(name, mesh)
    COLL.objects.link(o)
    if mat is not None:
        mesh.materials.append(mat)
    return o


def box(name, size, loc, mat, rot=(0, 0, 0), bevel=0.006, segs=2):
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    v = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz), (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(v, [], f)
    me.update()
    o = _obj(name, me, mat)
    o.location = loc
    o.rotation_euler = rot
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = min(bevel, min(size) * 0.45)
        b.segments = segs
        b.limit_method = "ANGLE"
        b.harden_normals = False
    return o


def cyl(name, r, h, loc, mat, rot=(0, 0, 0), verts=32, r2=None, bevel=0.0):
    import bmesh
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=r, radius2=r if r2 is None else r2, depth=h)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = len(p.vertices) == 4
    o = _obj(name, me, mat)
    o.location = loc
    o.rotation_euler = rot
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    return o


def torus(name, R, r, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=40, minor_segments=12, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    for c in o.users_collection:
        c.objects.unlink(o)
    COLL.objects.link(o)
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def tube(name, pts, r, mat, res=8):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
    o = bpy.data.objects.new(name, cu)
    COLL.objects.link(o)
    cu.materials.append(mat)
    return o


def sag(a, b, drop, n=10):
    out = []
    for i in range(n + 1):
        t = i / n
        p = Vector(a).lerp(Vector(b), t)
        p.z -= math.sin(math.pi * t) * drop
        out.append(tuple(p))
    return out


def plane(name, w, h, loc, rot, mat):
    v = [(-w / 2, 0, -h / 2), (w / 2, 0, -h / 2), (w / 2, 0, h / 2), (-w / 2, 0, h / 2)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(v, [], [(0, 1, 2, 3)])
    me.uv_layers.new()
    for i, uvp in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
        me.uv_layers.active.data[i].uv = uvp
    o = _obj(name, me, mat)
    o.location = loc
    o.rotation_euler = rot
    return o


def text(name, body, size, loc, rot, mat, font=FONT_B, align="CENTER"):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.font = font
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.extrude = 0.0004
    o = bpy.data.objects.new(name, cu)
    COLL.objects.link(o)
    cu.materials.append(mat)
    o.location = loc
    o.rotation_euler = rot
    return o


def label(name, body, loc, rot, w=0.16, h=0.035, size=0.018):
    """Engraved black label plate with white text, facing along its local -Y."""
    p = box(name + "_plate", (w, 0.003, h), loc, M["label"], rot, bevel=0.001)
    mw = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[0], 4, "X")
    off = mw @ Vector((0, -0.0025, 0))
    text(name + "_txt", body, size, (loc[0] + off.x, loc[1] + off.y, loc[2] + off.z), (rot[0] + math.pi / 2, 0, rot[2]), M["label_txt"])
    return p


LIVE = {}      # name -> (corners tl,tr,br,bl world)
LEDS = []      # (pos, rgb, pattern)
HOT = {}       # name -> list of world points


def screen(name, w, h, center, yaw, pitch, image, live=False, strength=1.6, bezel=0.03):
    """A display facing direction (yaw, pitch); yaw 0 = facing -Y (towards aft)."""
    rot = (pitch, 0, yaw)
    housing = box(name + "_bezel", (w + bezel * 2, 0.05, h + bezel * 2), center, M["black"], rot, bevel=0.008)
    mw = Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "X")
    fwd = mw @ Vector((0, -1, 0))
    c = Vector(center) + fwd * 0.027
    mat = screen_mat(name + "_scr", os.path.join(args.screens, image + ".png"), strength)
    # Plane: local X right, local Z up, normal -Y.
    p = plane(name, w, h, tuple(c), (pitch, 0, yaw), mat)
    right = mw @ Vector((1, 0, 0))
    up = mw @ Vector((0, 0, 1))
    tl = c - right * w / 2 + up * h / 2
    tr = c + right * w / 2 + up * h / 2
    br = c + right * w / 2 - up * h / 2
    bl = c - right * w / 2 - up * h / 2
    if live:
        LIVE[name] = [tuple(tl), tuple(tr), tuple(br), tuple(bl)]
        p["live"] = True
    return p


# --------------------------------------------------------------------------- #
# Room shell
# --------------------------------------------------------------------------- #

def build_shell():
    import bmesh
    # Pressure hull (inside surface) between deck and deckhead, with frames.
    me = bpy.data.meshes.new("hull")
    bm = bmesh.new()
    segs = 28
    a0 = math.asin((0.0 - AXIS_Z) / HULL_R)
    a1 = math.asin((DECKHEAD - AXIS_Z) / HULL_R)
    for side in (-1, 1):
        rows = []
        for j in range(segs + 1):
            a = a0 + (a1 - a0) * j / segs
            x = side * HULL_R * math.cos(a)
            z = AXIS_Z + HULL_R * math.sin(a)
            rows.append([bm.verts.new((x, Y0 - 0.3, z)), bm.verts.new((x, Y1 + 0.3, z))])
        for j in range(segs):
            f = bm.faces.new([rows[j][0], rows[j][1], rows[j + 1][1], rows[j + 1][0]] if side > 0 else [rows[j][0], rows[j + 1][0], rows[j + 1][1], rows[j][1]])
            f.smooth = True
    bm.to_mesh(me)
    bm.free()
    _obj("hull", me, M["hull"])
    # Insulation panel seams on the hull (thin dark strips) and frames every 0.6 m.
    y = Y0 + 0.2
    while y < Y1:
        for side in (-1, 1):
            pts = []
            for j in range(13):
                a = a0 + (a1 - a0) * j / 12
                pts.append((side * (HULL_R - 0.035) * math.cos(a), y, AXIS_Z + (HULL_R - 0.035) * math.sin(a)))
            o = tube("frame_%d_%d" % (int(y * 10), side), pts, 0.035, M["frame"])
            o.data.bevel_resolution = 0
        y += 0.6
    # Deck, deckhead, bulkheads.
    hw0 = hull_half_width(0.0)
    deck = box("deck", (hw0 * 2 + 0.2, Y1 - Y0 + 0.6, 0.04), (0, 0, -0.02), M["deck"], bevel=0.0)
    hwt = hull_half_width(DECKHEAD)
    box("deckhead", (hwt * 2 + 0.2, Y1 - Y0 + 0.6, 0.04), (0, 0, DECKHEAD + 0.02), M["deckhead"], bevel=0.0)
    for yy, nm in ((Y1, "fwd"), (Y0, "aft")):
        box("bulkhead_" + nm, (hw0 * 2 + 1.0, 0.06, DECKHEAD + 0.2), (0, yy + (0.03 if yy > 0 else -0.03), DECKHEAD / 2), M["hull"], bevel=0.0)
    # Deckhead panel seams.
    for yy in [i * 0.6 - 3.9 for i in range(14)]:
        box("dh_seam_%d" % int(yy * 10), (hwt * 2, 0.012, 0.004), (0, yy, DECKHEAD - 0.002), M["frame"], bevel=0.0)
    # Deck edge trim and tread plates around the periscope stand.
    for side in (-1, 1):
        box("deck_trim_%d" % side, (0.08, Y1 - Y0, 0.05), (side * (hw0 - 0.02), 0, 0.025), M["frame"], bevel=0.004)


# --------------------------------------------------------------------------- #
# Overhead: lights, pipes, cable trays, duct
# --------------------------------------------------------------------------- #

LIGHTS_NORMAL = []
LIGHTS_RED = []
EMIT_NORMAL = []
EMIT_RED = []


def area_light(name, loc, size, energy, color, kind="normal", rot=(0, 0, 0)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.shape = "RECTANGLE"
    ld.size, ld.size_y = size
    ld.energy = energy
    ld.color = color
    o = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    (LIGHTS_NORMAL if kind == "normal" else LIGHTS_RED).append(o)
    return o


def point_light(name, loc, energy, color, radius=0.05, kind="normal"):
    ld = bpy.data.lights.new(name, "POINT")
    ld.energy = energy
    ld.color = color
    ld.shadow_soft_size = radius
    o = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(o)
    o.location = loc
    (LIGHTS_NORMAL if kind == "normal" else LIGHTS_RED).append(o)
    return o


def spot_light(name, loc, rot, energy, color, size_deg=60, blend=0.6, radius=0.05, kind="normal"):
    ld = bpy.data.lights.new(name, "SPOT")
    ld.energy = energy
    ld.color = color
    ld.spot_size = math.radians(size_deg)
    ld.spot_blend = blend
    ld.shadow_soft_size = radius
    o = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    (LIGHTS_NORMAL if kind == "normal" else LIGHTS_RED).append(o)
    return o


def build_overhead():
    # Light fixtures: recessed linear units with diffusers.
    for x in (-1.05, 1.05):
        for y in (-2.6, -0.2, 2.2):
            box("fixture_%d_%d" % (x * 10, y * 10), (0.22, 1.25, 0.05), (x, y, DECKHEAD - 0.03), M["white"], bevel=0.004)
            d = box("diffuser_%d_%d" % (x * 10, y * 10), (0.17, 1.18, 0.01), (x, y, DECKHEAD - 0.058), M["glass"], bevel=0.0)
            EMIT_NORMAL.append(d)
            area_light("lamp_%d_%d" % (x * 10, y * 10), (x, y, DECKHEAD - 0.07), (0.17, 1.18), 15.0, (1.0, 0.88, 0.74))
            # Red night light beside each fixture.
            r = box("redlamp_%d_%d" % (x * 10, y * 10), (0.05, 0.4, 0.02), (x + (-0.2 if x > 0 else -0.2), y, DECKHEAD - 0.02), M["black"], bevel=0.003)
            rg = box("redglass_%d_%d" % (x * 10, y * 10), (0.035, 0.36, 0.006), (x + (-0.2 if x > 0 else -0.2), y, DECKHEAD - 0.033), emissive("red_led_%d_%d" % (x * 10, y * 10), (1.0, 0.05, 0.02, 1), 0.3), bevel=0.0)
            EMIT_RED.append(rg)
            area_light("red_%d_%d" % (x * 10, y * 10), (x - 0.2, y, DECKHEAD - 0.04), (0.035, 0.36), 9.5, (1.0, 0.06, 0.02), kind="red")
    # Pipe runs (fore-aft), with flanges, brackets and colour bands.
    pipes = [(-1.65, 2.22, 0.045, "pipe_white", "band_green"), (-1.5, 2.12, 0.03, "pipe_grey", "band_blue"),
             (-0.55, 2.27, 0.025, "pipe_grey", "band_yellow"), (0.42, 2.25, 0.05, "pipe_white", "band_green"),
             (0.62, 2.18, 0.03, "pipe_grey", "band_brown"), (2.02, 2.2, 0.06, "pipe_white", "band_blue"),
             (2.18, 2.05, 0.025, "pipe_grey", "band_yellow"), (-2.2, 2.0, 0.035, "pipe_grey", "band_green")]
    for i, (x, z, r, m, band) in enumerate(pipes):
        cyl("pipe_%d" % i, r, Y1 - Y0 + 0.4, (x, 0, z), M[m], rot=(math.pi / 2, 0, 0), verts=20)
        y = Y0 + 0.5 + (i % 3) * 0.2
        while y < Y1 - 0.3:
            cyl("flange_%d_%d" % (i, int(y * 10)), r * 1.55, 0.025, (x, y, z), M[m], rot=(math.pi / 2, 0, 0), verts=20, bevel=0.003)
            box("bracket_%d_%d" % (i, int(y * 10)), (0.03, 0.03, DECKHEAD - z), (x, y + 0.08, (DECKHEAD + z) / 2), M["frame"], bevel=0.003)
            y += 1.3
        for by in (-2.9, 0.4, 3.1):
            cyl("band_%d_%d" % (i, int(by * 10)), r * 1.04, 0.07, (x, by + i * 0.05, z), M[band], rot=(math.pi / 2, 0, 0), verts=20)
    # Valves with red handwheels.
    for (x, y, z, r) in [(-1.65, 1.35, 2.22, 0.045), (0.42, -1.9, 2.25, 0.05), (2.02, 2.6, 2.2, 0.06)]:
        cyl("valve_body_%d" % int(y * 10), r * 1.6, 0.16, (x, y, z), M["pipe_grey"], rot=(math.pi / 2, 0, 0), verts=20, bevel=0.004)
        cyl("valve_stem_%d" % int(y * 10), 0.01, 0.18, (x, y, z - 0.12), M["steel"])
        torus("handwheel_%d" % int(y * 10), 0.085, 0.009, (x, y, z - 0.21), M["red"])
        for k in range(3):
            box("spoke_%d_%d" % (int(y * 10), k), (0.17, 0.008, 0.008), (x, y, z - 0.21), M["red"], rot=(0, 0, k * math.pi / 3), bevel=0.0)
    # Cable trays with bundled cables.
    for x in (-2.35, 2.35, 0.0):
        if x == 0.0:
            continue
        box("tray_%d" % int(x * 10), (0.32, Y1 - Y0, 0.012), (x, 0, 2.05), M["frame"], bevel=0.002)
        for side in (-1, 1):
            box("tray_lip_%d_%d" % (int(x * 10), side), (0.012, Y1 - Y0, 0.06), (x + side * 0.16, 0, 2.08), M["frame"], bevel=0.002)
        for k in range(9):
            cx = x - 0.13 + k * 0.032
            col = M["cable"] if k % 3 else M["cable_grey"]
            tube("cable_%d_%d" % (int(x * 10), k), sag((cx, Y0, 2.075), (cx, Y1, 2.075), 0.0, 4), 0.011 + (k % 2) * 0.004, col)
        y = Y0 + 0.4
        while y < Y1:
            box("tray_hanger_%d_%d" % (int(x * 10), int(y * 10)), (0.02, 0.02, DECKHEAD - 2.05), (x, y, (DECKHEAD + 2.05) / 2), M["frame"], bevel=0.0)
            y += 1.1
    # Ventilation duct with diffusers.
    box("duct", (0.36, Y1 - Y0, 0.16), (1.58, 0, DECKHEAD - 0.12), M["pipe_white"], bevel=0.01)
    for y in (-2.0, 0.9, 3.2):
        box("diffuser_v_%d" % int(y * 10), (0.3, 0.3, 0.02), (1.58, y, DECKHEAD - 0.205), M["frame"], bevel=0.004)
        for k in range(6):
            box("slat_%d_%d" % (int(y * 10), k), (0.28, 0.012, 0.012), (1.58, y - 0.12 + k * 0.048, DECKHEAD - 0.218), M["black"], bevel=0.0)
    # Overhead speaker, smoke detectors.
    cyl("speaker", 0.11, 0.06, (-0.4, 1.0, DECKHEAD - 0.04), M["frame"], bevel=0.004)
    cyl("speaker_grille", 0.09, 0.01, (-0.4, 1.0, DECKHEAD - 0.075), M["black"])
    for (x, y) in [(0.2, -3.0), (-0.3, 3.2)]:
        cyl("detector_%d" % int(y * 10), 0.06, 0.035, (x, y, DECKHEAD - 0.02), M["white"], bevel=0.005)
        LEDS.append(((x + 0.03, y, DECKHEAD - 0.04), (1.0, 0.15, 0.1), "slow"))


# --------------------------------------------------------------------------- #
# Stations
# --------------------------------------------------------------------------- #

def chair(name, loc, yaw):
    x, y, _ = loc
    cyl(name + "_base", 0.24, 0.03, (x, y, 0.015), M["steel"], verts=24, bevel=0.005)
    cyl(name + "_post", 0.035, 0.42, (x, y, 0.24), M["chrome"])
    mw = Matrix.Rotation(yaw, 4, "Z")
    back = mw @ Vector((0, -0.24, 0))
    box(name + "_seat", (0.48, 0.46, 0.1), (x, y, 0.5), M["seat"], rot=(0, 0, yaw), bevel=0.03, segs=4)
    box(name + "_back", (0.46, 0.08, 0.55), (x + back.x, y + back.y, 0.84), M["seat"], rot=(-0.12, 0, yaw), bevel=0.03, segs=4)
    for side in (-1, 1):
        s = mw @ Vector((side * 0.26, 0.0, 0))
        box(name + "_arm_%d" % side, (0.05, 0.34, 0.04), (x + s.x, y + s.y, 0.68), M["black"], rot=(0, 0, yaw), bevel=0.012)
    # Lap belt lying on the seat.
    box(name + "_belt", (0.42, 0.04, 0.006), (x, y, 0.555), M["fabric"], rot=(0, 0, yaw + 0.1), bevel=0.0)


def keyboard(name, loc, yaw, w=0.42):
    box(name, (w, 0.15, 0.025), loc, M["black"], rot=(0.08, 0, yaw), bevel=0.006)
    mw = Matrix.Rotation(yaw, 4, "Z")
    for r in range(4):
        for c in range(14):
            p = Vector(loc) + mw @ Vector((-w / 2 + 0.03 + c * (w - 0.06) / 13, -0.05 + r * 0.032, 0.016 + r * 0.0025))
            box("%s_k%d_%d" % (name, r, c), (0.022, 0.022, 0.01), tuple(p), M["console_lt"] if (r + c) % 9 else M["console"], rot=(0.08, 0, yaw), bevel=0.003, segs=1)


def mfc(name, y, image_up, image_low, live=False, title=""):
    """Multi-function console against the starboard hull, facing to port (-X)."""
    x0 = 2.25
    yaw = -math.pi / 2  # facing -X
    box(name + "_cab", (0.75, 0.86, 0.72), (x0 + 0.2, y, 0.36), M["console"], bevel=0.008)
    box(name + "_kick", (0.7, 0.84, 0.06), (x0 + 0.22, y, 0.03), M["black"], bevel=0.004)
    box(name + "_desk", (0.86, 0.9, 0.035), (x0 + 0.12, y, 0.74), M["black"], bevel=0.008)
    box(name + "_upper", (0.42, 0.88, 1.02), (x0 + 0.42, y, 1.25), M["console"], bevel=0.01)
    box(name + "_hood", (0.5, 0.9, 0.06), (x0 + 0.38, y, 1.78), M["console_lt"], rot=(0, -0.25, 0), bevel=0.01)
    pitch_low, pitch_up = -0.35, -0.12
    screen(name + "_lower", 0.52, 0.32, (x0 + 0.2, y, 1.0), yaw, pitch_low, image_low, live=live, strength=2.0)
    screen(name + "_upper_s", 0.52, 0.32, (x0 + 0.24, y, 1.46), yaw, pitch_up, image_up, live=live, strength=2.0)
    spot_light(name + "_task", (x0 + 0.1, y, 1.74), (0, 0.55, 0), 9.0, (1.0, 0.9, 0.78), size_deg=85, blend=0.8, radius=0.04)
    point_light(name + "_task_red", (x0 + 0.0, y, 1.7), 1.2, (1.0, 0.08, 0.03), radius=0.05, kind="red")
    keyboard(name + "_kb", (x0 - 0.12, y - 0.05, 0.77), yaw)
    cyl(name + "_ball", 0.025, 0.02, (x0 - 0.1, y + 0.3, 0.765), M["steel"])
    box(name + "_ballbase", (0.1, 0.1, 0.02), (x0 - 0.1, y + 0.3, 0.755), M["black"], bevel=0.005)
    for k in range(6):
        LEDS.append(((x0 + 0.0, y - 0.38 + k * 0.03, 0.82), (0.3, 1.0, 0.4) if k != 4 else (1.0, 0.7, 0.2), "steady" if k % 3 else "blink"))
        box("%s_led%d" % (name, k), (0.006, 0.012, 0.006), (x0 + 0.0, y - 0.38 + k * 0.03, 0.82), M["black"], bevel=0.0)
    label(name + "_lbl", title, (x0 + 0.02, y, 1.86), (0, 0, yaw), w=0.3, h=0.04, size=0.024)
    # Headset on a hook.
    torus(name + "_headset", 0.075, 0.008, (x0 + 0.05, y + 0.45, 1.25), M["black"], rot=(0, math.pi / 2, 0))
    cyl(name + "_cup", 0.035, 0.03, (x0 + 0.05, y + 0.45, 1.18), M["black"], rot=(0, math.pi / 2, 0))
    chair(name + "_chair", (x0 - 0.62, y, 0), -math.pi / 2)


def ship_control():
    # Console across the forward end; operators face forward (+Y).
    yc = 3.25
    box("sc_cab", (2.7, 0.8, 0.72), (-0.3, yc + 0.15, 0.36), M["console"], bevel=0.01)
    box("sc_desk", (2.75, 0.9, 0.035), (-0.3, yc + 0.05, 0.74), M["black"], bevel=0.008)
    box("sc_upper", (2.7, 0.45, 0.85), (-0.3, yc + 0.5, 1.18), M["console"], rot=(-0.22, 0, 0), bevel=0.012)
    box("sc_hood", (2.75, 0.42, 0.05), (-0.3, yc + 0.55, 1.64), M["console_lt"], rot=(0.12, 0, 0), bevel=0.01)
    yaw = math.pi  # facing aft (-Y) -> towards operators? screens face the operators (aft)
    for i, (xc, img, live) in enumerate([(-1.3, "ship_control", True), (-0.72, "ballast", False), (0.12, "ship_control", True), (0.7, "esm", False)]):
        screen("sc_screen%d" % i if not live else ("ship_ctrl_l" if i == 0 else "ship_ctrl_r"), 0.5, 0.3, (xc, yc + 0.255, 1.2), 0.0, -0.22, img, live=live)
    # Control yokes and throttle.
    for i, xc in enumerate((-1.0, 0.4)):
        box("yoke_col_%d" % i, (0.06, 0.06, 0.2), (xc, yc - 0.18, 0.86), M["black"], rot=(0.6, 0, 0), bevel=0.01)
        torus("yoke_%d" % i, 0.13, 0.016, (xc, yc - 0.26, 0.96), M["black"], rot=(math.pi / 2 - 0.3, 0, 0))
        box("yoke_bar_%d" % i, (0.26, 0.03, 0.03), (xc, yc - 0.26, 0.96), M["black"], bevel=0.008)
        chair("sc_chair_%d" % i, (xc, yc - 0.85, 0), 0.0)
        keyboard("sc_kb_%d" % i, (xc + 0.3, yc - 0.15, 0.77), 0.0, w=0.32)
    box("throttle_base", (0.18, 0.22, 0.06), (-0.3, yc - 0.12, 0.78), M["console_lt"], bevel=0.01)
    box("throttle", (0.03, 0.12, 0.03), (-0.3, yc - 0.12, 0.85), M["steel"], rot=(0.3, 0, 0), bevel=0.006)
    # Indicator row and annunciators on the desk front edge.
    for k in range(18):
        x = -1.55 + k * 0.15
        col = [(0.3, 1.0, 0.4), (0.3, 1.0, 0.4), (1.0, 0.7, 0.2), (0.3, 0.8, 1.0)][k % 4]
        LEDS.append(((x, yc + 0.27, 0.95), col, "steady" if k % 5 else "blink"))
    label("sc_label", "SHIP CONTROL", (-0.3, yc + 0.325, 1.5), (-0.22, 0, 0), w=0.42, h=0.045, size=0.028)
    # Overhead instrument cluster.
    box("oh_cluster", (2.2, 0.16, 0.26), (-0.3, yc + 0.1, 2.06), M["console"], rot=(0.2, 0, 0), bevel=0.01)
    for k, nm in enumerate(["DEPTH", "HEADING", "TRIM", "SPEED", "RUDDER"]):
        x = -1.15 + k * 0.42
        cyl("gauge_%d" % k, 0.085, 0.04, (x, yc + 0.0, 2.05), M["black"], rot=(math.pi / 2 + 0.2, 0, 0), bevel=0.004)
        cyl("gauge_face_%d" % k, 0.072, 0.005, (x, yc - 0.022, 2.05), emissive("gauge_face_mat_%d" % k, (0.95, 0.85, 0.65, 1), 0.06), rot=(math.pi / 2 + 0.2, 0, 0))
        box("needle_%d" % k, (0.004, 0.002, 0.06), (x + 0.01, yc - 0.028, 2.06), M["red"], rot=(0.2, 0, 0.4 + k * 0.7), bevel=0.0)
        label("gauge_lbl_%d" % k, nm, (x, yc - 0.03, 1.94), (0.2, 0, 0), w=0.12, h=0.022, size=0.014)
    HOT["ship_control"] = [(-1.6, yc - 0.1, 0.7), (1.0, yc - 0.1, 0.7), (-1.6, yc + 0.5, 1.6), (1.0, yc + 0.5, 1.6)]


def ballast_panel():
    # Vertical panel on the port side, facing starboard (+X).
    x = -2.62
    box("bcp_cab", (0.42, 1.8, 1.7), (x, 1.45, 0.9), M["panel"], bevel=0.012)
    box("bcp_top", (0.5, 1.86, 0.08), (x + 0.02, 1.45, 1.78), M["console_lt"], bevel=0.01)
    yaw = math.pi / 2  # facing +X
    screen("bcp_mimic", 0.62, 0.38, (x + 0.215, 1.45, 1.35), yaw, 0.0, "ballast", strength=1.2)
    # Rows of toggle switches and indicator lamps.
    for r in range(3):
        for c in range(10):
            yy = 0.75 + c * 0.155
            zz = 0.95 - r * 0.14
            box("bcp_sw_%d_%d" % (r, c), (0.02, 0.04, 0.05), (x + 0.22, yy, zz), M["steel"], bevel=0.004)
            box("bcp_swl_%d_%d" % (r, c), (0.04, 0.006, 0.01), (x + 0.24, yy, zz + 0.02), M["chrome"], rot=(0.5, 0, 0), bevel=0.0)
            LEDS.append(((x + 0.215, yy, zz + 0.05), (0.3, 1.0, 0.4) if (r + c) % 4 else (1.0, 0.15, 0.1), "steady"))
    # Analogue gauges (HP air).
    for k in range(3):
        yy = 0.95 + k * 0.4
        cyl("bcp_g_%d" % k, 0.075, 0.04, (x + 0.22, yy, 1.62), M["chrome"], rot=(0, math.pi / 2, 0), bevel=0.004)
        cyl("bcp_gf_%d" % k, 0.065, 0.004, (x + 0.242, yy, 1.62), M["white"], rot=(0, math.pi / 2, 0))
        box("bcp_gn_%d" % k, (0.002, 0.004, 0.055), (x + 0.246, yy, 1.62), M["black"], rot=(0.9 + k * 0.6, 0, 0), bevel=0.0)
    # Emergency blow with red guards.
    for k in range(2):
        yy = 2.05 + k * 0.16
        box("blow_guard_%d" % k, (0.05, 0.1, 0.12), (x + 0.24, yy, 0.62), M["red"], bevel=0.01)
    label("bcp_lbl", "BALLAST CONTROL", (x + 0.212, 1.45, 1.66), (0, 0, yaw), w=0.4, h=0.04, size=0.024)
    label("blow_lbl", "EMERGENCY BLOW", (x + 0.212, 2.13, 0.75), (0, 0, yaw), w=0.28, h=0.03, size=0.016)
    HOT["ballast"] = [(x + 0.2, 0.55, 0.4), (x + 0.2, 2.35, 0.4), (x + 0.2, 0.55, 1.75), (x + 0.2, 2.35, 1.75)]


def nav_table():
    cx, cy = -1.45, -1.75
    box("nav_cab", (1.25, 0.85, 0.86), (cx, cy, 0.43), M["console"], bevel=0.01)
    box("nav_rim", (1.35, 0.95, 0.06), (cx, cy, 0.89), M["black"], bevel=0.012)
    # Horizontal display (live chart), facing up.
    w, h = 1.15, 0.72
    c = Vector((cx, cy, 0.925))
    mat = screen_mat("nav_table_scr", os.path.join(args.screens, "nav.png"), 1.1)
    p = plane("nav_table", w, h, tuple(c), (-math.pi / 2, 0, 0), mat)
    # corners as seen standing at the aft/starboard side: top edge = forward
    LIVE["nav_table"] = [(cx - w / 2, cy + h / 2, 0.925), (cx + w / 2, cy + h / 2, 0.925), (cx + w / 2, cy - h / 2, 0.925), (cx - w / 2, cy - h / 2, 0.925)]
    p["live"] = True
    # Paper, dividers, pencil, mug on the rim.
    box("nav_paper", (0.21, 0.3, 0.002), (cx + 0.52, cy - 0.28, 0.928), M["board"], rot=(0, 0, 0.2), bevel=0.0)
    box("nav_pencil", (0.006, 0.16, 0.006), (cx + 0.47, cy - 0.2, 0.932), M["yellow"], rot=(0, 0, 0.5), bevel=0.0)
    cyl("nav_mug", 0.04, 0.09, (cx - 0.62, cy + 0.38, 0.965), M["cork"], verts=24)
    torus("nav_mug_handle", 0.025, 0.006, (cx - 0.58, cy + 0.38, 0.97), M["cork"], rot=(math.pi / 2, 0, 0))
    # Overhead articulated lamp (warm).
    cyl("nav_lamp_arm", 0.012, 0.5, (cx + 0.2, cy, DECKHEAD - 0.25), M["black"])
    cyl("nav_lamp_head", 0.09, 0.09, (cx + 0.2, cy, DECKHEAD - 0.54), M["black"], r2=0.05)
    spot_light("nav_spot", (cx + 0.2, cy, DECKHEAD - 0.6), (0, 0, 0), 12.0, (1.0, 0.82, 0.6), size_deg=55, blend=0.8)
    point_light("nav_spot_red", (cx + 0.2, cy, DECKHEAD - 0.6), 3.0, (1.0, 0.08, 0.03), kind="red")
    label("nav_lbl", "NAVIGATION", (cx, cy - 0.478, 0.75), (0, 0, 0), w=0.3, h=0.035, size=0.02)
    # Navigation rack on the hull side.
    box("nav_rack", (0.5, 1.2, 1.7), (-2.65, -2.05, 0.85), M["console"], bevel=0.01)
    for k in range(4):
        z = 0.5 + k * 0.32
        box("nav_unit_%d" % k, (0.06, 1.1, 0.26), (-2.38, -2.05, z), M["console"], bevel=0.006)
        for j in range(3):
            cyl("nav_knob_%d_%d" % (k, j), 0.012, 0.02, (-2.345, -1.7 + j * 0.07, z - 0.02), M["steel"], rot=(0, math.pi / 2, 0), verts=12)
        screen("nav_unit_scr_%d" % k, 0.18, 0.08, (-2.345, -2.25, z + 0.04), math.pi / 2, 0.0, "comms", strength=0.8, bezel=0.01)
        for j in range(5):
            LEDS.append(((-2.345, -1.85 + j * 0.06, z - 0.06), (0.3, 1.0, 0.4) if j % 3 else (1.0, 0.7, 0.2), "steady" if j else "blink"))
    HOT["nav"] = [(cx - 0.6, cy - 0.45, 0.9), (cx + 0.6, cy - 0.45, 0.9), (cx - 0.6, cy + 0.45, 0.9), (cx + 0.6, cy + 0.45, 0.9)]


def periscope_stand():
    cx, cy = -0.3, -0.55
    cyl("stand", 0.85, 0.12, (cx, cy, 0.06), M["tread"], verts=48, bevel=0.01)
    torus("stand_edge", 0.85, 0.012, (cx, cy, 0.12), M["yellow"])
    # Handrail on stanchions (open towards the forward side).
    pts = []
    for k in range(25):
        a = math.radians(200 + k * 9.0)
        pts.append((cx + math.cos(a) * 0.8, cy + math.sin(a) * 0.8, 1.02))
    tube("rail", pts, 0.022, M["steel"])
    for k in range(0, 25, 6):
        a = math.radians(200 + k * 9.0)
        cyl("stanchion_%d" % k, 0.018, 0.9, (cx + math.cos(a) * 0.8, cy + math.sin(a) * 0.8, 0.57), M["steel"])
    # Attack periscope: barrel through the deckhead, eyepiece box, training handles.
    px, py = cx + 0.05, cy + 0.15
    cyl("scope_barrel", 0.105, DECKHEAD - 1.0, (px, py, 1.0 + (DECKHEAD - 1.0) / 2), M["steel"], verts=40)
    cyl("scope_well", 0.24, 0.16, (px, py, DECKHEAD - 0.08), M["pipe_grey"], verts=40, bevel=0.01)
    box("scope_body", (0.24, 0.26, 0.34), (px, py - 0.03, 1.42), M["scope"], bevel=0.035, segs=4)
    box("scope_hood", (0.16, 0.12, 0.12), (px, py - 0.2, 1.48), M["scope"], bevel=0.03, segs=3)
    cyl("scope_eye", 0.05, 0.05, (px, py - 0.27, 1.48), M["rubber_blk"], rot=(math.pi / 2, 0, 0), bevel=0.01)
    for side in (-1, 1):
        box("scope_hinge_%d" % side, (0.05, 0.07, 0.07), (px + side * 0.145, py - 0.03, 1.38), M["steel"], bevel=0.008)
        cyl("scope_handle_%d" % side, 0.024, 0.3, (px + side * 0.19, py - 0.03, 1.27), M["rubber_blk"], bevel=0.006)
    label("scope_ref", "TRAIN", (px + 0.1, py - 0.161, 1.32), (0, 0, 0), w=0.07, h=0.02, size=0.011)
    cyl("scope_collar", 0.15, 0.08, (px, py, 1.6), M["steel"], verts=40, bevel=0.006)
    label("scope_lbl", "ATTACK PERISCOPE", (px, py - 0.161, 1.62), (0, 0, 0), w=0.2, h=0.026, size=0.012)
    HOT["periscope"] = [(px - 0.3, py, 1.0), (px + 0.3, py, 1.0), (px - 0.3, py, 1.9), (px + 0.3, py, 1.9)]
    # Overhead periscope / optronic mast monitor facing aft (towards the command position).
    box("mon_bracket", (0.05, 0.05, 0.22), (0.25, 0.55, DECKHEAD - 0.11), M["steel"], bevel=0.004)
    screen("periscope_monitor", 0.62, 0.35, (0.25, 0.55, 1.96), 0.0, 0.12, "nav", live=True, strength=1.4)
    box("mon2_bracket", (0.05, 0.05, 0.22), (1.0, 0.55, DECKHEAD - 0.11), M["steel"], bevel=0.004)
    screen("tactical_monitor", 0.5, 0.3, (1.0, 0.55, 1.97), -0.12, 0.12, "fire_control", strength=1.1)
    label("mon_lbl", "OPTRONIC MAST", (0.25, 0.53, 1.75), (0.12, 0, 0), w=0.22, h=0.025, size=0.014)
    # Command position: a small lectern with intercom handset and 1MC microphone.
    box("cmd_lectern", (0.36, 0.28, 1.05), (0.75, -1.7, 0.525), M["console"], bevel=0.01)
    box("cmd_top", (0.4, 0.32, 0.03), (0.75, -1.68, 1.07), M["black"], rot=(0.3, 0, 0), bevel=0.006)
    box("cmd_handset", (0.06, 0.2, 0.05), (0.85, -1.7, 1.1), M["black"], rot=(0.3, 0, 0.2), bevel=0.015)
    tube("cmd_cord", [(0.85, -1.62, 1.08), (0.92, -1.6, 0.98), (0.9, -1.55, 0.9), (0.94, -1.58, 0.82), (0.92, -1.62, 0.76)], 0.006, M["black"])
    LEDS.append(((0.65, -1.66, 1.09), (0.3, 1.0, 0.4), "steady"))
    LEDS.append(((0.62, -1.66, 1.09), (1.0, 0.7, 0.2), "blink"))


def aft_bulkhead():
    y = Y0 + 0.035
    # Watertight door with dogs.
    box("door_frame", (0.9, 0.1, 1.75), (0.95, y + 0.03, 0.95), M["frame"], bevel=0.04, segs=4)
    box("door_leaf", (0.68, 0.06, 1.5), (0.95, y + 0.08, 0.95), M["hull"], bevel=0.06, segs=5)
    for k in range(6):
        a = k * math.pi / 3
        box("dog_%d" % k, (0.1, 0.03, 0.025), (0.95 + math.cos(a) * 0.38, y + 0.12, 0.95 + math.sin(a) * 0.8), M["steel"], rot=(0, a, 0), bevel=0.006)
    torus("door_wheel", 0.12, 0.012, (0.95, y + 0.13, 0.95), M["steel"], rot=(math.pi / 2, 0, 0))
    # State board, clocks, fire extinguisher, breathing masks, telephone.
    box("board", (1.1, 0.03, 0.72), (-1.0, y + 0.02, 1.5), M["frame"], bevel=0.01)
    plane("board_face", 1.04, 0.66, (-1.0, y + 0.037, 1.5), (0, 0, math.pi), screen_mat("board_mat", os.path.join(args.screens, "status_board.png"), 0.0))
    for k, xx in enumerate((-2.0, -1.72)):
        cyl("clock_%d" % k, 0.11, 0.05, (xx, y + 0.03, 1.95), M["black"], rot=(math.pi / 2, 0, 0), bevel=0.005)
        cyl("clockface_%d" % k, 0.095, 0.004, (xx, y + 0.057, 1.95), M["white"], rot=(math.pi / 2, 0, 0))
        box("clock_hand_%d" % k, (0.004, 0.003, 0.07), (xx, y + 0.06, 1.97), M["black"], rot=(0, 0.6 + k, 0), bevel=0.0)
    cyl("extinguisher", 0.075, 0.5, (1.8, y + 0.12, 0.55), M["red"], bevel=0.02)
    cyl("ext_head", 0.03, 0.08, (1.8, y + 0.12, 0.84), M["black"])
    box("eab_box", (0.4, 0.15, 0.3), (-2.25, y + 0.08, 1.55), M["yellow"], bevel=0.01)
    label("eab_lbl", "EAB", (-2.25, y + 0.157, 1.55), (0, 0, math.pi), w=0.12, h=0.04, size=0.026)
    box("phone_box", (0.18, 0.1, 0.25), (-0.05, y + 0.06, 1.35), M["console"], bevel=0.01)
    box("phone", (0.05, 0.04, 0.2), (-0.05, y + 0.12, 1.36), M["black"], bevel=0.015)
    # Radio / comms rack aft starboard.
    box("comms_rack", (0.7, 1.0, 1.9), (2.45, -3.3, 0.95), M["console"], bevel=0.01)
    for k in range(5):
        z = 0.35 + k * 0.32
        box("radio_%d" % k, (0.06, 0.92, 0.26), (2.08, -3.3, z), M["console_lt"], bevel=0.006)
        screen("radio_scr_%d" % k, 0.16, 0.06, (2.045, -3.55, z + 0.05), -math.pi / 2, 0.0, "comms", strength=0.7, bezel=0.008)
        for j in range(4):
            cyl("knob_%d_%d" % (k, j), 0.014, 0.025, (2.04, -3.25 + j * 0.1, z - 0.04), M["black"], rot=(0, math.pi / 2, 0))
        LEDS.append(((2.045, -2.95, z + 0.07), (0.3, 1.0, 0.4), "steady"))
    for k, mcol in enumerate((M["red"], M["black"])):
        box("handset_%d" % k, (0.06, 0.05, 0.2), (2.05, -2.7 + k * 0.12, 1.35), mcol, bevel=0.015)
    label("comms_lbl", "COMMUNICATIONS", (2.04, -3.3, 1.92), (0, 0, -math.pi / 2), w=0.34, h=0.04, size=0.022)


def starboard():
    mfc("sonar_console", 1.55, "sonar", "sonar", live=True, title="SONAR")
    mfc("fc_console", 0.62, "fire_control", "fire_control", title="FIRE CONTROL")
    mfc("esm_console", -0.31, "esm", "comms", title="ESM / COMMS")
    HOT["sonar"] = [(2.2, 1.1, 0.75), (2.2, 2.0, 0.75), (2.4, 1.1, 1.7), (2.4, 2.0, 1.7)]
    # Junction boxes and cable drops above the consoles.
    for y in (-0.8, 0.15, 1.1, 2.0):
        box("jbox_%d" % int(y * 10), (0.12, 0.3, 0.22), (2.85, y, 2.0), M["panel"], bevel=0.01)
        tube("drop_%d" % int(y * 10), [(2.82, y, 1.89), (2.78, y + 0.02, 1.84), (2.72, y + 0.03, 1.78)], 0.012, M["cable"])
    # Binders on a shelf above the forward console.
    box("shelf", (0.3, 0.8, 0.02), (2.75, 2.4, 1.7), M["frame"], bevel=0.003)
    for k in range(9):
        box("binder_%d" % k, (0.24, 0.05, 0.3), (2.75, 2.06 + k * 0.075, 1.86), [M["band_blue"], M["black"], M["red"], M["band_green"]][k % 4], bevel=0.006)


def working_details():
    import bmesh
    yf = Y1 - 0.035
    # Forward watertight door (port side), ajar onto a dim passage.
    dx = -2.15
    box("fdoor_frame", (0.9, 0.1, 1.75), (dx, yf - 0.03, 0.95), M["frame"], bevel=0.04, segs=4)
    box("fdoor_dark", (0.66, 0.04, 1.46), (dx, yf + 0.01, 0.95), paint("passage_dark", (0.01, 0.012, 0.014, 1), 0.9, grime=0.0), bevel=0.06, segs=5)
    box("fdoor_leaf", (0.66, 0.06, 1.46), (dx + 0.36, yf - 0.36, 0.95), M["hull"], rot=(0, 0, 1.25), bevel=0.06, segs=5)
    point_light("passage_light", (dx, yf + 0.6, 1.6), 6.0, (0.8, 0.85, 1.0))
    # Annunciator strip and clock above the ship control console.
    box("annunc", (1.6, 0.06, 0.16), (-0.3, yf - 0.05, 2.0), M["console"], bevel=0.008)
    for k in range(12):
        col = [(0.3, 1.0, 0.45), (0.3, 1.0, 0.45), (1.0, 0.72, 0.25), (0.3, 1.0, 0.45)][k % 4]
        box("annunc_w%d" % k, (0.1, 0.01, 0.06), (-1.0 + k * 0.127, yf - 0.085, 2.0), emissive("ann_%d" % k, col + (1,), 0.6 if k % 5 else 0.0), bevel=0.0)
    for k in range(3):
        cyl("fwd_pipe_%d" % k, 0.03, DECKHEAD, (1.45 + k * 0.12, yf - 0.08, DECKHEAD / 2), M["pipe_grey"] if k else M["pipe_white"], verts=16)
    # Ladder to the bridge trunk, with the lower hatch ring in the deckhead.
    lx, ly = 1.6, -2.62
    cyl("trunk_ring", 0.38, 0.12, (lx, ly, DECKHEAD - 0.02), M["frame"], verts=48, bevel=0.01)
    cyl("trunk_void", 0.33, 0.13, (lx, ly, DECKHEAD - 0.015), paint("trunk_dark", (0.01, 0.01, 0.012, 1), 0.9, grime=0.0), verts=48)
    for side in (-1, 1):
        cyl("ladder_rail_%d" % side, 0.018, DECKHEAD + 0.1, (lx + side * 0.2, ly + 0.2, DECKHEAD / 2 + 0.05), M["steel"], rot=(-0.08, 0, 0))
    for k in range(8):
        z = 0.25 + k * 0.27
        cyl("rung_%d" % k, 0.014, 0.4, (lx, ly + 0.2 - z * 0.08 + 0.04, z), M["steel"], rot=(0, math.pi / 2, 0))
    # High-pressure air manifold on the port hull above the ballast panel.
    for k in range(5):
        yy = 0.8 + k * 0.32
        cyl("hp_pipe_%d" % k, 0.016, 0.5, (-2.72, yy, 2.05), M["pipe_grey"], verts=12)
        cyl("hp_valve_%d" % k, 0.03, 0.06, (-2.72, yy, 1.85), M["steel"], verts=16, bevel=0.004)
        torus("hp_wheel_%d" % k, 0.045, 0.006, (-2.66, yy, 1.85), M["red"] if k % 2 else M["steel"], rot=(0, math.pi / 2, 0))
    label("hp_lbl", "HP AIR", (-2.665, 1.45, 2.18), (0, 0, math.pi / 2), w=0.16, h=0.03, size=0.018)
    # Conduits and cable runs along both hull sides.
    for side in (-1, 1):
        for k in range(4):
            z = 1.9 + k * 0.04
            x = side * (hull_half_width(z) - 0.12 - k * 0.025)
            tube("conduit_%d_%d" % (side, k), [(x, Y0 + 0.1, z), (x, Y1 - 0.1, z)], 0.012 + 0.004 * (k % 2), M["cable"] if k % 2 else M["pipe_grey"])
    # Emergency battle lanterns.
    for (x, y) in [(-2.5, -0.4), (2.6, 2.7), (-0.2, Y1 - 0.08), (2.0, Y0 + 0.1)]:
        rot = (0, 0, math.pi / 2 if abs(x) > 2 else 0)
        box("lantern_%d_%d" % (x * 10, y * 10), (0.14, 0.1, 0.12), (x, y, 2.12), M["yellow"], rot=rot, bevel=0.012)
        cyl("lantern_lens_%d_%d" % (x * 10, y * 10), 0.04, 0.03, (x, y, 2.05), M["glass"] if False else M["white"], bevel=0.004)
        LEDS.append(((x, y, 2.18), (0.3, 1.0, 0.4), "steady"))
    # Overhead grab rails (yellow / black).
    for x in (-0.55, 0.85):
        cyl("grab_%d" % int(x * 10), 0.016, 2.6, (x, -1.0, 2.15), M["yellow"], rot=(math.pi / 2, 0, 0))
        for y in (-2.1, 0.1):
            cyl("grab_post_%d_%d" % (int(x * 10), int(y * 10)), 0.01, 0.2, (x, y, 2.25), M["steel"])
    # Deck markings: walkway lines and a hatch in the deck.
    for x in (-0.95, 1.2):
        box("deckline_%d" % int(x * 10), (0.05, 5.2, 0.003), (x, 0.0, 0.002), M["yellow"], bevel=0.0)
    box("deck_hatch", (0.7, 0.7, 0.01), (0.25, 1.6, 0.005), M["tread"], bevel=0.004)
    torus("deck_hatch_ring", 0.06, 0.008, (0.45, 1.75, 0.02), M["steel"])
    # Fasteners on the bulkheads.
    for k in range(16):
        cyl("bolt_f_%d" % k, 0.008, 0.01, (-2.6 + k * 0.33, yf - 0.035, 2.25), M["steel"], rot=(math.pi / 2, 0, 0), verts=8)


SKIN_M = None


def person(name, pose, loc, yaw, hair=(0.08, 0.06, 0.045, 1), headset=False, bun=False, ponytail=False, grey=False, cap=False):
    """A restrained watchstander: realistic proportions, dark coveralls,
    staged from behind or in profile (no faces, no cartoon features)."""
    global SKIN_M
    if SKIN_M is None:
        SKIN_M = paint("skin", (0.62, 0.45, 0.37, 1), 0.5, grime=0.0, scale=30.0)
        b = SKIN_M.node_tree.nodes["Principled BSDF"]
        b.inputs["Subsurface Weight"].default_value = 0.25
        b.inputs["Subsurface Radius"].default_value = (0.9, 0.4, 0.25)
        b.inputs["Subsurface Scale"].default_value = 0.01
    hair_m = paint(name + "_hair", (0.6, 0.6, 0.6, 1) if grey else hair, 0.45, grime=0.0, scale=80.0, var=0.3)
    cover = paint(name + "_coverall", (0.035, 0.045, 0.075, 1), 0.85, grime=0.25, scale=25.0)
    # Cloth folds: a soft stretched-noise bump so the coverall reads as fabric.
    cn = cover.node_tree
    fold = cn.nodes.new("ShaderNodeTexNoise")
    fold.inputs["Scale"].default_value = 9.0
    fold.inputs["Detail"].default_value = 3.0
    fold.inputs["Distortion"].default_value = 1.5
    ftc = cn.nodes.new("ShaderNodeTexCoord")
    fmap = cn.nodes.new("ShaderNodeMapping")
    fmap.inputs["Scale"].default_value = (1.0, 1.0, 3.5)
    cn.links.new(ftc.outputs["Object"], fmap.inputs["Vector"])
    cn.links.new(fmap.outputs["Vector"], fold.inputs["Vector"])
    fb = cn.nodes.new("ShaderNodeBump")
    fb.inputs["Strength"].default_value = 0.35
    fb.inputs["Distance"].default_value = 0.02
    cn.links.new(fold.outputs["Fac"], fb.inputs["Height"])
    cn.links.new(fb.outputs["Normal"], cn.nodes["Principled BSDF"].inputs["Normal"])
    cn.nodes["Principled BSDF"].inputs["Sheen Weight"].default_value = 0.3
    if pose == "seated":
        V = [(0, 0, 0.58), (0, -0.01, 0.74), (0, 0.02, 0.93), (0, 0.05, 1.1), (0, 0.06, 1.16),
             (-0.18, 0.02, 1.04), (-0.22, 0.2, 0.86), (-0.15, 0.4, 0.8), (0.18, 0.02, 1.04), (0.22, 0.2, 0.86), (0.15, 0.4, 0.8),
             (-0.1, 0.02, 0.56), (-0.11, 0.44, 0.58), (-0.11, 0.5, 0.1), (-0.11, 0.62, 0.04),
             (0.1, 0.02, 0.56), (0.11, 0.44, 0.58), (0.11, 0.5, 0.1), (0.11, 0.62, 0.04)]
    elif pose == "lean":
        V = [(0, 0, 0.96), (0, 0.06, 1.12), (0, 0.17, 1.27), (0, 0.27, 1.38), (0, 0.3, 1.43),
             (-0.19, 0.17, 1.33), (-0.22, 0.3, 1.1), (-0.16, 0.48, 0.97), (0.19, 0.17, 1.33), (0.22, 0.3, 1.1), (0.15, 0.5, 0.97),
             (-0.1, 0.0, 0.92), (-0.1, 0.02, 0.5), (-0.1, -0.02, 0.08), (-0.1, 0.11, 0.03),
             (0.1, 0.0, 0.92), (0.1, 0.04, 0.5), (0.1, 0.06, 0.08), (0.1, 0.19, 0.03)]
    else:  # standing, hands behind the back
        V = [(0, 0, 0.96), (0, 0, 1.14), (0, 0.01, 1.33), (0, 0.02, 1.5), (0, 0.03, 1.56),
             (-0.19, 0.0, 1.44), (-0.24, -0.08, 1.2), (-0.08, -0.16, 1.02), (0.19, 0.0, 1.44), (0.24, -0.08, 1.2), (0.08, -0.16, 1.03),
             (-0.1, 0.0, 0.93), (-0.11, 0.03, 0.5), (-0.12, 0.0, 0.08), (-0.12, 0.13, 0.03),
             (0.1, 0.0, 0.93), (0.11, 0.0, 0.5), (0.12, -0.02, 0.08), (0.12, 0.11, 0.03)]
    E = [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6), (6, 7), (2, 8), (8, 9), (9, 10), (0, 11), (11, 12), (12, 13), (13, 14), (0, 15), (15, 16), (16, 17), (17, 18)]
    R = [(0.17, 0.12), (0.15, 0.11), (0.19, 0.12), (0.055, 0.055), (0.055, 0.055),
         (0.065, 0.065), (0.05, 0.05), (0.04, 0.035), (0.065, 0.065), (0.05, 0.05), (0.04, 0.035),
         (0.085, 0.085), (0.06, 0.06), (0.045, 0.045), (0.045, 0.03),
         (0.085, 0.085), (0.06, 0.06), (0.045, 0.045), (0.045, 0.03)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(V, E, [])
    o = _obj(name, me, cover)
    sk = o.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    for i, r in enumerate(R):
        me.skin_vertices[0].data[i].radius = r
    me.skin_vertices[0].data[0].use_root = True
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    o.location = loc
    o.rotation_euler = (0, 0, yaw)
    mw = o.matrix_basis.copy()

    def W(p):
        return tuple(Matrix.Translation(Vector(loc)) @ Matrix.Rotation(yaw, 4, "Z") @ Vector(p))

    hb = Vector(V[4])
    head_c = hb + Vector((0, 0.01, 0.1)) if pose != "lean" else hb + Vector((0, 0.06, 0.08))
    hd = cyl(name + "_head", 0.092, 0.2, W(head_c), SKIN_M, rot=(0, 0, yaw), verts=24)
    hd.modifiers.new("sub", "SUBSURF").levels = 2
    hd.scale = (0.95, 1.08, 0.95)
    hr = cyl(name + "_hairc", 0.097, 0.16, W(head_c + Vector((0, -0.018, 0.035))), hair_m, rot=(0, 0, yaw), verts=24)
    hr.modifiers.new("sub", "SUBSURF").levels = 2
    hr.scale = (0.98, 1.06, 0.95)
    if cap:
        knit = paint(name + "_cap", (0.03, 0.035, 0.05, 1), 0.95, grime=0.0, scale=120.0, var=0.25)
        kn = knit.node_tree
        rib = kn.nodes.new("ShaderNodeTexWave")
        rib.inputs["Scale"].default_value = 60.0
        kb = kn.nodes.new("ShaderNodeBump")
        kb.inputs["Strength"].default_value = 0.5
        kn.links.new(rib.outputs["Fac"], kb.inputs["Height"])
        kn.links.new(kb.outputs["Normal"], kn.nodes["Principled BSDF"].inputs["Normal"])
        kc = cyl(name + "_knitcap", 0.104, 0.15, W(head_c + Vector((0, -0.012, 0.045))), knit, rot=(0, 0, yaw), verts=24)
        kc.modifiers.new("sub", "SUBSURF").levels = 2
        kc.scale = (0.99, 1.07, 1.0)
        torus(name + "_capfold", 0.098, 0.018, W(head_c + Vector((0, -0.008, -0.005))), knit, rot=(0.0, 0.0, yaw))
    if bun:
        b2 = cyl(name + "_bun", 0.045, 0.06, W(head_c + Vector((0, -0.1, 0.06))), hair_m, rot=(math.pi / 2, 0, yaw), verts=16)
        b2.modifiers.new("sub", "SUBSURF").levels = 2
    if ponytail:
        tube(name + "_pony", [W(head_c + Vector((0, -0.09, 0.05))), W(head_c + Vector((0, -0.13, -0.05))), W(head_c + Vector((0, -0.11, -0.16)))], 0.025, hair_m)
    for side in (-1, 1):
        cyl(name + "_ear%d" % side, 0.022, 0.012, W(head_c + Vector((side * 0.088, 0.0, 0.0))), SKIN_M, rot=(0, math.pi / 2, yaw), verts=12)
        hand = Vector(V[7 if side < 0 else 10])
        cyl(name + "_hand%d" % side, 0.038, 0.06, W(hand + Vector((0, 0.03, 0))), SKIN_M, rot=(math.pi / 2, 0, yaw), verts=12).modifiers.new("sub", "SUBSURF").levels = 1
        toe = Vector(V[14 if side < 0 else 18])
        box(name + "_shoe%d" % side, (0.1, 0.27, 0.09), W(toe + Vector((0, -0.07, 0.015))), M["rubber_blk"], rot=(0, 0, yaw), bevel=0.03, segs=3)
    if headset:
        torus(name + "_band", 0.105, 0.009, W(head_c + Vector((0, -0.005, 0.0))), M["black"], rot=(0, math.pi / 2, yaw))
        for side in (-1, 1):
            cyl(name + "_cup%d" % side, 0.045, 0.035, W(head_c + Vector((side * 0.1, 0.0, -0.01))), M["black"], rot=(0, math.pi / 2, yaw), verts=20, bevel=0.008)
    # Collar of a lighter undershirt and shoulder slides: small, believable cues.
    cyl(name + "_collar", 0.065, 0.05, W(Vector(V[3]) + Vector((0, 0.0, -0.02))), paint(name + "_tee", (0.08, 0.09, 0.11, 1), 0.9, grime=0.0), rot=(0, 0, yaw), verts=16)
    return o


def crew_hint():
    # A jacket over a chair back, a headset left on the desk: lived-in details.
    box("jacket", (0.4, 0.07, 0.42), (0.4, 2.12, 0.92), M["fabric"], rot=(-0.12, 0, 0.05), bevel=0.04, segs=4)
    cyl("desk_mug", 0.04, 0.09, (-1.55, 2.98, 0.805), M["cork"], verts=24)


# --------------------------------------------------------------------------- #
# Build
# --------------------------------------------------------------------------- #

build_shell()
build_overhead()
ship_control()
ballast_panel()
nav_table()
periscope_stand()
aft_bulkhead()
starboard()
working_details()
crew_hint()
# The watch: sonar operator, helmsman, conning officer, navigator.
person("crew_sonar", "seated", (1.6, 1.55, 0.0), -math.pi / 2, hair=(0.35, 0.27, 0.17, 1), headset=True, cap=True)
person("crew_helm", "seated", (-1.0, 2.42, 0.0), 0.0, hair=(0.12, 0.09, 0.06, 1), cap=True)

# Ambient bounce fill so nothing is pitch-black (very low).
area_light("fill", (0, 0, 1.2), (5.0, 7.0), 1.2, (0.6, 0.7, 0.8), rot=(math.pi, 0, 0))

for o in scene.collection.objects:
    if o.type == "LIGHT":
        o.visible_camera = False
        if o.name == "fill":
            o.visible_glossy = False

world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.0, 0.0, 0.0, 1)
scene.world = world

# --------------------------------------------------------------------------- #
# Cameras and rendering
# --------------------------------------------------------------------------- #

VIEWS = {
    "command": {"loc": (0.95, -2.6, 1.66), "target": (0.15, 3.2, 1.12), "lens": 21.0},
    "wide": {"loc": (-2.05, -3.75, 1.88), "target": (1.2, 2.4, 0.9), "lens": 17.0},
    "sonar": {"loc": (0.62, 0.35, 1.64), "target": (2.45, 1.45, 1.12), "lens": 22.0, "hide": ["crew_sonar"], "ev": 0.5},
    "nav": {"loc": (-0.55, -0.62, 1.72), "target": (-1.55, -1.95, 0.88), "lens": 26.0},
}

q = args.quality
res = (1920, 1080) if q == "final" else (960, 540)
if args.res:
    res = tuple(int(v) for v in args.res.split("x"))
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 56 if q == "final" else 40
scene.cycles.use_adaptive_sampling = True
scene.cycles.adaptive_threshold = 0.03 if q == "final" else 0.05
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 8
scene.cycles.diffuse_bounces = 4
scene.cycles.glossy_bounces = 3
scene.cycles.sample_clamp_indirect = 4.0
scene.cycles.blur_glossy = 1.0
scene.render.resolution_x, scene.render.resolution_y = res
scene.render.resolution_percentage = 100
scene.render.use_persistent_data = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.image_settings.file_format = "JPEG"
scene.render.image_settings.quality = 92

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam_data.sensor_width = 36.0
cam_data.clip_start = 0.05


def aim(loc, target, lens):
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = lens
    bpy.context.view_layer.update()


def set_light(mode):
    for o in LIGHTS_NORMAL:
        o.hide_render = mode != "normal"
    for o in LIGHTS_RED:
        o.hide_render = mode != "red"
    for m in SCREEN_MATS:
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Emission Strength"].default_value = float(m["base_strength"]) * (1.0 if mode == "normal" else 0.55)
    for o in EMIT_NORMAL:
        o.material_slots[0].material.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.6 if mode == "normal" else 0.0
    for o in EMIT_RED:
        o.material_slots[0].material.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 0.02 if mode == "normal" else 9.0
    scene.view_settings.exposure = 0.0 if mode == "normal" else 0.9


def project(p):
    c = world_to_camera_view(scene, cam, Vector(p))
    return [c.x * res[0], (1.0 - c.y) * res[1], c.z]


def quad_grid(corners, n=8):
    tl, tr, br, bl = [Vector(c) for c in corners]
    out = []
    for j in range(n + 1):
        v = j / n
        left = tl.lerp(bl, v)
        right = tr.lerp(br, v)
        row = []
        for i in range(n + 1):
            u = i / n
            p = project(tuple(left.lerp(right, u)))
            row.append([round(p[0], 2), round(p[1], 2)])
        out.append(row)
    return out


LIVE_ORDER = ["periscope_monitor", "sonar_console_upper_s", "sonar_console_lower", "nav_table", "ship_ctrl_l", "ship_ctrl_r"]
meta = {"resolution": list(res), "views": {}, "live_order": LIVE_ORDER}


def render_masks(view):
    """Per live display: where it is directly visible (occlusion-aware)."""
    saved = {}
    black = emissive("mask_black", (0, 0, 0, 1), 0.0)
    black.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
    chans = {}
    for i, name in enumerate(LIVE_ORDER):
        col = [0.0, 0.0, 0.0, 1.0]
        col[i % 3] = 1.0
        chans[name] = emissive("mask_%s" % name, tuple(col), 1.0)
        chans[name].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
    hidden = []
    for o in COLL.objects:
        if o.type not in ("MESH", "CURVE", "FONT"):
            continue
        saved[o.name] = [s.material for s in o.material_slots]
    for o in list(LIGHTS_NORMAL) + list(LIGHTS_RED) + [x for x in scene.collection.objects if x.type == "LIGHT"]:
        if not o.hide_render:
            hidden.append(o)
            o.hide_render = True
    samples = scene.cycles.samples
    scene.cycles.samples = 6
    scene.cycles.use_denoising = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    exp = scene.view_settings.exposure
    scene.view_settings.exposure = 0.0
    scene.render.image_settings.file_format = "PNG"
    for group, names in (("A", LIVE_ORDER[0:3]), ("B", LIVE_ORDER[3:6])):
        for o in COLL.objects:
            if o.name not in saved:
                continue
            for s in o.material_slots:
                s.material = black
            if o.name in names:
                for s in o.material_slots:
                    s.material = chans[o.name]
        scene.render.filepath = os.path.join(args.out, "%s_mask%s.png" % (view, group))
        bpy.ops.render.render(write_still=True)
    for o in COLL.objects:
        if o.name in saved:
            for s, m in zip(o.material_slots, saved[o.name]):
                s.material = m
    for o in hidden:
        o.hide_render = False
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = exp
    scene.render.image_settings.file_format = "JPEG"


meta_path = os.path.join(args.out, "views.json")
if os.path.exists(meta_path):
    try:
        old = json.load(open(meta_path))
        if old.get("resolution") == list(res):
            meta["views"].update(old.get("views", {}))
    except Exception:
        pass

import time
for view in args.views.split(","):
    v = VIEWS[view]
    for o in COLL.objects:
        o.hide_render = any(o.name.startswith(h) for h in v.get("hide", []))
    aim(v["loc"], v["target"], v["lens"])
    vm = {"lens": v["lens"], "live": {}, "leds": [], "hot": {}}
    for name, corners in LIVE.items():
        vm["live"][name] = quad_grid(corners)
    dg = bpy.context.evaluated_depsgraph_get()
    for (p, rgb, pattern) in LEDS:
        pp = project(p)
        origin = cam.matrix_world.translation
        d = Vector(p) - origin
        hit = scene.ray_cast(dg, origin, d.normalized(), distance=d.length)
        if hit[0] and (hit[1] - Vector(p)).length > 0.03:
            continue
        if 0 <= pp[0] <= res[0] and 0 <= pp[1] <= res[1] and pp[2] > 0:
            vm["leds"].append([round(pp[0], 1), round(pp[1], 1), list(rgb), pattern, round(1.0 / max(pp[2], 0.3), 3)])
    for name, pts in HOT.items():
        ps = [project(p) for p in pts]
        if all(p[2] > 0 for p in ps):
            xs = [p[0] for p in ps]
            ys = [p[1] for p in ps]
            vm["hot"][name] = [round(min(xs)), round(min(ys)), round(max(xs)), round(max(ys))]
    meta["views"][view] = vm
    for mode in args.light.split(","):
        set_light(mode)
        scene.view_settings.exposure += float(v.get("ev", 0.0))
        scene.render.filepath = os.path.join(args.out, "%s_%s.jpg" % (view, mode))
        t = time.time()
        bpy.ops.render.render(write_still=True)
        print("RENDERED", view, mode, round(time.time() - t, 1), "s", flush=True)
    if not args.nomask:
        set_light("normal")
        render_masks(view)
        print("MASKS", view, flush=True)
    json.dump(meta, open(meta_path, "w"), indent=1)
print("DONE")
