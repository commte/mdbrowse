// pandoc が出したプレーンなコードブロックを Shiki で色付けし直す。
// 変換時に静的な HTML にするので、ブラウザ側で JS は動かない
import { readFile, writeFile } from 'node:fs/promises'

const THEME = process.env.MDBROWSE_SHIKI_THEME || 'github-dark'
const file = process.argv[2]
if (!file) process.exit(0)

const unescape = (s) =>
  s.replace(/&lt;/g, '<').replace(/&gt;/g, '>')
   .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
   .replace(/&amp;/g, '&')

const html = await readFile(file, 'utf8')
const blocks = [...html.matchAll(/<pre(?: class="([^"]*)")?><code(?: class="[^"]*")?>([\s\S]*?)<\/code><\/pre>/g)]
if (!blocks.length) process.exit(0)

const { createHighlighter, bundledLanguages } = await import('shiki')

const langOf = (cls) => {
  const first = (cls || '').split(/\s+/).filter(Boolean)[0]
  if (!first) return 'text'
  const name = first.replace(/^language-/, '').toLowerCase()
  return name in bundledLanguages ? name : 'text'
}

const langs = [...new Set(blocks.map((m) => langOf(m[1])))].filter((l) => l !== 'text')
const highlighter = await createHighlighter({ themes: [THEME], langs })

let out = html
for (const m of blocks) {
  const lang = langOf(m[1])
  const code = unescape(m[2])
  const rendered = highlighter.codeToHtml(code, { lang, theme: THEME })
  out = out.replace(m[0], rendered)
}
await writeFile(file, out)
