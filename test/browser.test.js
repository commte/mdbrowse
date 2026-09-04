// assets/head.html に埋め込んでいるブラウザ側のスクリプトを、jsdom の中で動かして確かめる。
// ページを配る作りなので、ここが壊れると開いているタブが黙って更新されなくなる
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'

const here = dirname(fileURLToPath(import.meta.url))
const head = readFileSync(join(here, '..', 'assets', 'head.html'), 'utf8')

const scripts = [...head.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1])
if (scripts.length < 1) throw new Error('head.html からスクリプトを取り出せない')

let reloads
let stamp
let stampRequests
let listeners

// スタンプは file:// の <script> で読む。jsdom は読みに行かないので、こちらで返す
function serveStamp() {
  const original = document.head.appendChild.bind(document.head)
  document.head.appendChild = (node) => {
    if (node.tagName === 'SCRIPT' && String(node.src || '').includes('-stamp.js')) {
      stampRequests++
      const el = node
      queueMicrotask(() => {
        if (stamp === null) {
          if (el.onerror) el.onerror()
          return
        }
        window.__mdbrowseStamp = stamp
        if (el.onload) el.onload()
      })
      return node
    }
    return original(node)
  }
}

function boot(bodyHtml, { intersectionObserver = true, hover = true } = {}) {
  document.documentElement.innerHTML = `<head></head><body>${bodyHtml}</body>`
  window.__mdbrowseStamp = undefined
  reloads = 0
  stampRequests = 0

  // jsdom の location.reload は差し替えられないので、スクリプトに渡す location を影にする
  const fakeLocation = {
    pathname: '/tmp/mdbrowse.html',
    href: 'file:///tmp/mdbrowse.html',
    reload: () => { reloads++ },
  }

  if (intersectionObserver) {
    window.IntersectionObserver = class {
      constructor(cb) { this.cb = cb }
      observe() {}
      disconnect() {}
    }
    globalThis.IntersectionObserver = window.IntersectionObserver
  } else {
    delete window.IntersectionObserver
    delete globalThis.IntersectionObserver
  }

  window.matchMedia = (q) => ({
    matches: q.includes('hover') ? hover : false,
    media: q,
    addListener() {},
    removeListener() {},
    addEventListener() {},
    removeEventListener() {},
  })

  // window に直接足すと、前のテストで登録した分まで一緒に動いてしまう。
  // スクリプトに渡す addEventListener を影にして、boot ごとに閉じる
  listeners = {}
  const addEventListenerShim = (type, fn) => {
    ;(listeners[type] = listeners[type] || []).push(fn)
  }

  serveStamp()
  for (const code of scripts) {
    window.eval('(function (location, addEventListener) {\n' + code + '\n})')(
      fakeLocation,
      addEventListenerShim
    )
  }
  fire('DOMContentLoaded')
}

function fire(type) {
  for (const fn of listeners[type] || []) fn(new window.Event(type))
}

// 最初の確認で known を埋め、その後に値を変えるとリロードが起きる
async function settle(ms = 0) {
  await Promise.resolve()
  if (ms) vi.advanceTimersByTime(ms)
  await Promise.resolve()
  await Promise.resolve()
}

beforeEach(() => {
  vi.useFakeTimers()
  stamp = 'first'
  localStorage.clear()
})

afterEach(() => {
  vi.useRealTimers()
})

describe('更新の検知', () => {
  it('スタンプが変わらないうちは読み直さない', async () => {
    boot('<h1 id="a">a</h1><p>x</p>')
    await settle()
    await settle(1000)
    expect(reloads).toBe(0)
    expect(stampRequests).toBeGreaterThan(1)
  })

  it('スタンプが変わったら読み直す', async () => {
    boot('<h1 id="a">a</h1><p>x</p>')
    await settle()
    stamp = 'second'
    await settle(1000)
    expect(reloads).toBeGreaterThan(0)
  })

  it('スタンプを読めなくても止まらない', async () => {
    boot('<h1 id="a">a</h1><p>x</p>')
    await settle()
    stamp = null
    await settle(1000)
    const before = stampRequests
    stamp = 'third'
    await settle(1000)
    expect(stampRequests).toBeGreaterThan(before)
  })

  it('印刷中は確認しない', async () => {
    boot('<h1 id="a">a</h1><p>x</p>')
    await settle()
    fire('beforeprint')
    const before = stampRequests
    stamp = 'while-printing'
    await settle(2000)
    expect(stampRequests).toBe(before)
    expect(reloads).toBe(0)

    fire('afterprint')
    await settle(1000)
    expect(reloads).toBeGreaterThan(0)
  })

  it('印刷が終わらないままでも、しばらくすれば再開する', async () => {
    boot('<h1 id="a">a</h1><p>x</p>')
    await settle()
    fire('beforeprint')
    stamp = 'later'
    await settle(2000)
    expect(reloads).toBe(0)
    await settle(61000)
    expect(reloads).toBeGreaterThan(0)
  })

  it('バーにポインタがある間は止め、離れれば再開する', async () => {
    boot('<h1 id="a">a</h1><p>x</p>')
    await settle()
    const bar = document.getElementById('mdbar')
    bar.matches = (sel) => sel === ':hover'
    stamp = 'hovering'
    await settle(1000)
    expect(reloads).toBe(0)
    bar.matches = () => false
    await settle(1000)
    expect(reloads).toBeGreaterThan(0)
  })

  it('hover を持たない端末では、hover で止めない', async () => {
    boot('<h1 id="a">a</h1><p>x</p>', { hover: false })
    await settle()
    const bar = document.getElementById('mdbar')
    bar.matches = (sel) => sel === ':hover'
    stamp = 'touch'
    await settle(1000)
    expect(reloads).toBeGreaterThan(0)
  })

  it('IntersectionObserver が無い環境でも更新の監視は動く', async () => {
    boot(
      '<h1 id="t">タイトル</h1><h2 id="a">a</h2><h2 id="b">b</h2><h2 id="c">c</h2>',
      { intersectionObserver: false }
    )
    await settle()
    stamp = 'no-io'
    await settle(1000)
    expect(reloads).toBeGreaterThan(0)
  })
})

describe('目次', () => {
  it('最上位が1つだけならタイトルとみなして外す', async () => {
    boot('<h1 id="t">タイトル</h1><h2 id="a">a</h2><h2 id="b">b</h2><h2 id="c">c</h2>')
    await settle()
    const links = [...document.querySelectorAll('#mdtoc a')].map((a) => a.textContent)
    expect(links).toEqual(['a', 'b', 'c'])
  })

  it('h3 から始まる文書でも同じように出る', async () => {
    boot('<h3 id="t">題</h3><h4 id="a">a</h4><h4 id="b">b</h4><h4 id="c">c</h4>')
    await settle()
    const links = [...document.querySelectorAll('#mdtoc a')].map((a) => a.textContent)
    expect(links).toEqual(['a', 'b', 'c'])
  })

  it('見出しが少なければ出さない', async () => {
    boot('<h1 id="t">題</h1><h2 id="a">a</h2>')
    await settle()
    expect(document.getElementById('mdtoc')).toBe(null)
  })

  it('いちばん浅い2階層に線を引く', async () => {
    boot('<h2 id="a">a</h2><h3 id="b">b</h3><h4 id="c">c</h4>')
    await settle()
    expect(document.getElementById('a').classList.contains('mdrule')).toBe(true)
    expect(document.getElementById('b').classList.contains('mdrule')).toBe(true)
    expect(document.getElementById('c').classList.contains('mdrule')).toBe(false)
  })
})

describe('バーの設定', () => {
  it('本文幅は1回目から変わる', async () => {
    boot('<h1 id="a">a</h1>')
    await settle()
    const bar = document.getElementById('mdbar')
    bar.querySelector('[data-act=width]').click()
    expect(JSON.parse(localStorage.getItem('mdbrowse')).width).toBe(680)
  })

  it('テーマと文字サイズは保存される', async () => {
    boot('<h1 id="a">a</h1>')
    await settle()
    const bar = document.getElementById('mdbar')
    bar.querySelector('[data-act=theme]').click()
    bar.querySelector('[data-act=inc]').click()
    const s = JSON.parse(localStorage.getItem('mdbrowse'))
    expect(s.theme).toBe('dark')
    expect(s.fontSize).toBe(17)
    expect(document.documentElement.dataset.theme).toBe('dark')
  })

  it('文字サイズは 16px を下回らない', async () => {
    boot('<h1 id="a">a</h1>')
    await settle()
    const dec = document.getElementById('mdbar').querySelector('[data-act=dec]')
    for (let i = 0; i < 10; i++) dec.click()
    expect(JSON.parse(localStorage.getItem('mdbrowse')).fontSize).toBe(16)
  })

  it('localStorage が使えなくても落ちない', async () => {
    const original = Storage.prototype.setItem
    Storage.prototype.setItem = () => { throw new Error('QuotaExceeded') }
    try {
      boot('<h1 id="a">a</h1>')
      await settle()
      const bar = document.getElementById('mdbar')
      expect(() => bar.querySelector('[data-act=theme]').click()).not.toThrow()
      expect(document.documentElement.dataset.theme).toBe('dark')
    } finally {
      Storage.prototype.setItem = original
    }
  })
})
