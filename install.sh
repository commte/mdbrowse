#!/usr/bin/env bash
# Install md-preview into ~/.local/bin and the stylesheet into ~/.config/md-browser-preview
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${MD_PREVIEW_BIN_DIR:-$HOME/.local/bin}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/md-browser-preview"

command -v pandoc >/dev/null 2>&1 || {
  echo "pandoc not found. Install it first (macOS: brew install pandoc, Debian: apt install pandoc)" >&2
  exit 127
}

mkdir -p "$bin_dir" "$config_dir"
install -m 755 "$here/bin/md-preview" "$bin_dir/md-preview"

if [ -f "$config_dir/head.html" ]; then
  echo "kept your existing stylesheet: $config_dir/head.html"
else
  install -m 644 "$here/assets/head.html" "$config_dir/head.html"
  echo "installed stylesheet: $config_dir/head.html"
fi

echo "installed: $bin_dir/md-preview"

# Zed task file — never overwrite an existing one
zed_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
if [ -d "$zed_dir" ]; then
  task_json=$(cat <<JSON
[
  {
    "label": "Preview in browser",
    "command": "$bin_dir/md-preview",
    "args": ["\$ZED_FILE"],
    "reveal": "never",
    "show_summary": false,
    "show_command": false,
    "allow_concurrent_runs": true
  },
  {
    "label": "Open preview tab",
    "command": "$bin_dir/md-preview",
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
  *) echo; echo "note: $bin_dir is not on your PATH. Add it, or call md-preview by its full path." ;;
esac

echo
echo "Next: open the preview tab once, then bind a key in your editor (see README)."
echo "  md-preview --open"
