"""Procedural anatomical brain geometry for Blender (bpy module).

Builds two cerebral hemispheres with gyri/sulci, a lateral (Sylvian)
fissure and central sulcus, a foliated cerebellum and a brainstem.
Each mesh stores a per-vertex "sulc" attribute (0 = groove, 1 = crown)
used by the shaders for glowing grooves.
Axes: +Y = anterior (front), +Z = superior (up), +X = right.
"""
import math
import bmesh
import bpy
import numpy as np
from mathutils import Vector, noise


def _ico(subdiv):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    v = np.array([vv.co[:] for vv in bm.verts], dtype=np.float64)
    faces = [[vv.index for vv in f.verts] for f in bm.faces]
    bm.free()
    return v, faces


def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _seg_dist(p, a, b):
    a = np.asarray(a); b = np.asarray(b)
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    proj = a + t[:, None] * ab
    return np.linalg.norm(p - proj, axis=1), t


def _noise_field(pts, scale, seed_off, basis="PERLIN_NEW"):
    out = np.empty(len(pts))
    so = Vector(seed_off)
    for i, p in enumerate(pts):
        out[i] = noise.noise(Vector(p) * scale + so, noise_basis=basis)
    return out


def _warp(pts, scale, amp, seed):
    out = pts.copy()
    so = Vector(seed)
    for i, p in enumerate(pts):
        w = noise.noise_vector(Vector(p) * scale + so, noise_basis="PERLIN_NEW")
        out[i] = p + amp * np.array(w)
    return out


def _make_mesh(name, verts, faces, sulc):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], faces)
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    attr = me.attributes.new("sulc", "FLOAT", "POINT")
    attr.data.foreach_set("value", sulc.astype(np.float32))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def hemisphere(side, subdiv=8, name=None):
    """side = +1 (right) or -1 (left)."""
    s = side
    u, faces = _ico(subdiv)
    x, y, z = u[:, 0], u[:, 1], u[:, 2]
    # base ellipsoid (local)
    rx, ry, rz = 0.40, 0.86, 0.58
    X = x * rx; Y = y * ry; Z = z * rz
    # frontal lobe slightly narrower & lower, occipital pointier
    X *= 1.0 - 0.10 * np.clip(Y / ry, 0, 1) ** 2
    Z *= 1.0 - 0.10 * np.clip(Y / ry, 0, 1) ** 3
    # flatten medial face (toward midline)
    medial = (x * -s) > 0
    X = np.where(medial, X * 0.45, X)
    # flatten the base, temporal lobe bulge low/lateral/forward
    Z = np.where(Z < 0, Z * 0.70, Z)
    temporal = np.exp(-((Y - 0.05) / 0.38) ** 2 - ((Z + 0.22) / 0.14) ** 2) * np.clip(x * s, 0, 1)
    X += s * 0.07 * temporal
    Z -= 0.10 * np.exp(-((Y - 0.05) / 0.40) ** 2) * np.clip(-z, 0, 1) * np.clip(x * s, 0, 1)
    # lift the occipital underside to make room for cerebellum
    occ = np.clip((-Y - 0.30) / 0.5, 0, 1)
    Z = np.where(Z < 0, Z * (1 - 0.45 * occ), Z)
    P = np.stack([X + s * 0.012, Y, Z + 0.02], axis=1)
    # outward normal of the ellipsoid approximation
    N = P - np.array([s * 0.15, 0.0, 0.0])
    N /= np.linalg.norm(N, axis=1, keepdims=True)

    # --- gyri / sulci: zero-crossings of warped noise form a labyrinth
    seed = (13.1 * s, 7.7, 3.3)
    Pw = _warp(P, 1.8, 0.10, seed)
    n1 = _noise_field(Pw, 5.2, (s * 31.0, 2.0, 5.0))
    n2 = _noise_field(Pw, 5.2, (s * 11.0, 9.0, 1.0))
    n3 = _noise_field(Pw, 9.0, (s * 5.0, 3.0, 17.0))
    g1 = _smoothstep(0.0, 0.20, np.abs(n1))
    g2 = _smoothstep(0.0, 0.20, np.abs(n2))
    g3 = _smoothstep(0.0, 0.10, np.abs(n3))
    # rounded gyral crowns: sqrt profile, deep narrow sulci
    sulc = np.sqrt(np.minimum(g1, g2)) * (0.75 + 0.25 * g3)

    # lateral (Sylvian) fissure on the lateral surface
    lat = np.clip(x * s, 0, 1)
    d_syl, t_syl = _seg_dist(P, (s * 0.38, 0.42, -0.14), (s * 0.40, -0.30, 0.10))
    syl = 1 - np.exp(-(d_syl / 0.030) ** 2) * (lat > 0.15)
    # central sulcus (runs from top midline down/forward)
    d_cen, _ = _seg_dist(P, (s * 0.05, -0.05, 0.60), (s * 0.40, 0.18, 0.05))
    cen = 1 - np.exp(-(d_cen / 0.022) ** 2) * (z > 0.0)
    sulc = np.minimum(sulc, np.minimum(syl, cen))
    depth = 0.042
    disp = (sulc - 1.0) * depth
    disp += (1 - syl) * -0.03
    P = P + N * disp[:, None]
    return _make_mesh(name or ("Hemi_R" if s > 0 else "Hemi_L"), P, faces, sulc)


def cerebellum(subdiv=7, name="Cerebellum"):
    u, faces = _ico(subdiv)
    x, y, z = u[:, 0], u[:, 1], u[:, 2]
    X = x * 0.50; Y = y * 0.27; Z = z * 0.22
    # two lobes with a midline notch at the back
    X *= 1.0
    Z -= 0.05 * np.exp(-(X / 0.08) ** 2) * (y < 0)
    Y += 0.06 * np.exp(-(X / 0.10) ** 2) * (y < 0)
    Z = np.where(Z > 0, Z * 0.85, Z)
    P = np.stack([X, Y, Z], axis=1)
    N = P / np.linalg.norm(P, axis=1, keepdims=True)
    # folia: fine, roughly horizontal parallel folds curving around
    Pw = _warp(P, 4.0, 0.045, (4.0, 1.0, 9.0))
    phase = (Pw[:, 2] * 1.0 + 0.45 * Pw[:, 1] ** 2 + 0.15 * Pw[:, 0] ** 2) * 290.0
    f = 0.5 + 0.5 * np.cos(phase)
    sulc = _smoothstep(0.0, 0.45, f)
    disp = (sulc - 1.0) * 0.008
    P = P + N * disp[:, None]
    P += np.array([0.0, -0.46, -0.33])
    return _make_mesh(name, P, faces, sulc)


def brainstem(name="Brainstem"):
    bm = bmesh.new()
    segs, rings = 48, 40
    pts = []
    for j in range(rings + 1):
        t = j / rings
        # pons bulge then medulla, curving slightly back
        r = 0.13 + 0.06 * math.exp(-((t - 0.25) / 0.12) ** 2) - 0.03 * t
        cy = -0.18 - 0.10 * t
        cz = -0.16 - 0.80 * t
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a), cy + r * 0.85 * math.sin(a), cz)))
        pts.append(ring)
    for j in range(rings):
        for i in range(segs):
            bm.faces.new((pts[j][i], pts[j][(i + 1) % segs], pts[j + 1][(i + 1) % segs], pts[j + 1][i]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    attr = me.attributes.new("sulc", "FLOAT", "POINT")
    attr.data.foreach_set("value", np.ones(len(me.vertices), dtype=np.float32))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob
