"""Procedural forearm + hand built with a Skin modifier skeleton.

Local frame: wrist at origin, fingers point +X, palm faces -Z,
thumb on -Y side (a right hand seen from above).
"""
import math
import bpy
from mathutils import Matrix, Vector

# (base y, segment lengths, radius) index..pinky
FINGERS = [
    (-0.30, (0.42, 0.26, 0.20), 0.085),
    (-0.10, (0.47, 0.29, 0.21), 0.088),
    (0.10, (0.44, 0.27, 0.20), 0.083),
    (0.28, (0.34, 0.21, 0.18), 0.075),
]
KNUCKLE_X = (0.86, 0.90, 0.87, 0.80)


def build_arm(name, curls=(0.15, 0.2, 0.25, 0.3), thumb_curl=0.2,
              spread=0.06, forearm_len=2.8, mirror=False, scale_r=1.0):
    """curls: per-finger bend in radians-ish factor (0 straight, 1.4 fist)."""
    verts, edges, radii = [], [], []

    def add(p, r):
        verts.append(Vector(p)); radii.append(r)
        return len(verts) - 1

    elbow = add((-forearm_len, 0, 0.05), (0.33, 0.30))
    mid = add((-forearm_len * 0.5, 0, 0.03), (0.27, 0.22))
    wrist = add((0, 0, 0), (0.21, 0.12))
    edges += [(elbow, mid), (mid, wrist)]
    for fi, (by, segs, r) in enumerate(FINGERS):
        kx = KNUCKLE_X[fi]
        # broad palm: one fan of metacarpal tubes from wrist to knuckles
        pb = add((0.22, by * 0.55, 0.0), (0.12, 0.10))
        edges.append((wrist, pb))
        k = add((kx, by * 1.05, 0.0), (r * 1.25, r * 1.0))
        edges.append((pb, k))
        ang = (fi - 1.5) * spread
        dirv = Vector((math.cos(ang), math.sin(ang), 0))
        cur = Vector((kx, by * 1.05, 0.0)); prev = k
        bend = 0.0
        for si, L in enumerate(segs):
            bend += curls[fi] * (1.0 if si == 0 else 1.25)
            d = Vector((dirv.x * math.cos(bend), dirv.y * math.cos(bend), -math.sin(bend)))
            cur = cur + d * L
            rr = r * (0.98 - 0.08 * si)
            idx = add(cur[:], (rr, rr * 0.85))
            edges.append((prev, idx)); prev = idx
    # thumb
    t0 = add((0.12, -0.20, -0.04), (0.14, 0.11))
    edges.append((wrist, t0))
    tdir = Vector((0.62, -0.62, -0.25)).normalized()
    cur = Vector((0.12, -0.20, -0.04)); prev = t0
    bend = 0.0
    for si, L in enumerate((0.36, 0.30, 0.24)):
        bend += thumb_curl * si
        d = (Matrix.Rotation(bend, 3, 'Z') @ tdir).normalized()
        d.z -= 0.15 * si
        cur = cur + d.normalized() * L
        rr = 0.105 - 0.012 * si
        idx = add(cur[:], (rr, rr * 0.9))
        edges.append((prev, idx)); prev = idx

    if mirror:
        verts = [Vector((v.x, -v.y, v.z)) for v in verts]
    me = bpy.data.meshes.new(name)
    me.from_pydata([v[:] for v in verts], edges, [])
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    sk = ob.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    for i, sv in enumerate(me.skin_vertices[0].data):
        sv.radius = (radii[i][0] * scale_r, radii[i][1] * scale_r)
    me.skin_vertices[0].data[elbow].use_root = True
    sub = ob.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 3; sub.render_levels = 3
    return ob


def nerve_points(forearm_len=2.8, z=0.0):
    """Path for the sensory nerve inside the forearm, wrist->elbow."""
    pts = []
    for i in range(24):
        t = i / 23
        x = 0.25 - t * (forearm_len + 1.2)
        pts.append((x, 0.04 * math.sin(t * 7.0), z + 0.02 * math.cos(t * 5.0)))
    return pts


def tube_curve(name, pts, bevel=0.012):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = bevel
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts):
        p.co = (*c, 1.0)
    sp.order_u = 4
    sp.use_endpoint_u = True
    sp.resolution_u = 12
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def build_with_bones(name, **kw):
    """Arm skin plus a thin inner x-ray 'skeleton' sharing the same pose."""
    arm = build_arm(name, **kw)
    bones = build_arm(name + "_bones", scale_r=0.33, **kw)
    bones.modifiers["Subsurf"].render_levels = 2
    bones.parent = arm
    return arm, bones
