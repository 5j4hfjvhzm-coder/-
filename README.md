# 빈칸 단어장 (iOS 앱)

예문의 빈칸에 단어를 채우며 외우는 단어장 앱입니다. claude.ai의 "빈칸 단어장" 아티팩트를 SwiftUI 네이티브 앱으로 옮겼어요.

## 실행 방법

1. Mac에서 **Xcode 16 이상**으로 `BlankVocab/BlankVocab.xcodeproj` 를 엽니다.
2. 왼쪽에서 `BlankVocab` 프로젝트 → **Signing & Capabilities** → **Team** 에 본인 Apple ID 팀을 선택합니다.
   (필요하면 Bundle Identifier `com.siwoolee.blankvocab1021` 를 고유한 값으로 바꾸세요.)
3. 상단에서 시뮬레이터나 연결한 iPhone을 고르고 ▶︎ (⌘R) 로 실행합니다.

최소 지원 버전: iOS 17

## 기능

- 단어장 만들기, 단어 추가/삭제, ★ 헷갈리는 단어 표시
- CSV 가져오기 (UTF-8 / EUC-KR). 첫 줄 열 이름으로 읽어요:
  `단어(W), 의미(M), 성별(G), 발음(P), 품사(POS), 예문(E), 파생어(DER), 유의어(SIM), 동의어(S), 반의어(A), 설명(D), 마크(B), 날짜(C), 이미지(I)`
- 퀴즈·테스트에서는 처음엔 **뜻과 예문만** 보여요. **확인**이나 **정답 보기**를 누르면 아래에 품사, 발음, 성별, 설명, 파생어, 유의어, 동의어, 반의어(값이 있는 것만)와 이미지(주소가 http로 시작할 때)가 나와요.
- CSV 내보내기, 전체 백업(.json) 저장/복원 — 웹 버전 백업 파일과 호환
- 빈칸 퀴즈 / 테스트(힌트·읽기 없음) / ★ 단어만 풀기, 여러 단어장 섞어서 테스트
- 🃏 플래시카드: 탭해서 뒤집기, 오른쪽으로 밀면 "알아요" / 왼쪽은 "몰라요", 뒷면에 뜻·예문·품사 등 표시, 몰랐던 카드만 다시 보기, 앞면(단어/뜻)·섞기·★만·자동 읽기 설정
- 힌트(첫 글자 + 글자 수), 영어 문장 읽기(TTS), 정답 후 자동 읽기
- "저장하고 나가기" 후 첫 화면에서 이어 풀기, 틀린 문제만 다시 풀기
- 🤖 AI로 틀린 이유 설명, 🤖 AI 영어 프리토킹(교정 피드백 포함)

## 사전 키보드

앱과 함께 **빈칸 단어장 키보드**(키보드 확장)가 설치돼요. 다른 앱에서 글을 쓰다가 바로 단어 뜻을 찾을 수 있어요.

- 두벌식 한글 / 영문 QWERTY, **한/영** 키로 전환 (숫자·기호 자판 포함)
- 키보드 위쪽 📖 버튼 → 사전 패널이 열리고, 그동안 치는 글자는 검색창으로 들어가요
- 커서 앞 단어(또는 선택한 글자)가 있으면 "“apple” 뜻 보기" 바로가기가 떠요
- **영한 / 국어** 사전 전환, 결과의 **입력** 버튼으로 단어를 문서에 넣기
- 사전 데이터: 네이버 사전 (비공식 API, [seia-soto/naverDict](https://github.com/seia-soto/naverDict) 방식)

켜는 법: 설정 › 일반 › 키보드 › 키보드 › 새로운 키보드 추가 › **빈칸 단어장 키보드** → 추가한 키보드에서 **전체 접근 허용** 켜기
(사전 검색에 인터넷이 필요해서 전체 접근이 있어야 해요. 입력한 글자는 사전 검색어 외에는 어디에도 보내지 않아요.)

실기기에 설치할 때는 `BlankVocabKeyboard` 타깃의 **Signing & Capabilities → Team** 도 앱과 같은 팀으로 맞춰 주세요.
Bundle Identifier를 바꿨다면 키보드 쪽도 `<앱 번들 ID>.Keyboard` 로 맞춰야 해요.

## AI 기능 설정

웹 아티팩트에서는 claude.ai 계정으로 AI를 썼지만, 앱에서는 **Claude** 또는 **Gemini** API 키가 필요해요. 둘 중 하나만 있어도 돼요.

| AI | 발급 | 키 모양 |
|---|---|---|
| Claude | [console.anthropic.com](https://console.anthropic.com) | `sk-ant-...` |
| Gemini | [aistudio.google.com](https://aistudio.google.com) → Get API key | `AQ....` (예전 키는 `AIza...`) |

`gen-lang-client-...`는 AI Studio가 만든 **프로젝트 이름**이지 키가 아니에요.

1. 앱 첫 화면 오른쪽 위 ⚙︎ → **AI 선택**에서 Claude / Gemini를 고릅니다.
2. 그 AI의 키 칸에 붙여 넣고 **저장** → **연결 테스트**로 확인합니다. (키는 기기 키체인에만 저장)
3. Gemini 모델은 기본값 `gemini-flash-latest`(항상 최신 Flash)이고, 설정에서 바꿀 수 있어요.

사용량만큼 각 회사 계정에 요금이 청구됩니다(Gemini는 무료 한도 안에서는 무료). AI를 쓰지 않으면 키 없이도 나머지 기능은 모두 동작해요.

## 웹 버전에서 단어 옮기기

웹 아티팩트의 **전체 백업 저장**으로 받은 `blank-vocab-backup.json` 을 iPhone 파일 앱(또는 iCloud Drive)에 넣고,
앱에서 **CSV 파일 가져오기** → 그 파일을 선택하면 단어장이 그대로 들어옵니다.

## 파일 구조

```
BlankVocab/
├── BlankVocab.xcodeproj
└── BlankVocab/
    ├── BlankVocabApp.swift   앱 진입점
    ├── Models.swift          단어/단어장/퀴즈 데이터
    ├── Store.swift           저장, 가져오기, 퀴즈 진행 로직
    ├── Blank.swift           예문에서 빈칸 만들기
    ├── CSV.swift             CSV 읽기/쓰기
    ├── AI.swift              AI 선택 + Gemini API (스트리밍)
    ├── ClaudeClient.swift    Claude API (스트리밍)
    ├── Keychain.swift        API 키 저장
    ├── Speech.swift          영어 읽기 (TTS)
    ├── Theme.swift           색상·버튼 스타일
    └── Views/                화면 (Home, Book, Quiz, Flashcard, Chat, Settings)
└── BlankVocabKeyboard/       사전 키보드 확장
    ├── KeyboardViewController.swift  키보드 진입점
    ├── KeyboardModel.swift   입력 처리, 한/영, 사전 상태
    ├── KeyboardView.swift    자판 화면
    ├── DictionaryPanel.swift 사전 패널
    ├── HangulComposer.swift  두벌식 한글 조합
    └── NaverDict.swift       네이버 사전 검색
```

---

# 가리기 단어장 (아이패드 전용 앱)

`WordSheet/WordSheet.xcodeproj` — 퀴즈 없이 **보기 / 단어 가리기 / 뜻 가리기 / 형광펜**만 있는 아이패드 전용 단어장이에요.

- 위의 빈칸 단어장 **CSV 형식 그대로** 가져와요 (UTF-8 / EUC-KR, 여러 파일 한 번에). 열 이름이 없으면 첫 열=단어, 둘째 열=뜻
- 단어 아래에 **품사·성별·발음**, 뜻 아래에 **예문·설명·파생어·유의어·동의어·반의어**(값이 있는 것만)가 나와요
- **단어 가리기 / 뜻 가리기**를 켜면 품사·예문 같은 나머지 정보도 함께 숨겨져요. 줄을 탭하면 그 단어만 잠깐 펼쳐지고, **다시 가리기**로 모두 덮어요. 열 제목(단어/뜻)을 탭해도 가리기가 켜지고 꺼져요
- **형광펜**: 버튼을 켜고 아래 팔레트에서 색(노랑·초록·분홍·파랑·주황)을 고른 뒤 단어를 탭하면 칠해져요. 같은 색을 다시 탭하거나 지우개로 지워요. 길게 눌러도 색을 고를 수 있어요
- CSV의 마크(B) 열이 1인 단어는 노란 형광펜으로 들어와요
- **🔊 읽기**: 단어 옆 스피커 버튼을 누르면 단어를 읽어줘요. 단어장 언어(영어·독일어·프랑스어 등)를 알아서 골라요. 단어를 가려도 들을 수 있어요
- **섞기**: 단어 순서를 무작위로 섞어요(번호도 1부터 다시). **다시 섞기**로 새로 섞고, 섞기를 끄면 원래 순서로 돌아가요
- 보기 필터(전체 / 형광펜만 / 색별), 검색, 글자 크기 조절

실행: Xcode에서 `WordSheet/WordSheet.xcodeproj` 를 열고 Team을 고른 뒤 아이패드(또는 아이패드 시뮬레이터)에서 ▶︎. Bundle ID `com.siwoolee.wordsheet1021`, iPadOS 17 이상.
