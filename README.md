# md-browser-preview

Preview the Markdown file you are editing in a real browser, with your own CSS, from any editor that can run a shell command.

No server. No port. No daemon. One shortcut renders the current file to a fixed HTML path, and the already-open browser tab picks it up.

## Why

Built-in Markdown previews render inside the editor and give you no control over the styling. Server-based previewers give you control but ask you to keep a process and a port around. This does neither: it is a 40-line shell script on top of `pandoc`.

Because the output path never changes, switching between files does not open new tabs. The tab you already have simply shows the new file.

## Requirements

- [pandoc](https://pandoc.org/)  (macOS: `brew install pandoc`, Debian/Ubuntu: `apt install pandoc`)
- An editor that can run a shell command with the path of the active file

## Install

```sh
git clone https://github.com/<you>/md-browser-preview.git
cd md-browser-preview
./install.sh
```

This installs `md-preview` into `~/.local/bin` and a stylesheet into `~/.config/md-browser-preview/head.html`. An existing stylesheet is never overwritten.

Open the preview tab once and leave it open:

```sh
md-preview --open
```

## Usage

```sh
md-preview file.md   # render (overwrites the output HTML)
md-preview --open    # open the preview tab
md-preview --path    # print the output HTML path
```

| Variable | Default | |
|---|---|---|
| `MD_PREVIEW_OUT` | `/tmp/md-preview.html` | output HTML path |
| `MD_PREVIEW_HEAD` | `~/.config/md-browser-preview/head.html` | stylesheet and reload script |

## Editor setup

### Zed

`install.sh` writes `~/.config/zed/tasks.json` for you (it will not overwrite an existing one). Then bind a key in `~/.config/zed/keymap.json`:

```json
{
  "bindings": {
    "cmd-shift-m": ["task::Spawn", { "task_name": "Preview in browser" }]
  }
}
```

Pick any key you like. Two things to know:

- `cmd-k`-style chord bindings are unreliable for this, because `cmd-k` is already a chord prefix in Zed's default keymaps. Use a single combination.
- If you do scope the binding with `"context"`, use `Workspace`. `task::Spawn` does not fire from an `Editor` context binding.

`cmd-shift-m` overrides Zed's diagnostics panel shortcut. Your keymap wins over the defaults, and the panel is still reachable from the command palette.

### VS Code / Cursor / Windsurf

`.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Preview in browser",
      "type": "shell",
      "command": "md-preview",
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
  vim.fn.jobstart({ "md-preview", vim.fn.expand("%:p") })
end)

-- or update the preview on every save
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.md",
  callback = function() vim.fn.jobstart({ "md-preview", vim.fn.expand("%:p") }) end,
})
```

### JetBrains IDEs

Settings → Tools → External Tools → add `md-preview` with `$FilePath$` as the argument, then assign a shortcut under Keymap.

### Emacs

```elisp
(defun md-preview ()
  (interactive)
  (start-process "md-preview" nil "md-preview" (buffer-file-name)))
```

### Anything else

If your editor can run `md-preview /path/to/current/file.md`, it works.

## Styling

Everything visual lives in `~/.config/md-browser-preview/head.html`: the CSS plus a small script that reloads the page once a second and restores the scroll position. Edit that one file and every preview follows. It ships with a GitHub-ish light theme and a dark variant that follows the OS setting.

## How it works

```
editor shortcut → md-preview <file> → pandoc → /tmp/md-preview.html
                                                      ↑
                                  browser tab reloads itself every second
```

The reload loop is what removes the need for a server. The page is static, so nothing is listening and nothing needs to be shut down.

## License

MIT
