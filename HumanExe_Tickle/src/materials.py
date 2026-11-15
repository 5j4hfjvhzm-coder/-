"""Shader node materials: glowing cortex, hologram skin, emissive fibers."""
import bpy


def _nodes(mat):
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    return nt, nt.nodes, nt.links


def value(nodes, name, v):
    n = nodes.new("ShaderNodeValue")
    n.name = n.label = name
    n.outputs[0].default_value = v
    return n


def math(nodes, links, op, a, b=None, clamp=False):
    n = nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, x in enumerate([a, b]):
        if x is None:
            continue
        if isinstance(x, (int, float)):
            n.inputs[i].default_value = x
        else:
            links.new(x, n.inputs[i])
    return n.outputs[0]


def frame_driver(socket, expr):
    fc = socket.driver_add("default_value")
    fc.driver.expression = expr
    return fc


def cortex(name, glow_col=(0.03, 0.42, 1.0), seed=0.0, spot_c=(0.0, 0.0, 0.0), spot_r=0.3):
    """Dark wet tissue with electric-blue light living in the sulci."""
    mat = bpy.data.materials.new(name)
    nt, N, L = _nodes(mat)
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.020, 0.035, 0.070, 1)
    bsdf.inputs["Roughness"].default_value = 0.32
    bsdf.inputs["Coat Weight"].default_value = 0.6
    bsdf.inputs["Coat Roughness"].default_value = 0.12
    bsdf.inputs["Specular IOR Level"].default_value = 0.6
    attr = N.new("ShaderNodeAttribute"); attr.attribute_name = "sulc"
    groove = math(N, L, "SUBTRACT", 1.0, attr.outputs["Fac"], clamp=True)
    groove2 = math(N, L, "POWER", groove, 1.6)

    glow = value(N, "glow", 1.4)
    rim = value(N, "rim", 1.2)
    pulse = value(N, "pulse", 5.0)
    flash = value(N, "flash", 0.0)
    hi = value(N, "highlight", 0.0)

    lw = N.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.35
    rimf = math(N, L, "POWER", lw.outputs["Facing"], 2.5)

    tc = N.new("ShaderNodeTexCoord")
    nz = N.new("ShaderNodeTexNoise"); nz.noise_dimensions = "4D"
    nz.inputs["Scale"].default_value = 2.6
    nz.inputs["Detail"].default_value = 3.0
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    frame_driver(nz.inputs["W"], f"frame/22+{seed}")
    # thin travelling bands of activity (electrical pulses)
    band = math(N, L, "SUBTRACT", nz.outputs["Fac"], 0.5)
    band = math(N, L, "ABSOLUTE", band)
    band = math(N, L, "LESS_THAN", band, 0.006)
    nz2 = N.new("ShaderNodeTexNoise"); nz2.noise_dimensions = "4D"
    nz2.inputs["Scale"].default_value = 1.2
    L.new(tc.outputs["Object"], nz2.inputs["Vector"])
    frame_driver(nz2.inputs["W"], f"frame/35+{seed}+7")
    gate = math(N, L, "GREATER_THAN", nz2.outputs["Fac"], 0.55)
    pulses = math(N, L, "MULTIPLY", band, gate)

    e = math(N, L, "MULTIPLY", groove2, glow.outputs[0])
    e = math(N, L, "ADD", e, math(N, L, "MULTIPLY", rimf, rim.outputs[0]))
    e = math(N, L, "ADD", e, math(N, L, "MULTIPLY", pulses, pulse.outputs[0]))
    e = math(N, L, "ADD", e, math(N, L, "MULTIPLY", flash.outputs[0],
                                    math(N, L, "ADD", groove, 0.35)))
    e = math(N, L, "ADD", e, math(N, L, "MULTIPLY", hi.outputs[0],
                                    math(N, L, "ADD", groove2, 0.18)))
    spot = value(N, "spot", 0.0)
    sv = N.new("ShaderNodeVectorMath"); sv.operation = "DISTANCE"
    L.new(tc.outputs["Object"], sv.inputs[0])
    sv.inputs[1].default_value = spot_c
    sd = math(N, L, "DIVIDE", sv.outputs["Value"], spot_r)
    sd = math(N, L, "POWER", sd, 2.0)
    sd = math(N, L, "MULTIPLY", sd, -1.0)
    sd = math(N, L, "EXPONENT", sd)
    e = math(N, L, "ADD", e, math(N, L, "MULTIPLY", math(N, L, "MULTIPLY", sd, spot.outputs[0]),
                                    math(N, L, "ADD", groove, 0.25)))
    bsdf.inputs["Emission Color"].default_value = (*glow_col, 1)
    L.new(e, bsdf.inputs["Emission Strength"])
    L.new(bsdf.outputs[0], out.inputs[0])
    return mat


def hologram(name, col=(0.05, 0.45, 1.0), base=(0.01, 0.02, 0.05)):
    """Anatomical x-ray hologram skin: fresnel edge glow + scanlines."""
    mat = bpy.data.materials.new(name)
    nt, N, L = _nodes(mat)
    out = N.new("ShaderNodeOutputMaterial")
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*base, 1)
    bsdf.inputs["Roughness"].default_value = 0.35
    bsdf.inputs["Coat Weight"].default_value = 0.4
    bsdf.inputs["Emission Color"].default_value = (*col, 1)
    lw = N.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.45
    rimf = math(N, L, "POWER", lw.outputs["Facing"], 2.2)
    edge = value(N, "edge", 4.0)
    fill = value(N, "fill", 0.12)
    flash = value(N, "flash", 0.0)
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sep.inputs[0])
    scan = math(N, L, "MULTIPLY", sep.outputs["Z"], 90.0)
    scan = math(N, L, "SINE", scan)
    scan = math(N, L, "GREATER_THAN", scan, 0.92)
    e = math(N, L, "MULTIPLY", rimf, edge.outputs[0])
    e = math(N, L, "ADD", e, fill.outputs[0])
    e = math(N, L, "ADD", e, math(N, L, "MULTIPLY", scan, 0.25))
    e = math(N, L, "ADD", e, flash.outputs[0])
    L.new(e, bsdf.inputs["Emission Strength"])
    # partially see-through
    tr = N.new("ShaderNodeBsdfTransparent")
    mix = N.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.78
    L.new(tr.outputs[0], mix.inputs[1])
    L.new(bsdf.outputs[0], mix.inputs[2])
    L.new(mix.outputs[0], out.inputs[0])
    return mat


def emissive(name, col=(0.1, 0.6, 1.0), strength=8.0):
    mat = bpy.data.materials.new(name)
    nt, N, L = _nodes(mat)
    out = N.new("ShaderNodeOutputMaterial")
    em = N.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*col, 1)
    s = value(N, "strength", strength)
    L.new(s.outputs[0], em.inputs["Strength"])
    L.new(em.outputs[0], out.inputs[0])
    return mat


def fiber(name, col=(0.05, 0.5, 1.0), strength=1.5):
    """Dim emissive tube with a travelling bright pulse along curve length.
    Pulse position is driven by the 'phase' value (0..1 along the curve)."""
    mat = bpy.data.materials.new(name)
    nt, N, L = _nodes(mat)
    out = N.new("ShaderNodeOutputMaterial")
    em = N.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*col, 1)
    ua = N.new("ShaderNodeAttribute"); ua.attribute_name = "u"
    phase = value(N, "phase", -1.0)
    base = value(N, "base", strength)
    peak = value(N, "peak", 60.0)
    d = math(N, L, "SUBTRACT", ua.outputs["Fac"], phase.outputs[0])
    # sharp head, soft tail behind the head
    head = math(N, L, "MULTIPLY", d, 40.0)
    head = math(N, L, "ABSOLUTE", head)
    head = math(N, L, "MULTIPLY", head, -1.0)
    head = math(N, L, "EXPONENT", head)
    tail = math(N, L, "MULTIPLY", d, 9.0)
    tail = math(N, L, "MINIMUM", tail, 0.0)
    tail = math(N, L, "EXPONENT", tail)
    tail = math(N, L, "MULTIPLY", tail, math(N, L, "LESS_THAN", d, 0.0))
    t = math(N, L, "ADD", head, math(N, L, "MULTIPLY", tail, 0.35))
    s = math(N, L, "ADD", base.outputs[0], math(N, L, "MULTIPLY", t, peak.outputs[0]))
    L.new(s, em.inputs["Strength"])
    L.new(em.outputs[0], out.inputs[0])
    return mat


def key_value(mat, name, frame_vals, interp="BEZIER"):
    """frame_vals: list of (frame, value)."""
    node = mat.node_tree.nodes[name]
    sock = node.outputs[0]
    for f, v in frame_vals:
        sock.default_value = v
        sock.keyframe_insert("default_value", frame=f)
    ad = mat.node_tree.animation_data
    if ad and ad.action:
        _set_interp(ad.action, interp)


def _set_interp(action, interp):
    fcs = []
    try:
        fcs = list(action.fcurves)
    except AttributeError:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    fcs += list(bag.fcurves)
    for fc in fcs:
        for kp in fc.keyframe_points:
            kp.interpolation = interp
