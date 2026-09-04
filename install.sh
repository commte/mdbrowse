#!/usr/bin/env bash
# Install mdbrowse into ~/.local/bin and the stylesheet into ~/.config/mdbrowse
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${MDBROWSE_BIN_DIR:-$HOME/.local/bin}"
force=0
[ "${1:-}" = "--force" ] && force=1   # overwrite the installed stylesheet
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mdbrowse"

command -v pandoc >/dev/null 2>&1 || {
  echo "pandoc not found. Install it first (macOS: brew install pandoc, Debian: apt install pandoc)" >&2
  exit 127
}

mkdir -p "$bin_dir" "$config_dir"
# コピーではなくリンクにする。スクリプトが自分の場所からリポジトリ内の
# lib/highlight.mjs と node_modules を辿れるようにするため
ln -sfn "$here/bin/mdbrowse" "$bin_dir/mdbrowse"
ln -sfn "$here/bin/mdbrowse" "$bin_dir/mdb"   # 短い別名

if [ -f "$config_dir/head.html" ] && [ "$force" -eq 0 ]; then
  echo "kept your existing stylesheet: $config_dir/head.html  (use --force to overwrite)"
else
  install -m 644 "$here/assets/head.html" "$config_dir/head.html"
  echo "installed stylesheet: $config_dir/head.html"
fi

echo "installed: $bin_dir/mdbrowse (short alias: $bin_dir/mdb)"

# Zed task file — never overwrite an existing one
zed_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
if [ -d "$zed_dir" ]; then
  task_json=$(cat <<JSON
[
  {
    "label": "Preview in browser",
    "command": "$bin_dir/mdb",
    "args": ["\$ZED_FILE"],
    "reveal": "never",
    "show_summary": false,
    "show_command": false,
    "allow_concurrent_runs": true
  },
  {
    "label": "Open preview tab",
    "command": "$bin_dir/mdb",
    "args": ["--open"],
    "reveal": "never",
    "show_summary": false,
    "show_command": false,
    "allow_concurrent_runs": true
  }
]
JSON
)
  if [ -f "$zed_dir/tasks.json" ]; then
    echo
    echo "$zed_dir/tasks.json already exists — add these entries yourself:"
    echo "$task_json"
  else
    printf '%s\n' "$task_json" > "$zed_dir/tasks.json"
    echo "wrote Zed tasks: $zed_dir/tasks.json"
  fi
fi

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) echo; echo "note: $bin_dir is not on your PATH. Add it, or call mdbrowse by its full path." ;;
esac

echo
echo "Next: start it on a file and keep it running."
echo "  mdb -w -o your-file.md"
