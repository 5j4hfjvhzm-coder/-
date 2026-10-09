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


class FreeSourcesTest(unittest.TestCase):
    """WordNet + open-english-korean-dict + kengdic (실제 파일과 같은 형식의 작은 예시)"""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        wn = os.path.join(cls.tmp, "wordnet")
        os.makedirs(wn)
        files = {
            "data.noun": [
                "  1 This software and database is being provided to you, the LICENSEE ...",
                "00000001 04 n 01 slang 0 000 | informal language",
                '00000002 21 n 01 dough 0 001 ;u 00000001 n 0000 | informal terms for money; "he made a lot of dough"',
                "00000003 15 n 01 Paris 0 000 | the capital of France",
            ],
            "index.noun": ["  1 license header", "slang n 1 0 1 0 00000001", "dough n 1 1 ;u 1 0 00000002",
                           "paris n 1 0 1 0 00000003"],
            "data.verb": [
                '00000010 40 v 02 give_up 0 quit 0 000 01 + 08 00 | stop maintaining or insisting on; "He gave up smoking"',
                "00000011 40 v 01 give 0 000 | transfer possession of something",
                "00000012 38 v 01 stop 0 000 | come to a halt",
            ],
            "index.verb": ["give_up v 1 0 1 0 00000010", "give v 1 0 1 0 00000011", "stop v 1 0 1 0 00000012"],
            "verb.exc": ["gave give", "given give"],
            "data.adj": [], "index.adj": [], "data.adv": [], "index.adv": [],
        }
        for name, lines in files.items():
            with open(os.path.join(wn, name), "w", encoding="utf-8") as f:
                f.write("\n".join(lines) + ("\n" if lines else ""))

        oekd = os.path.join(cls.tmp, "oekd.sqlite")
        db = sqlite3.connect(oekd)
        db.execute("CREATE TABLE words (word TEXT PRIMARY KEY, meaning_ko TEXT NOT NULL, meaning_ja TEXT, meaning_zh TEXT,"
                   " meaning_en TEXT, meaning_secondary TEXT, ipa TEXT, pos TEXT, cefr TEXT, freq_rank INTEGER)")
        db.executemany("INSERT INTO words(word, meaning_ko, meaning_secondary, ipa) VALUES (?,?,?,?)", [
            ("give", "주다", None, "/ɡɪv/"), ("sus", "의심스러운", None, None), ("dough", "반죽", "돈", None),
        ])
        db.commit()
        db.close()

        keng = os.path.join(cls.tmp, "kengdic.tsv")
        with open(keng, "w", encoding="utf-8") as f:
            f.write("id\tsurface\thanja\tgloss\tlevel\tcreated\tsource\n")
            f.write("1\t포기하다\t\tto give up; abandon\t\t\tx\n")
            f.write("2\t건네다\t\tto give (something)\t\t\tx\n")
            f.write("3\t주다\t\tgive\t\t\tx\n")

        cls.out = os.path.join(cls.tmp, "dict.db")
        args = build_dict.parse_args(["--wordnet", wn, "--oekd", oekd, "--kengdic", keng, "--out", cls.out])
        build_dict.build(args)
        cls.db = sqlite3.connect(cls.out)

    @classmethod
    def tearDownClass(cls):
        cls.db.close()
        shutil.rmtree(cls.tmp)

    def q(self, sql, *params):
        return self.db.execute(sql, params).fetchall()

    def senses(self, word, source):
        return self.q("SELECT e.pos, s.gloss, s.tags, s.examples FROM senses s JOIN entries e ON e.id=s.entry_id "
                      "WHERE e.word_lower=? AND e.source=? ORDER BY e.id, s.idx", word, source)

    def test_wordnet_gloss_examples_and_usage_tag(self):
        rows = self.senses("dough", "en")
        self.assertEqual(rows[0][:3], ("noun", "informal terms for money", "slang"))
        self.assertEqual(json.loads(rows[0][3]), [{"text": "he made a lot of dough"}])

    def test_wordnet_phrasal_verb(self):
        rows = self.senses("give up", "en")
        self.assertEqual(rows[0][1], "stop maintaining or insisting on")
        self.assertIn("phrasal-verb", rows[0][2].split())
        self.assertIn(("give", "give up"), self.q("SELECT * FROM phrases"))

    def test_proper_nouns_skipped(self):
        self.assertEqual(self.senses("paris", "en"), [])

    def test_irregular_and_regular_forms(self):
        give = {r[0] for r in self.q("SELECT form FROM forms WHERE lemma='give'")}
        self.assertEqual(give, {"gave", "given", "gives", "giving"})  # gived 는 없어야 함
        stop = {r[0] for r in self.q("SELECT form FROM forms WHERE lemma='stop'")}
        self.assertEqual(stop, {"stops", "stopped", "stopping"})

    def test_korean_meanings_merged_and_grouped_by_pos(self):
        # 대표 뜻(open-english-korean-dict) 먼저, kengdic 으로 보강, 품사는 영영 품사에 맞춤
        self.assertEqual([r[:2] for r in self.senses("give", "ko")], [("verb", "주다"), ("verb", "건네다")])
        self.assertEqual([r[:2] for r in self.senses("give up", "ko")], [("verb", "포기하다")])
        self.assertEqual([r[:2] for r in self.senses("dough", "ko")], [("noun", "반죽"), ("noun", "돈")])

    def test_word_only_in_korean_dictionary(self):
        self.assertEqual([r[:2] for r in self.senses("sus", "ko")], [("adj", "의심스러운")])
        self.assertEqual(self.q("SELECT ipa FROM entries WHERE word_lower='give' AND source='ko'"), [("/ɡɪv/",)])

    def test_korean_pos_guess(self):
        self.assertEqual(build_dict.korean_pos("포기하다"), "verb")
        self.assertEqual(build_dict.korean_pos("의심스러운"), "adj")
        self.assertEqual(build_dict.korean_pos("천천히"), "adv")
        self.assertEqual(build_dict.korean_pos("책"), "noun")


if __name__ == "__main__":
    unittest.main()
