(async function geminicapture() {
  'use strict';
  // Public browserscript: run on an open gemini.google.com/app/<hex> chat.
  // Same batchexecute dump as geminicapture.sh, but uses page cookies (no glider jar).
  console.log('[geminicapture] 🟡 batchexecute dump...');

  try {
    const path = location.pathname;
    const mAcc = path.match(/\/u\/(\d+)\//);
    const account = mAcc ? mAcc[1] : '2';
    const mHex = path.match(/(?:\/app\/|c_)([0-9a-f]{16,})/i);
    if (!mHex) throw new Error('🔴 open a chat URL (/app/<hex>) first');
    const hexId = mHex[1].toLowerCase();
    const apiCid = 'c_' + hexId;
    const spa = 'https://gemini.google.com/app/' + hexId;
    const pathPrefix = '/u/' + account;
    const goto = 'https://gemini.google.com/u/' + account + '/app/' + hexId;

    function utf16Len(s) {
      let n = 0;
      for (let i = 0; i < s.length; i++) {
        const c = s.charCodeAt(i);
        n += c >= 0xd800 && c <= 0xdbff ? 2 : 1;
        if (c >= 0xd800 && c <= 0xdbff) i++;
      }
      return n;
    }

    function dig(a) {
      try {
        let cur = a;
        for (let i = 1; i < arguments.length; i++) cur = cur[arguments[i]];
        return cur;
      } catch (_) {
        return null;
      }
    }

    function longestStr(node, depth, best) {
      depth = depth || 0;
      best = best || '';
      if (depth > 12) return best;
      if (typeof node === 'string') return node.length > best.length ? node : best;
      if (Array.isArray(node)) {
        for (let i = 0; i < Math.min(node.length, 50); i++) best = longestStr(node[i], depth + 1, best);
      }
      return best;
    }

    function tokensFromHtml(html) {
      const at = html.match(/"SNlM0e":"([^"]+)"/);
      const bl = html.match(/"cfb2h":"([^"]+)"/);
      const fsid = html.match(/"FdrFJe":"([^"]+)"/);
      if (!(at && bl && fsid)) return null;
      return { at: at[1], bl: bl[1], fsid: fsid[1] };
    }

    function parseBatchexecute(wire) {
      let body = wire.startsWith(")]}'") ? wire.slice(4).replace(/^\n+/, '') : wire;
      const frames = [];
      let i = 0;
      while (i < body.length) {
        const m = body.slice(i).match(/^(\d+)\n/);
        if (!m) break;
        const n = parseInt(m[1], 10);
        i += m[0].length;
        let j = i;
        while (j < body.length && utf16Len(body.slice(i, j)) < n) j++;
        while (j > i && utf16Len(body.slice(i, j)) > n) j--;
        frames.push(body.slice(i, j));
        i = j;
        if (i < body.length && body[i] === '\n') i++;
      }
      if (!frames.length) throw new Error('no batchexecute frames');
      const arr = JSON.parse(frames[0]);
      for (const part of arr) {
        if (Array.isArray(part) && part[0] === 'wrb.fr' && part[1] === 'hNvQHb') {
          return JSON.parse(part[2]);
        }
      }
      throw new Error('no hNvQHb frame');
    }

    function wireToStructured(wire, spaUrl) {
      const inner = parseBatchexecute(wire);
      const turns = dig(inner, 0) || [];
      const turnsOut = [];
      for (const t of turns) {
        if (!Array.isArray(t) || t.length < 2) continue;
        const cid = dig(t, 0) || apiCid;
        const rid = dig(t, 1);
        let user = dig(t, 2, 0, 0);
        if (typeof user !== 'string') user = longestStr(dig(t, 2) || []);
        let asst = null;
        let thoughts = null;
        let completionStatus = null;
        let rcid = null;
        let ts = null;
        const replies = dig(t, 3) || [];
        if (Array.isArray(replies) && replies.length) {
          const r0 = replies[0];
          if (Array.isArray(r0)) {
            rcid = dig(r0, 0);
            asst = Array.isArray(dig(r0, 1)) ? dig(r0, 1, 0) : dig(r0, 1);
            if (typeof asst !== 'string') asst = longestStr(r0);
            completionStatus = dig(r0, 10) || dig(r0, 9);
          }
        }
        const meta = dig(t, 4) || dig(t, 5);
        if (Array.isArray(meta)) ts = dig(meta, 2) || dig(meta, 0);
        const th = dig(t, 3, 0, 2) || dig(t, 6);
        if (typeof th === 'string' && th && th !== asst) thoughts = th;
        turnsOut.push({
          cid, rid, rcid,
          user: typeof user === 'string' ? user : null,
          assistant: typeof asst === 'string' ? asst : null,
          thoughts, timestamp: ts, completion_status: completionStatus,
        });
      }
      const messages = [];
      for (let k = turnsOut.length - 1; k >= 0; k--) {
        const t = turnsOut[k];
        if (t.user) messages.push({ role: 'user', content: t.user, rid: t.rid, timestamp: t.timestamp });
        if (t.assistant) {
          messages.push({
            role: 'assistant', content: t.assistant, rid: t.rid, rcid: t.rcid,
            timestamp: t.timestamp, completion_status: t.completion_status,
          });
        }
        if (t.thoughts) messages.push({ role: 'thoughts', content: t.thoughts, rid: t.rid });
      }
      return {
        source: 'gemini.google.com',
        rpc: 'hNvQHb',
        cid: apiCid,
        chat_hex: hexId,
        spa_url: spaUrl,
        turn_count: turnsOut.length,
        message_count: messages.length,
        messages,
        turns_newest_first: turnsOut,
      };
    }

    async function fetchWire() {
      let lastErr = null;
      for (const [prefix, page] of [[pathPrefix, goto], ['', spa]]) {
        try {
          const html = page === location.href ? document.documentElement.outerHTML : await (await fetch(page, { credentials: 'include' })).text();
          const toks = tokensFromHtml(html);
          if (!toks) {
            lastErr = new Error('no SNlM0e in HTML for ' + page);
            continue;
          }
          const payload = JSON.stringify([apiCid, 10000, null, 1, [0], [4], null, 1]);
          const freq = JSON.stringify([[['hNvQHb', payload, null, 'generic']]]);
          const body = new URLSearchParams({ 'f.req': freq, at: toks.at });
          const qs = new URLSearchParams({
            rpcids: 'hNvQHb',
            'source-path': prefix ? prefix + '/app/' + hexId : '/app/' + hexId,
            bl: toks.bl,
            'f.sid': toks.fsid,
            hl: 'en',
            rt: 'c',
            _reqid: String(Math.floor(Math.random() * 9999999) + 1),
          });
          const url = 'https://gemini.google.com' + prefix + '/_/BardChatUi/data/batchexecute?' + qs;
          const resp = await fetch(url, {
            method: 'POST',
            credentials: 'include',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
              Origin: 'https://gemini.google.com',
              Referer: page,
            },
            body,
          });
          const wire = await resp.text();
          if (wire.length > 200 && (wire.includes('wrb.fr') || wire.startsWith(")]}'"))) return wire;
          lastErr = new Error('short/bad wire via ' + (prefix || '/') + ': ' + wire.length + 'B');
        } catch (e) {
          lastErr = e;
        }
      }
      throw lastErr || new Error('dump failed');
    }

    const wire = await fetchWire();
    const doc = wireToStructured(wire, spa);
    const json = JSON.stringify(doc, null, 2);
    const day = new Date().toISOString().slice(0, 10);
    const stem = day + '_gemini_' + hexId;
    const stamp = (() => {
      const d = new Date();
      const p = (n) => String(n).padStart(2, '0');
      return d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + '-' + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds());
    })();
    const zipName = stem + '_' + stamp + '.zip';

    async function buildZip(entries) {
      const CRC_TABLE = (() => {
        const t = new Uint32Array(256);
        for (let n = 0; n < 256; n++) {
          let c = n;
          for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
          t[n] = c >>> 0;
        }
        return t;
      })();
      const crc32 = (u8) => {
        let c = 0xFFFFFFFF;
        for (let i = 0; i < u8.length; i++) c = CRC_TABLE[(c ^ u8[i]) & 0xFF] ^ (c >>> 8);
        return (c ^ 0xFFFFFFFF) >>> 0;
      };
      const u16 = (n) => { const b = new Uint8Array(2); new DataView(b.buffer).setUint16(0, n, true); return b; };
      const u32 = (n) => { const b = new Uint8Array(4); new DataView(b.buffer).setUint32(0, n, true); return b; };
      const concat = (parts) => {
        let n = 0; for (const p of parts) n += p.length;
        const out = new Uint8Array(n); let o = 0;
        for (const p of parts) { out.set(p, o); o += p.length; }
        return out;
      };
      const now = new Date();
      const time = (now.getHours() << 11) | (now.getMinutes() << 5) | (Math.floor(now.getSeconds() / 2));
      const date = ((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate();
      const enc = new TextEncoder();
      const locals = []; const centrals = []; let offset = 0;
      for (const ent of entries) {
        const name = String(ent.path).replace(/^\/+/, '');
        const data = ent.data instanceof Uint8Array ? ent.data : enc.encode(ent.data);
        const crc = crc32(data);
        let payload = data, method = 0;
        if (typeof CompressionStream !== 'undefined') {
          try {
            const stream = new Blob([data]).stream().pipeThrough(new CompressionStream('deflate-raw'));
            const out = new Uint8Array(await new Response(stream).arrayBuffer());
            if (out.length && out.length < data.length) { payload = out; method = 8; }
          } catch { /* STORE */ }
        }
        const nameBytes = enc.encode(name);
        const local = concat([
          u32(0x04034b50), u16(20), u16(0), u16(method), u16(time), u16(date),
          u32(crc), u32(payload.length), u32(data.length), u16(nameBytes.length), u16(0),
          nameBytes, payload,
        ]);
        locals.push(local);
        centrals.push(concat([
          u32(0x02014b50), u16(20), u16(20), u16(0), u16(method), u16(time), u16(date),
          u32(crc), u32(payload.length), u32(data.length), u16(nameBytes.length),
          u16(0), u16(0), u16(0), u16(0), u32(0), u32(offset), nameBytes,
        ]));
        offset += local.length;
      }
      const centralDir = concat(centrals);
      return concat([...locals, centralDir, u32(0x06054b50), u16(0), u16(0),
        u16(centrals.length), u16(centrals.length), u32(centralDir.length), u32(offset), u16(0)]);
    }

    const zipBytes = await buildZip([{ path: stem + '/' + stem + '.json', data: json + '\n' }]);

    window.__GEMINICAPTURE = { doc, json, stem, zipName, hexId };

    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([zipBytes], { type: 'application/zip' }));
    a.download = zipName;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);

    console.log('[geminicapture] 🟢: ' + zipName + ' | ' + doc.turn_count + ' turns / ' + doc.message_count + ' msgs | window.__GEMINICAPTURE');
  } catch (err) {
    console.error('[geminicapture] 🔴 (fucked):', err);
  }
})();
