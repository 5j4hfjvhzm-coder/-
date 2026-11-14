# 에딧 메이커 (Windows)

레퍼런스 edit 영상 + 내 클립 → **PC용 CapCut 프로젝트** 또는 **After Effects 프로젝트**를 자동으로 만들고, 미리보기를 보면서 "자막 더 크게" 같은 수정을 요청할 수 있는 Windows 앱이에요. (맥 버전과 같은 기능)

## 받기

GitHub 저장소 → **Releases** → 최신 `EditMaker for Windows` → `EditMaker.exe` 받기 → 더블클릭.

- "Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행** (서명 안 된 앱이라 뜨는 경고예요)
- Windows 10/11 필요 (화면은 Windows에 기본으로 있는 WebView2로 그려요)

## 처음 한 번

- **CapCut**: PC용 CapCut을 열어 아무 프로젝트나 만들었다 닫기
  (프로젝트 폴더: `%LOCALAPPDATA%\CapCut\User Data\Projects\com.lveditor.draft`. 다르면 설정에서 고르기)
- **After Effects** (쓸 때만): 편집 › 환경 설정 › 스크립팅 및 표현식 › "스크립트가 파일을 쓰고 네트워크에 액세스하도록 허용" 켜기
- **AI 감독** (선택): 설정에 Claude 또는 Gemini API 키

## 쓰는 순서

1. **재료**: 레퍼런스 edit 영상, 내 클립(영상·사진), 선택: 다른 음악, .ffx 프리셋
2. **스타일**: 자막 문구, 만들 곳(CapCut / After Effects), 자막 스타일, CC, 효과 양, 번짐 — 전부 AI 자동 가능
3. **만들기**: 폰트 자동 설치 → 프로젝트 생성 → 미리보기 영상
4. **검토·수정**: 채팅으로 수정 요청 또는 타임라인에서 직접 수정 → v2, v3…

결과물: `동영상\EditMaker\edit-날짜\` (버전별 설계도 `.plan.json`, 미리보기 `.preview.mp4`, AE면 `.aep`)

## 소스에서 실행 / 직접 빌드

- `run.bat` : Python 3.10+ 로 바로 실행
- `build.bat` : `dist\EditMaker.exe` 만들기

## 참고

- CapCut 프로젝트는 공식 기능이 아니라 프로젝트 파일 형식을 따라 쓰는 방식이라, CapCut 업데이트 후 안 열릴 수 있어요.
- 앱 안 미리보기는 ffmpeg로 만든 검토용이라 CapCut/AE 결과와 100% 같지는 않아요.
