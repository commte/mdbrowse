#!/usr/bin/env bash
# mdbrowse の CLI をひと通り動かす。依存は pandoc だけ（Shiki の確認は node があるときのみ）
set -uo pipefail
set +m   # 背景ジョブの終了通知を出さない

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
MDB="$repo/bin/mdbrowse"

pass=0
fail=0

ok()   { pass=$(( pass + 1 )); printf '  ok   %s\n' "$1"; }
ng()   { fail=$(( fail + 1 )); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }
check(){ # check <説明> <期待> <実際>
  if [ "$2" = "$3" ]; then ok "$1"; else ng "$1" "期待: $2 / 実際: $3"; fi
}
contains(){ # contains <説明> <文字列> <部分>
  case "$2" in *"$3"*) ok "$1" ;; *) ng "$1" "「$3」が含まれない" ;; esac
}
missing(){ # missing <説明> <文字列> <部分>
  case "$2" in *"$3"*) ng "$1" "「$3」が含まれている" ;; *) ok "$1" ;; esac
}

work="$(mktemp -d "${TMPDIR:-/tmp}/mdbtest.XXXXXX")"
work="$(cd "$work" && pwd -P)"
trap 'rm -rf "$work"; pkill -f -- "--sync-daemon $work" 2>/dev/null || true' EXIT

# ロックと PID は ${TMPDIR}/mdbrowse-<uid>/ に置かれる。テスト用に隔離して、
# 実際に動いている追従を止めないようにする
export TMPDIR="$work/tmp"
mkdir -p "$TMPDIR"

export MDBROWSE_OUT="$work/out.html"
export MDBROWSE_HEAD="$repo/assets/head.html"
export XDG_CONFIG_HOME="$work/config"
STAMP="$work/out-stamp.js"

# open を呼ばせない。タブを開かずに確認する
mkdir -p "$work/bin"
printf '#!/bin/sh\nexit 0\n' > "$work/bin/open"
chmod +x "$work/bin/open"
export PATH="$work/bin:$PATH"

title_of(){ grep -o '<title>[^<]*' "$MDBROWSE_OUT" | sed 's/<title>//'; }

echo "変換"

printf '# 見出し\n\n本文\n' > "$work/basic.md"
out="$("$MDB" "$work/basic.md" 2>&1)"; rc=$?
check "終了コード 0" 0 "$rc"
check "タブ名はファイル名" "basic.md" "$(title_of)"
contains "本文が入る" "$(cat "$MDBROWSE_OUT")" "見出し"

printf -- '---\ntitle: フロントマターの題\n---\n\n# 本文の見出し\n' > "$work/fm.md"
"$MDB" "$work/fm.md" >/dev/null 2>&1
missing "frontmatter の title は本文に出さない" "$(cat "$MDBROWSE_OUT")" "title-block-header"

mkdir -p "$work/日本語 ディレクトリ"
printf '# 空白入り\n' > "$work/日本語 ディレクトリ/空白 入り.md"
"$MDB" "$work/日本語 ディレクトリ/空白 入り.md" >/dev/null 2>&1
check "日本語と空白のファイル名" "空白 入り.md" "$(title_of)"

echo
echo "相対パスの書き換え"

mkdir -p "$work/img"
printf 'x' > "$work/img/p.png"
printf '# 画像\n\n![x](img/p.png)\n\n[隣](basic.md)\n\n[外](https://example.com/a.png)\n\n[章へ](#a)\n\n本文の `src="baz.png"` は触らない\n' > "$work/links.md"
"$MDB" "$work/links.md" >/dev/null 2>&1
body="$(cat "$MDBROWSE_OUT")"
contains "相対パスは file:// になる" "$body" "file://$work/img/p.png"
contains "http(s) はそのまま" "$body" 'href="https://example.com/a.png"'
contains "ページ内アンカーはそのまま" "$body" 'href="#a"'
contains "インラインコードは触らない" "$body" '<code>src="baz.png"</code>'

for d in 'a&b' 'c#d' 'e f' 'g"h'; do
  mkdir -p "$work/$d"; printf 'x' > "$work/$d/p.png"
  printf '# q\n\n![x](p.png)\n' > "$work/$d/q.md"
  "$MDB" "$work/$d/q.md" >/dev/null 2>&1
  src="$(grep -o 'src="[^"]*"' "$MDBROWSE_OUT" | head -1)"
  case "$src" in
    *'%26'*|*'%23'*|*'%20'*|*'%22'*) ok "特殊文字を含むディレクトリ（${d}）" ;;
    *) ng "特殊文字を含むディレクトリ（${d}）" "$src" ;;
  esac
done

printf '# raw\n\n<img title="a > b" src="one.png">\n<img src=%s>\n' "'two.png'" > "$work/raw.md"
"$MDB" "$work/raw.md" >/dev/null 2>&1
body="$(cat "$MDBROWSE_OUT")"
contains "属性値に > を含むタグ" "$body" 'src="file://'
contains "単引用符の属性" "$body" "src='file://"

echo
echo "異常系"

"$MDB" --help >/dev/null 2>&1
check "--help は 0" 0 "$?"

"$MDB" "$work/nope.md" >/dev/null 2>&1
check "存在しないファイルは 66" 66 "$?"

"$MDB" "$work/basic.md" "$work/fm.md" >/dev/null 2>&1
check "ファイル2つは 2" 2 "$?"

"$MDB" --nope >/dev/null 2>&1
check "不明なオプションは 2" 2 "$?"

( MDBROWSE_OUT="$work/bad.htm" "$MDB" --path ) >/dev/null 2>&1
check "MDBROWSE_OUT が .html でないと 2" 2 "$?"

before="$(title_of)"
printf 'x\n' > "$work/locked.md"; chmod 000 "$work/locked.md"
"$MDB" "$work/locked.md" >/dev/null 2>&1
rc=$?; chmod 644 "$work/locked.md"
check "変換に失敗したら 0 以外" 1 "$rc"
check "失敗しても前の表示が残る" "$before" "$(title_of)"
check "中間ファイルを残さない" "" "$(ls "$work"/out.html.part* "$work"/out-stamp.js.part* 2>/dev/null)"

echo
echo "スタンプ"

"$MDB" "$work/basic.md" >/dev/null 2>&1; s1="$(cat "$STAMP")"
sleep 1
"$MDB" "$work/basic.md" >/dev/null 2>&1; s2="$(cat "$STAMP")"
if [ "$s1" != "$s2" ]; then ok "変換のたびにスタンプが変わる"; else ng "変換のたびにスタンプが変わる"; fi

echo
echo "--eject と --open"

"$MDB" --eject >/dev/null 2>&1
check "--eject は設定ディレクトリに出す" 0 "$?"
"$MDB" --eject >/dev/null 2>&1
check "--eject の2回目は上書きせず 1" 1 "$?"

rm -f "$MDBROWSE_OUT" "$STAMP"
"$MDB" --open >/dev/null 2>&1
contains "仮ページにも更新監視が入る" "$(cat "$MDBROWSE_OUT")" "checkStamp"
check "--open は追従を始めない" "" "$(pgrep -f -- "--sync-daemon" 2>/dev/null | while read -r p; do ps -p "$p" -o command= | grep -q "$work" && echo x; done)"

echo
echo "監視"

printf '# 最初\n' > "$work/watch.md"
"$MDB" -w "$work/watch.md" >/dev/null 2>&1 &
wpid=$!
sleep 2
printf '# 二回目\n' > "$work/watch.md"
sleep 2
contains "保存すると変換し直す" "$(cat "$MDBROWSE_OUT")" "二回目"
{ kill $wpid; wait $wpid; } 2>/dev/null || true

mkdir -p "$work/tree/sub"
printf '# A\n' > "$work/tree/a.md"; printf '# B\n' > "$work/tree/sub/b.md"
"$MDB" -w "$work/tree" >/dev/null 2>&1 &
wpid=$!
sleep 2
printf '# B を更新\n' > "$work/tree/sub/b.md"
sleep 2
contains "ディレクトリ監視は最後に保存したものを出す" "$(cat "$MDBROWSE_OUT")" "B を更新"
{ kill $wpid; wait $wpid; } 2>/dev/null || true

( MDBROWSE_HEAD="$work/nonexistent.html" "$MDB" -w "$work/watch.md" >/dev/null 2>&1 & echo $! > "$work/w2.pid" )
sleep 2
if kill -0 "$(cat "$work/w2.pid")" 2>/dev/null; then ok "スタイルシートが無くても監視は続く"; else ng "スタイルシートが無くても監視は続く"; fi
{ kill "$(cat "$work/w2.pid")"; wait; } 2>/dev/null || true

echo
echo "背景プロセス"

# Spotlight が何も返さない状況を作る
printf '#!/bin/sh\nexit 0\n' > "$work/bin/mdfind"; chmod +x "$work/bin/mdfind"
daemons(){ pgrep -f -- "--sync-daemon $work" 2>/dev/null | wc -l | tr -d ' '; }

"$MDB" --stop >/dev/null 2>&1
for i in 1 2 3 4 5; do "$MDB" --sync-daemon "$work" >/dev/null 2>&1 & done
sleep 3
check "同時に起こしても1つだけ" 1 "$(daemons)"
contains "起きているものは --status に出る" "$("$MDB" --status 2>&1)" "in sync"

"$MDB" --stop >/dev/null 2>&1
sleep 1
check "--stop で消える" 0 "$(daemons)"
contains "--stop のあとは not running" "$("$MDB" --status 2>&1)" "not running"

# Spotlight が何も返さなくても落ちない（起動直後は該当なしが普通）
"$MDB" --sync-daemon "$work" >/dev/null 2>&1 &
sleep 2
check "該当なしでも生き続ける" 1 "$(daemons)"
"$MDB" --stop >/dev/null 2>&1

echo
echo "そのほか"

contains "--version は版を出す" "$("$MDB" --version)" "mdbrowse"
check "--path は出力先" "$MDBROWSE_OUT" "$("$MDB" --path)"
contains "--help は使い方" "$("$MDB" --help)" "Usage:"

if command -v node >/dev/null 2>&1; then
  printf '# code\n\n```js\nconst a = 1;\n```\n' > "$work/code.md"
  "$MDB" "$work/code.md" >/dev/null 2>&1
  if grep -q 'style="color:#' "$MDBROWSE_OUT"; then ok "Shiki で色が付く"; else ng "Shiki で色が付く"; fi
fi

echo
printf '通った %d 件、落ちた %d 件\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
