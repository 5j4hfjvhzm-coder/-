"""Build the full 'Your Brain Can't Tickle Itself' 3D scene and render frames.

Usage:
  python3 build_scene.py --save scene.blend            (build + save + projections)
  python3 build_scene.py --render START END OUTDIR      (build + render range)
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from mathutils import Euler, Vector  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402

import arm_geo as ag  # noqa: E402
import brain_geo as bg  # noqa: E402
import materials as M  # noqa: E402
import tubes  # noqa: E402

FPS = 30
TOTAL = 825  # 27.5 s
ARM_O = Vector((40.0, 0.0, 0.0))


def F(t):
    """seconds -> frame number (1-based)."""
    return int(round(t * FPS)) + 1


# ---------------------------------------------------------------- shot table
SHOTS = [  # name, start_s, end_s
    ("S1a_hook_zoom", 0.0, 1.5),
    ("S1b_hook_orbit", 1.5, 3.0),
    ("S2a_touch", 3.0, 5.0),
    ("S2b_nerve", 5.0, 7.0),
    ("S2c_arrive", 7.0, 9.0),
    ("S3a_cereb_side", 9.0, 11.5),
    ("S3b_cereb_close", 11.5, 13.5),
    ("S3c_predict", 13.5, 15.5),
    ("S4a_self", 15.5, 17.3),
    ("S4b_other", 17.3, 19.3),
    ("S4c_surprise", 19.3, 21.5),
    ("S5_outro", 21.5, 27.5),
]


def shot_frames(name):
    for n, a, b in SHOTS:
        if n == name:
            return F(a), F(b) - 1
    raise KeyError(name)


# ---------------------------------------------------------------- helpers
def all_fcurves(idblock):
    ad = idblock.animation_data
    if not ad or not ad.action:
        return []
    act = ad.action
    try:
        return list(act.fcurves)
    except AttributeError:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    out += list(bag.fcurves)
        return out


def set_interp(idblock, interp="BEZIER", easing="AUTO", path=None):
    for fc in all_fcurves(idblock):
        if path and fc.data_path != path:
            continue
        for kp in fc.keyframe_points:
            kp.interpolation = interp
            kp.easing = easing


def key_loc(ob, frame, loc):
    ob.location = loc
    ob.keyframe_insert("location", frame=frame)


def area_light(name, loc, target, col, energy, size=2.0):
    li = bpy.data.lights.new(name, "AREA")
    li.energy = energy; li.color = col; li.size = size
    ob = bpy.data.objects.new(name, li)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return ob


def make_cam(name, keys, interp="BEZIER", easing="AUTO", dof=None):
    """keys: list of (frame, loc, target, lens)."""
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    bpy.context.scene.collection.objects.link(cam)
    tgt = bpy.data.objects.new(name + "_tgt", None)
    bpy.context.scene.collection.objects.link(tgt)
    c = cam.constraints.new("TRACK_TO")
    c.target = tgt; c.track_axis = "TRACK_NEGATIVE_Z"; c.up_axis = "UP_Y"
    cam.data.sensor_fit = "VERTICAL"
    cam.data.sensor_height = 24.0
    cam.data.clip_start = 0.05
    for f, loc, target, lens in keys:
        key_loc(cam, f, loc)
        key_loc(tgt, f, target)
        cam.data.lens = lens
        cam.data.keyframe_insert("lens", frame=f)
    for ob in (cam, tgt, cam.data):
        set_interp(ob, interp, easing)
    if dof:
        cam.data.dof.use_dof = True
        cam.data.dof.focus_object = tgt
        cam.data.dof.aperture_fstop = dof
    return cam


def mat_keys(mat, name, kv, interp="BEZIER"):
    node = mat.node_tree.nodes[name]
    for f, v in kv:
        node.outputs[0].default_value = v
        node.outputs[0].keyframe_insert("default_value", frame=f)
    # interpolation per curve
    for fc in all_fcurves(mat.node_tree):
        if f'nodes["{name}"]' in fc.data_path:
            for kp in fc.keyframe_points:
                kp.interpolation = interp


def sawtooth_phase(mat, f0, f1, period, lo=-0.08, hi=1.08):
    node = mat.node_tree.nodes["phase"]
    s = node.outputs[0]
    f = f0
    while f < f1:
        s.default_value = lo; s.keyframe_insert("default_value", frame=f)
        s.default_value = hi; s.keyframe_insert("default_value", frame=min(f + period - 1, f1))
        f += period
    s.default_value = lo; s.keyframe_insert("default_value", frame=f1 + 1)
    for fc in all_fcurves(mat.node_tree):
        if 'nodes["phase"]' in fc.data_path:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT" if kp.co[1] > 1.0 else "LINEAR"


def one_pulse(mat, f0, f1, lo=-0.06, hi=1.08, interp="LINEAR"):
    node = mat.node_tree.nodes["phase"]
    s = node.outputs[0]
    s.default_value = lo; s.keyframe_insert("default_value", frame=f0)
    s.default_value = hi; s.keyframe_insert("default_value", frame=f1)
    for fc in all_fcurves(mat.node_tree):
        if 'nodes["phase"]' in fc.data_path:
            for kp in fc.keyframe_points:
                if abs(kp.co[0] - f0) < 0.5:
                    kp.interpolation = interp
                if abs(kp.co[0] - f1) < 0.5:
                    kp.interpolation = "CONSTANT"


# ---------------------------------------------------------------- build
def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start, sc.frame_end = 1, TOTAL

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)
    sc.world = world

    # ---------------- BRAIN
    hr = bg.hemisphere(1); hl = bg.hemisphere(-1)
    cb = bg.cerebellum(); bs = bg.brainstem()
    SPOT = (0.30, -0.12, 0.52)
    mc = M.cortex("Cortex", spot_c=SPOT, spot_r=0.32)
    mcb = M.cortex("CerebMat", glow_col=(0.0, 0.75, 1.0), seed=3.0)
    for o in (hr, hl):
        o.data.materials.append(mc)
    bs.data.materials.append(mc)
    cb.data.materials.append(mcb)

    area_light("B_rimL", (-3, -3, 2), (0, 0, 0), (0.3, 0.6, 1), 45)
    area_light("B_rimR", (3, -3, 1), (0, 0, 0), (0.2, 0.5, 1), 30)
    area_light("B_key", (2, 3, 3), (0, 0, 0), (0.8, 0.9, 1), 25)
    area_light("B_under", (0, 2, -3), (0, 0, 0), (0.1, 0.4, 1), 20)


    # touch signal climbing the brainstem
    spinal = tubes.tube("SpinalFiber", [(0, -0.12, -1.45), (0, -0.12, -1.05),
                                        (0, -0.07, -0.55), (0, -0.04, -0.25)], radius=0.016,
                        taper=(1.0, 0.7))
    m_sp = M.fiber("SpinalMat", (0.35, 0.75, 1.0), strength=0.25)
    spinal.data.materials.append(m_sp)
    # cerebellar prediction signal arc
    arc = tubes.tube("PredictArc", [(0.24, -0.66, -0.28), (0.36, -1.02, -0.10), (0.44, -1.0, 0.30),
                                    (0.40, -0.62, 0.66), (0.32, -0.16, 0.70)], radius=0.022,
                     taper=(0.8, 1.1))
    m_arc = M.fiber("ArcMat", (0.0, 1.0, 0.85), strength=0.0)
    arc.data.materials.append(m_arc)

    # ---------------- ARMS
    A, Ab = ag.build_with_bones("ArmA", curls=(0.12, 0.15, 0.2, 0.25))
    B, Bb = ag.build_with_bones("ArmB", curls=(0.05, 0.08, 1.2, 1.3), thumb_curl=0.5)
    C, Cb = ag.build_with_bones("ArmC", curls=(0.10, 0.35, 0.5, 0.6), thumb_curl=0.3,
                                mirror=True, spread=0.12)
    for o in (A, B, C):
        o.location = ARM_O.copy()
    holo_a = M.hologram("HoloA")
    holo_b = M.hologram("HoloB")
    holo_c = M.hologram("HoloC", col=(1.0, 0.12, 0.55), base=(0.05, 0.0, 0.03))
    bone_b = M.emissive("BoneBlue", (0.55, 0.82, 1.0), 0.7)
    bone_m = M.emissive("BoneMag", (1.0, 0.6, 0.85), 0.8)
    A.data.materials.append(holo_a); B.data.materials.append(holo_b); C.data.materials.append(holo_c)
    Ab.data.materials.append(bone_b); Bb.data.materials.append(bone_b); Cb.data.materials.append(bone_m)

    area_light("A_top", ARM_O + Vector((0, -1, 4)), ARM_O, (0.4, 0.7, 1), 80, size=4)

    # top surface of forearm A (ray cast down on evaluated mesh)
    dg = bpy.context.evaluated_depsgraph_get()
    top = {}
    for i in range(-30, 12):
        x = i * 0.1
        hit, loc, *_ = sc.ray_cast(dg, ARM_O + Vector((x, 0.0, 3.0)), Vector((0, 0, -1)))
        top[round(x, 1)] = (loc.z - ARM_O.z) if hit else 0.15

    def top_z(x):
        x0 = math.floor(x * 10) / 10
        x1 = x0 + 0.1
        a = top.get(round(x0, 1), 0.15); b = top.get(round(x1, 1), 0.15)
        return a + (b - a) * (x - x0) / 0.1

    # nerve inside forearm A: contact (x=-0.9) -> elbow and beyond
    nerve_pts = [(ARM_O.x + x, 0.0 + 0.03 * math.sin(x * 3), top_z(x) - 0.07)
                 for x in [-0.6, -1.0, -1.6, -2.2, -2.8, -3.4, -4.2]]
    nerve = tubes.tube("NerveA", nerve_pts, radius=0.022)
    m_nv = M.fiber("NerveMat", (0.3, 0.75, 1.0), strength=1.2)
    nerve.data.materials.append(m_nv)

    # ---- hand poses: solve location so fingertip rests on forearm skin
    def tip_local(ob, idx_a=7, idx_b=12):
        v = ob.data.vertices
        return (v[idx_a].co + v[idx_b].co) * 0.5

    tipB = tip_local(B)
    tipC = tip_local(C)
    rotB = Euler((0.25, 0.35, math.radians(-115)))
    rotC = Euler((-0.30, 0.38, math.radians(-62)))

    def place(ob, tip, rot, frame, cx, lift=0.0, wiggle=0.0):
        r = Euler((rot.x, rot.y + wiggle * 0.5, rot.z + wiggle))
        R = r.to_matrix()
        target = ARM_O + Vector((cx, 0.0, top_z(cx) + 0.075 + lift))
        ob.rotation_euler = r
        ob.location = target - R @ tip
        ob.keyframe_insert("location", frame=frame)
        ob.keyframe_insert("rotation_euler", frame=frame)
        return target

    contacts = {}
    away = Vector((0, 0, 6))
    # B: self-tickle strokes in S2a, S2b, S4a; exits at start of S4b
    sB = [shot_frames("S2a_touch")[0], shot_frames("S2b_nerve")[1]]
    sB2 = [shot_frames("S4a_self")[0] - 2, shot_frames("S4b_other")[0] + 2]
    for f in range(1, TOTAL + 1):
        if sB[0] <= f <= sB[1] or sB2[0] <= f <= sB2[1]:
            t = f / FPS
            cx = -0.9 + 0.22 * math.sin(2 * math.pi * t / 0.55)
            lift = 0.035 * max(0.0, math.cos(2 * math.pi * t / 0.55))
            p = place(B, tipB, rotB, f, cx, lift, wiggle=0.05 * math.sin(2 * math.pi * t / 0.27))
            contacts[f] = ("B", list(p))
        elif sB2[1] < f <= sB2[1] + 8:
            k = (f - sB2[1]) / 8.0
            p = place(B, tipB, rotB, f, -0.9, lift=0.3 + 3.5 * k * k)
        else:
            B.location = ARM_O + away * 3; B.keyframe_insert("location", frame=f)
    # C: someone else's hand lunges in during S4b
    c0, c1 = shot_frames("S4b_other")
    hit_f = c0 + 8
    for f in range(1, TOTAL + 1):
        if c0 - 1 <= f < hit_f:
            k = (f - (c0 - 1)) / (hit_f - (c0 - 1))
            e = 1 - (1 - k) ** 3
            place(C, tipC, rotC, f, -1.7 - 1.2 * (1 - e), lift=2.4 * (1 - e) ** 2)
        elif hit_f <= f <= c1 + 2:
            t = f / FPS
            cx = -1.7 + 0.16 * math.sin(2 * math.pi * t / 0.30)
            lift = 0.03 * max(0.0, math.cos(2 * math.pi * t / 0.30))
            p = place(C, tipC, rotC, f, cx, lift, wiggle=0.09 * math.sin(2 * math.pi * t / 0.15))
            contacts[f] = ("C", list(p))
        else:
            C.location = ARM_O + away * 3; C.keyframe_insert("location", frame=f)
    for ob in (B, C):
        set_interp(ob, "LINEAR")

    # ---------------- material animation
    s2c = shot_frames("S2c_arrive"); s3a = shot_frames("S3a_cereb_side")
    s3c = shot_frames("S3c_predict"); s4c = shot_frames("S4c_surprise"); s5 = shot_frames("S5_outro")
    s2a = shot_frames("S2a_touch"); s2b = shot_frames("S2b_nerve")
    s4a = shot_frames("S4a_self"); s4b = shot_frames("S4b_other")

    mat_keys(mc, "flash", [(1, 7.0), (7, 0.0), (s4c[0] - 1, 0.0), (s4c[0], 9.0), (s4c[0] + 8, 1.2), (s4c[1], 0.6), (s5[0], 0.0)])
    mat_keys(mc, "glow", [(1, 1.6), (s2c[1], 1.4), (s3a[0] + 15, 0.9), (s3c[1], 0.9),
                         (s4c[0], 2.6), (s4c[1], 2.2), (s5[0], 1.1)])
    mat_keys(mc, "pulse", [(1, 8.0), (s2c[1], 6.0), (s3a[0] + 15, 3.0), (s3c[1], 3.0),
                          (s4c[0], 22.0), (s4c[1], 16.0), (s5[0], 4.0)])
    mat_keys(mc, "spot", [(1, 0.0), (s2c[0] + 30, 0.0), (s2c[0] + 38, 9.0), (s2c[1], 4.0),
                         (s3a[0], 0.0), (s3c[0] + 26, 0.0), (s3c[0] + 34, 1.6), (s3c[1], 1.0), (s4c[0] - 1, 0.0),
                         (s4c[0], 16.0), (s4c[0] + 20, 11.0), (s4c[1], 8.0), (s5[0], 0.0)])
    mat_keys(mcb, "highlight", [(1, 0.0), (s3a[0] + 12, 0.0), (s3a[0] + 32, 2.2), (s3c[1], 2.0),
                               (s4c[0], 0.2), (s5[0], 0.8)])
    mat_keys(mcb, "glow", [(1, 1.4), (s3a[0] + 12, 1.4), (s3a[0] + 32, 1.9), (s3c[1], 1.9),
                          (s4c[0], 0.6), (s5[0], 1.1)])
    mat_keys(mcb, "pulse", [(1, 6.0), (s4c[0], 3.0), (s5[0], 4.0)])

    # spinal signal pulses (touch signal arriving)
    one_pulse(m_sp, s2c[0] + 2, s2c[0] + 34)
    one_pulse(m_sp, s3c[0] + 2, s3c[0] + 30)
    one_pulse(m_sp, s4c[0] - 6, s4c[0] + 2)
    mat_keys(m_sp, "peak", [(1, 70.0), (s4c[0] - 6, 140.0)], "CONSTANT")
    # prediction arc (only in S3c)
    mat_keys(m_arc, "base", [(1, 0.0), (s3c[0], 0.0), (s3c[0] + 4, 0.5), (s3c[1], 0.4), (s3c[1] + 1, 0.0)])
    mat_keys(m_arc, "peak", [(1, 0.0), (s3c[0], 40.0), (s3c[1] + 1, 0.0)], "CONSTANT")
    one_pulse(m_arc, s3c[0] + 2, s3c[0] + 30)

    # arm nerve pulses
    sawtooth_phase(m_nv, s2a[0], s2a[1], 20)
    one_pulse(m_nv, s2b[0] + 4, s2b[1] - 4, interp="SINE")
    sawtooth_phase(m_nv, s4a[0], s4a[1], 20)
    sawtooth_phase(m_nv, s4b[0] + 8, s4b[1], 18)
    mat_keys(m_nv, "peak", [(1, 30.0), (s2b[0], 90.0), (s4a[0], 30.0)], "CONSTANT")
    mat_keys(holo_c, "flash", [(1, 0.0), (hit_f - 1, 0.0), (hit_f, 3.5), (hit_f + 10, 0.2)])
    mat_keys(holo_a, "flash", [(1, 0.0), (hit_f - 1, 0.0), (hit_f, 1.2), (hit_f + 8, 0.0)])

    # ---------------- cameras
    cams = {}
    f0, f1 = shot_frames("S1a_hook_zoom")
    cams["S1a_hook_zoom"] = make_cam("Cam1", [(f0, (3.0, 9.5, 2.2), (0, 0, 0.0), 32),
                                              (f1 + 1, (1.25, 2.55, 0.75), (0, 0.05, 0.05), 42)],
                                     interp="EXPO", easing="EASE_OUT")
    f0, f1 = shot_frames("S1b_hook_orbit")
    cams["S1b_hook_orbit"] = make_cam("Cam2", [(f0, (1.15, 1.75, 1.35), (0.0, 0.3, 0.3), 38),
                                               (f1 + 1, (-0.85, 1.65, 1.45), (0.0, 0.25, 0.32), 40)],
                                      interp="SINE", easing="EASE_IN_OUT")
    O = ARM_O
    f0, f1 = shot_frames("S2a_touch")
    cams["S2a_touch"] = make_cam("Cam3", [(f0, O + Vector((0.9, -3.3, 3.2)), O + Vector((-0.9, 0.5, 0.4)), 26),
                                          (f1 + 1, O + Vector((0.5, -2.8, 2.6)), O + Vector((-0.9, 0.5, 0.4)), 28)],
                                 interp="SINE", easing="EASE_OUT", dof=4.0)
    f0, f1 = shot_frames("S2b_nerve")
    cams["S2b_nerve"] = make_cam("Cam4", [(f0, O + Vector((-0.6, -2.0, 1.3)), O + Vector((-1.2, 0.0, 0.1)), 28),
                                          (f1 + 1, O + Vector((-3.0, -2.0, 1.3)), O + Vector((-3.6, 0.0, 0.1)), 28)],
                                 interp="SINE", easing="EASE_IN_OUT", dof=3.2)
    f0, f1 = shot_frames("S2c_arrive")
    cams["S2c_arrive"] = make_cam("Cam5", [(f0, (2.4, 1.6, -1.9), (0, -0.1, -1.2), 30),
                                           (f0 + 30, (2.5, 1.9, -0.6), (0, -0.05, -0.15), 30),
                                           (f1 + 1, (2.3, 2.2, 0.5), (0.1, -0.05, 0.25), 32)],
                                  interp="SINE", easing="EASE_IN_OUT")
    f0, f1 = shot_frames("S3a_cereb_side")
    cams["S3a_cereb_side"] = make_cam("Cam6", [(f0, (-4.6, 0.2, 0.5), (0, -0.15, -0.05), 48),
                                               (f1 + 1, (-3.9, -2.2, 0.1), (0, -0.3, -0.12), 50)],
                                      interp="SINE", easing="EASE_IN_OUT")
    f0, f1 = shot_frames("S3b_cereb_close")
    cams["S3b_cereb_close"] = make_cam("Cam7", [(f0, (-1.5, -1.7, -0.75), (0.0, -0.58, -0.36), 48),
                                                (f1 + 1, (-0.35, -1.95, -0.62), (0.05, -0.62, -0.36), 52)],
                                       interp="SINE", easing="EASE_IN_OUT", dof=5.6)
    f0, f1 = shot_frames("S3c_predict")
    cams["S3c_predict"] = make_cam("Cam8", [(f0, (2.9, -3.3, 1.3), (0.15, -0.35, 0.05), 34),
                                            (f1 + 1, (3.4, -2.3, 1.0), (0.15, -0.3, 0.05), 34)],
                                   interp="SINE", easing="EASE_IN_OUT")
    f0, f1 = shot_frames("S4a_self")
    cams["S4a_self"] = make_cam("Cam9", [(f0, O + Vector((-0.2, -3.8, 3.4)), O + Vector((-1.0, 0.6, 0.5)), 24),
                                         (f1 + 1, O + Vector((-0.5, -3.3, 2.9)), O + Vector((-1.0, 0.6, 0.5)), 26)],
                                interp="SINE", easing="EASE_IN_OUT")
    f0, f1 = shot_frames("S4b_other")
    cams["S4b_other"] = make_cam("Cam10", [(f0, O + Vector((-1.0, -3.6, 2.6)), O + Vector((-1.7, 0.5, 0.6)), 24),
                                           (f1 + 1, O + Vector((-1.3, -3.0, 2.1)), O + Vector((-1.7, 0.5, 0.6)), 26)],
                                  interp="SINE", easing="EASE_OUT")
    f0, f1 = shot_frames("S4c_surprise")
    cams["S4c_surprise"] = make_cam("Cam11", [(f0, (3.9, 3.6, 2.4), (0, 0, 0.05), 30),
                                              (f1 + 1, (1.9, 2.1, 1.25), (0, 0.0, 0.1), 32)],
                                    interp="EXPO", easing="EASE_OUT")
    f0, f1 = shot_frames("S5_outro")
    keys = []
    for i in range(7):
        a = math.radians(25 + 60 * i / 6)
        f = f0 + int((f1 + 1 - f0) * i / 6)
        keys.append((f, (4.7 * math.cos(a), 4.7 * math.sin(a), 0.6), (0, 0, -0.85), 40))
    cams["S5_outro"] = make_cam("Cam12", keys, interp="LINEAR")

    # dust clouds, kept clear of every camera path (no out-of-focus blobs)
    paths = []
    for name, cam in cams.items():
        f0, f1 = shot_frames(name)
        pts = []
        for f in (f0, (f0 + f1) // 2, f1 + 1):
            sc.frame_set(f); pts.append(tuple(cam.matrix_world.translation))
        paths += [(pts[0], pts[1]), (pts[1], pts[2])]
    sc.frame_set(1)
    dmat = M.emissive("DustMat", (0.15, 0.55, 1.0), 6.0)
    dust = tubes.particles("BrainDust", 650, (0, 0, 0), 5.0, size=(0.004, 0.014), seed=3, avoid=paths, clear=1.0)
    dust.data.materials.append(dmat)
    dust.rotation_euler = (0, 0, 0); dust.keyframe_insert("rotation_euler", frame=1)
    dust.rotation_euler = (0.05, 0.0, 0.5); dust.keyframe_insert("rotation_euler", frame=TOTAL)
    set_interp(dust, "LINEAR")
    adust = tubes.particles("ArmDust", 500, tuple(ARM_O), 5.0, size=(0.005, 0.015), seed=7, avoid=paths, clear=1.4)
    adust.data.materials.append(dmat)

    for name, cam in cams.items():
        f0, _ = shot_frames(name)
        m = sc.timeline_markers.new(name, frame=f0)
        m.camera = cam
    sc.camera = cams["S1a_hook_zoom"]

    # ---------------- render settings
    r = sc.render
    r.engine = "CYCLES"
    r.resolution_x, r.resolution_y = 1080, 1920
    r.resolution_percentage = int(os.environ.get("RES_PCT", "100"))
    r.use_motion_blur = os.environ.get("MBLUR", "1") == "1"
    r.motion_blur_shutter = 0.4
    r.use_persistent_data = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_depth = "16"
    cy = sc.cycles
    cy.device = "CPU"
    cy.samples = int(os.environ.get("SAMPLES", "10"))
    cy.adaptive_threshold = 0.04
    cy.use_denoising = True
    cy.denoising_prefilter = "FAST"
    cy.denoising_input_passes = "RGB_ALBEDO_NORMAL"
    if os.environ.get("THREADS"):
        r.threads_mode = "FIXED"; r.threads = int(os.environ["THREADS"])
    cy.max_bounces = 4; cy.diffuse_bounces = 1; cy.glossy_bounces = 2
    cy.transmission_bounces = 2; cy.transparent_max_bounces = 8
    cy.caustics_reflective = False; cy.caustics_refractive = False
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    return sc, cams, contacts


def active_cam(cams, f):
    cur = None
    for n, a, b in SHOTS:
        if F(a) <= f:
            cur = n
    return cams[cur], cur


def export_projections(sc, cams, contacts, path):
    pts = {"cereb": Vector((0.0, -0.48, -0.30)), "spot": Vector((0.30, -0.12, 0.55)),
           "arc": Vector((0.44, -1.0, 0.30)), "brain": Vector((0, 0, 0.05))}
    out = {}
    for f in range(1, TOTAL + 1):
        sc.frame_set(f)
        cam, shot = active_cam(cams, f)
        d = {"shot": shot}
        for k, p in pts.items():
            v = world_to_camera_view(sc, cam, p)
            d[k] = [v.x, 1 - v.y, v.z]
        if f in contacts:
            who, p = contacts[f]
            v = world_to_camera_view(sc, cam, Vector(p))
            d["contact"] = [who, v.x, 1 - v.y, v.z]
        out[f] = d
    with open(path, "w") as fh:
        json.dump(out, fh)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    sc, cams, contacts = build()
    if args[0] == "--save":
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args[1]))
        export_projections(sc, cams, contacts, os.path.splitext(args[1])[0] + "_proj.json")
    elif args[0] == "--render":
        a, b, outdir = int(args[1]), int(args[2]), args[3]
        step = int(args[4]) if len(args) > 4 else 1
        os.makedirs(outdir, exist_ok=True)
        for f in range(a, b + 1, step):
            fp = os.path.join(outdir, f"f{f:04d}.png")
            if os.path.exists(fp):
                continue
            sc.frame_set(f)
            cam, shot = active_cam(cams, f)
            sc.camera = cam
            sc.render.use_motion_blur = shot in ("S1a_hook_zoom", "S4b_other", "S4c_surprise")
            sc.render.filepath = fp
            bpy.ops.render.render(write_still=True)
