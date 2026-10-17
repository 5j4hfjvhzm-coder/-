// node scripts/test_core.js  — core.js 순수 로직 테스트 (실제 사전 조각을 읽는다)
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const NT = require('../web/core.js');
const meta = JSON.parse(fs.readFileSync(path.join(__dirname, '../web/d/meta.json')));
const cache = {};
function get(key) {
  const n = NT.shardOf(key, meta.shards);
  if (!cache[n]) cache[n] = JSON.parse(fs.readFileSync(path.join(__dirname, `../web/d/${String(n).padStart(2, '0')}.json`)));
  return cache[n][key];
}
let fail = 0;
function t(name, fn) { try { fn(); console.log('ok  ', name); } catch (e) { fail++; console.log('FAIL', name, '\n    ', e.message); } }
const top = (text, at = 0) => { const r = NT.lookupAt(text, at, get); return r[0] && r[0].term; };

t('기본형 그대로', () => assert.strictEqual(top('食べる'), '食べる'));
t('ます형', () => assert.strictEqual(top('食べました。'), '食べる'));
t('5단 과거', () => assert.strictEqual(top('読んだ本'), '読む'));
t('行った', () => assert.strictEqual(top('学校に行った', 3), '行く'));
t('ている', () => assert.strictEqual(top('待っています'), '待つ'));
t('てしまった', () => assert.strictEqual(top('忘れてしまった'), '忘れる'));
t('ちゃった', () => assert.strictEqual(top('食べちゃった'), '食べる'));
t('ない', () => assert.ok(['分かる', '分からない'].includes(top('分からない'))));
t('ない (사전에 없는 꼴)', () => assert.strictEqual(top('読まない'), '読む'));
t('なかった', () => assert.ok(['知る', '知らない'].includes(top('知らなかった'))));
t('なかった (사전에 없는 꼴)', () => assert.strictEqual(top('書かなかった'), '書く'));
t('たい', () => assert.strictEqual(top('行きたくない'), '行く'));
t('い형용사 과거', () => assert.strictEqual(top('楽しかった'), '楽しい'));
t('い형용사 부정', () => assert.strictEqual(top('高くない'), '高い'));
t('する 활용', () => assert.strictEqual(top('勉強しました'), '勉強する'));
t('来る', () => assert.strictEqual(top('来ました'), '来る'));
t('가능형', () => assert.strictEqual(top('話せる'), '話す'));
t('수동형', () => assert.ok(['言う', '言われる'].includes(top('言われた'))));
t('사역형', () => assert.strictEqual(top('待たせた'), '待つ'));
t('히라가나 활용', () => assert.strictEqual(top('たべた'), 'たべる'));
t('명사 긴 일치', () => assert.strictEqual(top('今日は'), '今日'));
t('문장 중간', () => assert.strictEqual(top('私は日本語を勉強しています', 6), '勉強する'));
t('카타카나', () => assert.ok(top('コーヒーを飲む')));
t('결과에 이유', () => { const r = NT.lookupAt('食べました', 0, get)[0]; assert.ok(r.reasons.length >= 1 && r.surface === '食べました'); });

t('정답: 문장 모양', () => assert.ok(NT.isCorrect('食べた', { surface: '食べた', term: '食べる', reading: 'たべる' })));
t('정답: 기본형', () => assert.ok(NT.isCorrect('食べる', { surface: '食べた', term: '食べる', reading: 'たべる' })));
t('정답: 히라가나 활용', () => assert.ok(NT.isCorrect('たべた', { surface: '食べた', term: '食べる', reading: 'たべる' })));
t('정답: 가타카나 → 히라가나', () => assert.ok(NT.isCorrect('タベル', { surface: '食べた', term: '食べる', reading: 'たべる' })));
t('정답: 다른 읽기', () => assert.ok(NT.isCorrect('いく', { surface: '行く', term: '行く', reading: 'ゆく', readings: ['ゆく', 'いく'] })));
t('대표 읽기', () => assert.strictEqual(NT.readingOf(NT.lookupAt('行く', 0, get)[0]), 'いく'));
t('오답', () => assert.ok(!NT.isCorrect('のむ', { surface: '食べた', term: '食べる', reading: 'たべる' })));
t('빈칸', () => { const b = NT.makeBlank('昨日ラーメンを食べた。', '食べた', 7); assert.strictEqual(b.before, '昨日ラーメンを'); assert.strictEqual(b.after, '。'); });
t('힌트', () => assert.strictEqual(NT.firstCharHint('食べた'), '食＿＿ (3글자)'));

t('srt', () => {
  const c = NT.parseSrtVtt('1\n00:00:01,000 --> 00:00:03,500\nこんにちは\n안녕하세요\n\n2\n00:00:04,000 --> 00:00:05,000\n<i>元気？</i>\n');
  assert.strictEqual(c.length, 2); assert.strictEqual(c[0].start, 1000); assert.strictEqual(c[0].end, 3500);
  const { ja, ko } = NT.splitBilingual(c);
  assert.strictEqual(ja[0].text, 'こんにちは'); assert.strictEqual(ko[0].text, '안녕하세요'); assert.strictEqual(ja[1].text, '元気？');
});
t('vtt', () => {
  const c = NT.parseSrtVtt('WEBVTT\n\n00:01.000 --> 00:02.000\nはい\n\n00:02.000 --> 00:03.000 align:start\nいいえ');
  assert.deepStrictEqual(c.map((x) => x.start), [1000, 2000]);
});
t('유튜브 스크립트 (시간 줄 따로)', () => {
  const c = NT.parseTranscript('0:00\n3초\nこんにちは\n0:05\n5초\n今日は\nいい天気');
  assert.strictEqual(c.length, 2); assert.strictEqual(c[1].start, 5000); assert.strictEqual(c[1].text, '今日は いい天気'); assert.strictEqual(c[0].end, 5000);
});
t('유튜브 스크립트 (시간 앞에)', () => {
  const c = NT.parseTranscript('1:02:03 ありがとう\n1:02:05 またね');
  assert.strictEqual(c[0].start, 3723000);
});
t('시간 없는 글', () => { const c = NT.parseTranscript('一行目\n二行目'); assert.strictEqual(c.length, 2); assert.strictEqual(c[0].start, -1); });
t('정렬', () => {
  const a = NT.alignBilingual([{ start: 0, end: 2000, text: 'A' }, { start: 2000, end: 4000, text: 'B' }], [{ start: 100, end: 1900, text: '가' }, { start: 2100, end: 3000, text: '나' }]);
  assert.deepStrictEqual(a.map((x) => x.ko), ['가', '나']);
});
t('영상 ID', () => { assert.strictEqual(NT.parseVideoId('https://youtu.be/dQw4w9WgXcQ?t=3'), 'dQw4w9WgXcQ'); assert.strictEqual(NT.parseVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=x'), 'dQw4w9WgXcQ'); });
t('줄 찾기', () => assert.strictEqual(NT.findCueIndex([{ start: 0 }, { start: 1000 }, { start: 2000 }], 1500), 1));
t('하이라이트', () => { const m = NT.savedRanges('昨日食べた', ['食べた']); assert.deepStrictEqual(Array.from(m), [0, 0, 1, 1, 1]); });
t('분절', () => { const s = NT.segment('私は学生です'); assert.ok(s.length >= 3); assert.strictEqual(s.map((x) => x.text).join(''), '私は学生です'); });
console.log(fail ? `\n${fail}개 실패` : '\n모두 통과');
process.exit(fail ? 1 : 0);
