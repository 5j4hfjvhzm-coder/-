# 빈칸 단어장 (iOS 앱)

예문의 빈칸에 단어를 채우며 외우는 단어장 앱입니다. claude.ai의 "빈칸 단어장" 아티팩트를 SwiftUI 네이티브 앱으로 옮겼어요.

## 실행 방법

1. Mac에서 **Xcode 16 이상**으로 `BlankVocab/BlankVocab.xcodeproj` 를 엽니다.
2. 왼쪽에서 `BlankVocab` 프로젝트 → **Signing & Capabilities** → **Team** 에 본인 Apple ID 팀을 선택합니다.
   (필요하면 Bundle Identifier `com.example.BlankVocab` 를 고유한 값으로 바꾸세요.)
3. 상단에서 시뮬레이터나 연결한 iPhone을 고르고 ▶︎ (⌘R) 로 실행합니다.

최소 지원 버전: iOS 17

## 기능

- 단어장 만들기, 단어 추가/삭제, ★ 헷갈리는 단어 표시
- CSV 가져오기 (UTF-8 / EUC-KR, 첫 줄에 `단어(W),의미(M),예문(E)` 열, `품사(POS)`, `마크(B)` 도 읽음)
- CSV 내보내기, 전체 백업(.json) 저장/복원 — 웹 버전 백업 파일과 호환
- 빈칸 퀴즈 / 테스트(힌트·읽기 없음) / ★ 단어만 풀기, 여러 단어장 섞어서 테스트
- 힌트(첫 글자 + 글자 수), 영어 문장 읽기(TTS), 정답 후 자동 읽기
- "저장하고 나가기" 후 첫 화면에서 이어 풀기, 틀린 문제만 다시 풀기
- 🤖 AI로 틀린 이유 설명, 🤖 AI 영어 프리토킹(교정 피드백 포함)

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
```
