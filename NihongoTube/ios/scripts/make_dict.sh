#!/bin/sh
# 앱에 들어가는 일→한 사전(NihongoTube/Resources/jadict.db) 다시 만들기
#   사용법: ios 폴더에서  sh scripts/make_dict.sh
set -e
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
git clone --depth 1 https://github.com/Lyroxide/yomichan-ko-dic "$TMP/src"
python3 ../scripts/build_ja_dict.py "$TMP/src" "$TMP/out" --sqlite NihongoTube/Resources/jadict.db
rm -rf "$TMP"
echo "✓ NihongoTube/Resources/jadict.db"
