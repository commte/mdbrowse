[English](README.md) | 日本語

# md-browser-preview

編集中の Markdown を、自分の CSS でブラウザに表示する。シェルコマンドを実行できるエディタなら何でも使える

サーバーもポートも常駐プロセスも要らない。ショートカットを押すと現在のファイルが固定パスの HTML に変換され、開いたままのブラウザのタブがそれを拾う

![ライトテーマ](docs/preview-light.png)

## 何のために作ったか

エディタ内蔵のプレビューは、エディタの中で描画されるので見た目に手を入れられない。サーバーを立てるツールなら自由になるが、常駐とポートを引き受けることになる。これはどちらでもない。pandoc の上に乗せたシェルスクリプトと、スタイルを収めた HTML が1枚あるだけ

出力先が常に同じなので、ファイルを切り替えてもタブは増えない。すでに開いているタブの中身が入れ替わる

## 必要なもの

- [pandoc](https://pandoc.org/) macOS は `brew install pandoc`、Debian/Ubuntu は `apt install pandoc`
- 現在開いているファイルのパスを渡してシェルコマンドを実行できるエディタ

## インストール

```sh
git clone https://github.com/commte/md-browser-preview.git
cd md-browser-preview
./install.sh
```

`md-preview` が `~/.local/bin` に、スタイルシートが `~/.config/md-browser-preview/head.html` に入る。再インストールしても自分で編集したスタイルシートは上書きされない。配布時の状態に戻したいときは `--force` を付ける

プレビュー用のタブを1回だけ開いて、そのままにしておく

```sh
md-preview --open
```

## 使い方

```sh
md-preview file.md   # 変換する（出力 HTML を上書きする）
md-preview --open    # プレビュー用のタブを開く
md-preview --path    # 出力先の HTML のパスを表示する
```

| 環境変数 | 既定値 | |
|---|---|---|
| `MD_PREVIEW_OUT` | `/tmp/md-preview.html` | 出力先の HTML |
| `MD_PREVIEW_HEAD` | `~/.config/md-browser-preview/head.html` | スタイルとブラウザ側のスクリプト |

## ページ内の操作

右上に小さなバーが出る。テーマ、文字サイズ、本文幅、目次の表示を切り替えられる。選択はブラウザに保存されるので、再読み込みしても次に開くファイルにも引き継がれる。ディスクには何も書かず、サーバーも使わない

右サイドバーの目次は、そのファイルの見出しから組み立てられ、スクロール位置に追従する。見出しが3つ以上あるファイルで表示される

![ダークテーマ](docs/preview-dark.png)

## エディタの設定

### Zed

`install.sh` が `~/.config/zed/tasks.json` を作る。既存のファイルがある場合は上書きせず、貼り付ける内容を表示する。あとは `~/.config/zed/keymap.json` にキーを追加する

```json
{
  "bindings": {
    "cmd-shift-m": ["task::Spawn", { "task_name": "Preview in browser" }]
  }
}
```

つまずきやすい点

- 単独のキーの組み合わせにする。`cmd-k` から始まる2段のキーは、Zed 自身が前置きキーとして使っているため安定しない
- `"context"` を書くなら `Workspace` にする。`Editor` に書くと `task::Spawn` は発火しない

### VS Code / Cursor / Windsurf

`.vscode/tasks.json`

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

`keybindings.json` で `workbench.action.tasks.runTask` に割り当てる

### Neovim

```lua
vim.keymap.set("n", "<leader>mp", function()
  vim.fn.jobstart({ "md-preview", vim.fn.expand("%:p") })
end)

-- 保存のたびに更新する場合
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.md",
  callback = function() vim.fn.jobstart({ "md-preview", vim.fn.expand("%:p") }) end,
})
```

### JetBrains 系

設定 → ツール → 外部ツール で `md-preview` を追加し、引数に `$FilePath$` を指定する。Keymap でショートカットを割り当てる

### Emacs

```elisp
(defun md-preview ()
  (interactive)
  (start-process "md-preview" nil "md-preview" (buffer-file-name)))
```

### それ以外

`md-preview /path/to/current/file.md` を実行できるエディタなら動く

## 見た目を変える

見た目に関わるものは `~/.config/md-browser-preview/head.html` に集まっている。先頭の設定ブロック、それを使う CSS、バーと更新検知のスクリプトという構成で、配色とタイポグラフィは GitHub（Primer）に合わせてある。このファイルを直せば全ファイルのプレビューに反映される。バーで変更した値は、その人のブラウザ側で既定値を上書きする

表示確認用に `sample.md` が入っている

```sh
md-preview sample.md
```

## 仕組み

```
エディタのショートカット → md-preview <file> → pandoc → /tmp/md-preview.html
                                                      → /tmp/md-preview-stamp.js
                                                              ↑
                                       ブラウザがスタンプを見て、変化したときだけ再読み込み
```

変換のたびに1行のスタンプファイルも書き出す。ブラウザは無条件に再読み込みせず、このスタンプを見て、新しく変換されたときだけ読み直す。画像のあるページで定期的にちらつかないのはこのため。スクロール中と印刷中、バーを操作している間はスタンプの確認を止める。画像の寸法はセッションに記憶して、読み込み中にレイアウトがずれないようにしている

元ファイルからの相対パス（画像や隣のファイルへのリンク）は、変換時に絶対 `file://` へ書き換える。HTML が `/tmp` にあっても画像が表示されるのはこのため。絶対パス、`http(s)`、`data:`、`mailto:`、ページ内アンカーはそのまま残す

ページは静的なので、待ち受けているものは何も無く、終了させる必要もない

## ライセンス

MIT
