#!/usr/bin/env python3
"""yomichan-ko-dic (한→일 사전) 을 뒤집어 일→한 사전 조각 파일로 만든다.

사용: python3 build_ja_dict.py <yomichan-ko-dic 폴더> <출력 폴더> [--shards 96]

출력: <출력>/d/NN.json  { "일본어 표제어": [[읽기, 한국어 단어, 한국어 뜻, 출처], ...], ... }
      <출력>/d/meta.json { shards, count, sources }
표제어는 한자 표기와 가나 읽기 둘 다로 넣는다. 조각은 표제어 첫 글자로 나눈다. 출처 k = 한국어기초사전(krdict), n = 네이버.
"""
import json, os, re, sys, argparse

KANA = r'぀-ヿー'
JA_CHARS = re.compile(r'^[぀-ヿー㐀-鿿豈-﫿々〆ヶ〇ー・～]+$')


def shard_of(key, n):
    """첫 글자로 조각을 정한다. 활용형을 기본형으로 바꿔도 첫 글자는 그대로라
    한 번 탭할 때 조각 파일 하나만 받으면 된다. (페이지 JS 와 같은 계산)"""
    cp = ord(key[0])
    return (cp * 2654435761 & 0xffffffff) % n


def ko_head(line):
    """'가격표 [價格表]' / '녹신하다  ｛형용사…｝' / '법정 후견인 [法定後見人] [명사]' → ('가격표', '價格表')"""
    line = re.sub(r'[｛{].*?[｝}]', '', line).strip()
    m = re.match(r'^(.*?)\s*\[([^\]]*)\]', line)
    head, hanja = (m.group(1), m.group(2)) if m else (line, '')
    if hanja and re.fullmatch(r'[가-힣·\s]+', hanja):  # [명사] 같은 품사 표시
        hanja = ''
    head = re.sub(r'\s+\[.*$', '', head).strip()
    return head, hanja


def clean_ja(s):
    s = re.sub(r'\(.*?\)|（.*?）|\[.*?\]|〔.*?〕.*$|〈.*?〉', '', s)
    s = s.strip(' 　…。、.,~～')
    return s


class Builder:
    def __init__(self):
        self.d = {}

    def add(self, key, reading, ko, kodef, src, rank=99):
        key = key.strip()
        if not key or len(key) > 16 or not JA_CHARS.match(key):
            return
        lst = self.d.setdefault(key, [])
        for e in lst:
            if e[1] == ko:
                if not e[2] and kodef:
                    e[2] = kodef
                if not e[0] and reading:
                    e[0] = reading
                e[4] = min(e[4], rank)
                return
        lst.append([reading, ko, kodef, src, rank])

    def add_word(self, written, reading, ko, kodef, src, rank=99):
        reading = reading if reading != written else ''
        self.add(written, reading, ko, kodef, src, rank)
        if reading:
            self.add(reading, '', ko, kodef, src, rank)
        # 형용동사 '不安だ' → '不安' 로도
        if written.endswith('だ') and len(written) > 1:
            self.add_word(written[:-1], reading[:-1] if reading.endswith('だ') else reading, ko, kodef, src, rank)


def parse_krdict(path, b):
    seen = set()
    for e in json.load(open(path, encoding='utf-8')):
        for g in e[5]:
            if not isinstance(g, str) or g in seen:
                continue
            seen.add(g)
            lines = g.split('\n')
            head, hanja = ko_head(lines[0])
            ko = head + (f' ({hanja})' if hanja else '')
            rest = lines[1:]
            # 뜻마다 [일본어 대역어, 한국어 뜻, 일본어 뜻] 3줄
            for i in range(0, len(rest), 3):
                jline = re.sub(r'^\d+\.', '', rest[i]).strip()
                kodef = rest[i + 1].strip() if i + 1 < len(rest) else ''
                if '対訳語無し' in jline:
                    continue
                sense = i // 3
                for pos, item in enumerate(jline.split('。')):
                    rank = min(sense, 3) * 4 + min(pos, 3)
                    item = item.strip()
                    if not item:
                        continue
                    m = re.match(r'^(.*?)【(.*?)】$', item)
                    if m:
                        readings = [r for r in m.group(1).split('・') if r]
                        writtens = [w for w in m.group(2).split('・') if w]
                        for w in writtens:
                            for r in readings[:1]:
                                b.add_word(w, r, ko, kodef, 'k', rank)
                        for r in readings[1:]:
                            b.add_word(r, '', ko, kodef, 'k', rank + 1)
                    else:
                        b.add_word(clean_ja(item), '', ko, kodef, 'k', rank)


def parse_naver(path, b):
    seen = set()
    for e in json.load(open(path, encoding='utf-8')):
        for g in e[5]:
            if not isinstance(g, str) or g in seen:
                continue
            seen.add(g)
            lines = g.split('\n')
            head, hanja = ko_head(lines[0])
            ko = head + (f' ({hanja})' if hanja else '')
            for line in lines[1:]:
                line = line.strip()
                if not line or line.startswith('【') or line.startswith('⇒') or line.startswith('='):
                    continue
                if re.search(r'[가-힣]', re.sub(r'〔.*$', '', line)):
                    continue  # 한국어 설명·참고 줄
                for part in re.split(r'[;；。]', line):
                    w = clean_ja(part)
                    if 1 <= len(w) <= 10:
                        b.add_word(w, '', ko, '', 'n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('out')
    ap.add_argument('--shards', type=int, default=96)
    ap.add_argument('--sqlite', help='iOS 앱용 SQLite 파일도 만든다 (표 e: k 표제어, v 항목 JSON)')
    a = ap.parse_args()
    b = Builder()
    parse_krdict(os.path.join(a.src, 'krdict-kr-jp', 'term_bank_1.json'), b)
    parse_naver(os.path.join(a.src, 'naver_kr_jp_dict', 'term_bank_1.json'), b)
    # 가나 표제어에 한자 표기의 읽기를 빌려 오기 (네이버 항목은 읽기가 없다)
    reading_of = {}
    for k, lst in b.d.items():
        for e in lst:
            if e[0] and e[3] == 'k':
                reading_of.setdefault(k, e[0])
    shards = [dict() for _ in range(a.shards)]
    for k, lst in b.d.items():
        def order(e):
            head = e[1].split(' (')[0]
            return (e[3] != 'k', head.startswith('-') or head.endswith('-'), e[4], max(len(head), 2), not e[2])
        lst.sort(key=order)
        r = reading_of.get(k, '')
        for e in lst:
            if not e[0] and r:
                e[0] = r
        out = []
        for e in lst[:14]:
            if e[3] == 'k':
                out.append(e[:3])  # 출처 k 는 생략
            else:
                out.append([e[0], e[1]])
        shards[shard_of(k, a.shards)][k] = out
    if a.sqlite:
        import sqlite3
        if os.path.exists(a.sqlite):
            os.remove(a.sqlite)
        con = sqlite3.connect(a.sqlite)
        con.execute('CREATE TABLE e (k TEXT PRIMARY KEY, v TEXT NOT NULL) WITHOUT ROWID')
        con.executemany('INSERT INTO e VALUES (?, ?)', ((k, json.dumps(v, ensure_ascii=False, separators=(',', ':')))
                                                         for s in shards for k, v in s.items()))
        con.commit()
        con.execute('VACUUM')
        con.close()
    os.makedirs(os.path.join(a.out, 'd'), exist_ok=True)
    for i, s in enumerate(shards):
        with open(os.path.join(a.out, 'd', f'{i:02d}.json'), 'w', encoding='utf-8') as f:
            json.dump(s, f, ensure_ascii=False, separators=(',', ':'))
    with open(os.path.join(a.out, 'd', 'meta.json'), 'w', encoding='utf-8') as f:
        json.dump({'shards': a.shards, 'count': len(b.d)}, f)
    print('표제어', len(b.d))


if __name__ == '__main__':
    main()
