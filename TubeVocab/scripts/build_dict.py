#!/usr/bin/env python3
"""
kaikki.org 위키낱말사전 덤프(wiktextract JSONL) → 앱 내장용 SQLite 사전(dict.db)

  영어판:   https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz
  한국어판: https://kaikki.org/kowiktionary/raw-wiktextract-data.jsonl.gz

예)
  python3 scripts/build_dict.py \
      --en raw-wiktextract-data.jsonl.gz \
      --ko ko-raw-wiktextract-data.jsonl.gz \
      --out TubeVocab/Resources/dict.db

  # 파일 대신 URL 을 줘도 내려받으면서(스트리밍) 바로 변환한다
  python3 scripts/build_dict.py --en https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz ...

  # 크기를 줄이려면 단어 목록(한 줄에 하나)으로 제한. 그 단어로 시작하는 숙어·구동사는 같이 들어간다.
  python3 scripts/build_dict.py --en ... --wordlist top50k.txt --max-examples 1

표준 라이브러리만 쓴다 (Python 3.9+).
"""
from __future__ import annotations

import argparse
import gzip
import io
import json
import os
import sqlite3
import sys
import time
import urllib.request
from typing import Iterable, Iterator

# TubeVocab/Core/Tags.swift 의 tagKorean 와 같은 목록
KEEP_TAGS = {
    "slang", "informal", "colloquial", "idiomatic", "vulgar", "offensive", "derogatory",
    "pejorative", "euphemistic", "humorous", "ironic", "figuratively", "metaphoric", "formal",
    "literary", "archaic", "obsolete", "dated", "rare", "Internet", "Internet-slang", "US", "UK",
    "British", "Australia", "transitive", "intransitive", "countable", "uncountable", "phrasal-verb",
}

# 한국어판은 raw_tags 에 한국어로 들어있는 경우가 많다
KO_RAW_TAGS = {
    "속어": "slang", "비격식": "informal", "구어": "colloquial", "관용": "idiomatic",
    "관용구": "idiomatic", "비속어": "vulgar", "비어": "vulgar", "모욕": "offensive",
    "경멸": "derogatory", "완곡": "euphemistic", "익살": "humorous", "비유": "figuratively",
    "격식": "formal", "문어": "literary", "고어": "archaic", "폐어": "obsolete",
    "드묾": "rare", "미국": "US", "영국": "UK", "타동사": "transitive", "자동사": "intransitive",
    "가산": "countable", "불가산": "uncountable", "인터넷": "Internet",
}

KO_POS = {
    "명사": "noun", "동사": "verb", "형용사": "adj", "부사": "adv", "대명사": "pron",
    "전치사": "prep", "접속사": "conj", "감탄사": "intj", "한정사": "det", "관사": "article",
    "수사": "num", "숙어": "phrase", "관용구": "phrase", "구": "phrase", "속담": "proverb",
    "접두사": "prefix", "접미사": "suffix", "약어": "abbrev", "축약형": "contraction",
}

SKIP_FORM_TAGS = {
    "table-tags", "inflection-template", "class", "romanization", "canonical", "auxiliary",
    "multiword-construction", "error-unknown-tag",
}

# TubeVocab/Core/Phrase.swift 와 같은 자리표시자
PLACEHOLDERS = {"someone", "somebody", "something", "sb", "sth", "one", "one's", "someone's", "somebody's", "oneself"}

DEFAULT_SKIP_POS = {"name", "character", "symbol", "romanization", "punct"}


def open_stream(src: str) -> Iterator[str]:
    """경로 또는 URL, .gz 여부 자동 판단. 줄 단위로 내준다."""
    if src.startswith(("http://", "https://")):
        req = urllib.request.Request(src, headers={"User-Agent": "TubeVocab-dict-builder"})
        raw = urllib.request.urlopen(req)  # noqa: S310 (사용자가 준 URL)
        binary = gzip.GzipFile(fileobj=raw) if src.endswith(".gz") else raw
    else:
        binary = gzip.open(src, "rb") if src.endswith(".gz") else open(src, "rb")
    with io.TextIOWrapper(binary, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                yield line


def iter_entries(src: str, lang_code: str = "en") -> Iterator[dict]:
    n = 0
    t0 = time.time()
    for line in open_stream(src):
        n += 1
        if n % 200_000 == 0:
            print(f"  {src}: {n:,} 줄 ({time.time() - t0:.0f}초)", file=sys.stderr)
        # 언어 필터를 JSON 파싱 전에 빠르게 (영어 항목이 아닌 줄이 대부분)
        if f'"lang_code": "{lang_code}"' not in line and f'"lang_code":"{lang_code}"' not in line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("lang_code") != lang_code or "word" not in obj or "redirect" in obj:
            continue
        yield obj


def phrase_first_token(phrase: str) -> str | None:
    for t in phrase.lower().split():
        if t not in PLACEHOLDERS:
            return t
    return None


def norm(s: str) -> str:
    return s.strip().lower().replace("’", "'")


def sense_tags(sense: dict) -> list[str]:
    tags = []
    for t in sense.get("tags", []) or []:
        if t in KEEP_TAGS:
            tags.append(t)
    for rt in sense.get("raw_tags", []) or []:
        mapped = KO_RAW_TAGS.get(rt.strip())
        if mapped:
            tags.append(mapped)
        elif rt in KEEP_TAGS:
            tags.append(rt)
    for q in [sense.get("qualifier")] if sense.get("qualifier") else []:
        for part in str(q).split(","):
            p = part.strip()
            if p in KEEP_TAGS:
                tags.append(p)
    return list(dict.fromkeys(tags))


def sense_gloss(sense: dict) -> str | None:
    glosses = sense.get("glosses") or sense.get("raw_glosses")
    if not glosses:
        return None
    g = glosses[-1].strip()
    return g or None


def sense_examples(sense: dict, max_examples: int, max_len: int) -> list[dict]:
    out = []
    exs = sense.get("examples") or []
    # 짧은 예문(type=example)을 인용문보다 먼저
    exs = sorted(exs, key=lambda e: (e.get("type") == "quotation", len(e.get("text") or "")))
    for ex in exs:
        text = (ex.get("text") or "").strip()
        if not text or len(text) > max_len:
            continue
        item = {"text": text}
        ko = ex.get("translation") or ex.get("korean")
        if ko:
            item["ko"] = ko.strip()
        out.append(item)
        if len(out) >= max_examples:
            break
    return out


def is_form_sense(sense: dict) -> bool:
    tags = set(sense.get("tags", []) or [])
    return bool(sense.get("form_of") or sense.get("alt_of")) or "form-of" in tags or "alt-of" in tags


def ko_translations(items: Iterable[dict]) -> list[dict]:
    out = []
    for tr in items or []:
        if (tr.get("lang_code") or tr.get("code")) != "ko":
            continue
        w = (tr.get("word") or "").strip()
        if w:
            out.append({"word": w, "sense": (tr.get("sense") or "").strip().lower()})
    return out


def attach_translations(senses: list[dict], trans: list[dict]) -> list[str]:
    """번역란의 sense 설명으로 뜻을 찾아 붙인다. 못 찾은 건 항목 전체 번역으로 돌려준다."""
    leftover = []
    for tr in trans:
        hint = tr["sense"]
        target = None
        if hint:
            for s in senses:
                g = s["gloss"].lower()
                if g.startswith(hint[:40]) or hint in g:
                    target = s
                    break
        if target is not None:
            if tr["word"] not in target["ko"]:
                target["ko"].append(tr["word"])
        elif tr["word"] not in leftover:
            leftover.append(tr["word"])
    return leftover


SCHEMA = """
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE entries(
  id INTEGER PRIMARY KEY,
  word TEXT NOT NULL,
  word_lower TEXT NOT NULL,
  pos TEXT NOT NULL,
  source TEXT NOT NULL,      -- 'en' 영어판(영영), 'ko' 한국어판(영한)
  ipa TEXT,
  ko TEXT                    -- 뜻에 연결 못 한 한국어 번역 JSON 배열
);
CREATE TABLE senses(
  id INTEGER PRIMARY KEY,
  entry_id INTEGER NOT NULL,
  idx INTEGER NOT NULL,
  gloss TEXT NOT NULL,
  tags TEXT NOT NULL,        -- 공백 구분
  examples TEXT NOT NULL,    -- JSON [{text, ko?}]
  ko TEXT NOT NULL           -- JSON 한국어 번역 배열
);
CREATE TABLE forms(form TEXT NOT NULL, lemma TEXT NOT NULL, tags TEXT NOT NULL, PRIMARY KEY(form, lemma)) WITHOUT ROWID;
CREATE TABLE phrases(first TEXT NOT NULL, phrase TEXT NOT NULL, PRIMARY KEY(first, phrase)) WITHOUT ROWID;
"""

INDEXES = """
CREATE INDEX entries_word ON entries(word_lower);
CREATE INDEX senses_entry ON senses(entry_id);
CREATE INDEX forms_lemma ON forms(lemma);
"""


class Builder:
    def __init__(self, out: str, args: argparse.Namespace):
        if os.path.exists(out):
            os.remove(out)
        self.db = sqlite3.connect(out)
        self.db.executescript(SCHEMA)
        self.args = args
        self.wordlist: set[str] | None = None
        if args.wordlist:
            with open(args.wordlist, encoding="utf-8") as f:
                self.wordlist = {norm(l) for l in f if l.strip()}
        self.skip_pos = set(DEFAULT_SKIP_POS) | set(args.skip_pos or [])
        self.stats = {"entries": 0, "senses": 0, "forms": 0, "phrases": 0}
        self.forms: dict[tuple[str, str], str] = {}

    def keep_word(self, word_lower: str) -> bool:
        if self.wordlist is None:
            return True
        if word_lower in self.wordlist:
            return True
        first = word_lower.split()[0] if " " in word_lower else None
        return bool(first and first in self.wordlist)

    def add_form(self, form: str, lemma: str, tags: Iterable[str]):
        f, l = norm(form), norm(lemma)
        if not f or not l or f == l or " " in f or len(f) > 40:
            return
        if self.wordlist is not None and l not in self.wordlist and f not in self.wordlist:
            return
        key = (f, l)
        t = " ".join(t for t in tags if t not in SKIP_FORM_TAGS)
        if key not in self.forms or (t and not self.forms[key]):
            self.forms[key] = t

    def add_entry(self, obj: dict, source: str):
        word = obj["word"].strip()
        wl = norm(word)
        pos = obj.get("pos") or "unknown"
        pos = KO_POS.get(pos, pos)
        if pos in self.skip_pos or not wl or not self.keep_word(wl):
            return

        # 활용형 표 (영어판만 신뢰)
        if source == "en":
            for fm in obj.get("forms", []) or []:
                tags = fm.get("tags", []) or []
                if any(t in SKIP_FORM_TAGS for t in tags):
                    continue
                if fm.get("form"):
                    self.add_form(fm["form"], word, tags)

        senses = []
        for s in obj.get("senses", []) or []:
            if is_form_sense(s):
                if source == "en":
                    for ref in (s.get("form_of") or []) + (s.get("alt_of") or []):
                        if ref.get("word"):
                            self.add_form(word, ref["word"], s.get("tags", []) or [])
                continue
            gloss = sense_gloss(s)
            if not gloss:
                continue
            senses.append({
                "gloss": gloss,
                "tags": sense_tags(s),
                "examples": sense_examples(s, self.args.max_examples, self.args.max_example_len),
                "ko": [t["word"] for t in ko_translations(s.get("translations", []))],
            })
            if len(senses) >= self.args.max_senses:
                break
        if not senses:
            return
        if " " in wl and pos == "verb" and wl.split()[-1] in {"up", "down", "out", "off", "in", "on", "away", "back", "over", "through", "around", "about"}:
            for s in senses:
                if "phrasal-verb" not in s["tags"]:
                    s["tags"].append("phrasal-verb")

        leftover = attach_translations(senses, ko_translations(obj.get("translations", [])))
        ipa = next((snd["ipa"] for snd in obj.get("sounds", []) or [] if snd.get("ipa")), None)

        cur = self.db.execute(
            "INSERT INTO entries(word, word_lower, pos, source, ipa, ko) VALUES (?,?,?,?,?,?)",
            (word, wl, pos, source, ipa, json.dumps(leftover, ensure_ascii=False) if leftover else None),
        )
        eid = cur.lastrowid
        self.db.executemany(
            "INSERT INTO senses(entry_id, idx, gloss, tags, examples, ko) VALUES (?,?,?,?,?,?)",
            [
                (eid, i, s["gloss"], " ".join(s["tags"]), json.dumps(s["examples"], ensure_ascii=False),
                 json.dumps(s["ko"], ensure_ascii=False))
                for i, s in enumerate(senses)
            ],
        )
        self.stats["entries"] += 1
        self.stats["senses"] += len(senses)
        if " " in wl:
            first = phrase_first_token(wl)
            if first:
                self.db.execute("INSERT OR IGNORE INTO phrases(first, phrase) VALUES (?,?)", (first, wl))

    def finish(self):
        self.db.executemany(
            "INSERT OR IGNORE INTO forms(form, lemma, tags) VALUES (?,?,?)",
            [(f, l, t) for (f, l), t in self.forms.items()],
        )
        self.stats["forms"] = len(self.forms)
        self.stats["phrases"] = self.db.execute("SELECT COUNT(*) FROM phrases").fetchone()[0]
        self.db.executescript(INDEXES)
        self.db.executemany(
            "INSERT INTO meta(key, value) VALUES (?,?)",
            [("built_at", time.strftime("%Y-%m-%d")), ("schema", "1")] + [(k, str(v)) for k, v in self.stats.items()],
        )
        self.db.commit()
        self.db.execute("VACUUM")
        self.db.close()


def build(args: argparse.Namespace) -> dict:
    b = Builder(args.out, args)
    for src, source in ((args.en, "en"), (args.ko, "ko")):
        if not src:
            continue
        print(f"[{source}] {src}", file=sys.stderr)
        for i, obj in enumerate(iter_entries(src, "en")):
            if args.limit and i >= args.limit:
                break
            b.add_entry(obj, source)
            if i % 50_000 == 0:
                b.db.commit()
    b.finish()
    return b.stats


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--en", help="영어판 raw-wiktextract-data.jsonl(.gz) 경로 또는 URL")
    p.add_argument("--ko", help="한국어판 raw-wiktextract-data.jsonl(.gz) 경로 또는 URL")
    p.add_argument("--out", default="TubeVocab/Resources/dict.db")
    p.add_argument("--wordlist", help="이 단어들(+그 단어로 시작하는 숙어)만 넣기")
    p.add_argument("--max-senses", type=int, default=15)
    p.add_argument("--max-examples", type=int, default=2)
    p.add_argument("--max-example-len", type=int, default=220)
    p.add_argument("--skip-pos", nargs="*", help="추가로 뺄 품사 (기본: name character symbol ...)")
    p.add_argument("--limit", type=int, default=0, help="파일당 영어 항목 수 제한 (시험용)")
    args = p.parse_args(argv)
    if not args.en and not args.ko:
        p.error("--en 또는 --ko 중 하나는 필요합니다")
    return args


if __name__ == "__main__":
    a = parse_args()
    stats = build(a)
    size = os.path.getsize(a.out) / 1024 / 1024
    print(f"완료: {a.out} ({size:.1f} MB) {stats}", file=sys.stderr)
