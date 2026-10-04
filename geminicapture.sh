#!/usr/bin/env bash
# geminicapture.sh - Gemini chat dump (cookie jar + HTTP, no tab hijack)
#
# usage:
#   geminicapture <hex>                 # bare chat hex is enough
#   geminicapture <chat-url>            # ~/Downloads/YYYY-MM-DD_gemini_<hex>.json + clipboard
#   geminicapture --clean <hex>         # same file, empty fields / dup lines / indent whitespace removed
#   geminicapture --raw <hex>           # wire batchexecute → ~/Downloads/...txt + clipboard
#
# SPA URL only (no dump): use geminicanonical.sh
set -euo pipefail
trap 'exit 130' INT TERM HUP

DUMP=1
RAW_WIRE=0
CLEAN=0
CLEAN_ONLY=0
PARSE_ID=0
RAW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dump|-d) DUMP=1; shift;;
    --raw) DUMP=1; RAW_WIRE=1; shift;;
    --clean) CLEAN=1; shift;;
    --clean-json) CLEAN_ONLY=1; shift;;
    --parse-id) PARSE_ID=1; shift;;
    -h|--help)
      cat <<'EOF'
usage: geminicapture <hex>              # bare 16+ hex is enough
       geminicapture <chat-url>
       geminicapture --clean <hex>      # post-pass on the same JSON
       geminicapture --clean-json       # clean a JSON document on stdin (no fetch)
       geminicapture --raw <hex>        # wire batchexecute text dump

JSON → ~/Downloads/YYYY-MM-DD_gemini_<hex>.json and the clipboard.
--clean keeps every non-empty value. It drops nulls, empty strings, empty
lists, empty objects, consecutive duplicate lines, and indent whitespace.
does NOT navigate / steal your browser tabs (cookie + HTTP background dump).

reads from the glider cookie jar (live extension → jar fallback).
override jar script: GEMINI_COOKIE_JAR_SCRIPT=/path/to/glider-cookie-jar.sh
EOF
      exit 0
      ;;
    *) RAW="$1"; shift;;
  esac
done

if [[ -z "$RAW" ]]; then
  RAW="$(/usr/bin/pbpaste 2>/dev/null || true)"
fi

export GEMINI_CANON_RAW="$RAW"
export GEMINI_CANON_DUMP="$DUMP"
export GEMINI_CANON_RAW_WIRE="$RAW_WIRE"
export GEMINI_CANON_CLEAN="$CLEAN"
export GEMINI_CANON_CLEAN_ONLY="$CLEAN_ONLY"
export GEMINI_CANON_PARSE_ID="$PARSE_ID"
# Program on fd 3 so --clean-json can read the JSON document on stdin.
python3 /dev/fd/3 3<<'PY'
import json, os, random, re, subprocess, sys, time, urllib.error, urllib.parse, urllib.request
from datetime import date
from json import JSONDecoder
from pathlib import Path

raw = os.environ.get("GEMINI_CANON_RAW") or ""
dump = os.environ.get("GEMINI_CANON_DUMP") == "1"
raw_wire = os.environ.get("GEMINI_CANON_RAW_WIRE") == "1"
clean = os.environ.get("GEMINI_CANON_CLEAN") == "1"
clean_only = os.environ.get("GEMINI_CANON_CLEAN_ONLY") == "1"
parse_id = os.environ.get("GEMINI_CANON_PARSE_ID") == "1"


def squeeze_text(s: str) -> str:
    """Trim, collapse blank runs, drop consecutive duplicate lines. Keep the words."""
    text = s.replace("\r\n", "\n").replace("\r", "\n").replace("\u00a0", " ")
    lines = [ln.rstrip() for ln in text.split("\n")]
    out = []
    prev = object()
    for ln in lines:
        if ln == prev:
            continue
        out.append(ln)
        prev = ln
    return "\n".join(out).strip()


def clean_noise(node):
    """Drop empty containers and whitespace noise. Keep 0, False, and any real value."""
    if isinstance(node, str):
        return squeeze_text(node)
    if isinstance(node, list):
        out = []
        prev = object()
        for item in node:
            cleaned = clean_noise(item)
            if cleaned in (None, "", [], {}):
                continue
            if cleaned == prev:
                continue
            out.append(cleaned)
            prev = cleaned
        return out
    if isinstance(node, dict):
        out = {}
        for key, val in node.items():
            cleaned = clean_noise(val)
            if cleaned in (None, "", [], {}):
                continue
            out[key] = cleaned
        return out
    return node


def parse_chat_ref(text: str):
    """Bare hex, c_<hex>, or a gemini /app/ URL. Account defaults to 2."""
    s = (text or "").strip()
    m_u = re.search(r"/u/(\d+)/", s)
    account = m_u.group(1) if m_u else "2"
    m = re.fullmatch(r"(?:c_)?([0-9a-f]{16,})", s, re.I)
    if not m:
        m = re.search(r"(?:/app/|c_)([0-9a-f]{16,})", s, re.I)
    if not m:
        return None, account
    return m.group(1).lower(), account


if clean_only:
    doc = json.load(sys.stdin)
    cleaned = clean_noise(doc)
    sys.stdout.write(json.dumps(cleaned, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.exit(0)

hex_id, account = parse_chat_ref(raw)
if not hex_id:
    print("🔴 usage: geminicapture <hex>  (or a chat URL, or copy one first)", file=sys.stderr)
    sys.exit(1)

if parse_id:
    print(hex_id)
    sys.exit(0)
spa = f"https://gemini.google.com/app/{hex_id}"
goto = f"https://gemini.google.com/u/{account}/app/{hex_id}"
api_cid = f"c_{hex_id}"
path_prefix = f"/u/{account}"

subprocess.run(["/usr/bin/pbcopy"], input=spa.encode(), check=False)
if not dump:
    print(f"🟢 {hex_id} -> SPA canonical copied.")
    print("🟢 dump: geminicapture   (copy chat URL first)")
    sys.exit(0)

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"
)


def sh(*args, timeout=60):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout)


def _parse_cookie_header(stdout: str) -> str:
    for line in (stdout or "").splitlines():
        s = line.strip()
        # strip ANSI
        s = re.sub(r"\x1b\[[0-9;]*m", "", s)
        if s.lower().startswith("cookie:"):
            return s.split(":", 1)[1].strip()
        if "SID=" in s and ("SAPISID=" in s or "__Secure-1PSID=" in s):
            return s.replace("Cookie:", "").replace("cookie:", "").strip()
    return ""


JAR_SCRIPT = Path(os.environ.get("GEMINI_COOKIE_JAR_SCRIPT") or "").expanduser() if os.environ.get("GEMINI_COOKIE_JAR_SCRIPT") else (Path.home() / ".cursor" / "tools" / "glider" / "glider-cookie-jar.sh")


def cookie_header() -> str:
    """Cookie jar read (live → jar fallback). No glider connect, no manual files."""
    r = sh(str(JAR_SCRIPT), "read", "gemini.google.com", timeout=25)
    hdr = (r.stdout or "").strip()
    if hdr and "SID=" in hdr:
        return hdr
    print(
        "🔴 no cookies. extension down and no jar. run: glider-cookie-jar sync",
        file=sys.stderr,
    )
    sys.exit(2)


def http_get(url: str, cookie: str) -> str:
    req = urllib.request.Request(
        url,
        headers={
            "Cookie": cookie,
            "User-Agent": UA,
            "Accept": "text/html,application/xhtml+xml",
        },
    )
    with urllib.request.urlopen(req, timeout=45) as resp:
        return resp.read().decode("utf-8", "replace")


def http_post(url: str, body: bytes, cookie: str, referer: str) -> str:
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Cookie": cookie,
            "User-Agent": UA,
            "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
            "Origin": "https://gemini.google.com",
            "Referer": referer,
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        return resp.read().decode("utf-8", "replace")


def tokens_from_html(html: str):
    at = re.search(r'"SNlM0e":"([^"]+)"', html)
    bl = re.search(r'"cfb2h":"([^"]+)"', html)
    fsid = re.search(r'"FdrFJe":"([^"]+)"', html)
    if not (at and bl and fsid):
        return None
    return at.group(1), bl.group(1), fsid.group(1)


def fetch_wire(cookie: str) -> str:
    # try multi-account path first, then bare /app/
    last_err = None
    for prefix, page in (
        (path_prefix, goto),
        ("", spa),
    ):
        try:
            html = http_get(page, cookie)
        except Exception as e:
            last_err = e
            continue
        toks = tokens_from_html(html)
        if not toks:
            last_err = RuntimeError(f"no SNlM0e in HTML for {page} ({len(html)}B)")
            continue
        at, bl, fsid = toks
        payload = json.dumps([api_cid, 10000, None, 1, [0], [4], None, 1])
        freq = json.dumps([[["hNvQHb", payload, None, "generic"]]])
        body = urllib.parse.urlencode({"f.req": freq, "at": at}).encode()
        qs = urllib.parse.urlencode(
            {
                "rpcids": "hNvQHb",
                "source-path": f"{prefix}/app/{hex_id}" if prefix else f"/app/{hex_id}",
                "bl": bl,
                "f.sid": fsid,
                "hl": "en",
                "rt": "c",
                "_reqid": str(random.randint(1, 9_999_999)),
            }
        )
        url = f"https://gemini.google.com{prefix}/_/BardChatUi/data/batchexecute?{qs}"
        try:
            wire = http_post(url, body, cookie, page)
        except urllib.error.HTTPError as e:
            last_err = e
            continue
        if len(wire) > 200 and ("wrb.fr" in wire or wire.startswith(")]}'")):
            return wire
        last_err = RuntimeError(f"short/bad wire via {prefix or '/'}: {len(wire)}B")
    raise RuntimeError(f"dump failed: {last_err}")


def utf16_len(s: str) -> int:
    return len(s.encode("utf-16-le")) // 2


def dig(a, *idxs):
    try:
        cur = a
        for ix in idxs:
            cur = cur[ix]
        return cur
    except Exception:
        return None


def longest_str(node, depth=0, best=""):
    if depth > 12:
        return best
    if isinstance(node, str):
        return node if len(node) > len(best) else best
    if isinstance(node, list):
        for x in node[:50]:
            best = longest_str(x, depth + 1, best)
    return best


def parse_batchexecute(wire: str) -> list:
    body = wire[4:].lstrip("\n") if wire.startswith(")]}'") else wire
    frames = []
    i = 0
    while i < len(body):
        m = re.match(r"(\d+)\n", body[i:])
        if not m:
            break
        n = int(m.group(1))
        i += m.end()
        j = i
        while j < len(body) and utf16_len(body[i:j]) < n:
            j += 1
        while j > i and utf16_len(body[i:j]) > n:
            j -= 1
        frames.append(body[i:j])
        i = j
        if i < len(body) and body[i] == "\n":
            i += 1
    arr, _ = JSONDecoder().raw_decode(frames[0])
    for part in arr:
        if isinstance(part, list) and part and part[0] == "wrb.fr" and part[1] == "hNvQHb":
            return json.loads(part[2])
    raise RuntimeError("no hNvQHb frame")


def wire_to_structured(wire: str, spa_url: str) -> dict:
    inner = parse_batchexecute(wire)
    # shape: [[[[cid, rid, user, …], …], …], …] — walk turns
    turns = dig(inner, 0) or []
    turns_out = []
    for t in turns:
        if not isinstance(t, list) or len(t) < 2:
            continue
        cid = dig(t, 0) or api_cid
        rid = dig(t, 1)
        # user text often at [2][0][0] or nearby longest string in user slot
        user = dig(t, 2, 0, 0)
        if not isinstance(user, str):
            user = longest_str(dig(t, 2) or [])
        # assistant candidates under [3] / [4]
        asst = None
        thoughts = None
        completion_status = None
        rcid = None
        ts = None
        # RE layout (Gemini-API / kept): turn[3] replies, turn[4] meta
        replies = dig(t, 3) or []
        if isinstance(replies, list) and replies:
            r0 = replies[0]
            if isinstance(r0, list):
                rcid = dig(r0, 0)
                asst = dig(r0, 1, 0) if isinstance(dig(r0, 1), list) else dig(r0, 1)
                if not isinstance(asst, str):
                    asst = longest_str(r0)
                completion_status = dig(r0, 10) or dig(r0, 9)
        meta = dig(t, 4) or dig(t, 5)
        if isinstance(meta, list):
            ts = dig(meta, 2) or dig(meta, 0)
        # thoughts sometimes nested
        th = dig(t, 3, 0, 2) or dig(t, 6)
        if isinstance(th, str) and th and th != asst:
            thoughts = th
        turns_out.append(
            {
                "cid": cid,
                "rid": rid,
                "rcid": rcid,
                "user": user if isinstance(user, str) else None,
                "assistant": asst if isinstance(asst, str) else None,
                "thoughts": thoughts,
                "timestamp": ts,
                "completion_status": completion_status,
            }
        )

    messages = []
    for t in reversed(turns_out):
        if t["user"]:
            messages.append(
                {
                    "role": "user",
                    "content": t["user"],
                    "rid": t["rid"],
                    "timestamp": t["timestamp"],
                }
            )
        if t["assistant"]:
            messages.append(
                {
                    "role": "assistant",
                    "content": t["assistant"],
                    "rid": t["rid"],
                    "rcid": t["rcid"],
                    "timestamp": t["timestamp"],
                    "completion_status": t["completion_status"],
                }
            )
        if t.get("thoughts"):
            messages.append(
                {"role": "thoughts", "content": t["thoughts"], "rid": t["rid"]}
            )

    chat_hex = (api_cid or "").removeprefix("c_")
    return {
        "source": "gemini.google.com",
        "rpc": "hNvQHb",
        "cid": api_cid,
        "chat_hex": chat_hex,
        "spa_url": spa_url,
        "turn_count": len(turns_out),
        "message_count": len(messages),
        "messages": messages,
        "turns_newest_first": turns_out,
    }


print(f"🌕 background dump {api_cid} (no tab nav)…")
cookie = cookie_header()
try:
    wire = fetch_wire(cookie)
except Exception as e:
    print(f"🔴 {e}", file=sys.stderr)
    sys.exit(3)

out_dir = Path.home() / "Downloads"
out_dir.mkdir(parents=True, exist_ok=True)
stem = f"{date.today().isoformat()}_gemini_{hex_id}"

if raw_wire:
    wire_path = out_dir / f"{stem}.txt"
    wire_path.write_text(wire)
    subprocess.run(["/usr/bin/pbcopy"], input=wire.encode(), check=False)
    print(f"🟢 {api_cid} RAW {len(wire)}B -> clipboard + {wire_path}")
else:
    doc = wire_to_structured(wire, spa)
    bad = [t for t in doc["turns_newest_first"] if t.get("completion_status") not in (2, None)]
    if clean:
        doc = clean_noise(doc)
        doc["turn_count"] = len(doc.get("turns_newest_first") or [])
        doc["message_count"] = len(doc.get("messages") or [])
        payload = json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n"
    else:
        payload = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    js_path = out_dir / f"{stem}.json"
    js_path.write_text(payload)
    subprocess.run(["/usr/bin/pbcopy"], input=payload.encode(), check=False)
    print(
        f"🟢 {doc['cid']} JSON {doc['turn_count']} turns / {doc['message_count']} msgs -> clipboard + {js_path}"
    )
    if bad:
        print(f"🌕 {len(bad)} turns not status=2 — re-run if still generating", file=sys.stderr)
    if doc["turn_count"] == 0:
        print(f"🔴 parsed 0 turns — check {js_path}", file=sys.stderr)
        sys.exit(4)
print("🟢 done.")
PY
