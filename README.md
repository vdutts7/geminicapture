<p align="center">
  <img src="https://raw.githubusercontent.com/vdutts7/squircle/main/webp/gemini.webp?v=1790340717" alt="gemini" width="80" height="80" />
</p>
<h1 align="center">geminicapture</h1>
<p align="center">Export your Gemini chat data from <a href="https://gemini.google.com">gemini.google.com</a></p>

<p align="center">Related: <a href="https://github.com/vdutts7/gptcapture">gptcapture</a></p>

---

## Which tool

<table>
  <tr>
    <td valign="top"><img src="https://raw.githubusercontent.com/vdutts7/squircle/main/webp/gemini.webp?v=1790340717" width="40" height="40" alt="Gemini" /></td>
    <td valign="top">
      <strong><code>geminicanonical.sh</code></strong> - SPA URL → clipboard<br/>
      paste in a logged-in browser address bar
    </td>
  </tr>
  <tr>
    <td valign="top"><img src="https://raw.githubusercontent.com/vdutts7/squircle/main/webp/json.webp?v=1790340717" width="40" height="40" alt="JSON" /></td>
    <td valign="top">
      <strong><code>geminicapture.sh</code></strong> - cookie jar + HTTP dump<br/>
      writes <code>~/Downloads/YYYY-MM-DD_gemini_&lt;hex&gt;.json</code> + clipboard<br/>
      example: <a href="examples/geminicapture.one-turn.json"><code>examples/geminicapture.one-turn.json</code></a>
    </td>
  </tr>
</table>

There is no public GET conversation URL (unlike ChatGPT / Claude). Dump path POSTs `batchexecute` rpc `hNvQHb` with session cookies.

## Setup

```bash
chmod +x geminicanonical.sh geminicapture.sh
```

Prereqs for `geminicapture.sh`:

- [ ] logged into `https://gemini.google.com` in Chrome (or Chromium) with the glider cookie extension / jar
- [ ] jar readable: `glider-cookie-jar read gemini.google.com` (or set `GEMINI_COOKIE_JAR_SCRIPT`)

> note: API keys do NOT work here

## Usage

### Path A · `geminicanonical.sh`

```bash
./geminicanonical.sh https://gemini.google.com/app/8ea7ec555c54ce08
# copies https://gemini.google.com/app/<hex> → clipboard
```

### Path B · `geminicapture.sh`

```bash
./geminicapture.sh 8ea7ec555c54ce08
./geminicapture.sh --clean https://gemini.google.com/app/8ea7ec555c54ce08
# → ~/Downloads/YYYY-MM-DD_gemini_<hex>.json + clipboard
```

## Output shape

| method | example |
|---|---|
| geminicapture (one turn) | `examples/geminicapture.one-turn.json` |
| geminicapture (full skeleton) | `examples/geminicapture.schema.json` |

Dump fields: `source`, `rpc`, `cid`, `chat_hex`, `spa_url`, `messages[]`, `turns_newest_first[]`.

## Gotchas

| problem | fix | why |
|---|---|---|
| no cookies / jar empty | open gemini.google.com logged in; `glider-cookie-jar sync` | dump is cookie-gated batchexecute |
| parsed 0 turns | re-run after generation finishes; try without `--clean` | incomplete wire or still streaming |
| wrong account path | use `/u/N/app/<hex>` URL so account index parses | multi-account Gemini defaults to `/u/2` |

## Tools Used

<img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white&v=1790340717" alt="Bash"/>
<img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white&v=1790340717" alt="Python"/>

<br/>

## Contact

<a href="https://vd7.io"><img src="https://res.cloudinary.com/ddyc1es5v/image/upload/v1773910810/readme-badges/readme-badge-vd7.png?v=1790340717" alt="vd7.io" height="40" /></a>
<a href="https://x.com/vdutts7"><img src="https://res.cloudinary.com/ddyc1es5v/image/upload/v1773910817/readme-badges/readme-badge-x.png?v=1790340717" alt="/vdutts7" height="40" /></a>
