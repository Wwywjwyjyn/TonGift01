/**
 * بازار گیفت — بک‌اند پراکسی امن
 * ---------------------------------------------------------------
 * - توکن API مارکت‌اپ فقط اینجا و فقط در متغیر محیطی MARKETAPP_API_TOKEN
 * - اپلیکیشن موبایل هرگز به api.marketapp.org وصل نمی‌شود؛ فقط به این سرور
 * - بدون هیچ وابستگی npm — فقط Node.js >= 18
 * - اجرا:  MARKETAPP_API_TOKEN=xxxx node server.js
 */
'use strict';

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;

// بارگذاری خودکار .env کنار همین فایل (بدون هیچ وابستگی) — فقط اگر متغیر ست نشده باشد
try {
  const envRaw = fs.readFileSync(path.join(__dirname, '.env'), 'utf8');
  for (const line of envRaw.split('\n')) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  }
} catch (_) { /* .env نیست — از متغیر محیطی سیستم خوانده می‌شود */ }

const TOKEN = process.env.MARKETAPP_API_TOKEN || '';
const MARKETAPP_BASE = 'https://api.marketapp.org';
const TONAPI_BASE = 'https://tonapi.io';
const APP_NAME = process.env.APP_NAME || 'بازار گیفت تلگرام';

// ---------- کش کوچک در حافظه ----------
const cache = new Map(); // key -> {t, data}
function cacheGet(key, ttlMs) {
  const e = cache.get(key);
  if (e && Date.now() - e.t < ttlMs) return e.data;
  if (e) cache.delete(key);
  return null;
}
function cacheSet(key, data) {
  if (cache.size > 800) cache.clear();
  cache.set(key, { t: Date.now(), data });
}

// ---------- ابزار HTTP ----------
function fetchJson(url, opts = {}, timeoutMs = 20000) {
  return new Promise((resolve, reject) => {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeoutMs);
    fetch(url, { ...opts, signal: ctl.signal })
      .then(async (r) => {
        const text = await r.text();
        clearTimeout(timer);
        let body = null;
        try { body = text ? JSON.parse(text) : null; } catch (_) { body = { raw: text }; }
        resolve({ status: r.status, body });
      })
      .catch((e) => { clearTimeout(timer); reject(e); });
  });
}

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      try { resolve(raw ? JSON.parse(raw) : {}); } catch (_) { resolve({}); }
    });
    req.on('error', () => resolve({}));
  });
}

// ---------- آدرس TON: raw -> friendly (EQ.../UQ...) ----------
function crc16(data) {
  // CRC-16/XMODEM استاندارد TON (init صفر، poly 0x1021)
  let crc = 0;
  const poly = 0x1021;
  for (const b of data) {
    crc ^= b << 8;
    for (let i = 0; i < 8; i++) {
      crc = crc & 0x8000 ? ((crc << 1) ^ poly) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc & 0xFFFF;
}

function friendlyAddress(raw) {
  try {
    if (!raw) return raw;
    if (raw.includes(':')) {
      const wc = parseInt(raw.split(':')[0], 10);
      const hex = raw.split(':')[1].toLowerCase();
      if (/^[0-9a-f]{64}$/.test(hex)) {
        // ساختار استاندارد: [tag] [chain] [32 بایت هش] [2 بایت CRC]
        const tag = wc === -1 ? 0xff : 0x11; // bounceable استاندارد (EQ…)
        const chainByte = wc === -1 ? 0xff : wc;
        const payload = Buffer.concat([
          Buffer.from([tag]),
          Buffer.from([chainByte]),
          Buffer.from(hex, 'hex'),
        ]);
        const crc = crc16(payload);
        const full = Buffer.concat([payload, Buffer.from([(crc >> 8) & 0xff, crc & 0xff])]);
        return full.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      }
    }
    return raw; // از قبل friendly است
  } catch (_) {
    return raw;
  }
}

function shortAddr(a) {
  if (!a) return '';
  return a.slice(0, 6) + '…' + a.slice(-4);
}

// ---------- نرمال‌سازی NFT از tonapi ----------
function normalizeTonapiNft(it) {
  const meta = it.metadata || {};
  const attrs = (meta.attributes || []).map((a) => ({ trait_type: a.trait_type, value: a.value }));
  let sale = null;
  if (it.sale && it.sale.address) {
    let price = '';
    if (it.sale.price != null) {
      price = String(typeof it.sale.price === 'object' ? (it.sale.price.value || '') : it.sale.price);
    }
    sale = { price, currency: 'TON' };
  }
  return {
    address: it.address,
    collection_address: it.collection ? it.collection.address : '',
    collection_name: it.collection ? it.collection.name : '',
    name: (meta && meta.name) ? meta.name : (it.name || 'گیفت بدون نام'),
    real_owner: it.owner && it.owner.address ? it.owner.address : '',
    owner: it.owner && it.owner.address ? it.owner.address : '',
    attributes: attrs,
    image: meta.image || (it.previews && it.previews.length ? it.previews[it.previews.length - 1].url : ''),
    lottie: meta.lottie || '',
    status: sale ? 'for_sale' : 'not_for_sale',
    status_details: sale,
    source: 'tonapi',
  };
}

// ---------- resolve لینک گیفت تلگرام (t.me/nft/...) ----------
function fetchText(url, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: { 'User-Agent': 'TelegramBot (like TwitterBot)', 'Accept-Language': 'en' },
    }, (r) => {
      if (r.statusCode >= 300 && r.statusCode < 400 && r.headers.location) {
        fetchText(r.headers.location, timeoutMs).then(resolve).catch(reject);
        return;
      }
      const chunks = [];
      r.on('data', (c) => chunks.push(c));
      r.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    });
    req.on('error', reject);
    req.setTimeout(timeoutMs, () => { req.destroy(new Error('timeout')); });
  });
}

function parseOg(html) {
  function og(prop) {
    const re = new RegExp('<meta[^>]+property=["\']og:' + prop + '["\'][^>]+content=["\']([^"\']+)', 'i');
    const m = html.match(re);
    if (m) return m[1];
    const re2 = new RegExp('<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:' + prop + '["\']', 'i');
    const m2 = html.match(re2);
    return m2 ? m2[1] : '';
  }
  return { image: og('image'), title: og('title'), description: og('description') };
}

// ---------- نرخ TON به ریال (نمایشی، از صرافی‌های ایرانی) ----------
async function tonIrtRate() {
  const cached = cacheGet('irt', 120000);
  if (cached) return cached;
  const sources = [
    {
      url: 'https://api.wallex.ir/v1/markets',
      pick: (d) => (d && d.result && d.result.markets && d.result.markets['TONIRT'])
        ? Number(d.result.markets['TONIRT'].stats.price) : null,
      tag: 'wallex',
    },
    {
      url: 'https://api.nobitex.ir/market/stats?srcCurrency=ton&dstCurrency=irt',
      pick: (d) => (d && d.stats && d.stats['ton-irt']) ? Number(d.stats['ton-irt'].latest) : null,
      tag: 'nobitex',
    },
  ];
  for (const s of sources) {
    try {
      const r = await fetchJson(s.url, {}, 8000);
      const v = s.pick(r.body);
      if (v && v > 0) {
        const out = { irt_per_ton: Math.round(v), source: s.tag };
        cacheSet('irt', out);
        return out;
      }
    } catch (_) { /* منبع بعدی */ }
  }
  return null;
}

// ---------- گیت «اولین کاربر» برای API ID / API Hash تلگرام ----------
// فقط اولین دستگاهی که وضعیت را می‌پرسد، «مالک» شناخته می‌شود.
// هیچ‌گاه api_hash به هیچ کلاینتی برگردانده نمی‌شود؛ فقط روی همین سرور ذخیره می‌شود.
const OWNER_FILE = path.join(__dirname, 'owner.json');
function loadOwner() {
  try { return JSON.parse(fs.readFileSync(OWNER_FILE, 'utf8')); } catch (_) { return null; }
}
function saveOwner(o) {
  try { fs.writeFileSync(OWNER_FILE, JSON.stringify(o, null, 2)); } catch (_) {}
}
function randToken() {
  return require('crypto').randomBytes(24).toString('hex');
}
function ownerStatus(req) {
  const dev = String(req.headers['x-device-token'] || '');
  const o = loadOwner();
  if (!o) {
    // هنوز هیچ‌کس نیامده — توکن خودِ همین دستگاه اول = مالک
    const fresh = {
      state: 'pending',
      owner_token: dev || randToken(),
      created_at: Date.now(),
      api_id: null,
      api_hash: null,
    };
    saveOwner(fresh);
    return { state: 'pending', is_owner: !!dev, device_token: dev, api_id_set: false };
  }
  // hatch اضطراری: اگر OWNER_DEVICE_TOKEN روی سرور ست شده باشد، آن دستگاه مالک است
  const forced = String(process.env.OWNER_DEVICE_TOKEN || '').trim();
  if (forced && dev === forced && o.owner_token !== forced) {
    o.owner_token = forced;
    if (o.state === 'pending') { o.api_id = null; o.api_hash = null; }
    saveOwner(o);
  }
  const isOwner = !!dev && (dev === o.owner_token || (forced && dev === forced));
  if (o.state === 'pending') {
    return isOwner
      ? { state: 'pending', is_owner: true, device_token: dev, api_id_set: false }
      : { state: 'locked', is_owner: false, api_id_set: false }; // نفر اول درگیر است — به بقیه هیچ‌وقت نشان داده نمی‌شود
  }
  return { state: 'claimed', is_owner: isOwner, api_id_set: !!o.api_id };
}

// ---------- تاریخچه کف قیمت کالکشن‌ها (داده واقعیِ تجمع‌شده از فید کالکشن‌ها) ----------
const FLOOR_FILE = path.join(__dirname, 'floor_history.json');
const FLOOR_RANGES = { '1d': 1, '1w': 7, '1m': 30, '3m': 90, '6m': 182, '1y': 365 };
let _floorDb = null;
function floorDb() {
  if (_floorDb) return _floorDb;
  try { _floorDb = JSON.parse(fs.readFileSync(FLOOR_FILE, 'utf8')); } catch (_) { _floorDb = { snapshots: [] }; }
  if (!Array.isArray(_floorDb.snapshots)) _floorDb.snapshots = [];
  return _floorDb;
}
function saveFloorDb() {
  try { fs.writeFileSync(FLOOR_FILE, JSON.stringify(_floorDb)); } catch (_) {}
}
let _lastFloorPoll = 0;
async function pollFloors() {
  if (!TOKEN) return;
  if (Date.now() - _lastFloorPoll < 9 * 60 * 1000) return; // حداکثر هر ۹ دقیقه
  _lastFloorPoll = Date.now();
  try {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/collections/gifts/`, { headers: { 'Authorization': TOKEN } }, 15000);
    if (r.status !== 200 || !Array.isArray(r.body)) return;
    const db = floorDb();
    const last = db.snapshots.length ? db.snapshots[db.snapshots.length - 1] : null;
    if (last && Date.now() - last.ts < 10 * 60 * 1000) return; // اسنپ‌شات تکراری ثبت نشود
    const floors = {};
    for (const c of r.body) {
      const addr = (c && c.address || '').toString();
      if (!addr) continue;
      const e = (c.extra_data || {});
      floors[addr] = { f: Number(e.floor || 0) / 1e9, rf: Number(e.rent_floor || 0) / 1e9 };
    }
    db.snapshots.push({ ts: Date.now(), floors });
    const cutoff = Date.now() - 400 * 86400 * 1000;
    while (db.snapshots.length && db.snapshots[0].ts < cutoff) db.snapshots.shift();
    saveFloorDb();
    console.log(`[bazaar-gift] floor snapshot saved (${Object.keys(floors).length} collections, ${db.snapshots.length} total)`);
  } catch (e) { /* بی‌صدا — پول بعدی */ }
}
function floorHistory(addr, range) {
  const days = FLOOR_RANGES[range] || 30;
  const cutoff = Date.now() - days * 86400 * 1000;
  const db = floorDb();
  const pts = [];
  for (const s of db.snapshots) {
    if (s.ts < cutoff) continue;
    const f = s.floors[addr];
    if (f && f.f > 0) pts.push({ t: s.ts, v: f.f });
  }
  // نمونه‌برداری به حداکثر ۱۲۰ نقطه برای رسم روان
  const MAX = 120;
  let out = pts;
  if (pts.length > MAX) {
    out = [];
    const step = (pts.length - 1) / (MAX - 1);
    for (let i = 0; i < MAX; i++) out.push(pts[Math.round(i * step)]);
  }
  return out;
}

// ---------- بررسی وضعیت پلن (فید فروش واقعی فعال است؟) ----------
async function saleFeedAvailable() {
  const c = cacheGet('salefeed', 300000);
  if (c !== null) return c;
  let ok = false;
  try {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/gifts/onsale/?limit=1`, { headers: { 'Authorization': TOKEN } }, 12000);
    ok = r.status === 200;
  } catch (_) { ok = false; }
  cacheSet('salefeed', ok);
  return ok;
}

// ---------- دروازه MTProto تلگرام (مارکت رسمی گیفت‌ها) ----------
// @mtcute/node + long — با npm install نصب می‌شود؛ اگر نبود بقیه بک‌اند بدون تغییر کار می‌کند
let tgHandle = null;
import('./mtproto.mjs')
  .then((m) => { tgHandle = m.handleTg; console.log('[bazaar-gift] MTProto gateway ready (layer 223)'); })
  .catch((e) => console.log('[bazaar-gift] MTProto gateway DISABLED:', e.message));

// ---------- مسیرها ----------
async function handle(req, res, pathname, query, body) {
  // سلامت
  if (pathname === '/api/health') {
    const saleFeed = TOKEN ? await saleFeedAvailable() : false;
    let tgReady = false;
    try {
      const o = loadOwner();
      tgReady = !!(process.env.TELEGRAM_API_ID || (o && o.api_id));
    } catch (_) {}
    return sendJson(res, 200, {
      ok: true,
      token_set: !!TOKEN,
      sale_feed: saleFeed,
      tg_ready: tgReady,
      tg_gateway: !!tgHandle,
      sale_feed_note: saleFeed ? 'فید فروش واقعی فعال است' : 'فید فروش واقعی نیاز به پلن API دارد — فید اجاره جایگزین می‌شود',
      name: APP_NAME,
      time: Date.now(),
    });
  }

  // مانیفست TON Connect (داینامیک روی همان هاست)
  if (pathname === '/tonconnect-manifest.json') {
    let proto = 'https';
    const host = req.headers['x-forwarded-host'] || req.headers.host || 'localhost';
    if (host.startsWith('localhost') || host.startsWith('127.')) proto = 'http';
    const base = `${proto}://${host}`;
    return sendJson(res, 200, {
      url: base,
      name: APP_NAME,
      iconUrl: `${base}/icon.png`,
      termsOfUseUrl: `${base}/`,
    });
  }

  // لیست کیف پول‌های TON Connect
  if (pathname === '/ton-wallets.json') {
    try {
      const raw = fs.readFileSync(path.join(__dirname, 'wallets.json'), 'utf8');
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Access-Control-Allow-Origin': '*' });
      return res.end(raw);
    } catch (_) {
      return sendJson(res, 404, { detail: 'wallets.json not found' });
    }
  }

  // آیکون اپ
  if (pathname === '/icon.png') {
    try {
      const buf = fs.readFileSync(path.join(__dirname, 'icon.png'));
      res.writeHead(200, { 'Content-Type': 'image/png', 'Access-Control-Allow-Origin': '*' });
      return res.end(buf);
    } catch (_) {
      return sendJson(res, 404, { detail: 'icon not found' });
    }
  }

  // ---- گیت اولین کاربر (بدون نیاز به توکن مارکت‌اپ) ----
  if (pathname === '/api/owner/status' && req.method === 'GET') {
    return sendJson(res, 200, ownerStatus(req));
  }
  if (pathname === '/api/owner/claim' && req.method === 'POST') {
    const dev = String(req.headers['x-device-token'] || '');
    const o = loadOwner();
    if (!o || o.state !== 'pending' || !dev || dev !== o.owner_token) {
      return sendJson(res, 403, { detail: 'only the first user can claim' });
    }
    const apiId = parseInt(body.api_id, 10);
    const apiHash = String(body.api_hash || '').trim();
    if (!apiId || apiId < 1 || !/^[a-f0-9]{32}$/.test(apiHash)) {
      return sendJson(res, 400, { detail: 'invalid api_id or api_hash (must be 32 hex chars from my.telegram.org)' });
    }
    saveOwner({ state: 'claimed', owner_token: dev, created_at: o.created_at, claimed_at: Date.now(), api_id: apiId, api_hash: apiHash });
    return sendJson(res, 200, { ok: true, state: 'claimed', is_owner: true });
  }

  // ---- تاریخچه کف قیمت (داده واقعی جمع‌شده روی سرور) ----
  if (pathname === '/api/floor-history' && req.method === 'GET') {
    const addr = String(query.addr || '');
    const range = FLOOR_RANGES[query.range] ? query.range : '1m';
    if (!addr) return sendJson(res, 400, { detail: 'addr required' });
    const points = floorHistory(addr, range);
    return sendJson(res, 200, { addr, range, points, snapshot_count: floorDb().snapshots.length });
  }

  // ---- دروازه MTProto: /api/tg/* (مارکت رسمی گیفت تلگرام) ----
  if (pathname.startsWith('/api/tg/')) {
    if (!tgHandle) return sendJson(res, 503, { detail: 'MTProto gateway not loaded — روی سرور npm install اجرا کنید' });
    const dev = String(req.headers['x-device-token'] || '');
    const out = await tgHandle({ method: req.method, pathname, query, body, dev });
    if (!out) return sendJson(res, 404, { detail: 'no tg route' });
    if (out.raw) {
      res.writeHead(out.status || 200, {
        'Content-Type': out.type || 'image/jpeg',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=86400',
      });
      return res.end(out.raw);
    }
    return sendJson(res, out.status, out.body);
  }

  if (!pathname.startsWith('/api/')) return sendJson(res, 404, { detail: 'not found' });
  if (!TOKEN) {
    return sendJson(res, 500, { detail: 'MARKETAPP_API_TOKEN تنظیم نشده است. روی سرور متغیر محیطی را ست کنید.' });
  }

  const auth = { 'Authorization': TOKEN, 'Content-Type': 'application/json' };
  const qs = new URLSearchParams(query).toString();

  // ---- Fragment: استارز ----
  if (pathname === '/api/stars/price' && req.method === 'POST') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/fragment/stars/price/`, {
      method: 'POST', headers: auth, body: JSON.stringify({ quantity: Number(body.quantity || 0) }),
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/stars/recipient' && req.method === 'POST') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/fragment/stars/recipient/`, {
      method: 'POST', headers: auth,
      body: JSON.stringify({ username: String(body.username || '').replace(/^@/, '') }),
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/stars/buy' && req.method === 'POST') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/fragment/stars/buy/`, {
      method: 'POST', headers: auth,
      body: JSON.stringify({
        username: String(body.username || '').replace(/^@/, ''),
        quantity: Number(body.quantity || 0),
        currency: body.currency || 'TON',
      }),
    });
    return sendJson(res, r.status, r.body);
  }

  // ---- Fragment: پریمیوم ----
  if (pathname === '/api/premium/price' && req.method === 'POST') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/fragment/premium/price/`, {
      method: 'POST', headers: auth, body: '{}',
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/premium/recipient' && req.method === 'POST') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/fragment/premium/recipient/`, {
      method: 'POST', headers: auth,
      body: JSON.stringify({ username: String(body.username || '').replace(/^@/, '') }),
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/premium/buy' && req.method === 'POST') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/fragment/premium/buy/`, {
      method: 'POST', headers: auth,
      body: JSON.stringify({
        username: String(body.username || '').replace(/^@/, ''),
        months: Number(body.months || 3),
        currency: body.currency || 'TON',
      }),
    });
    return sendJson(res, r.status, r.body);
  }

  // ---- کالکشن‌ها (رایگان) ----
  if (pathname === '/api/collections/gifts' && req.method === 'GET') {
    const c = cacheGet('colgifts', 60000);
    if (c) return sendJson(res, 200, c);
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/collections/gifts/`, { headers: auth });
    if (r.status === 200) cacheSet('colgifts', r.body);
    return sendJson(res, r.status, r.body);
  }
  if (pathname.startsWith('/api/collections/attributes/') && req.method === 'GET') {
    const addr = pathname.split('/').pop();
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/collections/${encodeURIComponent(addr)}/attributes/`, { headers: auth });
    return sendJson(res, r.status, r.body);
  }

  // ---- مارکت: گیفت‌های در حال فروش (نیاز به پلن API — با فعال شدن پلن خودکار روشن می‌شود) ----
  if (pathname === '/api/gifts/onsale' && req.method === 'GET') {
    const c = cacheGet('onsale' + qs, 30000);
    if (c) return sendJson(res, c.status, c.body);
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/gifts/onsale/?${qs}`, { headers: auth });
    if (r.status === 200) cacheSet('onsale' + qs, r);
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/gifts/history' && req.method === 'GET') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/gifts/history/?${qs}`, { headers: auth });
    return sendJson(res, r.status, r.body);
  }

  // ---- اجاره گیفت (رایگان — فید واقعی گیفت‌ها) ----
  if (pathname === '/api/rent/gifts' && req.method === 'GET') {
    const c = cacheGet('rent' + qs, 30000);
    if (c) return sendJson(res, 200, c);
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/gifts/?${qs}`, { headers: auth });
    if (r.status === 200) cacheSet('rent' + qs, r.body);
    return sendJson(res, r.status, r.body);
  }

  // ---- پرداخت اجاره یک NFT (تراکنش برای امضای کاربر) ----
  if (pathname === '/api/rent/pay' && req.method === 'POST') {
    const addr = String(body.nft_address || '');
    if (!addr) return sendJson(res, 400, { detail: 'nft_address لازم است' });
    const payload = { ...body };
    delete payload.nft_address;
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/${encodeURIComponent(friendlyAddress(addr))}/pay/`, {
      method: 'POST', headers: auth, body: JSON.stringify(payload),
    });
    return sendJson(res, r.status, r.body);
  }

  // ---- مدیریت اجاره (اندپوینت‌های سندباکس rent) ----
  if (pathname === '/api/rent/my-rented' && req.method === 'GET') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/my-rented/?${qs}`, { headers: auth });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/rent/history' && req.method === 'GET') {
    const cat = String(query.category || 'gifts').replace(/[^a-z]/g, '') || 'gifts';
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/${cat}/history/?${qs}`, { headers: auth });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/rent/extend' && req.method === 'POST') {
    const addr = String(body.nft_address || '');
    if (!addr) return sendJson(res, 400, { detail: 'nft_address لازم است' });
    const payload = { ...body };
    delete payload.nft_address;
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/${encodeURIComponent(friendlyAddress(addr))}/extend/`, {
      method: 'POST', headers: auth, body: JSON.stringify(payload),
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/rent/cancel' && req.method === 'POST') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/cancel/`, {
      method: 'POST', headers: auth, body: JSON.stringify(body),
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/rent/rent-out' && req.method === 'POST') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/gifts/rent-out/`, {
      method: 'POST', headers: auth, body: JSON.stringify(body),
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/rent/update-settings' && req.method === 'POST') {
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/gifts/update-settings/`, {
      method: 'POST', headers: auth, body: JSON.stringify(body),
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/rent/tonconnect' && req.method === 'POST') {
    const addr = String(body.nft_address || '');
    if (!addr) return sendJson(res, 400, { detail: 'nft_address لازم است' });
    const payload = { ...body };
    delete payload.nft_address;
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/${encodeURIComponent(friendlyAddress(addr))}/tonconnect/`, {
      method: 'POST', headers: auth, body: JSON.stringify(payload),
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/rent/login-code' && req.method === 'POST') {
    const addr = String(body.nft_address || '');
    if (!addr) return sendJson(res, 400, { detail: 'nft_address لازم است' });
    const payload = { ...body };
    delete payload.nft_address;
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/${encodeURIComponent(friendlyAddress(addr))}/login-code/`, {
      method: 'POST', headers: auth, body: JSON.stringify(payload),
    });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/rent/toggle-login-code' && req.method === 'POST') {
    const addr = String(body.nft_address || '');
    if (!addr) return sendJson(res, 400, { detail: 'nft_address لازم است' });
    const payload = { ...body };
    delete payload.nft_address;
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/rent/${encodeURIComponent(friendlyAddress(addr))}/toggle-login-code/`, {
      method: 'POST', headers: auth, body: JSON.stringify(payload),
    });
    return sendJson(res, r.status, r.body);
  }

  // ---- NFT: فروش/خرید/تغییر قیمت/لغو (آدرس‌ها نرمال می‌شوند) ----
  function normalizeData(d) {
    if (Array.isArray(d)) {
      return d.map((x) => (x && x.nft_address ? { ...x, nft_address: friendlyAddress(x.nft_address) } : x));
    }
    return d;
  }

  if (pathname === '/api/nfts/sale' && req.method === 'POST') {
    const payload = { ...body, owner_address: friendlyAddress(body.owner_address), data: normalizeData(body.data) };
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/nfts/sale/`, { method: 'POST', headers: auth, body: JSON.stringify(payload) });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/nfts/buy' && req.method === 'POST') {
    const payload = { data: normalizeData(body.data) };
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/nfts/buy/`, { method: 'POST', headers: auth, body: JSON.stringify(payload) });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/nfts/change_price' && req.method === 'POST') {
    const payload = { ...body, owner_address: friendlyAddress(body.owner_address), data: normalizeData(body.data) };
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/nfts/change_price/`, { method: 'POST', headers: auth, body: JSON.stringify(payload) });
    return sendJson(res, r.status, r.body);
  }
  if (pathname === '/api/nfts/cancel_sale' && req.method === 'POST') {
    const payload = {
      owner_address: friendlyAddress(body.owner_address),
      nft_addresses: Array.isArray(body.nft_addresses) ? body.nft_addresses.map(friendlyAddress) : [],
    };
    const r = await fetchJson(`${MARKETAPP_BASE}/v1/nfts/cancel_sale/`, { method: 'POST', headers: auth, body: JSON.stringify(payload) });
    return sendJson(res, r.status, r.body);
  }

  // ---- آیتم‌های یک کالکشن (اول marketapp، فال‌بک رایگان tonapi/toncenter) ----
  if (pathname.startsWith('/api/nfts/collection/') && req.method === 'GET') {
    const addr = friendlyAddress(decodeURIComponent(pathname.split('/').pop()));
    const first = await fetchJson(`${MARKETAPP_BASE}/v1/nfts/collections/${encodeURIComponent(addr)}/?${qs}`, { headers: auth });
    if (first.status === 200) return sendJson(res, 200, first.body);
    // فال‌بک ۱: tonapi.com (در دسترس بودن بسته به سرور)
    for (const base of ['https://tonapi.com', 'https://tonapi.io']) {
      try {
        const t = await fetchJson(`${base}/v2/collections/${encodeURIComponent(addr)}/items?limit=${Math.min(Number(query.limit || 50), 1000)}`, {}, 15000);
        if (t.status === 200 && t.body && Array.isArray(t.body.nft_items)) {
          const items = t.body.nft_items.map(normalizeTonapiNft);
          return sendJson(res, 200, { cursor: null, items, fallback: 'tonapi' });
        }
      } catch (_) { /* فال‌بک بعدی */ }
    }
    // فال‌بک ۲: toncenter v3 — آیتم‌های واقعی با مالک (نام/عکس از الگوی fragment ساخته می‌شود)
    try {
      const lim = Math.min(Number(query.limit || 50), 256);
      const off = Math.max(Number(query.offset || 0), 0);
      const t = await fetchJson(`https://toncenter.com/api/v3/nft/items?collection_address=${encodeURIComponent(addr)}&limit=${lim}&offset=${off}`, {}, 20000);
      if (t.status === 200 && t.body && Array.isArray(t.body.nft_items)) {
        const items = t.body.nft_items.map((it) => {
          const rawAddr = friendlyAddress(it.address || '');
          let slug = '';
          try {
            const uri = (it.content && it.content.uri) || '';
            const m = uri.match(/gift\/([a-z0-9\-]+)\.json/i);
            if (m) slug = m[1];
          } catch (_) {}
          let name = slug || rawAddr.slice(0, 10);
          let number = null;
          const nm = slug.match(/-([0-9]+)$/);
          if (nm) {
            number = parseInt(nm[1], 10);
            name = slug.replace(/-[0-9]+$/, '');
          }
          return {
            address: rawAddr,
            collection_address: friendlyAddress(it.collection_address || ''),
            collection_name: '',
            name,
            real_owner: friendlyAddress(it.owner_address || ''),
            owner: friendlyAddress(it.owner_address || ''),
            attributes: [],
            image: slug ? `https://nft.fragment.com/gift/${slug}.webp` : '',
            lottie: slug ? `https://nft.fragment.com/gift/${slug}.lottie.json` : '',
            status: 'not_for_sale',
            status_details: null,
            source: 'toncenter',
          };
        });
        return sendJson(res, 200, { cursor: String(off + items.length), items, fallback: 'toncenter' });
      }
    } catch (_) { /* خطای اصلی برگردانده می‌شود */ }
    return sendJson(res, first.status, first.body);
  }

  // ---- انبار: NFTهای مالک (اول marketapp، در صورت نیاز به پلن → tonapi) ----
  if (pathname.startsWith('/api/nfts/owner/') && req.method === 'GET') {
    const addrRaw = decodeURIComponent(pathname.split('/').pop());
    const addr = friendlyAddress(addrRaw);
    const first = await fetchJson(`${MARKETAPP_BASE}/v1/nfts/owner/${encodeURIComponent(addr)}/?${qs}`, { headers: auth });
    if (first.status === 200) return sendJson(res, 200, first.body);
    if (first.status === 402 || first.status === 403) {
      try {
        const lim = Math.min(Number(query.limit || 250), 1000);
        const t = await fetchJson(`${TONAPI_BASE}/v2/accounts/${encodeURIComponent(addr)}/nfts?limit=${lim}&indirect_ownership=true`, {}, 25000);
        if (t.status === 200 && t.body && t.body.nft_items) {
          const items = t.body.nft_items.map(normalizeTonapiNft);
          return sendJson(res, 200, { cursor: null, items, fallback: 'tonapi' });
        }
      } catch (_) { /* ادامه با خطای اصلی */ }
    }
    return sendJson(res, first.status, first.body);
  }

  // ---- اطلاعات یک NFT (اول marketapp، سپس tonapi) ----
  if (pathname.startsWith('/api/nfts/info/') && req.method === 'GET') {
    const addr = friendlyAddress(decodeURIComponent(pathname.split('/').pop()));
    const first = await fetchJson(`${MARKETAPP_BASE}/v1/nfts/${encodeURIComponent(addr)}/`, { headers: auth });
    if (first.status === 200) return sendJson(res, 200, first.body);
    try {
      const t = await fetchJson(`${TONAPI_BASE}/v2/nfts/${encodeURIComponent(addr)}`, {}, 20000);
      if (t.status === 200) return sendJson(res, 200, normalizeTonapiNft(t.body));
    } catch (_) { /* ignore */ }
    return sendJson(res, first.status, first.body);
  }

  // ---- تشخیص گیفت از لینک t.me/nft/... ----
  if (pathname === '/api/resolve-gift' && req.method === 'POST') {
    const link = String(body.link || '').trim();
    const m = link.match(/t\.me\/nft\/([A-Za-z0-9_\-]+)/);
    if (!m) return sendJson(res, 400, { detail: 'لینک معتبر نیست. باید شبیه https://t.me/nft/PlushPepe-1234 باشد' });
    const slug = m[1];
    const c = cacheGet('res' + slug, 3600000);
    if (c) return sendJson(res, 200, c);
    let og = { image: '', title: '', description: '' };
    try {
      const html = await fetchText(`https://t.me/nft/${slug}`);
      og = parseOg(html);
    } catch (_) { /* اگر تلگرام پاسخ نداد، از الگوی شناخته‌شده می‌سازیم */ }
    const numMatch = slug.match(/-([0-9]+)$/);
    const number = numMatch ? parseInt(numMatch[1], 10) : null;
    let name = slug.replace(/-[0-9]+$/, '');
    if (og.title) name = og.title.replace(/#[0-9]+$/, '').trim();
    const out = {
      slug,
      name,
      number,
      image: og.image || `https://nft.fragment.com/gift/${slug.toLowerCase()}.webp`,
      lottie: `https://nft.fragment.com/gift/${slug.toLowerCase()}.lottie.json`,
      description: og.description || '',
    };
    cacheSet('res' + slug, out);
    return sendJson(res, 200, out);
  }

  // ---- موجودی TON کیف پول (tonapi) ----
  if (pathname.startsWith('/api/wallet/') && pathname.endsWith('/balance') && req.method === 'GET') {
    const addr = friendlyAddress(decodeURIComponent(pathname.split('/')[3]));
    try {
      const t = await fetchJson(`${TONAPI_BASE}/v2/accounts/${encodeURIComponent(addr)}`, {}, 15000);
      if (t.status === 200) {
        const b = t.body.balance ? String(t.body.balance) : '0';
        return sendJson(res, 200, { balance_nano: b, balance_ton: Number(b) / 1e9, status: t.body.status || 'uninit' });
      }
      return sendJson(res, t.status, t.body);
    } catch (_) {
      return sendJson(res, 502, { detail: 'tonapi unreachable' });
    }
  }

  // ---- نرخ TON/IRT (نمایشی) ----
  if (pathname === '/api/rate/irt' && req.method === 'GET') {
    const r = await tonIrtRate();
    if (r) return sendJson(res, 200, r);
    return sendJson(res, 404, { detail: 'rate unavailable' });
  }

  return sendJson(res, 404, { detail: `no route: ${req.method} ${pathname}` });
}

const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, 'http://x');
  const pathname = decodeURIComponent(u.pathname);
  const query = Object.fromEntries(u.searchParams.entries());

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    });
    return res.end();
  }

  const body = req.method === 'POST' ? await readBody(req) : {};
  try {
    await handle(req, res, pathname, query, body);
  } catch (e) {
    sendJson(res, 500, { detail: 'server error', error: String((e && e.message) || e) });
  }
});

server.listen(PORT, () => {
  console.log(`[bazaar-gift] backend listening on :${PORT}`);
  console.log(`[bazaar-gift] MARKETAPP_API_TOKEN is ${TOKEN ? 'SET ✓' : 'MISSING ✗ (متغیر محیطی را ست کنید)'}`);
  // پولر کف قیمت — اسنپ‌شات واقعی هر ۱۵ دقیقه (چارت کالکشن‌ها از همین داده واقعی پر می‌شود)
  setTimeout(pollFloors, 4000);
  setInterval(pollFloors, 15 * 60 * 1000);
});
