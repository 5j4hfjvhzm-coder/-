# 유튜브 단어장 (TubeVocab, iOS 앱)

유튜브 영어 영상을 영/한 이중자막으로 보면서, 모르는 단어를 탭해 오프라인 사전으로 찾고,
그 문장 그대로 빈칸 시험을 보는 SwiftUI 앱입니다. **유료 API·API 키를 쓰지 않습니다.**

## 실행 방법

1. Mac에서 **Xcode 16 이상**으로 `TubeVocab/TubeVocab.xcodeproj` 를 엽니다.
2. `TubeVocab` 타깃 → **Signing & Capabilities** → **Team** 에서 본인 Apple ID 팀을 고릅니다.
   필요하면 Bundle Identifier(`com.example.TubeVocab`)를 고유한 값으로 바꾸세요.
3. 시뮬레이터나 연결한 iPhone을 고르고 ▶︎(⌘R)로 실행합니다.
4. 테스트는 **⌘U** 를 누르면 됩니다 (`TubeVocabTests`).

최소 지원 버전은 iOS 17이고, 외부 패키지는 쓰지 않습니다 (SwiftUI, WebKit, SQLite3만 사용).

## 기능

**영상 + 이중자막 (영상 탭)**
- 유튜브 링크를 붙여 넣으면 앱 안에서 재생합니다 (WKWebView + 유튜브 IFrame API).
- 영어 자막은 유튜브 공개 자막 트랙(`captionTracks` → `fmt=json3`)에서 가져옵니다.
  한국어 트랙이 없으면 영어 트랙에 `&tlang=ko` 를 붙여 유튜브 자동번역을 씁니다.
- 자동생성 자막은 단어 시간을 보고 문장 단위로 합치고, 영/한 자막은 시간이 겹치는 정도로 짝을 맞춥니다.
- 현재 줄은 크게 보여 주고, 아래 전체 대본에서 줄을 탭하면 그 시점으로 이동합니다.
- 영/한 표시 토글이 있고, 자막을 못 받으면 **자막 파일**로 `.srt`/`.vtt` 를 불러올 수 있습니다.
  한 파일에 영/한이 같이 있어도 되고, UTF-8과 CP949(EUC-KR) 파일을 읽습니다.
- 다른 탭으로 가면 오른쪽 아래 미니 플레이어로 바뀌고, 재생은 끊기지 않습니다.

**단어 탭 → 사전**
- 자막 단어를 탭하면 영상이 멈추고 사전 시트가 열립니다. 사전은 앱에 들어 있는 SQLite(`dict.db`)라 오프라인으로 동작합니다.
- 탭한 단어 앞뒤로 숙어·구동사를 먼저 찾습니다 (gave up → give up, pick it up → pick up, made up my mind → make up one's mind).
- 활용형은 기본형으로 찾고(went → go), 앞 단어로 품사를 추정해 맞는 뜻을 위로 올립니다 (a book은 명사, to book은 동사).
- 속어·비격식·관용 같은 태그는 한국어 배지로 보여 주고, 속어는 빨간색으로 표시합니다.
- 뜻을 하나 골라 **모르는 단어로 저장**하면 단어, 고른 뜻, 영/한 문장, 영상 ID, 시간이 저장되고 자막에서 노랗게 칠해집니다.

**단어장**: 저장 단어 목록, 검색, 밀어서 삭제, 원문 문장 보기, "영상에서 보기", 사전 직접 검색.

**빈칸 시험**: 저장했던 그 문장에서 단어를 빈칸으로 가립니다.
- 문제 위에 저장할 때 고른 한국어 뜻이 나오고, 빈칸에 들어갈 말을 직접 입력합니다.
- 힌트는 한국어 자막과 첫 글자 두 가지입니다.
- 활용형과 기본형 모두 정답으로 인정합니다.
- 맞히면 1·3·7·14·30·60일 뒤, 틀리면 10분 뒤에 다시 나옵니다.

## 사전 (dict.db)

앱에 들어 있는 `TubeVocab/Resources/dict.db`(약 40MB)는 무료 사전 세 개를 합쳐 만든 것입니다.

| 출처 | 들어간 내용 | 라이선스 |
|---|---|---|
| [open-english-korean-dict](https://github.com/jhseo1211/open-english-korean-dict) | 단어 4.8만 개의 한국어 대표 뜻, 발음 기호 | CC BY-SA 4.0 |
| [kengdic](https://github.com/garfieldnate/kengdic) | 한국어 뜻 보강, give up→포기하다 같은 숙어 | MPL 2.0 / LGPL |
| [WordNet 3.0](https://wordnet.princeton.edu/) | 영어 뜻풀이·예문, went→go 같은 불규칙 활용, 구동사, 일부 속어·구어 표시 | WordNet License |

영영 항목 약 15만 개, 영한 항목 약 9만 개, 숙어·구동사 약 5.6만 개가 들어 있습니다.
open-english-korean-dict 가 CC BY-SA 4.0 이므로 **dict.db 는 CC BY-SA 4.0 으로 배포**하고, 앱의 단어장 → 사전 검색 화면 아래에 출처를 표시합니다.

다시 만들기 (원본 세 개를 받아서 변환, 10초 정도):

```bash
cd TubeVocab
sh scripts/make_free_dict.sh
```

### 더 풍부한 사전 (선택)

위키낱말사전(kaikki.org) 덤프를 같이 넣으면 속어·비격식 표시와 예문이 훨씬 많아집니다. 대신 파일이 커집니다.

```bash
curl -LO https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz
curl -L -o ko-raw-wiktextract-data.jsonl.gz https://kaikki.org/kowiktionary/raw-wiktextract-data.jsonl.gz
sh scripts/make_free_dict.sh --en raw-wiktextract-data.jsonl.gz --ko ko-raw-wiktextract-data.jsonl.gz
```

- `--wordlist 단어목록.txt` 로 단어를 제한하면 크기를 줄일 수 있습니다 (그 단어로 시작하는 숙어는 같이 들어감).
- 변환기 테스트: `python3 -m unittest discover -s scripts -p 'test_*.py'`

## 알아 둘 점

- 자막은 공식 API가 아니라 유튜브 앱/웹이 쓰는 공개 경로로 받습니다. 유튜브가 방식을 바꾸면 못 받을 수 있는데,
  그럴 때는 **자막 파일**로 불러오면 됩니다. 수정할 곳은 `Data/CaptionService.swift` 입니다.
- 일부 영상은 소유자가 외부 재생을 막아 앱 안에서 재생되지 않습니다 (오류 101/150).
  오류 152/153이 나오면 `PlayerModel.origin` 값(임베드 출처)을 확인하세요.
- 단어장은 기기의 `Documents/words.json` 에 저장됩니다.

## 파일 구조

```
TubeVocab/
├── TubeVocab.xcodeproj
├── TubeVocab/
│   ├── TubeVocabApp.swift      앱 진입점
│   ├── Core/                   순수 로직 (테스트 대상)
│   │   ├── Subtitles.swift     json3·SRT/VTT 파싱, 문장 합치기, 영/한 시간 정렬
│   │   ├── YouTube.swift       링크 파싱, captionTracks 추출, 트랙 선택(tlang=ko)
│   │   ├── Dictionary.swift    문맥 사전 조회 (숙어 → 기본형 → 품사 정렬)
│   │   ├── Phrase.swift        숙어·구동사 매칭 (분리형, one's/someone 자리)
│   │   ├── Lemma.swift  POS.swift  Tags.swift
│   │   ├── Blank.swift         빈칸·보기·정답 판정
│   │   ├── SRS.swift           간격 반복
│   │   └── Highlight.swift     저장 단어 하이라이트
│   ├── Data/                   SQLite 사전, 자막 내려받기
│   ├── Models/                 플레이어(WKWebView), 단어장, 앱 상태
│   ├── Views/                  화면 (영상, 사전 시트, 단어장, 시험, 하단 탭)
│   └── Resources/dict.db       내장 사전 (CC BY-SA 4.0)
├── TubeVocabTests/             XCTest (자막 정렬, 사전 조회, 빈칸 생성 등)
└── scripts/
    ├── make_free_dict.sh       무료 사전 3개 받아서 dict.db 만들기
    ├── build_dict.py           WordNet / 영한 사전 / kaikki 덤프 → dict.db
    ├── test_build_dict.py
    └── sample/                 샘플 덤프 (kaikki 형식)
```
