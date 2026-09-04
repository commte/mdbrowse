English | [日本語](README.ja.md)

# mdbrowse

Preview the Markdown file you are editing in a real browser, with your own CSS, from any editor.

Run `mdb` once. It opens a tab, and from then on whatever Markdown file you save — in any project, from any editor — appears in it. No configuration, no server, no port.

![Light theme](docs/preview-light.png)

## Why

Editors render Markdown previews inside their own window and give you little control over the result. Server-based previewers give you control but ask you to keep a process and a port around. This is a shell script on top of `pandoc` plus one HTML file holding the styles: it renders to a fixed path and the tab reloads itself.

Because the output path never changes, switching between files does not open new tabs. The tab you already have simply shows the new file.

## Requirements

- [pandoc](https://pandoc.org/) — macOS: `brew install pandoc`, Debian/Ubuntu: `apt install pandoc`

## Install

```sh
npm install -g @commte/mdbrowse
```

That gives you the command under two names, `mdb` and `mdbrowse`. The examples below use the short one.

Or without installing anything:

```sh
npx @commte/mdbrowse file.md
```

The stylesheet ships with the package. To customize it, copy it to `~/.config/mdbrowse/head.html` — that copy wins over the bundled one from then on:

```sh
mdb --eject
```

<details>
<summary>Install from source instead</summary>

```sh
git clone https://github.com/commte/mdbrowse.git
cd mdbrowse
./install.sh
```

This installs `mdb` (and the longer `mdbrowse`) into `~/.local/bin`, and the stylesheet into `~/.config/mdbrowse/head.html`. Your stylesheet is never overwritten on reinstall; pass `--force` when you do want the shipped one back.

</details>

Then run it once:

```sh
mdb
```

That opens the preview tab and starts a small background process. Save any Markdown file from here on and it shows up in that tab, whichever project it lives in. `mdb --stop` ends it; `mdb` starts it again.

## Usage

```sh
mdb              # open the tab and keep it in sync
mdb --stop       # stop the background sync
mdb --status     # show what is being previewed
mdb file.md      # render one file, once
mdb -w file.md   # follow one file in the foreground (Ctrl-C to stop)
mdb --path       # print the output HTML path
```

| Variable | Default | |
|---|---|---|
| `MDBROWSE_OUT` | `/tmp/mdbrowse.html` | output HTML path |
| `MDBROWSE_HEAD` | `~/.config/mdbrowse/head.html` | stylesheet and browser script |

### How the sync finds your file

It asks Spotlight (`mdfind`) which Markdown file was saved most recently, twice a second-and-a-bit, and renders that one. Walking your disk is never involved, so it stays cheap. Files under hidden directories, `node_modules` and `~/Library` are ignored. Without Spotlight it falls back to watching the directory you started `mdb` in.

The file you are editing right now is checked every second directly, so repeated saves show up immediately; moving to a different file takes a couple of seconds longer, while Spotlight notices it.

Because it follows whatever was saved last, another program writing a Markdown file can pull the preview away. If you want the tab pinned to one file, run `mdb -w that-file.md` instead — that watches only what you name, and stops when you press `Ctrl-C`.

## In-page controls

A small bar sits in the top-right corner: theme, font size, content width, and a toggle for the table of contents. Choices are stored in the browser, so they survive reloads and apply to every file you preview afterwards. Nothing is written to disk and no server is involved.

The table of contents is built from the headings of the current file and follows your position as you scroll. It appears when a file has at least three headings.

![Dark theme](docs/preview-dark.png)

## Editor setup

None of this is needed — `mdb` already follows what you save. Set one of these up if you would rather press a key and have nothing running in the background. They all call `mdb <file>`, the render-once mode.

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
      "command": "mdb",
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
  vim.fn.jobstart({ "mdb", vim.fn.expand("%:p") })
end)

-- or update the preview on every save
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.md",
  callback = function() vim.fn.jobstart({ "mdb", vim.fn.expand("%:p") }) end,
})
```

### JetBrains IDEs

Settings → Tools → External Tools → add `mdb` with `$FilePath$` as the argument, then assign a shortcut under Keymap.

### Emacs

```elisp
(defun mdb ()
  (interactive)
  (start-process "mdb" nil "mdb" (buffer-file-name)))
```

### Anything else

If your editor can run `mdb /path/to/the/current/file.md`, it works.

## Styling

Code blocks are highlighted with [Shiki](https://shiki.style/) (`github-dark` by default; set `MDBROWSE_SHIKI_THEME` to any bundled theme, e.g. `tokyo-night`). Highlighting happens at conversion time, so the page stays static. Without Node available it falls back to pandoc's built-in highlighting.

Everything else visual lives in `~/.config/mdbrowse/head.html`: a settings block at the top, the rules that use it, and the script that draws the bar and runs the reload loop. Colors and typography follow GitHub (Primer) by default. Edit that one file and every preview follows; values changed in the bar override them per browser.

`sample.md` in this repository exercises headings, lists, task lists, quotes, code blocks, tables and links — render it to check your styling:

```sh
mdb sample.md
```

## How it works

```
save a file → mdb (or an editor shortcut) → pandoc → /tmp/mdbrowse.html
                                             → /tmp/mdbrowse-stamp.js
                                                      ↑
                              browser polls the stamp, reloads only on change
```

YAML front matter is consumed rather than printed: the file's own `title` does not become a second heading above your document. Relative paths in the source file (images, links to neighbouring files) are rewritten to absolute `file://` URLs during conversion, so images show up even though the HTML lives in `/tmp`. Only attributes of tags such as `img` and `a` are touched, so `src="foo.png"` written in your prose stays as you typed it. Absolute paths, anything with a scheme (`http(s)`, `data:`, `mailto:`), protocol-relative URLs and in-page anchors are left alone, and `&`, `#` or spaces in the path do not break the result.

Each render also writes a one-line stamp file. The page polls that stamp instead of reloading blindly, so it refreshes only when you actually preview something new — no periodic flicker on pages with images. Polling pauses while you scroll, while you print, and while the pointer is on the bar. Image dimensions are remembered per session, so a refresh does not shift the layout while images load.

Watching is the same render in a loop. The background process compares the file's timestamp and size once a second, asks Spotlight for the newest Markdown file every other second, and renders again when either changes. It listens on nothing and has no port; `mdb --stop` ends it, and it is a single shell process you can see in `ps`.

The page is static, so nothing is listening and nothing needs to be shut down.

## License

MIT
