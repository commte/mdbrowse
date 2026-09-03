English | [日本語](README.ja.md)

# mdbrowse

Preview the Markdown file you are editing in a real browser, with your own CSS, from any editor that can run a shell command.

No server. No port. No daemon. One shortcut renders the current file to a fixed HTML path, and the browser tab you already have open picks it up.

![Light theme](docs/preview-light.png)

## Why

Editors render Markdown previews inside their own window and give you little control over the result. Server-based previewers give you control but ask you to keep a process and a port around. This does neither: it is a shell script on top of `pandoc`, plus one HTML file holding the styles.

Because the output path never changes, switching between files does not open new tabs. The tab you already have simply shows the new file.

## Requirements

- [pandoc](https://pandoc.org/) — macOS: `brew install pandoc`, Debian/Ubuntu: `apt install pandoc`
- An editor that can run a shell command with the path of the active file

## Install

```sh
npm install -g @commte/mdbrowse
```

Or without installing anything:

```sh
npx @commte/mdbrowse file.md
```

The stylesheet ships with the package. To customize it, copy it to `~/.config/mdbrowse/head.html` — that copy wins over the bundled one from then on:

```sh
mdbrowse --eject
```

<details>
<summary>Install from source instead</summary>

```sh
git clone https://github.com/commte/mdbrowse.git
cd mdbrowse
./install.sh
```

This installs `mdbrowse` into `~/.local/bin` and the stylesheet into `~/.config/mdbrowse/head.html`. Your stylesheet is never overwritten on reinstall; pass `--force` when you do want the shipped one back.

</details>

Open the preview tab once and leave it open:

```sh
mdbrowse --open
```

## Usage

```sh
mdbrowse file.md   # render (overwrites the output HTML)
mdbrowse --open    # open the preview tab
mdbrowse --path    # print the output HTML path
```

| Variable | Default | |
|---|---|---|
| `MDBROWSE_OUT` | `/tmp/mdbrowse.html` | output HTML path |
| `MDBROWSE_HEAD` | `~/.config/mdbrowse/head.html` | stylesheet and browser script |

## In-page controls

A small bar sits in the top-right corner: theme, font size, content width, and a toggle for the table of contents. Choices are stored in the browser, so they survive reloads and apply to every file you preview afterwards. Nothing is written to disk and no server is involved.

The table of contents is built from the headings of the current file and follows your position as you scroll. It appears when a file has at least three headings.

![Dark theme](docs/preview-dark.png)

## Editor setup

### Zed

`install.sh` writes `~/.config/zed/tasks.json` for you — it will not overwrite an existing one; it prints the entries to paste instead. Then bind a key in `~/.config/zed/keymap.json`:

```json
{
  "bindings": {
    "cmd-shift-m": ["task::Spawn", { "task_name": "Preview in browser" }]
  }
}
```

Two things worth knowing:

- Use a single key combination. `cmd-k`-style chords are unreliable here, because `cmd-k` is already a chord prefix in Zed's own keymaps.
- If you scope the binding with `"context"`, use `Workspace`. `task::Spawn` does not fire from an `Editor` context binding.

### VS Code / Cursor / Windsurf

`.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Preview in browser",
      "type": "shell",
      "command": "mdbrowse",
      "args": ["${file}"],
      "presentation": { "reveal": "never" },
      "problemMatcher": []
    }
  ]
}
```

Bind it in `keybindings.json` with `workbench.action.tasks.runTask`.

### Neovim

```lua
vim.keymap.set("n", "<leader>mp", function()
  vim.fn.jobstart({ "mdbrowse", vim.fn.expand("%:p") })
end)

-- or update the preview on every save
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.md",
  callback = function() vim.fn.jobstart({ "mdbrowse", vim.fn.expand("%:p") }) end,
})
```

### JetBrains IDEs

Settings → Tools → External Tools → add `mdbrowse` with `$FilePath$` as the argument, then assign a shortcut under Keymap.

### Emacs

```elisp
(defun mdbrowse ()
  (interactive)
  (start-process "mdbrowse" nil "mdbrowse" (buffer-file-name)))
```

### Anything else

If your editor can run `mdbrowse /path/to/the/current/file.md`, it works.

## Styling

Code blocks are highlighted with [Shiki](https://shiki.style/) (`github-dark` by default; set `MDBROWSE_SHIKI_THEME` to any bundled theme, e.g. `tokyo-night`). Highlighting happens at conversion time, so the page stays static. Without Node available it falls back to pandoc's built-in highlighting.

Everything else visual lives in `~/.config/mdbrowse/head.html`: a settings block at the top, the rules that use it, and the script that draws the bar and runs the reload loop. Colors and typography follow GitHub (Primer) by default. Edit that one file and every preview follows; values changed in the bar override them per browser.

`sample.md` in this repository exercises headings, lists, task lists, quotes, code blocks, tables and links — render it to check your styling:

```sh
mdbrowse sample.md
```

## How it works

```
editor shortcut → mdbrowse <file> → pandoc → /tmp/mdbrowse.html
                                             → /tmp/mdbrowse-stamp.js
                                                      ↑
                              browser polls the stamp, reloads only on change
```

YAML front matter is consumed rather than printed: the file's own `title` does not become a second heading above your document. Relative paths in the source file (images, links to neighbouring files) are rewritten to absolute `file://` URLs during conversion, so images show up even though the HTML lives in `/tmp`. Absolute paths, `http(s)`, `data:`, `mailto:` and in-page anchors are left alone.

Each render also writes a one-line stamp file. The page polls that stamp instead of reloading blindly, so it refreshes only when you actually preview something new — no periodic flicker on pages with images. Polling pauses while you scroll, while you print, and while the pointer is on the bar. Image dimensions are remembered per session, so a refresh does not shift the layout while images load.

The page is static, so nothing is listening and nothing needs to be shut down.

## License

MIT
