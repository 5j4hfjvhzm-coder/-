import Foundation

/// After Effects 안에서 실행되는 ExtendScript(JSX).
/// __PLAN__ 자리에 EditPlan JSON, __OUT__ 자리에 저장 경로가 들어가요.
/// ExtendScript는 오래된 JavaScript(ES3)라서 let/const, 화살표 함수, JSON, 배열 indexOf를 쓰지 않아요.
enum Templates {
    static let jsx = #"""
(function () {
var PLAN = __PLAN__;
var OUT = __OUT__;
var warnings = [];

function q(s) {
    s = String(s);
    var r = '"';
    for (var i = 0; i < s.length; i++) {
        var c = s.charAt(i), code = s.charCodeAt(i);
        if (c == '"' || c == '\\') r += '\\' + c;
        else if (code < 32 || code > 126) r += '\\u' + ('0000' + code.toString(16)).slice(-4);
        else r += c;
    }
    return r + '"';
}

function writeDone(ok, msg, renderPath) {
    try {
        var f = new File(OUT.done);
        f.encoding = "UTF-8";
        f.open("w");
        var w = [];
        for (var i = 0; i < warnings.length; i++) w.push(q(warnings[i]));
        f.write('{"ok":' + (ok ? 'true' : 'false') + ',"message":' + q(msg) + ',"render":' + q(renderPath || "") + ',"warnings":[' + w.join(',') + ']}');
        f.close();
    } catch (e) {}
}

function rgb(hex) {
    var h = String(hex).replace("#", "");
    return [parseInt(h.substr(0, 2), 16) / 255, parseInt(h.substr(2, 2), 16) / 255, parseInt(h.substr(4, 2), 16) / 255];
}
function rgba(hex) { var c = rgb(hex); return [c[0], c[1], c[2], 1]; }

function addFx(layer, matchName) {
    try { return layer.property("ADBE Effect Parade").addProperty(matchName); }
    catch (e) { warnings.push("효과를 못 찾았어요: " + matchName); return null; }
}
function setp(fx, idx, v) { if (!fx) return; try { fx.property(idx).setValue(v); } catch (e) {} }
function keyp(fx, idx, times, vals) {
    if (!fx) return;
    try { var p = fx.property(idx); for (var i = 0; i < times.length; i++) p.setValueAtTime(times[i], vals[i]); easeAll(p); } catch (e) {}
}
function easeAll(prop) {
    try {
        var n = 1;
        var t = prop.propertyValueType;
        if (t == PropertyValueType.TwoD) n = 2;
        else if (t == PropertyValueType.ThreeD) n = 3;
        var ein = [], eout = [];
        for (var d = 0; d < n; d++) { ein.push(new KeyframeEase(0, 75)); eout.push(new KeyframeEase(0, 75)); }
        for (var k = 1; k <= prop.numKeys; k++) prop.setTemporalEaseAtKey(k, ein, eout);
    } catch (e) {}
}
function keys(prop, times, vals, ease) {
    for (var i = 0; i < times.length; i++) prop.setValueAtTime(times[i], vals[i]);
    if (ease) easeAll(prop);
}

var cache = {};
var clipFolder = null;
function imp(path) {
    if (cache[path]) return cache[path];
    var f = new File(path);
    if (!f.exists) { warnings.push("파일이 없어요: " + path); return null; }
    try {
        var io = new ImportOptions(f);
        var item = app.project.importFile(io);
        try { item.parentFolder = clipFolder; } catch (e1) {}
        cache[path] = item;
        return item;
    } catch (e) {
        warnings.push("가져오기 실패: " + f.name);
        return null;
    }
}

// ---------- 색보정(CC) ----------
function applyCC(L, cc) {
    var k = cc.intensity;
    var table = {
        dreamy_glow: { bri: 6, con: -6, vib: 25, sat: 0, tint: [[0.18, 0.05, 0.2, 1], [1, 0.86, 0.95, 1], 12], sharp: 0, glowR: 80, glowT: 62 },
        vivid_pop: { bri: 2, con: 18, vib: 40, sat: 10, tint: null, sharp: 18, glowR: 40, glowT: 78 },
        soft_film: { bri: 8, con: -12, vib: -10, sat: -5, tint: [[0.15, 0.08, 0.03, 1], [1, 0.93, 0.82, 1], 15], sharp: 0, glowR: 60, glowT: 70 },
        cool_night: { bri: -2, con: 12, vib: 15, sat: 0, tint: [[0.05, 0.04, 0.2, 1], [0.85, 0.9, 1, 1], 15], sharp: 8, glowR: 70, glowT: 65 },
        clean: { bri: 2, con: 6, vib: 15, sat: 0, tint: null, sharp: 10, glowR: 30, glowT: 85 }
    };
    var P = table[cc.preset] || table.dreamy_glow;
    var bc = addFx(L, "ADBE Brightness & Contrast 2"); setp(bc, 1, P.bri * k); setp(bc, 2, P.con * k);
    var vb = addFx(L, "ADBE Vibrance"); setp(vb, 1, P.vib * k); setp(vb, 2, P.sat * k);
    if (P.tint) { var tn = addFx(L, "ADBE Tint"); setp(tn, 1, P.tint[0]); setp(tn, 2, P.tint[1]); setp(tn, 3, P.tint[2] * k); }
    if (P.sharp > 0) { var sh = addFx(L, "ADBE Sharpen"); setp(sh, 1, P.sharp * k); }
    if (cc.bloom > 0) {
        // 살짝 번지는 효과: 밝은 부분만 부드럽게 퍼지는 글로우
        var gl = addFx(L, "ADBE Glo2");
        setp(gl, 2, P.glowT); setp(gl, 3, P.glowR * (0.5 + cc.bloom)); setp(gl, 4, 0.2 + cc.bloom * 0.8);
    }
    if (cc.grain > 0) { var nz = addFx(L, "ADBE Noise"); setp(nz, 1, cc.grain * 6); setp(nz, 2, false); }
    if (cc.vignette > 0) { var vg = addFx(L, "CC Vignette"); setp(vg, 1, cc.vignette * 60); }
}

// ---------- 자막 ----------
var STROKE = { neon_glow: 3, soft_blur: 0, impact_pop: 8, typewriter: 2, cute_bounce: 7, light_sweep: 2, glitch: 0, minimal: 0 };

function glow(L, hex, thr, rad, inten) {
    var g = addFx(L, "ADBE Glo2");
    if (!g) return;
    setp(g, 2, thr); setp(g, 3, rad); setp(g, 4, inten);
    setp(g, 7, 2);
    setp(g, 12, rgba(hex)); setp(g, 13, rgba(hex));
}
function shadow(L) {
    var d = addFx(L, "ADBE Drop Shadow");
    if (!d) return;
    setp(d, 1, [0, 0, 0, 1]); setp(d, 2, 140); setp(d, 4, 6); setp(d, 5, 18);
}
function rgbSplit(T, off, jitter) {
    var cols = [[1, 0.1, 0.35], [0.1, 0.85, 1]];
    for (var i = 0; i < 2; i++) {
        var D2 = T.duplicate();
        D2.moveAfter(T);
        D2.name = T.name + (i == 0 ? " · R" : " · B");
        var fx = D2.property("ADBE Effect Parade");
        while (fx.numProperties > 0) fx.property(1).remove();
        var tp = D2.property("ADBE Text Properties").property("ADBE Text Document");
        var td = tp.value;
        td.fillColor = cols[i];
        td.applyStroke = false;
        tp.setValue(td);
        D2.blendingMode = BlendingMode.SCREEN;
        var dx = (i == 0 ? -off : off);
        var tr = D2.property("ADBE Transform Group");
        tr.property("ADBE Opacity").expression = "value * 0.75";
        tr.property("ADBE Position").expression = jitter
            ? "posterizeTime(12); value + [" + dx + " + random(-8, 8), random(-3, 3)]"
            : "value + [" + dx + ", 0]";
    }
}
function typewriter(T, t0, t1) {
    var anims = T.property("ADBE Text Properties").property("ADBE Text Animators");
    anims.addProperty("ADBE Text Animator");
    var A = anims.property(anims.numProperties);
    A.property("ADBE Text Animator Properties").addProperty("ADBE Text Opacity");
    A = anims.property(anims.numProperties);
    A.property("ADBE Text Animator Properties").property("ADBE Text Opacity").setValue(0);
    A.property("ADBE Text Selectors").addProperty("ADBE Text Selector");
    A = anims.property(anims.numProperties);
    var st = A.property("ADBE Text Selectors").property(1).property("ADBE Text Percent Start");
    st.setValueAtTime(t0, 0);
    st.setValueAtTime(t1, 100);
}

function makeText(comp, sub, W, H) {
    var T = comp.layers.addText(String(sub.text).replace(/\n/g, "\r"));
    T.name = "자막 " + sub.id;
    var tp = T.property("ADBE Text Properties").property("ADBE Text Document");
    var td = tp.value;
    try { td.resetCharStyle(); td.resetParagraphStyle(); } catch (e0) {}
    td.fontSize = sub.size;
    try { td.font = sub.font; } catch (e1) { warnings.push("폰트를 못 찾았어요: " + sub.font); }
    td.applyFill = true;
    td.fillColor = rgb(sub.color);
    var sw = STROKE[sub.style] || 0;
    if (sw > 0) {
        td.applyStroke = true;
        td.strokeColor = rgb(sub.accent);
        td.strokeWidth = sw * sub.size / 84;
        td.strokeOverFill = false;
    } else {
        td.applyStroke = false;
    }
    td.justification = ParagraphJustification.CENTER_JUSTIFY;
    td.tracking = (sub.style == "minimal") ? 60 : 0;
    tp.setValue(td);
    T.inPoint = sub.start;
    T.outPoint = sub.end;
    var r = T.sourceRectAtTime(sub.start, false);
    var tr = T.property("ADBE Transform Group");
    tr.property("ADBE Anchor Point").setValue([r.left + r.width / 2, r.top + r.height / 2]);
    tr.property("ADBE Position").setValue([W * sub.x, H * sub.y]);
    return T;
}

function animateText(T, sub) {
    var a = sub.start, b = sub.end, len = b - a;
    var inD = Math.min(0.4, len * 0.35), outD = Math.min(0.2, len * 0.2);
    var tr = T.property("ADBE Transform Group");
    var op = tr.property("ADBE Opacity"), sc = tr.property("ADBE Scale");
    var pos = tr.property("ADBE Position"), rot = tr.property("ADBE Rotate Z");
    var P0 = pos.value;
    var sizeK = sub.size / 84;
    function fadeOut() { op.setValueAtTime(b - outD, 100); op.setValueAtTime(b, 0); }

    if (sub.style == "neon_glow") {
        keys(op, [a, a + 0.05, a + 0.09, a + 0.13, a + 0.2], [0, 100, 25, 100, 100], false);
        fadeOut();
        glow(T, sub.accent, 45, 30 * sizeK, 1.6);
        rgbSplit(T, 6 * sizeK, false);
    } else if (sub.style == "soft_blur") {
        var gb = addFx(T, "ADBE Gaussian Blur 2"); keyp(gb, 1, [a, a + inD], [40, 0]);
        keys(op, [a, a + inD], [0, 100], true);
        keys(sc, [a, a + inD], [[112, 112], [100, 100]], true);
        fadeOut();
        glow(T, sub.accent, 60, 25 * sizeK, 0.8);
    } else if (sub.style == "impact_pop") {
        keys(sc, [a, a + 0.12, a + 0.22], [[0, 0], [124, 124], [100, 100]], true);
        keys(op, [a, a + 0.04], [0, 100], false);
        fadeOut();
        var rb = addFx(T, "CC Radial Fast Blur"); keyp(rb, 2, [a, a + 0.25], [70, 0]);
        shadow(T);
    } else if (sub.style == "typewriter") {
        try { typewriter(T, a, a + Math.min(len * 0.6, Math.max(0.3, String(sub.text).length * 0.06))); }
        catch (e) { keys(op, [a, a + inD], [0, 100], true); }
        fadeOut();
        glow(T, sub.accent, 60, 18 * sizeK, 0.7);
        shadow(T);
    } else if (sub.style == "cute_bounce") {
        keys(pos, [a, a + 0.15, a + 0.26, a + 0.34], [[P0[0], P0[1] + 70], [P0[0], P0[1] - 18], [P0[0], P0[1] + 6], [P0[0], P0[1]]], true);
        keys(sc, [a, a + 0.15, a + 0.26], [[70, 70], [106, 106], [100, 100]], true);
        keys(rot, [a, a + 0.15, a + 0.3], [-6, 3, 0], true);
        keys(op, [a, a + 0.08], [0, 100], false);
        fadeOut();
        shadow(T);
    } else if (sub.style == "light_sweep") {
        keys(op, [a, a + inD], [0, 100], true);
        fadeOut();
        var r = T.sourceRectAtTime(a, false);
        var ls = addFx(T, "CC Light Sweep");
        if (ls) {
            var cy = r.top + r.height / 2;
            keyp(ls, 1, [a + 0.1, Math.min(b, a + 0.9)], [[r.left - 150, cy], [r.left + r.width + 150, cy]]);
            setp(ls, 4, 60 * sizeK); setp(ls, 5, 100); setp(ls, 8, [1, 1, 1, 1]);
        }
        glow(T, sub.accent, 55, 22 * sizeK, 1.0);
    } else if (sub.style == "glitch") {
        keys(op, [a, a + 0.03], [0, 100], false);
        fadeOut();
        pos.expression = "posterizeTime(12); var t0 = " + a + "; (time - t0 < 0.45) ? value + [random(-24, 24), random(-6, 6)] : ((random() < 0.1) ? value + [random(-10, 10), 0] : value)";
        rgbSplit(T, 10 * sizeK, true);
    } else {
        keys(op, [a, a + inD], [0, 100], true);
        keys(pos, [a, a + inD], [[P0[0], P0[1] + 24], [P0[0], P0[1]]], true);
        fadeOut();
        shadow(T);
    }
}

// ---------- 메인 ----------
try {
    app.newProject();
    if (!app.project) throw new Error("새 프로젝트를 만들 수 없어요");
    app.beginUndoGroup("EditMaker");

    var W = PLAN.width, H = PLAN.height, D = PLAN.duration, FPS = PLAN.fps;
    clipFolder = app.project.items.addFolder("Clips");
    var comp = app.project.items.addComp("EDIT", W, H, 1.0, D, FPS);
    comp.motionBlur = true;
    comp.frameBlending = true;
    comp.bgColor = [0, 0, 0];

    // 음악 (맨 아래)
    if (PLAN.music) {
        var mi = imp(PLAN.music.path);
        if (mi) {
            var ml = comp.layers.add(mi);
            ml.name = "MUSIC";
            if (mi.hasVideo) ml.enabled = false;
            ml.startTime = -PLAN.music.offset;
            try { ml.inPoint = 0; ml.outPoint = D; } catch (e2) {}
        }
    }

    // 클립
    var flashes = [];
    for (var i = 0; i < PLAN.segments.length; i++) {
        var s = PLAN.segments[i];
        var it = imp(s.clip);
        if (!it) continue;
        var L = comp.layers.add(it);
        L.name = (i + 1) + " " + it.name;
        var len = s.end - s.start;
        var still = (it.mainSource && it.mainSource.isStill) || !(it.duration > 0);
        try { if (it.hasAudio) L.audioEnabled = false; } catch (e3) {}
        var sp = s.speed > 0 ? s.speed : 1;
        if (!still) {
            if (Math.abs(sp - 1) > 0.001) { L.stretch = 100 / sp; L.frameBlendingType = FrameBlendingType.FRAME_MIX; }
            L.startTime = s.start - s.clipIn / sp;
        } else {
            L.startTime = s.start;
        }
        try { L.inPoint = s.start; L.outPoint = s.end; }
        catch (e4) { warnings.push((i + 1) + "번 컷 길이를 맞추지 못했어요"); }

        var base = Math.max(W / it.width, H / it.height) * 100;
        var tr = L.property("ADBE Transform Group");
        var sc = tr.property("ADBE Scale");
        var a = s.start, b = s.end;
        var endScale = base * (1 + (s.push || 0));
        var tIn = Math.min(0.25, len * 0.5);
        if (s.transition == "zoom_punch") {
            var t1 = Math.min(a + 0.22, a + len * 0.6);
            keys(sc, [a, t1, b], [[base * 1.22, base * 1.22], [base * 1.02, base * 1.02], [endScale, endScale]], true);
            L.motionBlur = true;
        } else if (s.push > 0) {
            keys(sc, [a, b], [[base, base], [endScale, endScale]], true);
        } else {
            sc.setValue([base, base]);
        }
        if (s.transition == "blur_in") {
            var gb = addFx(L, "ADBE Gaussian Blur 2"); setp(gb, 3, true); keyp(gb, 1, [a, a + tIn], [60, 0]);
        } else if (s.transition == "radial_blur") {
            var rb = addFx(L, "CC Radial Fast Blur"); keyp(rb, 2, [a, a + tIn], [80, 0]);
        } else if (s.transition == "whip") {
            var pos = tr.property("ADBE Position");
            keys(pos, [a, a + tIn], [[W / 2 + W * 0.35, H / 2], [W / 2, H / 2]], true);
            var db = addFx(L, "ADBE Motion Blur"); setp(db, 1, 90); keyp(db, 2, [a, a + tIn], [120, 0]);
            L.motionBlur = true;
        } else if (s.transition == "flash") {
            flashes.push(a);
        }
        if (s.shake) {
            tr.property("ADBE Position").expression =
                "var t0 = " + a + ", t1 = " + Math.min(b, a + 0.5) + "; (time >= t0 && time < t1) ? wiggle(22, 40 * (1 - (time - t0) / (t1 - t0))) : value";
            L.motionBlur = true;
        }
    }

    // 색보정 조정 레이어
    var adj = comp.layers.addSolid([1, 1, 1], "CC " + PLAN.cc.preset, W, H, 1, D);
    adj.adjustmentLayer = true;
    applyCC(adj, PLAN.cc);
    for (var u = 0; u < PLAN.cc.userPresets.length; u++) {
        try { adj.applyPreset(new File(PLAN.cc.userPresets[u])); }
        catch (e5) { warnings.push("프리셋 적용 실패: " + PLAN.cc.userPresets[u]); }
    }

    // 자막
    for (var j = 0; j < PLAN.subtitles.length; j++) {
        var sub = PLAN.subtitles[j];
        try {
            var T = makeText(comp, sub, W, H);
            animateText(T, sub);
        } catch (e6) {
            warnings.push("자막 " + sub.id + " 만들기 실패: " + e6.toString());
        }
    }

    // 플래시
    var flashSource = null;
    for (var f = 0; f < flashes.length; f++) {
        var F;
        if (!flashSource) { F = comp.layers.addSolid([1, 1, 1], "FLASH", W, H, 1, D); flashSource = F.source; }
        else { F = comp.layers.add(flashSource); }
        F.blendingMode = BlendingMode.ADD;
        var ft = flashes[f];
        F.inPoint = ft;
        F.outPoint = Math.min(D, ft + 0.2);
        keys(F.property("ADBE Transform Group").property("ADBE Opacity"), [ft, ft + 0.16], [85, 0], false);
    }

    // 렌더 대기열
    var renderPath = "";
    try {
        var rqi = app.project.renderQueue.items.add(comp);
        var om = rqi.outputModule(1);
        var tpl = om.templates;
        var pick = null;
        for (var t = 0; t < tpl.length && !pick; t++) if (String(tpl[t]).indexOf("H.264") == 0) pick = tpl[t];
        for (var t2 = 0; t2 < tpl.length && !pick; t2++) if (tpl[t2] == "High Quality") pick = tpl[t2];
        if (pick) om.applyTemplate(pick);
        om.file = new File(OUT.renderBase + ((pick && String(pick).indexOf("H.264") == 0) ? ".mp4" : ".mov"));
        renderPath = om.file.fsName;
    } catch (e7) {
        warnings.push("렌더 대기열 설정 실패: " + e7.toString());
    }

    comp.openInViewer();
    app.endUndoGroup();
    app.project.save(new File(OUT.aep));
    writeDone(true, "완료", renderPath);
} catch (err) {
    try { app.endUndoGroup(); } catch (e8) {}
    writeDone(false, err.toString() + (err.line ? " (줄 " + err.line + ")" : ""), "");
}
})();
"""#
}
