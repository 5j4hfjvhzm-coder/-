"""변환 스크립트 테스트:  python3 -m unittest discover -s scripts -p 'test_*.py'"""
import gzip
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_dict  # noqa: E402


class BuildDictTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run([sys.executable, os.path.join(HERE, "sample", "make_sample.py")], check=True, capture_output=True)
        cls.tmp = tempfile.mkdtemp()
        # .gz 경로도 확인하려고 영어판은 압축해서 넣는다
        en_gz = os.path.join(cls.tmp, "en.jsonl.gz")
        with open(os.path.join(HERE, "sample", "en-sample.jsonl"), "rb") as src, gzip.open(en_gz, "wb") as dst:
            shutil.copyfileobj(src, dst)
        cls.out = os.path.join(cls.tmp, "dict.db")
        args = build_dict.parse_args(["--en", en_gz, "--ko", os.path.join(HERE, "sample", "ko-sample.jsonl"), "--out", cls.out])
        cls.stats = build_dict.build(args)
        cls.db = sqlite3.connect(cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.db.close()
        shutil.rmtree(cls.tmp)

    def q(self, sql, *params):
        return self.db.execute(sql, params).fetchall()

    def test_filters_non_english_redirect_and_names(self):
        self.assertEqual(self.q("SELECT * FROM entries WHERE word_lower IN ('aller','paris','가다')"), [])

    def test_form_of_entries_become_forms(self):
        # went 는 항목이 아니라 활용형 표로
        self.assertEqual(self.q("SELECT * FROM entries WHERE word_lower='went'"), [])
        self.assertIn(("went", "go"), self.q("SELECT form, lemma FROM forms WHERE form='went'"))
        self.assertIn(("saw", "see"), self.q("SELECT form, lemma FROM forms WHERE form='saw'"))
        # 명사 saw(톱)는 그대로
        self.assertEqual(self.q("SELECT pos FROM entries WHERE word_lower='saw' AND source='en'"), [("noun",)])

    def test_inflection_table(self):
        forms = {r[0] for r in self.q("SELECT form FROM forms WHERE lemma='give'")}
        self.assertTrue({"gives", "gave", "given", "giving"} <= forms)

    def test_tags_and_examples(self):
        rows = self.q(
            "SELECT s.gloss, s.tags, s.examples FROM senses s JOIN entries e ON e.id=s.entry_id "
            "WHERE e.word_lower='cool' AND e.source='en' ORDER BY s.idx"
        )
        self.assertEqual(rows[1][1].split(), ["slang", "informal"])
        self.assertEqual(json.loads(rows[1][2])[0]["text"], "That's so cool!")

    def test_korean_translations_attached_to_sense(self):
        rows = self.q(
            "SELECT s.gloss, s.ko FROM senses s JOIN entries e ON e.id=s.entry_id "
            "WHERE e.word_lower='give up' AND e.source='en' ORDER BY s.idx"
        )
        self.assertEqual(json.loads(rows[0][1]), ["포기하다"])
        self.assertEqual(json.loads(rows[1][1]), ["끊다"])

    def test_korean_edition(self):
        rows = self.q(
            "SELECT e.pos, s.gloss, s.tags FROM senses s JOIN entries e ON e.id=s.entry_id "
            "WHERE e.word_lower='cool' AND e.source='ko' ORDER BY s.idx"
        )
        self.assertEqual(rows[0][0], "adj")  # 형용사 → adj
        self.assertEqual(rows[1], ("adj", "멋진, 끝내주는", "slang"))  # raw_tags 속어 → slang
        ex = self.q(
            "SELECT s.examples FROM senses s JOIN entries e ON e.id=s.entry_id WHERE e.word_lower='go' AND e.source='ko' AND s.idx=0"
        )
        self.assertEqual(json.loads(ex[0][0]), [{"text": "Let's go home.", "ko": "집에 가자."}])

    def test_phrases(self):
        self.assertIn(("give", "give up"), self.q("SELECT * FROM phrases"))
        self.assertIn(("make", "make up one's mind"), self.q("SELECT * FROM phrases"))
        tags = self.q("SELECT s.tags FROM senses s JOIN entries e ON e.id=s.entry_id WHERE e.word_lower='pick up' AND e.source='en' AND s.idx=0")
        self.assertIn("phrasal-verb", tags[0][0].split())

    def test_wordlist(self):
        wl = os.path.join(self.tmp, "wl.txt")
        with open(wl, "w") as f:
            f.write("give\ncool\n")
        out = os.path.join(self.tmp, "small.db")
        args = build_dict.parse_args(["--en", os.path.join(HERE, "sample", "en-sample.jsonl"), "--out", out, "--wordlist", wl])
        build_dict.build(args)
        db = sqlite3.connect(out)
        words = {r[0] for r in db.execute("SELECT word_lower FROM entries")}
        db.close()
        self.assertEqual(words, {"give", "give up", "cool"})

    def test_tag_list_matches_app(self):
        # 앱의 한국어 배지 목록(Tags.swift)과 변환기가 남기는 태그가 같아야 한다
        with open(os.path.join(HERE, "..", "TubeVocab", "Core", "Tags.swift"), encoding="utf-8") as f:
            swift = f.read()
        for tag in build_dict.KEEP_TAGS:
            self.assertIn(f'"{tag}":', swift, tag)


if __name__ == "__main__":
    unittest.main()
