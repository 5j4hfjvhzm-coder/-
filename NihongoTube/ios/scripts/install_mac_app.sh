#!/bin/sh
# 맥에 "니혼고 튜브" 앱을 설치한다 (Xcode 를 켜지 않고 터미널 한 줄로).
#   사용법: NihongoTube 폴더에서  sh scripts/install_mac_app.sh
# Mac Catalyst 로 Release 빌드 → 이 맥에서만 실행되도록 서명(Sign to Run Locally) → /Applications 에 복사.
# 필요한 것: Xcode (한 번이라도 실행해서 추가 구성요소 설치를 마친 상태)
set -e
cd "$(dirname "$0")/.."

BUILD_DIR="build/mac"
APP="$BUILD_DIR/Build/Products/Release-maccatalyst/NihongoTube.app"

echo "▶︎ 빌드 중… (처음엔 몇 분 걸려요)"
xcodebuild \
  -project NihongoTube.xcodeproj \
  -scheme NihongoTube \
  -configuration Release \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  -quiet \
  build

if [ ! -d "$APP" ]; then
  echo "빌드한 앱을 찾지 못했어요: $APP" >&2
  exit 1
fi

DEST="/Applications/니혼고 튜브.app"
echo "▶︎ $DEST 에 설치"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
# 직접 만든 앱이라 처음 열 때 막히지 않게 격리 표시 제거
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "✓ 설치 끝. Launchpad 나 응용 프로그램 폴더에서 '니혼고 튜브'을 여세요."
open "$DEST"
