#!/usr/bin/env python3
"""
kaikki 덤프와 같은 모양의 작은 샘플 JSONL 을 만든다 (앱 기본 내장 dict.db, 변환 스크립트 테스트용).
실제 사전은 README 의 "사전 만들기" 대로 전체 덤프로 다시 만드세요.

  python3 scripts/sample/make_sample.py && python3 scripts/build_dict.py \
      --en scripts/sample/en-sample.jsonl --ko scripts/sample/ko-sample.jsonl --out TubeVocab/Resources/dict.db
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def en(word, pos, senses, forms=(), translations=(), ipa=None):
    obj = {
        "word": word, "lang": "English", "lang_code": "en", "pos": pos,
        "senses": [], "forms": [{"form": f, "tags": t} for f, t in forms],
    }
    if ipa:
        obj["sounds"] = [{"ipa": ipa}]
    if translations:
        obj["translations"] = [
            {"lang": "Korean", "lang_code": "ko", "word": w, "sense": s} for s, w in translations
        ]
    for s in senses:
        if isinstance(s, str):
            s = {"g": s}
        sense = {"glosses": [s["g"]], "tags": s.get("tags", [])}
        if "ex" in s:
            sense["examples"] = [{"text": e, "type": "example"} for e in s["ex"]]
        if "form_of" in s:
            sense["form_of"] = [{"word": s["form_of"]}]
            sense["tags"] = sense["tags"] + ["form-of"]
        obj["senses"].append(sense)
    return obj


def ko(word, pos, senses):
    obj = {"word": word, "lang": "영어", "lang_code": "en", "pos": pos, "senses": []}
    for s in senses:
        if isinstance(s, str):
            s = {"g": s}
        sense = {"glosses": [s["g"]]}
        if "raw" in s:
            sense["raw_tags"] = s["raw"]
        if "ex" in s:
            sense["examples"] = [{"text": t, "translation": k} for t, k in s["ex"]]
        obj["senses"].append(sense)
    return obj


V = lambda base, s3, past, pp, ing: [(s3, ["present", "singular", "third-person"]), (past, ["past"]), (pp, ["participle", "past"]), (ing, ["participle", "present"])]

EN = [
    en("go", "verb", [
        {"g": "To move from one place to another.", "ex": ["We go to school by bus."]},
        {"g": "To leave; to depart.", "ex": ["I have to go now."]},
        {"g": "To say (introducing direct speech).", "tags": ["informal", "colloquial"], "ex": ["And then he goes, “No way!”"]},
    ], forms=V("go", "goes", "went", "gone", "going"), translations=[("to move", "가다")], ipa="/ɡəʊ/"),
    en("go", "noun", [{"g": "An attempt or try.", "tags": ["informal"], "ex": ["Let me have a go."]}]),
    en("went", "verb", [{"g": "simple past of go", "tags": ["past"], "form_of": "go"}]),
    en("give", "verb", [
        {"g": "To transfer the possession of something to someone else.", "ex": ["She gave me a book."]},
    ], forms=V("give", "gives", "gave", "given", "giving"), translations=[("", "주다")]),
    en("give up", "verb", [
        {"g": "To stop trying; to surrender.", "tags": ["idiomatic", "intransitive"], "ex": ["Don't give up!"]},
        {"g": "To stop doing a habit.", "tags": ["transitive"], "ex": ["He gave up smoking."]},
    ], translations=[("to stop trying", "포기하다"), ("to stop doing a habit", "끊다")]),
    en("pick", "verb", [{"g": "To choose.", "ex": ["Pick a card."]}], forms=V("pick", "picks", "picked", "picked", "picking")),
    en("pick up", "verb", [
        {"g": "To lift; to take up.", "ex": ["Pick it up off the floor."]},
        {"g": "To learn informally, by observation.", "tags": ["informal"], "ex": ["I picked up some Spanish."]},
        {"g": "To collect someone in a vehicle.", "ex": ["I'll pick you up at six."]},
    ], translations=[("to lift", "줍다"), ("to collect someone", "태우러 가다")]),
    en("up", "adv", [{"g": "Toward a higher position.", "ex": ["Look up."]}]),
    en("cool", "adj", [
        {"g": "Having a slightly low temperature.", "ex": ["a cool breeze"]},
        {"g": "Fashionable; excellent; impressive.", "tags": ["slang", "informal"], "ex": ["That's so cool!"]},
        {"g": "Calm; unexcited.", "ex": ["Stay cool."]},
    ], forms=[("cooler", ["comparative"]), ("coolest", ["superlative"])], translations=[("having a slightly low temperature", "시원한"), ("fashionable", "멋진")]),
    en("sick", "adj", [
        {"g": "In poor health.", "ex": ["I was sick yesterday."]},
        {"g": "Very good; excellent; awesome.", "tags": ["slang"], "ex": ["That trick was sick!"]},
    ], translations=[("in poor health", "아픈")]),
    en("book", "noun", [{"g": "A collection of sheets of paper bound together.", "ex": ["I read a book."]}], forms=[("books", ["plural"])], translations=[("", "책")]),
    en("book", "verb", [{"g": "To reserve (something) for future use.", "ex": ["I need to book a room."]}], forms=V("book", "books", "booked", "booked", "booking"), translations=[("", "예약하다")]),
    en("see", "verb", [{"g": "To perceive with the eyes.", "ex": ["I saw a bird."]}], forms=V("see", "sees", "saw", "seen", "seeing"), translations=[("", "보다")]),
    en("saw", "noun", [{"g": "A tool with a toothed blade used for cutting.", "ex": ["Hand me the saw."]}], translations=[("", "톱")]),
    en("saw", "verb", [{"g": "simple past of see", "form_of": "see", "tags": ["past"]}]),
    en("make up one's mind", "verb", [{"g": "To decide.", "tags": ["idiomatic"], "ex": ["I can't make up my mind."]}], translations=[("", "결심하다")]),
    en("make", "verb", [{"g": "To create.", "ex": ["She makes cakes."]}], forms=V("make", "makes", "made", "made", "making")),
    en("look", "verb", [{"g": "To try to see; to pay attention to with one's eyes.", "ex": ["Look at that!"]}], forms=V("look", "looks", "looked", "looked", "looking")),
    en("look forward to", "verb", [{"g": "To anticipate with pleasure.", "tags": ["idiomatic"], "ex": ["I look forward to seeing you."]}], translations=[("", "고대하다")]),
    en("run", "verb", [{"g": "To move swiftly on foot.", "ex": ["She runs every morning."]}], forms=V("run", "runs", "ran", "run", "running")),
    en("run out", "verb", [{"g": "To have none left.", "ex": ["We ran out of milk."]}], translations=[("", "다 떨어지다")]),
    en("hang out", "verb", [{"g": "To spend time with friends casually.", "tags": ["informal", "idiomatic"], "ex": ["Let's hang out this weekend."]}], translations=[("", "어울려 놀다")]),
    en("hang", "verb", [{"g": "To be suspended from above.", "ex": ["A picture hangs on the wall."]}], forms=V("hang", "hangs", "hung", "hung", "hanging")),
    en("figure out", "verb", [{"g": "To come to understand; to solve.", "ex": ["I can't figure it out."]}], translations=[("", "알아내다")]),
    en("figure", "verb", [{"g": "To suppose; to think.", "tags": ["informal"]}], forms=V("figure", "figures", "figured", "figured", "figuring")),
    en("chill", "verb", [
        {"g": "To make cold.", "ex": ["Chill the wine."]},
        {"g": "To relax; to calm down.", "tags": ["slang"], "ex": ["Just chill, man."]},
    ], forms=V("chill", "chills", "chilled", "chilled", "chilling")),
    en("lit", "adj", [
        {"g": "Illuminated.", "ex": ["a lit room"]},
        {"g": "Exciting, excellent.", "tags": ["slang"], "ex": ["The party was lit."]},
    ]),
    en("awesome", "adj", [{"g": "Excellent, very good.", "tags": ["colloquial"], "ex": ["That's awesome!"]}], translations=[("", "굉장한")]),
    en("learn", "verb", [{"g": "To acquire knowledge or skill.", "ex": ["We learn English."]}], forms=V("learn", "learns", "learned", "learned", "learning") + [("learnt", ["past"])], translations=[("", "배우다")]),
    en("word", "noun", [{"g": "The smallest unit of language that has a particular meaning.", "ex": ["Learn a new word."]}], forms=[("words", ["plural"])], translations=[("", "단어")]),
    en("today", "adv", [{"g": "On the current day.", "ex": ["What are we doing today?"]}], translations=[("", "오늘")]),
    en("really", "adv", [{"g": "Actually; in fact.", "ex": ["I really like it."]}, {"g": "Very.", "tags": ["informal"]}], translations=[("", "정말")]),
    en("like", "verb", [{"g": "To enjoy; to be pleased by.", "ex": ["I like apples."]}], forms=V("like", "likes", "liked", "liked", "liking"), translations=[("", "좋아하다")]),
    en("like", "prep", [{"g": "Similar to.", "ex": ["She looks like her mother."]}], translations=[("", "~처럼")]),
    en("like", "intj", [{"g": "Used as a filler in speech.", "tags": ["colloquial"], "ex": ["It was, like, really big."]}]),
    en("kind of", "adv", [{"g": "Somewhat; to a certain extent.", "tags": ["informal", "idiomatic"], "ex": ["I'm kind of tired."]}], translations=[("", "좀, 약간")]),
    en("kind", "noun", [{"g": "A type, race or category.", "ex": ["What kind of music do you like?"]}], forms=[("kinds", ["plural"])], translations=[("", "종류")]),
    en("kind", "adj", [{"g": "Having a benevolent, courteous nature.", "ex": ["She is very kind."]}], forms=[("kinder", ["comparative"]), ("kindest", ["superlative"])], translations=[("", "친절한")]),
    en("stuff", "noun", [{"g": "Miscellaneous items or things.", "tags": ["informal", "uncountable"], "ex": ["Put your stuff away."]}], translations=[("", "물건, 것들")]),
    en("guy", "noun", [{"g": "A man.", "tags": ["informal"], "ex": ["He's a nice guy."]}], forms=[("guys", ["plural"])], translations=[("", "남자, 녀석")]),
    en("gonna", "contraction", [{"g": "going to", "tags": ["informal", "colloquial"], "ex": ["I'm gonna win."]}]),
    en("get", "verb", [{"g": "To obtain; to acquire.", "ex": ["I got a new phone."]}, {"g": "To understand.", "tags": ["informal"], "ex": ["I don't get it."]}], forms=V("get", "gets", "got", "gotten", "getting") + [("got", ["participle", "past"])], translations=[("to obtain", "얻다"), ("to understand", "이해하다")]),
    en("get over", "verb", [{"g": "To recover from.", "ex": ["She got over the flu."]}], translations=[("", "극복하다, 회복하다")]),
]

KO = [
    ko("go", "verb", [{"g": "가다", "ex": [("Let's go home.", "집에 가자.")]}, "떠나다", {"g": "(말을) 하다", "raw": ["구어"]}]),
    ko("give up", "verb", [{"g": "포기하다", "raw": ["관용"]}, "그만두다, 끊다"]),
    ko("pick up", "verb", ["줍다, 집어 들다", "(차로) 데리러 가다", {"g": "(어깨너머로) 익히다", "raw": ["비격식"]}]),
    ko("cool", "형용사", ["시원한", {"g": "멋진, 끝내주는", "raw": ["속어"]}, "침착한"]),
    ko("sick", "형용사", ["아픈", {"g": "쩌는, 끝내주는", "raw": ["속어"]}]),
    ko("book", "명사", ["책"]),
    ko("book", "동사", ["예약하다"]),
    ko("see", "동사", ["보다", "알다, 이해하다"]),
    ko("saw", "명사", ["톱"]),
    ko("chill", "동사", ["차게 하다", {"g": "쉬다, 진정하다", "raw": ["속어"]}]),
    ko("hang out", "동사", [{"g": "어울려 놀다, 시간을 보내다", "raw": ["구어"]}]),
    ko("figure out", "동사", ["알아내다, 이해하다"]),
    ko("run out", "동사", ["다 떨어지다, 바닥나다"]),
    ko("learn", "동사", ["배우다", "알게 되다"]),
    ko("word", "명사", ["단어, 낱말", "말"]),
    ko("kind of", "부사", [{"g": "좀, 약간, 어느 정도", "raw": ["구어"]}]),
    ko("awesome", "형용사", [{"g": "굉장한, 끝내주는", "raw": ["구어"]}]),
    ko("lit", "형용사", ["불이 켜진", {"g": "신나는, 끝내주는", "raw": ["속어"]}]),
]

# 덤프에는 영어가 아닌 항목·리다이렉트도 섞여 있다 → 변환기가 걸러내야 함
NOISE = [
    {"word": "aller", "lang": "French", "lang_code": "fr", "pos": "verb", "senses": [{"glosses": ["to go"]}]},
    {"title": "Gave up", "redirect": "give up"},
    {"word": "Paris", "lang": "English", "lang_code": "en", "pos": "name", "senses": [{"glosses": ["The capital of France."]}]},
]


def write(name, rows):
    with open(os.path.join(HERE, name), "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    write("en-sample.jsonl", EN + NOISE)
    write("ko-sample.jsonl", KO + [{"word": "가다", "lang": "한국어", "lang_code": "ko", "pos": "verb", "senses": [{"glosses": ["move"]}]}])
    print("ok")
