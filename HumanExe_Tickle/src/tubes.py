"""Tube meshes along smooth paths, carrying a 'u' (0..1 arc length) attribute,
plus a cloud of tiny emissive particles."""
import math
import bpy
import numpy as np


def _catmull(pts, n=200):
    P = np.asarray(pts, dtype=float)
    P = np.vstack([P[0] * 2 - P[1], P, P[-1] * 2 - P[-2]])
    out = []
    segs = len(P) - 3
    per = max(2, n // segs)
    for i in range(segs):
        p0, p1, p2, p3 = P[i:i + 4]
        for t in np.linspace(0, 1, per, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2])
    return np.array(out)


def tube(name, pts, radius=0.012, taper=(1.0, 1.0), ring=10, n=240):
    C = _catmull(pts, n)
    seg = np.linalg.norm(np.diff(C, axis=0), axis=1)
    u = np.concatenate([[0], np.cumsum(seg)]); u /= u[-1]
    T = np.gradient(C, axis=0); T /= np.linalg.norm(T, axis=1, keepdims=True)
    ref = np.array([0, 0, 1.0]) if abs(T[0][2]) < 0.9 else np.array([1.0, 0, 0])
    verts, faces, uu = [], [], []
    nprev = None
    for i, (c, t) in enumerate(zip(C, T)):
        n1 = np.cross(t, ref if nprev is None else nprev)
        if np.linalg.norm(n1) < 1e-6:
            n1 = np.cross(t, [1, 0, 0])
        n1 /= np.linalg.norm(n1)
        n2 = np.cross(t, n1)
        nprev = n2
        r = radius * (taper[0] + (taper[1] - taper[0]) * u[i])
        for k in range(ring):
            a = 2 * math.pi * k / ring
            verts.append(c + r * (math.cos(a) * n1 + math.sin(a) * n2))
            uu.append(u[i])
    for i in range(len(C) - 1):
        for k in range(ring):
            a = i * ring + k; b = i * ring + (k + 1) % ring
            faces.append((a, b, b + ring, a + ring))
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    for p in me.polygons:
        p.use_smooth = True
    at = me.attributes.new("u", "FLOAT", "POINT")
    at.data.foreach_set("value", np.array(uu, dtype=np.float32))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def particles(name, count, center, radius, size=(0.004, 0.012), seed=1, flat=None, avoid=(), clear=1.4):
    rng = np.random.default_rng(seed)
    verts, faces = [], []
    # tiny octahedra
    base = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], float)
    tri = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]
    for i in range(count):
        while True:
            p = rng.uniform(-1, 1, 3)
            if np.linalg.norm(p) <= 1:
                break
        if flat is not None:
            p *= np.array(flat)
        p = np.array(center) + p * radius
        if any(_seg_d(p, a, b) < clear for a, b in avoid):
            continue
        s = rng.uniform(*size)
        off = len(verts)
        verts += list(p + base * s)
        faces += [(a + off, b + off, c + off) for a, b, c in tri]
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _seg_d(p, a, b):
    a = np.asarray(a, float); b = np.asarray(b, float)
    ab = b - a
    t = np.clip(np.dot(p - a, ab) / max(np.dot(ab, ab), 1e-9), 0, 1)
    return np.linalg.norm(p - (a + t * ab))
