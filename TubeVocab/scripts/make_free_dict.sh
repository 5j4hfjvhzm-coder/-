#!/bin/sh
# 무료 사전 소스 3개를 받아서 앱 내장 사전(TubeVocab/Resources/dict.db)을 만든다.
#   WordNet 3.0 (영영 뜻·예문·불규칙 활용·구동사)
#   open-english-korean-dict (한국어 대표 뜻, CC BY-SA 4.0)
#   kengdic (한국어 뜻 보강·숙어)
# 사용법: TubeVocab 폴더에서  sh scripts/make_free_dict.sh
set -e
cd "$(dirname "$0")/.."
SRC=scripts/sources
mkdir -p "$SRC"

if [ ! -f "$SRC/wordnet/data.noun" ]; then
  curl -L -o "$SRC/wordnet.zip" https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/wordnet.zip
  (cd "$SRC" && unzip -qo wordnet.zip)
fi
[ -f "$SRC/word_dictionary.sqlite" ] || curl -L -o "$SRC/word_dictionary.sqlite" \
  https://raw.githubusercontent.com/jhseo1211/open-english-korean-dict/main/dict/word_dictionary.sqlite
[ -f "$SRC/kengdic.tsv" ] || curl -L -o "$SRC/kengdic.tsv" \
  https://raw.githubusercontent.com/garfieldnate/kengdic/master/kengdic.tsv

python3 scripts/build_dict.py \
  --wordnet "$SRC/wordnet" \
  --oekd "$SRC/word_dictionary.sqlite" \
  --kengdic "$SRC/kengdic.tsv" \
  --max-senses 10 \
  --out TubeVocab/Resources/dict.db "$@"
