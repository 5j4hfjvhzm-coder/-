/* 니혼고 튜브 — 화면과 상관없는 순수 로직 (node 로 테스트: node scripts/test_core.js) */
(function (root) {
  'use strict';

  // ───────── 글자 ─────────
  const KANA_RE = /[぀-ヿ]/;
  const KANJI_RE = /[㐀-鿿豈-﫿々]/;
  const HANGUL_RE = /[가-힣ㄱ-ㆎ]/;
  const JA_WORD_CHAR = /[぀-ヿー㐀-鿿豈-﫿々〆ヶ〇ーa-zA-Z0-9０-９Ａ-Ｚａ-ｚ]/;

  function toHiragana(s) {
    return s.replace(/[ァ-ヶ]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0x60));
  }
  function normalizeAnswer(s) {
    return toHiragana((s || '').normalize('NFKC').replace(/[\s　。、！？!?.,「」『』]/g, ''));
  }
  function isJapanese(s) { return KANA_RE.test(s) || KANJI_RE.test(s); }
  function hasHangul(s) { return HANGUL_RE.test(s); }

  /** 사전 조각 번호 (scripts/build_ja_dict.py 의 shard_of 와 같음) */
  function shardOf(key, n) {
    const cp = key.codePointAt(0);
    return Number((BigInt(cp) * 2654435761n) & 0xffffffffn) % n;
  }

  // ───────── 활용형 → 기본형 (Yomichan 방식의 규칙) ─────────
  // 규칙: [활용 어미, 기본형 어미, 이 어미가 붙은 말이 될 수 있는 품사들(빈 배열 = 원문에서만), 결과 품사, 이유]
  const RULES = [];
  const r = (from, to, inT, outT, why) => RULES.push({ from, to, inT, outT, why });

  // 5단 동사: 기본 어미 → [い단, あ단, え단, お단, て형, た형]
  const GODAN = {
    'う': ['い', 'わ', 'え', 'お', 'って', 'った'],
    'く': ['き', 'か', 'け', 'こ', 'いて', 'いた'],
    'ぐ': ['ぎ', 'が', 'げ', 'ご', 'いで', 'いだ'],
    'す': ['し', 'さ', 'せ', 'そ', 'して', 'した'],
    'つ': ['ち', 'た', 'て', 'と', 'って', 'った'],
    'ぬ': ['に', 'な', 'ね', 'の', 'んで', 'んだ'],
    'ぶ': ['び', 'ば', 'べ', 'ぼ', 'んで', 'んだ'],
    'む': ['み', 'ま', 'め', 'も', 'んで', 'んだ'],
    'る': ['り', 'ら', 'れ', 'ろ', 'って', 'った'],
  };

  /** 품사 하나의 활용 규칙을 만든다. f = {i 연용형, a 미연형, te, ta, ba 가정형, vol 의지형, imp 명령형, pot 가능, pass 수동, caus 사역} */
  function verbRules(base, f, type) {
    const mx = (s, why) => r(f.i + s, base, [], type, why);
    mx('ます', '정중(ます)'); mx('ません', '정중 부정(ません)'); mx('ました', '정중 과거(ました)');
    mx('ませんでした', '정중 과거 부정'); mx('ましょう', '권유(ましょう)'); mx('ましょうか', '권유(ましょうか)');
    mx('まして', '정중 て형'); mx('ながら', '~하면서(ながら)'); mx('なさい', '명령(なさい)');
    mx('そう', '~할 것 같다(そう)'); mx('に', '~하러(に)');
    r(f.i + 'ませ', base, [], type, '정중 명령');
    r(f.i + 'たい', base, ['adj-i'], type, '희망(たい)');
    r(f.i + 'すぎる', base, ['v1'], type, '너무 ~하다(すぎる)');
    r(f.i + 'やすい', base, ['adj-i'], type, '~하기 쉽다');
    r(f.i + 'にくい', base, ['adj-i'], type, '~하기 어렵다');
    r(f.i + 'たがる', base, ['v5'], type, '~하고 싶어하다');
    r(f.i + 'かた', base, [], type, '~하는 법(方)');
    r(f.i + '方', base, [], type, '~하는 법(方)');
    r(f.a + 'ない', base, ['adj-i'], type, '부정(ない)');
    r(f.a + 'ず', base, [], type, '부정(ず)');
    r(f.a + 'ずに', base, [], type, '~하지 않고(ずに)');
    r(f.a + 'ぬ', base, [], type, '부정(ぬ)');
    r(f.a + 'ん', base, [], type, '부정(ん)');
    r(f.a + 'なきゃ', base, [], type, '~해야 해(なきゃ)');
    r(f.a + 'なくちゃ', base, [], type, '~해야 해(なくちゃ)');
    r(f.a + 'なければ', base, [], type, '~하지 않으면');
    r(f.a + 'ないで', base, [], type, '~하지 말고(ないで)');
    r(f.te, base, ['te'], type, 'て형');
    for (const s of ['', 'ら', 'り']) {
      r(f.ta + s, base, s ? [] : ['ta'], type, s === 'ら' ? '~하면(たら)' : s === 'り' ? '~하거나(たり)' : '과거(た)');
    }
    r(f.ba + 'ば', base, [], type, '가정(ば)');
    if (f.vol) r(f.vol, base, [], type, '의지(よう)');
    if (f.imp) for (const imp of [].concat(f.imp)) r(imp, base, [], type, '명령형');
    for (const p of [].concat(f.pot || [])) r(p, base, ['v1'], type, '가능');
    for (const p of [].concat(f.pass || [])) r(p, base, ['v1'], type, '수동');
    for (const p of [].concat(f.caus || [])) r(p, base, ['v1', 'v5'], type, '사역');
  }

  for (const [u, [i, a, e, o, te, ta]] of Object.entries(GODAN)) {
    verbRules(u, { i, a, te, ta, ba: e, vol: o + 'う', imp: e, pot: e + 'る', pass: a + 'れる', caus: [a + 'せる', a + 'す', a + 'せられる', a + 'される'] }, 'v5');
  }
  // 行く 는 て/た형이 특별
  for (const k of ['行', 'い']) {
    r(k + 'って', k + 'く', ['te'], 'v5', 'て형');
    r(k + 'った', k + 'く', ['ta'], 'v5', '과거(た)');
    r(k + 'ったら', k + 'く', [], 'v5', '~하면(たら)');
    r(k + 'ったり', k + 'く', [], 'v5', '~하거나(たり)');
  }
  // 1단 동사
  verbRules('る', { i: '', a: '', te: 'て', ta: 'た', ba: 'れ', vol: 'よう', imp: ['ろ', 'よ'], pot: ['られる', 'れる'], pass: 'られる', caus: ['させる', 'さす', 'させられる'] }, 'v1');
  // する
  verbRules('する', { i: 'し', a: 'し', te: 'して', ta: 'した', ba: 'すれ', vol: 'しよう', imp: ['しろ', 'せよ'], pot: 'できる', pass: 'される', caus: ['させる', 'させられる'] }, 'vs');
  r('さない', 'する', ['adj-i'], 'vs', '부정(ない)');
  r('せず', 'する', [], 'vs', '부정(ず)');
  r('せずに', 'する', [], 'vs', '~하지 않고(ずに)');
  // 来る / くる
  verbRules('くる', { i: 'き', a: 'こ', te: 'きて', ta: 'きた', ba: 'くれ', vol: 'こよう', imp: 'こい', pot: ['こられる', 'これる'], pass: 'こられる', caus: 'こさせる' }, 'vk');
  verbRules('来る', { i: '来', a: '来', te: '来て', ta: '来た', ba: '来れ', vol: '来よう', imp: '来い', pot: ['来られる', '来れる'], pass: '来られる', caus: '来させる' }, 'vk');

  // い형용사
  r('く', 'い', [], 'adj-i', '부사형(く)');
  r('くて', 'い', ['te'], 'adj-i', 'て형(くて)');
  r('かった', 'い', ['ta'], 'adj-i', '과거(かった)');
  r('かったら', 'い', [], 'adj-i', '~하면(かったら)');
  r('かったり', 'い', [], 'adj-i', '~하거나(かったり)');
  r('くない', 'い', ['adj-i'], 'adj-i', '부정(くない)');
  r('くなる', 'い', ['v5'], 'adj-i', '~해지다(くなる)');
  r('くする', 'い', ['vs'], 'adj-i', '~하게 하다(くする)');
  r('ければ', 'い', [], 'adj-i', '가정(ければ)');
  r('けりゃ', 'い', [], 'adj-i', '가정(けりゃ)');
  r('さ', 'い', [], 'adj-i', '명사형(さ)');
  r('そう', 'い', [], 'adj-i', '~해 보인다(そう)');
  r('すぎる', 'い', ['v1'], 'adj-i', '너무 ~하다(すぎる)');
  r('かろう', 'い', [], 'adj-i', '추측(かろう)');
  r('くありません', 'い', [], 'adj-i', '정중 부정');
  r('くありませんでした', 'い', [], 'adj-i', '정중 과거 부정');
  r('き', 'い', [], 'adj-i', '문어체(き)');
  r('げ', 'い', [], 'adj-i', '~한 듯(げ)');
  r('かったです', 'い', [], 'adj-i', '정중 과거');
  r('いです', 'い', [], 'adj-i', '정중(です)');
  r('え', 'い', [], 'adj-i', '구어체(すげえ)');

  // て형 뒤에 붙는 보조 동사·축약 → て형으로
  const TE_AUX = [
    ['いる', ['v1'], '~하고 있다(ている)'], ['る', ['v1'], '~하고 있다(てる)'],
    ['いた', ['ta'], '~하고 있었다(ていた)'], ['た', ['ta'], '~하고 있었다(てた)'],
    ['います', [], '~하고 있습니다'], ['ます', [], '~하고 있습니다(てます)'],
    ['しまう', ['v5'], '~해 버리다(てしまう)'], ['おく', ['v5'], '~해 두다(ておく)'],
    ['ある', ['v5'], '~해 있다(てある)'], ['いく', ['v5'], '~해 가다(ていく)'],
    ['くる', ['vk'], '~해 오다(てくる)'], ['みる', ['v1'], '~해 보다(てみる)'],
    ['あげる', ['v1'], '~해 주다(てあげる)'], ['くれる', ['v1'], '~해 주다(てくれる)'],
    ['もらう', ['v5'], '~해 받다(てもらう)'], ['ください', [], '~해 주세요(てください)'],
    ['くれ', [], '~해 줘(てくれ)'], ['ほしい', ['adj-i'], '~해 줬으면(てほしい)'],
    ['も', [], '~해도(ても)'], ['は', [], '~해서는(ては)'], ['いい', [], '~해도 된다'],
    ['よ', [], '~해 줘(てよ)'], ['ね', [], '~해 줘(てね)'],
  ];
  for (const [aux, inT, why] of TE_AUX) {
    r('て' + aux, 'て', inT, 'te', why);
    r('で' + aux, 'で', inT, 'te', why);
  }
  // 축약형
  r('ちゃう', 'て', ['v5'], 'te', '~해 버리다(ちゃう)');
  r('じゃう', 'で', ['v5'], 'te', '~해 버리다(じゃう)');
  r('ちまう', 'て', ['v5'], 'te', '~해 버리다(ちまう)');
  r('ちゃ', 'て', [], 'te', '~하면(ちゃ)');
  r('じゃ', 'で', [], 'te', '~하면(じゃ)');
  r('とく', 'て', ['v5'], 'te', '~해 두다(とく)');
  r('どく', 'で', ['v5'], 'te', '~해 두다(どく)');
  r('とる', 'て', ['v5'], 'te', '~하고 있다(とる)');

  // 가장 긴 어미부터
  RULES.sort((x, y) => y.from.length - x.from.length);

  /** 활용형으로 보이는 말 → 기본형 후보들 [{term, reasons, type}] (원문 자체도 포함) */
  function deinflect(text) {
    const out = [{ term: text, reasons: [], types: null }];
    const seen = new Map([[text + '|', true]]);
    for (let k = 0; k < out.length && out.length < 200; k++) {
      const c = out[k];
      if (c.reasons.length >= 5) continue;
      for (const rule of RULES) {
        if (c.types && !rule.inT.some((t) => c.types.includes(t))) continue;
        if (!c.term.endsWith(rule.from)) continue;
        const stem = c.term.slice(0, c.term.length - rule.from.length);
        if (!stem && rule.to.length <= 1) continue;
        const term = stem + rule.to;
        const key = term + '|' + rule.outT;
        if (seen.has(key)) continue;
        seen.set(key, true);
        out.push({ term, reasons: [rule.why].concat(c.reasons), types: [rule.outT] });
      }
    }
    return out;
  }

  /** 활용 품사가 그 기본형 어미와 맞는지 (예: v1 은 る 로 끝나야) */
  function typeFits(term, types) {
    if (!types) return true;
    const t = types[0];
    if (t === 'v1') return term.endsWith('る');
    if (t === 'v5') return /[うくぐすつぬぶむる]$/.test(term);
    if (t === 'vs') return term.endsWith('する');
    if (t === 'vk') return term.endsWith('くる') || term.endsWith('来る');
    if (t === 'adj-i') return term.endsWith('い');
    return true; // te, ta 는 중간 단계
  }

  // ───────── 사전 조회 ─────────
  const STOP = /[\s　、。！？!?,.・「」『』（）()【】〈〉《》…‥〜~"'“”‘’♪→]/;

  /**
   * 문장 text 의 at 번째 글자에서 시작하는 가장 긴 사전 단어를 찾는다.
   * getEntries(key) → 사전 항목 배열 또는 undefined (같은 첫 글자 조각에서 동기 조회)
   * 돌려주는 값: [{surface, start, len, term, reasons, entries}] 긴 것부터
   */
  function lookupAt(text, at, getEntries, maxLen) {
    maxLen = maxLen || 18;
    let s = '';
    for (let i = at; i < text.length && s.length < maxLen; i++) {
      const ch = text[i];
      if (STOP.test(ch)) break;
      s += ch;
    }
    const results = [];
    const seenTerms = new Set();
    for (let len = s.length; len >= 1; len--) {
      const sub = s.slice(0, len);
      const subs = [sub];
      const hira = toHiragana(sub);
      if (hira !== sub) subs.push(hira);
      for (const q of subs) {
        for (const c of deinflect(q)) {
          if (!typeFits(c.term, c.types)) continue;
          if (c.types && (c.types[0] === 'te' || c.types[0] === 'ta')) continue;
          if (seenTerms.has(c.term)) continue;
          const entries = getEntries(c.term);
          if (entries && entries.length) {
            seenTerms.add(c.term);
            results.push({ surface: text.substr(at, len), start: at, len, term: c.term, reasons: c.reasons, entries });
          }
        }
      }
    }
    // 같은 길이면 활용 단계가 적은 쪽
    results.sort((a, b) => b.len - a.len || a.reasons.length - b.reasons.length);
    return results;
  }

  /** 검색창: 입력 전체를 활용형까지 풀어서 찾기, 없으면 앞부분 가장 긴 단어 */
  function lookupQuery(q, getEntries) {
    q = (q || '').trim().normalize('NFKC');
    if (!q) return [];
    return lookupAt(q, 0, getEntries, 24);
  }

  /** 조회 결과의 대표 읽기 */
  function readingOf(res) {
    const rs = readingsOf(res);
    return rs[0] || '';
  }
  /** 항목들의 읽기 (많이 나온 순) */
  function readingsOf(res) {
    const n = new Map();
    for (const e of res.entries) if (e[0]) n.set(e[0], (n.get(e[0]) || 0) + 1);
    return [...n.entries()].sort((a, b) => b[1] - a[1]).map((x) => x[0]);
  }

  // ───────── 자막 ─────────
  function toMs(h, m, s, frac) {
    const f = frac ? Number((frac + '00').slice(0, 3)) : 0;
    return ((Number(h || 0) * 60 + Number(m)) * 60 + Number(s)) * 1000 + f;
  }

  function stripTags(s) {
    return s.replace(/<[^>]+>/g, '').replace(/\{\\[^}]*\}/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').trim();
  }

  /** .srt / .vtt → [{start, end, text}] */
  function parseSrtVtt(raw) {
    const text = raw.replace(/^﻿/, '').replace(/\r\n?/g, '\n');
    const blocks = text.split(/\n{2,}/);
    const timeRe = /(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[.,](\d{1,3})\s*-->\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[.,](\d{1,3})/;
    const out = [];
    for (const b of blocks) {
      const lines = b.split('\n');
      const ti = lines.findIndex((l) => timeRe.test(l));
      if (ti < 0) continue;
      const m = lines[ti].match(timeRe);
      const body = lines.slice(ti + 1).map(stripTags).filter(Boolean);
      if (!body.length) continue;
      out.push({ start: toMs(m[1], m[2], m[3], m[4]), end: toMs(m[5], m[6], m[7], m[8]), lines: body, text: body.join(' ') });
    }
    // 자동 생성 VTT 처럼 같은 줄이 겹쳐 나오면 합친다
    const merged = [];
    for (const c of out) {
      const prev = merged[merged.length - 1];
      if (prev && prev.text === c.text) { prev.end = Math.max(prev.end, c.end); continue; }
      merged.push(c);
    }
    return merged;
  }

  const TS_RE = /^(?:(\d{1,2}):)?(\d{1,2}):(\d{2})$/;
  const TS_LEAD_RE = /^(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\s+(.+)$/;
  const SPOKEN_TIME_RE = /^(\d+\s*(시간|분|초)\s*)+$|^(\d+\s*(hours?|minutes?|seconds?)\s*,?\s*)+$/i;

  /** 유튜브 "스크립트 표시" 복사 글, 또는 그냥 줄마다 쓴 글 → [{start, end, text}] (시간이 없으면 start = -1) */
  function parseTranscript(raw) {
    const lines = raw.replace(/^﻿/, '').replace(/\r\n?/g, '\n').split('\n').map((l) => l.trim());
    if (/-->/.test(raw)) return parseSrtVtt(raw);
    const cues = [];
    let cur = null;
    let anyTime = false;
    for (const l of lines) {
      if (!l) continue;
      let m = l.match(TS_RE);
      if (m) {
        anyTime = true;
        cur = { start: toMs(m[1], m[2], m[3]), end: 0, lines: [] };
        cues.push(cur);
        continue;
      }
      if (SPOKEN_TIME_RE.test(l)) continue;
      m = l.match(TS_LEAD_RE);
      if (m) {
        anyTime = true;
        cur = { start: toMs(m[1], m[2], m[3]), end: 0, lines: [m[4]] };
        cues.push(cur);
        continue;
      }
      if (cur && anyTime) { cur.lines.push(l); continue; }
      cues.push({ start: -1, end: -1, lines: [l] });
    }
    const out = cues.filter((c) => c.lines.length).map((c) => ({ start: c.start, end: c.end, lines: c.lines, text: c.lines.join(' ') }));
    for (let i = 0; i < out.length; i++) {
      if (out[i].start < 0) continue;
      const next = out[i + 1];
      out[i].end = next && next.start > out[i].start ? next.start : out[i].start + 4000;
    }
    return out;
  }

  /** 한 자막 안에 일본어·한국어가 섞여 있으면 줄마다 나눈다 */
  function splitBilingual(cues) {
    const ja = [], ko = [];
    for (const c of cues) {
      const jl = [], kl = [];
      for (const l of c.lines || [c.text]) (hasHangul(l) && !KANA_RE.test(l) ? kl : jl).push(l);
      if (jl.length) ja.push({ start: c.start, end: c.end, text: jl.join(' ') });
      if (kl.length) ko.push({ start: c.start, end: c.end, text: kl.join(' ') });
    }
    return { ja, ko };
  }

  /** 일본어 줄마다 시간이 가장 많이 겹치는 한국어 줄을 붙인다 → [{start, end, ja, ko}] */
  function alignBilingual(ja, ko) {
    if (!ja.length) return ko.map((k) => ({ start: k.start, end: k.end, ja: '', ko: k.text }));
    const out = ja.map((j) => ({ start: j.start, end: j.end, ja: j.text, ko: '' }));
    const timed = ja.every((j) => j.start >= 0) && ko.every((k) => k.start >= 0);
    if (!timed) {
      // 시간이 없으면 순서대로
      ko.forEach((k, i) => { if (out[i]) out[i].ko = k.text; });
      return out;
    }
    const parts = out.map(() => []);
    let jStart = 0;
    for (const k of ko) {
      let best = -1, bestOv = 0;
      while (jStart < ja.length && ja[jStart].end <= k.start - 10000) jStart++;
      for (let i = jStart; i < ja.length && ja[i].start < k.end; i++) {
        const ov = Math.min(ja[i].end, k.end) - Math.max(ja[i].start, k.start);
        if (ov > bestOv) { bestOv = ov; best = i; }
      }
      if (best < 0) {
        // 안 겹치면 시작 시간이 가장 가까운 줄
        let d = Infinity;
        for (let i = 0; i < ja.length; i++) {
          const dd = Math.abs(ja[i].start - k.start);
          if (dd < d) { d = dd; best = i; }
        }
        if (d > 3000) best = -1;
      }
      if (best >= 0) parts[best].push(k.text);
    }
    parts.forEach((p, i) => { out[i].ko = p.join(' '); });
    return out;
  }

  /** 글(들) 하나를 읽어 언어별로 나눈다 */
  function parseAny(raw) {
    const cues = /-->/.test(raw) ? parseSrtVtt(raw) : parseTranscript(raw);
    return splitBilingual(cues);
  }

  /** time 에 해당하는 줄 번호 (없으면 직전 줄, 처음 전이면 -1) */
  function findCueIndex(cues, ms) {
    let lo = 0, hi = cues.length - 1, ans = -1;
    while (lo <= hi) {
      const mid = (lo + hi) >> 1;
      if (cues[mid].start <= ms) { ans = mid; lo = mid + 1; } else hi = mid - 1;
    }
    return ans;
  }

  function formatTime(ms) {
    if (ms == null || ms < 0) return '';
    const s = Math.floor(ms / 1000);
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), ss = s % 60;
    return (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(ss).padStart(2, '0');
  }

  function parseVideoId(input) {
    const s = (input || '').trim();
    if (/^[\w-]{11}$/.test(s)) return s;
    const m = s.match(/(?:youtu\.be\/|[?&]v=|\/shorts\/|\/embed\/|\/live\/)([\w-]{11})/);
    return m ? m[1] : null;
  }

  // ───────── 빈칸 시험 ─────────
  /** 문장에서 저장한 표현 자리를 빈칸으로. {before, answer, after} */
  function makeBlank(sentence, surface, start) {
    let i = -1;
    if (start != null && sentence.substr(start, surface.length) === surface) i = start;
    if (i < 0) i = sentence.indexOf(surface);
    if (i < 0) return { before: sentence + ' ', answer: surface, after: '' };
    return { before: sentence.slice(0, i), answer: surface, after: sentence.slice(i + surface.length) };
  }

  /** 정답 판정: 문장 속 모양, 기본형, 기본형 읽기, 다른 활용형(히라가나 포함) 모두 인정 */
  function isCorrect(answer, word) {
    const a = normalizeAnswer(answer);
    if (!a) return false;
    const ok = new Set([word.surface, word.term, word.reading].concat(word.readings || []).filter(Boolean).map(normalizeAnswer));
    if (ok.has(a)) return true;
    for (const c of deinflect(a)) if (typeFits(c.term, c.types) && ok.has(normalizeAnswer(c.term))) return true;
    return false;
  }

  /** 힌트: 첫 글자 + 글자 수 */
  function firstCharHint(answer) {
    const chars = Array.from(answer);
    return chars[0] + '＿'.repeat(Math.max(0, chars.length - 1)) + ' (' + chars.length + '글자)';
  }

  // ───────── 저장 단어 하이라이트 ─────────
  /** text 에서 저장 단어(surface·term)가 있는 글자 위치 → Set */
  function savedRanges(text, needles) {
    const marks = new Uint8Array(text.length);
    for (const n of needles) {
      if (!n || n.length < 1) continue;
      if (n.length === 1 && !KANJI_RE.test(n)) continue;
      let i = text.indexOf(n);
      while (i >= 0) {
        for (let k = i; k < i + n.length; k++) marks[k] = 1;
        i = text.indexOf(n, i + n.length);
      }
    }
    return marks;
  }

  /** 탭할 단위로 나누기: [{text, start, word}] */
  function segment(text) {
    const out = [];
    let seg = null;
    try { seg = new Intl.Segmenter('ja', { granularity: 'word' }); } catch (e) { seg = null; }
    if (seg) {
      for (const s of seg.segment(text)) out.push({ text: s.segment, start: s.index, word: s.isWordLike !== false && JA_WORD_CHAR.test(s.segment) });
      return out;
    }
    let i = 0;
    for (const ch of Array.from(text)) { out.push({ text: ch, start: i, word: JA_WORD_CHAR.test(ch) }); i += ch.length; }
    return out;
  }

  const api = {
    toHiragana, normalizeAnswer, isJapanese, hasHangul, shardOf, deinflect, typeFits, lookupAt, lookupQuery, readingOf, readingsOf,
    parseSrtVtt, parseTranscript, splitBilingual, alignBilingual, parseAny, findCueIndex, formatTime, parseVideoId,
    makeBlank, isCorrect, firstCharHint, savedRanges, segment, RULES,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.NT = api;
})(typeof self !== 'undefined' ? self : this);
