# 빈칸 단어장 (iOS 앱)

예문의 빈칸에 단어를 채우며 외우는 단어장 앱입니다. claude.ai의 "빈칸 단어장" 아티팩트를 SwiftUI 네이티브 앱으로 옮겼어요.

## 실행 방법

1. Mac에서 **Xcode 16 이상**으로 `BlankVocab/BlankVocab.xcodeproj` 를 엽니다.
2. 왼쪽에서 `BlankVocab` 프로젝트 → **Signing & Capabilities** → **Team** 에 본인 Apple ID 팀을 선택합니다.
   (필요하면 Bundle Identifier `com.siwoo.BlankVocab` 를 고유한 값으로 바꾸세요.)
3. 상단에서 시뮬레이터나 연결한 iPhone을 고르고 ▶︎ (⌘R) 로 실행합니다.

최소 지원 버전: iOS 17

## 기능

- 단어장 만들기, 단어 추가/삭제, ★ 헷갈리는 단어 표시
- CSV 가져오기 (UTF-8 / EUC-KR). 첫 줄 열 이름으로 읽어요:
  `단어(W), 의미(M), 성별(G), 발음(P), 품사(POS), 예문(E), 파생어(DER), 유의어(SIM), 동의어(S), 반의어(A), 설명(D), 마크(B), 날짜(C), 이미지(I)`
- 퀴즈·테스트에서는 처음엔 **뜻과 예문만** 보여요. **확인**이나 **정답 보기**를 누르면 아래에 품사, 발음, 성별, 설명, 파생어, 유의어, 동의어, 반의어(값이 있는 것만)와 이미지(주소가 http로 시작할 때)가 나와요.
- CSV 내보내기, 전체 백업(.json) 저장/복원 — 웹 버전 백업 파일과 호환
- 빈칸 퀴즈 / 테스트(힌트·읽기 없음) / ★ 단어만 풀기, 여러 단어장 섞어서 테스트
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

웹 아티팩트에서는 claude.ai 계정으로 AI를 썼지만, 앱에서는 **Claude API 키**가 필요해요.

1. [console.anthropic.com](https://console.anthropic.com)에서 API 키를 발급받습니다.
2. 앱 첫 화면 오른쪽 위 ⚙︎ → **Claude API 키**에 붙여 넣고 저장합니다. (키는 기기 키체인에만 저장)

사용량만큼 Anthropic 계정에 요금이 청구됩니다. AI를 쓰지 않으면 키 없이도 나머지 기능은 모두 동작해요.

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
    ├── ClaudeClient.swift    Claude API (스트리밍)
    ├── Keychain.swift        API 키 저장
    ├── Speech.swift          영어 읽기 (TTS)
    ├── Theme.swift           색상·버튼 스타일
    └── Views/                화면 (Home, Book, Quiz, Chat, Settings)
└── BlankVocabKeyboard/       사전 키보드 확장
    ├── KeyboardViewController.swift  키보드 진입점
    ├── KeyboardModel.swift   입력 처리, 한/영, 사전 상태
    ├── KeyboardView.swift    자판 화면
    ├── DictionaryPanel.swift 사전 패널
    ├── HangulComposer.swift  두벌식 한글 조합
    └── NaverDict.swift       네이버 사전 검색
```
