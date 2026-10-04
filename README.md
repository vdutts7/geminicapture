<p align="center">
  <img src="https://raw.githubusercontent.com/vdutts7/squircle/main/webp/gemini.webp?v=1790340717" alt="gemini" width="80" height="80" />
</p>
<h1 align="center">geminicapture</h1>
<p align="center">Export your Gemini chat data from <a href="https://gemini.google.com">gemini.google.com</a></p>

<p align="center">Related: <a href="https://github.com/vdutts7/gptcapture">gptcapture</a></p>

---

## Usage

Paste `geminicapture.js` in DevTools on an open chat (`/app/<hex>`). Downloads `~/Downloads`-style filename via browser: `YYYY-MM-DD_gemini_<hex>.json`.

```js
// on https://gemini.google.com/app/8ea7ec555c54ce08 (logged in)
// auto-downloads 2026-09-30_gemini_8ea7ec555c54ce08.json
```

Uses page session cookies + `batchexecute` rpc `hNvQHb` (no public GET conversation URL). Debug: `window.__GEMINICAPTURE`.

> note: API keys do NOT work here

## Output shape

| method | example |
|---|---|
| geminicapture (one turn) | `examples/geminicapture.one-turn.json` |
| geminicapture (full skeleton) | `examples/geminicapture.schema.json` |

Dump fields: `source`, `rpc`, `cid`, `chat_hex`, `spa_url`, `messages[]`, `turns_newest_first[]`.

## Gotchas

| problem | fix | why |
|---|---|---|
| not on a chat URL | open `/app/<hex>` then re-run | hex parsed from path |
| parsed 0 turns | wait until generation finishes; re-run | incomplete wire / still streaming |
| wrong account path | use `/u/N/app/<hex>` | multi-account Gemini |

## Tools Used

<img src="https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black&v=1790340717" alt="JavaScript"/>

<br/>

## Contact

<a href="https://vd7.io"><img src="https://res.cloudinary.com/ddyc1es5v/image/upload/v1773910810/readme-badges/readme-badge-vd7.png?v=1790340717" alt="vd7.io" height="40" /></a>
<a href="https://x.com/vdutts7"><img src="https://res.cloudinary.com/ddyc1es5v/image/upload/v1773910817/readme-badges/readme-badge-x.png?v=1790340717" alt="/vdutts7" height="40" /></a>
