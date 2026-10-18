# 유튜브 단어장 (TubeVocab, iOS 앱)

유튜브 영어 영상을 영/한 이중자막으로 보면서, 모르는 단어를 탭해 오프라인 사전으로 찾고,
그 문장 그대로 빈칸 시험을 보는 SwiftUI 앱입니다. **유료 API·API 키를 쓰지 않습니다.**

## 실행 방법

1. Mac에서 **Xcode 16 이상**으로 `TubeVocab/TubeVocab.xcodeproj` 를 엽니다.
2. `TubeVocab` 타깃 → **Signing & Capabilities** → **Team** 에서 본인 Apple ID 팀을 고릅니다.
   필요하면 Bundle Identifier(`com.example.TubeVocab`)를 고유한 값으로 바꾸세요.
3. 시뮬레이터나 연결한 iPhone을 고르고 ▶︎(⌘R)로 실행합니다.
4. 테스트는 **⌘U** 를 누르면 됩니다 (`TubeVocabTests`).

### 아이폰 · 아이패드

같은 앱이 아이폰과 아이패드에서 다 돌아가요 (실행 대상에서 아이패드 시뮬레이터나 연결한 아이패드를 고르면 됨).
- 아이폰: 평소 세로, 전체화면 버튼을 누르면 가로로 돌아가요.
- 아이패드: 세로·가로 모두, 화면 분할·Stage Manager 도 돼요. 가로로 두면 왼쪽에 영상·자막 카드, 오른쪽에 대본이 나오고,
  영상 위 자막과 미니 플레이어가 더 크게 보여요. 전체화면은 화면을 돌리지 않고 그대로 꽉 채워요.

### 맥에서 실행

같은 프로젝트로 맥 앱도 만들어져요. Xcode 위쪽 실행 대상에서 고르면 됩니다.

- **My Mac (Mac Catalyst)**: 인텔·애플 실리콘 맥 모두. 맥 앱으로 빌드돼요 (처음 한 번 Signing 에서 Team 을 다시 확인).
- **My Mac (Designed for iPad)**: 애플 실리콘(M1 이상) 맥에서 아이패드 앱 그대로 실행.

#### Xcode 없이 쓰도록 맥에 설치하기

터미널에서 한 줄이면 맥 앱으로 빌드해서 **응용 프로그램 폴더에 설치**해요. 그다음부터는 Xcode 없이 Launchpad·Dock 에서 열면 됩니다.

```bash
cd TubeVocab
sh scripts/install_mac_app.sh
```

"이 맥에서만 실행" 서명이라 무료 Apple ID 의 7일 만료가 없어요. 코드를 바꾸면 같은 명령을 다시 실행하면 업데이트돼요.

Xcode 화면으로 하려면: 실행 대상 **My Mac (Mac Catalyst)** → Signing & Capabilities 의 **Signing Certificate** 를
"Sign to Run Locally" 로 → ⌘R → **Product ▸ Show Build Folder in Finder** → `Products/Debug-maccatalyst/TubeVocab.app` 을
응용 프로그램 폴더로 끌어다 놓기.
맥에서는 전체화면 버튼을 누르면 화면을 돌리는 대신 창 안을 영상으로 꽉 채워요.

### 아이폰 ↔ 맥 단어장 동기화

단어장 탭 오른쪽 위 ☁︎ 버튼 → **동기화 폴더 고르기**. 아이폰과 맥에서 **같은 iCloud Drive 폴더**를 한 번씩 골라 두면
그 폴더의 `TubeVocab-words.json` 으로 단어장이 합쳐져요 (저장·삭제·★·시험 기록). 앱을 열어 둔 동안 30초마다, 그리고 단어가 바뀔 때마다 동기화해요.
앱에 iCloud 기능을 넣지 않은 방식이라 무료 Apple ID 로도 쓸 수 있어요. 두 기기가 같은 Apple ID 로 iCloud Drive 에 로그인되어 있어야 해요.

최소 지원 버전은 iOS 17 / macOS 14 이고, 외부 패키지는 쓰지 않습니다 (SwiftUI, WebKit, SQLite3만 사용).

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

**빈칸 시험** (예전 "빈칸 단어장" 앱과 같은 방식): 저장했던 그 문장에서 단어를 빈칸으로 가립니다.
- **전체 퀴즈**(힌트·문장 읽기 가능), **전체 테스트**(힌트 없음), **★ 헷갈리는 단어만** 중에서 고르고, 단어는 섞여서 한 바퀴 나옵니다.
- 문제 위에 저장할 때 고른 한국어 뜻이 나오고, 빈칸에 입력하는 글자가 문장 안에 바로 보입니다. 활용형·기본형 모두 정답으로 인정합니다.
- 힌트는 첫 글자 + 글자 수(예: w＿＿＿ (4글자))와 한국어 자막입니다.
- ☆ 헷갈려요 표시, "★ 헷갈리는 단어는 빼고 풀기", 정답 확인 후 문장 자동 읽기.
- 💾 저장하고 나가기 → 시험 첫 화면 "이어서 하기"에서 계속, 끝나면 틀린 문제 다시 풀기 / 처음부터 다시.
- 사전·단어장·시험 곳곳의 🔊 버튼으로 단어와 문장 발음을 들을 수 있습니다 (iOS 내장 음성).

## 네이버 영어사전

인터넷이 되면 단어를 탭할 때 **네이버 영어사전** 결과를 맨 위에 보여 줘요 (초록 "네이버" 배지). 아래에는 내장 사전 결과가 그대로 있어요.
- 방식은 [seia-soto/naverDict](https://github.com/seia-soto/naverDict) 와 같아요: 네이버 사전 웹이 쓰는 `dict.naver.com/api3/enko/search` 를 API 키 없이 불러요.
- 활용형·숙어는 내장 사전이 먼저 기본형으로 바꿔서 물어봐요 (went → go, gave up → give up).
- 인터넷이 없거나 네이버가 응답하지 않으면 "네이버 사전에 연결하지 못해서 내장 사전으로 보여 줘요"라고 나오고 내장 사전만 보여 줘요.
- 공식 API가 아니라서 네이버가 주소나 응답 모양을 바꾸면 안 될 수 있어요. 고칠 곳: `Data/NaverDictService.swift`, `Core/NaverDict.swift`.
- 단어장 탭의 사전 검색도 같은 방식이에요.

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
- 영상은 세 가지 방식으로 재생해요: 기본 IFrame 플레이어 → 유튜브 임베드 페이지 → 유튜브 모바일 페이지.
  10초 안에 영상이 안 뜨거나 오류(152/153, 101/150 등)가 나면 자동으로 다음 방식으로 넘어가고,
  영상 아래 **다른 방식으로 재생** 버튼으로 직접 바꿀 수도 있어요. 그래도 안 되면 **유튜브 앱에서 열기**.
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
│   │   └── Highlight.swift     저장 단어 하이라이트
│   ├── Data/                   SQLite 사전, 자막 내려받기
│   ├── Models/                 플레이어(WKWebView), 단어장, 시험 진행, 동기화, 앱 상태
│   ├── Views/                  화면 (영상, 사전 시트, 단어장, 시험, 하단 탭)
│   └── Resources/dict.db       내장 사전 (CC BY-SA 4.0)
├── TubeVocabTests/             XCTest (자막 정렬, 사전 조회, 빈칸 생성 등)
└── scripts/
    ├── install_mac_app.sh      맥 앱으로 빌드해서 응용 프로그램 폴더에 설치
    ├── make_free_dict.sh       무료 사전 3개 받아서 dict.db 만들기
    ├── build_dict.py           WordNet / 영한 사전 / kaikki 덤프 → dict.db
    ├── test_build_dict.py
    └── sample/                 샘플 덤프 (kaikki 형식)
```
