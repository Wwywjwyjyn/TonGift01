/**
 * بازار گیفت — دروازه MTProto تلگرام (مارکت رسمی گیفت‌های استارزی)
 * ---------------------------------------------------------------
 * با API ID / API Hash خودِ کاربر (my.telegram.org) و لاگین واقعی اکانت،
 * کاتالوگ رسمی گیفت‌ها + بازار دست‌دوم (resale) تلگرام داخل اپ فراهم می‌شود:
 *
 *   auth:          ارسال کد، ورود، تایید دومرحله‌ای (SRP)، خروج
 *   catalog:       payments.getStarGifts            (همه گیفت‌های مارکت اصلی)
 *   resale:        payments.getResaleStarGifts       (فروشندگان دیگر)
 *   inventory:     payments.getSavedStarGifts        (گیفت‌های خودم)
 *   buy:           payments.getPaymentForm + sendStarsForm (با موجودی استارز)
 *   list/unlist:   payments.updateStarGiftPrice      (挂牌 / حذف از فروش)
 *   transfer:      payments.transferStarGift         (هدیه به یوزرنیم)
 *   upgrade:       payments.upgradeStarGift          (تبدیل به گیفت یکتا)
 *   sticker:       دانلود Thumbnail استیکرها با کش دیسک
 *
 * موتور: @mtcute/node (لایه ۲۲۳ اسکیمای تلگرام) — نشست هر دستگاه جدا نگهداری و
 * در tg_sessions.json ذخیره می‌شود (با TG_SESSION_KEY رمزنگاری AES-256-CBC).
 * api_id/api_hash هرگز به کلاینت برنمی‌گردد — فقط از env یا owner.json خوانده می‌شود.
 */
'use strict';

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import Long from 'long';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ---------- بارگذاری .env مشترک با server.js (بدون وابستگی) ----------
try {
  const envRaw = fs.readFileSync(path.join(__dirname, '.env'), 'utf8');
  for (const line of envRaw.split('\n')) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  }
} catch (_) { /* .env نیست */ }

const SESSIONS_FILE = path.join(__dirname, 'tg_sessions.json');
const STICKER_DIR = path.join(__dirname, 'tgcache');
const OWNER_FILE = path.join(__dirname, 'owner.json');

// ---------- اعتبارنامه MTProto ----------
function loadOwner() {
  try { return JSON.parse(fs.readFileSync(OWNER_FILE, 'utf8')); } catch (_) { return null; }
}

export function tgCredentials() {
  let apiId = parseInt(process.env.TELEGRAM_API_ID || '0', 10) || 0;
  let apiHash = (process.env.TELEGRAM_API_HASH || '').trim();
  if (!apiId || !/^[a-f0-9]{32}$/i.test(apiHash)) {
    const o = loadOwner();
    if (o && o.api_id && o.api_hash) {
      apiId = o.api_id;
      apiHash = o.api_hash;
    }
  }
  if (apiId && /^[a-f0-9]{32}$/i.test(apiHash)) return { apiId, apiHash };
  return null;
}

// ---------- رمزنگاری فایل نشست‌ها (AES-256-CBC با TG_SESSION_KEY) ----------
function sessionKey() {
  const k = process.env.TG_SESSION_KEY || '';
  if (!k) return null;
  return crypto.createHash('sha256').update(k).digest();
}

function readSessions() {
  try {
    const buf = fs.readFileSync(SESSIONS_FILE);
    const key = sessionKey();
    if (buf.subarray(0, 4).toString() === 'TGS1') {
      if (!key) throw new Error('TG_SESSION_KEY لازم است');
      const iv = buf.subarray(4, 20);
      const data = buf.subarray(20);
      const d = crypto.createDecipheriv('aes-256-cbc', key, iv);
      const out = Buffer.concat([d.update(data), d.final()]);
      return JSON.parse(out.toString('utf8'));
    }
    if (key) throw new Error('فایل نشست رمزنگاری نیست — TG_SESSION_KEY را بردارید یا فایل را حذف کنید');
    return JSON.parse(buf.toString('utf8'));
  } catch (e) {
    if (e.code !== 'ENOENT') console.log('[tg] sessions load warn:', e.message);
    return {};
  }
}

let _saveTimer = null;
function writeSessions(map) {
  try {
    const key = sessionKey();
    let body;
    if (key) {
      const iv = crypto.randomBytes(16);
      const c = crypto.createCipheriv('aes-256-cbc', key, iv);
      const data = Buffer.concat([c.update(JSON.stringify(map), 'utf8'), c.final()]);
      body = Buffer.concat([Buffer.from('TGS1'), iv, data]);
    } else {
      body = Buffer.from(JSON.stringify(map, null, 1), 'utf8');
    }
    fs.writeFileSync(SESSIONS_FILE, body, { mode: 0o600 });
  } catch (e) { console.log('[tg] sessions save warn:', e.message); }
}
function scheduleSave(map) {
  if (_saveTimer) clearTimeout(_saveTimer);
  _saveTimer = setTimeout(() => { _saveTimer = null; writeSessions(map); }, 400);
}

// ---------- وضعیت درون حافظه ----------
const sessions = readSessions();          // dev -> {session, user:{...}, saved_at}
const clients = new Map();                // dev -> TelegramClient
const pending = new Map();                // dev -> {phone, phoneCodeHash}
const docs = new Map();                   // docId -> RawDocument (برای استیکرها)
const floorsCache = new Map();            // giftId -> {t, count, min}
const listingsCache = new Map();          // key -> {t, data}
const catalogCache = { t: 0, data: null };
let configCache = null;                   // {t, min, max, commission}
let lib = null;                           // mtcute module lazily

async function mtcute() {
  if (!lib) lib = await import('@mtcute/node');
  return lib;
}

function log(...a) { console.log('[tg]', ...a); }

// ---------- خطاها ----------
class TgError extends Error {
  constructor(status, detail, extra = {}) {
    super(detail);
    this.status = status;
    this.extra = extra;
  }
}

function rpcErrorToHttp(e) {
  const txt = String((e && (e.text || e.message)) || e);
  const m = txt.match(/FLOOD_WAIT_(\d+)/) || txt.match(/FLOOD_PREMIUM_WAIT_(\d+)/);
  if (m) return new TgError(429, `تلگرام محدودیت زمانی گذاشته است — ${m[1]} ثانیه دیگر تلاش کنید`, { retry_after: parseInt(m[1], 10) });
  if (/PHONE_CODE_INVALID|PHONE_CODE_EXPIRED/.test(txt)) return new TgError(400, 'کد وارد شده اشتباه یا منقضی است');
  if (/PHONE_NUMBER_INVALID/.test(txt)) return new TgError(400, 'شماره تلفن معتبر نیست');
  if (/PHONE_NUMBER_UNOCCUPIED/.test(txt)) return new TgError(400, 'این شماره ثبت‌نام نشده است');
  if (/SESSION_PASSWORD_NEEDED/.test(txt)) return new TgError(401, 'NEED_PASSWORD');
  if (/PASSWORD_HASH_INVALID|SRP_ID_INVALID/.test(txt)) return new TgError(400, 'رمز دومرحله‌ای اشتباه است');
  if (/AUTH_KEY_UNREGISTERED|SESSION_REVOKED|USER_DEACTIVATED/.test(txt)) return new TgError(401, 'نشست تلگرام باطل شده — دوباره وارد شوید');
  if (/TIMEOUT|ETIMEDOUT/.test(txt)) return new TgError(504, 'تلگرام پاسخ نداد — دوباره تلاش کنید');
  if (/BALANCE|STARS_AMOUNT_TOO_LOW|STARS_AMOUNT_INVALID/.test(txt)) return new TgError(400, 'موجودی استارز کافی نیست');
  if (/RESALE_AMOUNT_TOO_LOW|RESALE_AMOUNT_TOO_HIGH/.test(txt)) return new TgError(400, 'قیمت خارج از محدوده مجاز تلگرام است');
  if (/STARGIFT_RESELL_OWNER/.test(txt)) return new TgError(400, 'این گیفت مال شما نیست');
  if (/NOT_ENOUGH_STARS/.test(txt)) return new TgError(400, 'موجودی استارز کافی نیست');
  return new TgError(502, txt.replace(/^RpcError\s*:?\s*/i, '').slice(0, 220));
}

// ---------- کلاینت‌ها ----------
async function makeClient(creds) {
  const { TelegramClient } = await mtcute();
  return new TelegramClient({
    apiId: creds.apiId,
    apiHash: creds.apiHash,
    storage: ':memory:',
    disableUpdates: true,
  });
}

async function getClient(dev) {
  const creds = tgCredentials();
  if (!creds) throw new TgError(428, 'API ID/Hash تنظیم نشده — ابتدا گیت API را کامل کنید', { code: 'need_api' });
  if (clients.has(dev)) return clients.get(dev);

  const rec = sessions[dev];
  if (!rec || !rec.session) throw new TgError(401, 'تلگرام متصل نیست', { code: 'not_connected' });

  const tg = await makeClient(creds);
  try {
    await tg.importSession(rec.session);
    await tg.connect();
    clients.set(dev, tg);
    log(`client ready for device ${dev.slice(0, 8)}… (${rec.user && rec.user.username ? '@' + rec.user.username : rec.user && rec.user.id})`);
    return tg;
  } catch (e) {
    try { await tg.destroy(); } catch (_) {}
    if (/AUTH_KEY_UNREGISTERED|AUTH_KEY_DUPLICATED|SESSION_REVOKED/.test(String(e.text || e.message))) {
      delete sessions[dev];
      writeSessions(sessions);
      throw new TgError(401, 'نشست منقضی شده — دوباره وارد شوید', { code: 'session_dead' });
    }
    throw e;
  }
}

function storeUser(dev, u) {
  sessions[dev] = {
    ...sessions[dev],
    session: sessions[dev] && sessions[dev].session,
    user: {
      id: u.id,
      accessHash: String(u.accessHash ?? u.access_hash ?? ''),
      first: u.firstName || '',
      last: u.lastName || '',
      username: u.username || '',
      phone: u.phone || '',
    },
    saved_at: Date.now(),
  };
}

function userName(u) {
  if (!u) return '';
  return [u.first, u.last].filter(Boolean).join(' ') || (u.username ? '@' + u.username : `id${u.id || ''}`);
}

function selfInputPeer(dev) {
  const u = sessions[dev] && sessions[dev].user;
  if (!u || !u.id) throw new TgError(401, 'تلگرام متصل نیست', { code: 'not_connected' });
  return { _: 'inputPeerUser', userId: u.id, accessHash: Long.fromString(String(u.accessHash || '0')) };
}

async function destroyClient(dev) {
  const tg = clients.get(dev);
  if (tg) {
    clients.delete(dev);
    try { await tg.destroy(); } catch (_) {}
  }
}

// دسترسی — فقط دستگاه مالک (یا TG_OPEN_FOR_ALL=1)
function authorized(dev) {
  if (process.env.TG_OPEN_FOR_ALL === '1') return true;
  const o = loadOwner();
  return !!o && !!dev && o.owner_token === dev;
}

// ---------- نرمال‌سازی اشیا TL ----------
function asStars(amount) {
  // StarsAmount -> {stars, ton}
  if (!amount) return null;
  if (amount._ === 'starsTonAmount') return { ton: Number(amount.amount) / 1e9, stars: null };
  return { stars: Number(amount.amount), ton: null };
}

function regDoc(d) {
  if (d && d._ === 'document' && d.id) {
    docs.set(String(d.id), d);
    if (docs.size > 4000) { // جلوگیری از رشد بی‌حد
      const k = docs.keys().next().value;
      docs.delete(k);
    }
  }
}

function attrName(attrs, kind) {
  const a = (attrs || []).find((x) => x._ === `starGiftAttribute${kind}`);
  return a ? a.name : null;
}

function attrDoc(attrs, kind) {
  const a = (attrs || []).find((x) => x._ === `starGiftAttribute${kind}`);
  if (a && a.document) { regDoc(a.document); return String(a.document.id); }
  return null;
}

function normalizeAttributes(attrs) {
  const out = [];
  for (const a of attrs || []) {
    if (a._ === 'starGiftAttributeModel' || a._ === 'starGiftAttributePattern') {
      regDoc(a.document);
      out.push({
        type: a._ === 'starGiftAttributeModel' ? 'model' : 'symbol',
        name: a.name,
        doc_id: String(a.document ? a.document.id : ''),
        rarity: rarityOf(a.rarity),
      });
    } else if (a._ === 'starGiftAttributeBackdrop') {
      out.push({
        type: 'backdrop',
        name: a.name,
        colors: [a.centerColor, a.edgeColor, a.patternColor, a.textColor].map((c) => `#${(c || 0).toString(16).padStart(6, '0')}`),
        rarity: rarityOf(a.rarity),
      });
    } else if (a._ === 'starGiftAttributeOriginalDetails') {
      out.push({ type: 'original', date: a.date || null });
    }
  }
  return out;
}

function rarityOf(r) {
  if (!r) return null;
  if (r._ === 'starGiftAttributeRarityUncommon') return 'uncommon';
  if (r._ === 'starGiftAttributeRarityRare') return 'rare';
  if (r._ === 'starGiftAttributeRarityEpic') return 'epic';
  if (r._ === 'starGiftAttributeRarityLegendary') return 'legendary';
  if (r._ === 'starGiftAttributeRarity') return r.permille != null ? Number(r.permille) : null;
  return null;
}

function normalizeStarGift(sg) {
  // گیفت معمولی از کاتالوگ
  if (sg.sticker) regDoc(sg.sticker);
  return {
    kind: 'gift',
    id: Number(sg.id),
    title: sg.title || '',
    stars: Number(sg.stars || 0),
    sticker_doc_id: sg.sticker ? String(sg.sticker.id) : '',
    limited: !!sg.limited,
    sold_out: !!sg.soldOut,
    birthday: !!sg.birthday,
    auction: !!sg.auction,
    require_premium: !!sg.requirePremium,
    availability_remains: sg.availabilityRemains != null ? Number(sg.availabilityRemains) : null,
    availability_total: sg.availabilityTotal != null ? Number(sg.availabilityTotal) : null,
    availability_resale: sg.availabilityResale != null ? Number(sg.availabilityResale) : null,
    resell_min_stars: sg.resellMinStars != null ? Number(sg.resellMinStars) : null,
    upgrade_stars: sg.upgradeStars != null ? Number(sg.upgradeStars) : null,
    convert_stars: Number(sg.convertStars || 0),
    first_sale_date: sg.firstSaleDate || null,
    last_sale_date: sg.lastSaleDate || null,
  };
}

function normalizeUnique(sgu) {
  const ra = asStars((sgu.resellAmount || [])[0]);
  return {
    kind: 'unique',
    id: Number(sgu.id),
    gift_id: Number(sgu.giftId || 0),
    title: sgu.title || '',
    slug: sgu.slug || '',
    num: Number(sgu.num || 0),
    sticker_doc_id: '',
    resale_ton_only: !!sgu.resaleTonOnly,
    require_premium: !!sgu.requirePremium,
    burned: !!sgu.burned,
    crafted: !!sgu.crafted,
    owner_id: sgu.ownerId && sgu.ownerId.userId ? Number(sgu.ownerId.userId) : null,
    owner_name: sgu.ownerName || '',
    owner_address: sgu.ownerAddress || '',
    model: attrName(sgu.attributes, 'Model'),
    backdrop: attrName(sgu.attributes, 'Backdrop'),
    symbol: attrName(sgu.attributes, 'Pattern'),
    model_doc_id: attrDoc(sgu.attributes, 'Model'),
    rarity: rarityOf(((sgu.attributes || []).find((x) => x._ === 'starGiftAttributeModel') || {}).rarity),
    attributes: normalizeAttributes(sgu.attributes),
    issued: Number(sgu.availabilityIssued || 0),
    total: Number(sgu.availabilityTotal || 0),
    resell_stars: ra && ra.stars != null ? ra.stars : null,
    resell_ton: ra && ra.ton != null ? ra.ton : null,
    value_usd: sgu.valueUsdAmount != null ? Number(sgu.valueUsdAmount) : null,
  };
}

function normalizeSavedGift(s) {
  const g = s.gift;
  let gift;
  if (g && g._ === 'starGiftUnique') {
    gift = normalizeUnique(g);
  } else if (g && g._ === 'starGift') {
    gift = normalizeStarGift(g);
  } else {
    return null;
  }
  return {
    msg_id: s.msgId != null ? Number(s.msgId) : null,
    saved_id: s.savedId != null ? String(s.savedId) : '',
    unsaved: !!s.unsaved,
    can_upgrade: !!s.canUpgrade,
    upgrade_stars: s.upgradeStars != null ? Number(s.upgradeStars) : null,
    transfer_stars: s.transferStars != null ? Number(s.transferStars) : null,
    can_transfer_at: s.canTransferAt || null,
    can_resell_at: s.canResellAt || null,
    convert_stars: s.convertStars != null ? Number(s.convertStars) : null,
    date: s.date || null,
    from_id: s.fromId && s.fromId.userId ? Number(s.fromId.userId) : null,
    from_name: (s.fromId && s.fromId.userId && usersNames.get(Number(s.fromId.userId))) || '',
    listed: !!(gift.kind === 'unique' && gift.resell_stars != null),
    list_price: gift.kind === 'unique' ? gift.resell_stars : null,
    gift,
  };
}

const usersNames = new Map(); // userId -> name (پر شده از پاسخ‌ها)

function collectUsers(users) {
  for (const u of users || []) {
    if (u && u.id) usersNames.set(Number(u.id), [u.firstName, u.lastName].filter(Boolean).join(' ') || (u.username ? '@' + u.username : ''));
  }
}

// ---------- کانفیگ تلگرام (حداقل/حداکثر قیمت، کمیسیون) ----------
async function giftConfig(tg) {
  if (configCache && Date.now() - configCache.t < 3600e3) return configCache;
  try {
    const cfg = await tg.call({ _: 'help.getConfig' });
    const pick = (v, d) => (v == null ? d : Number(v));
    configCache = {
      t: Date.now(),
      min: pick(cfg.starsStargiftResaleAmountMin, 125),
      max: pick(cfg.starsStargiftResaleAmountMax, 1000000),
      commission: cfg.starsStargiftResaleCommissionPermille != null ? Number(cfg.starsStargiftResaleCommissionPermille) : null,
      transfer_min_days: null,
    };
  } catch (_) {
    if (!configCache) configCache = { t: Date.now(), min: 125, max: 1000000, commission: null };
  }
  return configCache;
}

// ---------- توابع مارکت ----------
async function getCatalog(tg) {
  if (catalogCache.data && Date.now() - catalogCache.t < 300e3) return catalogCache.data;
  const res = await tg.call({ _: 'payments.getStarGifts', hash: 0 });
  if (res._ !== 'payments.starGifts') throw new TgError(502, 'پاسخ غیرمنتظره کاتالوگ');
  collectUsers(res.users);
  const gifts = (res.gifts || []).map(normalizeStarGift);
  const cfg = await giftConfig(tg);
  const data = {
    gifts,
    meta: {
      min_resale: cfg.min,
      max_resale: cfg.max,
      commission_permille: cfg.commission,
      updated: Date.now(),
    },
  };
  catalogCache.t = Date.now();
  catalogCache.data = data;
  return data;
}

async function getResaleListings(tg, giftId, { sort = 'price', offset = '', limit = 24 }) {
  const key = `${giftId}|${sort}|${offset}`;
  const c = listingsCache.get(key);
  if (c && Date.now() - c.t < 45e3) return c.data;
  const params = { _: 'payments.getResaleStarGifts', giftId: Long.fromValue(giftId), offset: offset || '', limit: Math.min(limit, 50), attributesHash: Long.UZERO };
  if (sort === 'price') params.sortByPrice = true;
  if (sort === 'num') params.sortByNum = true;
  const res = await tg.call(params);
  if (res._ !== 'payments.resaleStarGifts') throw new TgError(502, 'پاسخ غیرمنتظره لیست فروش');
  collectUsers(res.users);
  const data = {
    count: Number(res.count || 0),
    items: (res.gifts || []).map(normalizeUnique),
    next_offset: res.nextOffset || '',
  };
  listingsCache.set(key, { t: Date.now(), data });
  if (listingsCache.size > 600) listingsCache.delete(listingsCache.keys().next().value);
  return data;
}

async function getMyGifts(tg, dev) {
  const peer = selfInputPeer(dev);
  const all = [];
  let offset = '';
  for (let page = 0; page < 6; page++) {
    const res = await tg.call({
      _: 'payments.getSavedStarGifts',
      peer,
      offset,
      limit: 100,
    });
    if (res._ !== 'payments.savedStarGifts') break;
    collectUsers(res.users);
    for (const g of res.gifts || []) {
      const n = normalizeSavedGift(g);
      if (n) all.push(n);
    }
    if (!res.nextOffset || !(res.gifts || []).length) break;
    offset = res.nextOffset;
  }
  return { count: all.length, items: all };
}

async function resolveUsernamePeer(tg, username) {
  const uname = String(username || '').trim().replace(/^@/, '');
  if (!uname) throw new TgError(400, 'یوزرنیم لازم است');
  const res = await tg.call({ _: 'contacts.resolveUsername', username: uname });
  const u = (res.users || []).find((x) => x && x._ === 'user');
  if (!u) throw new TgError(404, 'کاربر پیدا نشد');
  collectUsers(res.users);
  return { peer: { _: 'inputPeerUser', userId: u.id, accessHash: u.accessHash }, user: { id: Number(u.id), first: u.firstName || '', username: u.username || '' } };
}

// ---------- استیکرها ----------
function bestThumbSize(doc) {
  const sizes = (doc.thumbs || []).filter((t) => t && t._ === 'photoSize').map((t) => t.type);
  for (const pref of ['x', 'y', 'm', 'w']) if (sizes.includes(pref)) return pref;
  return sizes[0] || 'm';
}

async function stickerBytes(tg, docId) {
  const doc = docs.get(String(docId));
  if (!doc) return null;
  fs.mkdirSync(STICKER_DIR, { recursive: true });
  const file = path.join(STICKER_DIR, `${docId}.jpg`);
  if (fs.existsSync(file) && fs.statSync(file).size > 0) return fs.readFileSync(file);
  let buf = null;
  for (const thumbSize of [bestThumbSize(doc), '']) {
    try {
      const loc = {
        _: 'inputDocumentFileLocation',
        id: doc.id,
        accessHash: doc.accessHash,
        fileReference: doc.fileReference,
        thumbSize: thumbSize || 'm',
      };
      const params = thumbSize ? { ...loc } : { ...loc, thumbSize: '' };
      if (!thumbSize) delete params.thumbSize;
      buf = Buffer.from(await tg.downloadAsBuffer(thumbSize ? loc : { _: 'inputDocumentFileLocation', id: doc.id, accessHash: doc.accessHash, fileReference: doc.fileReference }, { dcId: doc.dcId }));
      if (buf && buf.length > 0) break;
    } catch (e) {
      log('sticker dl fail', docId, String(e.text || e.message).slice(0, 80));
    }
  }
  if (!buf || !buf.length) return null;
  try { fs.writeFileSync(file, buf); } catch (_) {}
  return buf;
}

// ---------- هندل اصلی ----------
/**
 * @param {{method:string, pathname:string, query:Object, body:Object, dev:string}} ctx
 * @returns {null | {status:number, body:Object} | {status:number, raw:Buffer, type:string}}
 */
export async function handleTg(ctx) {
  const { method, pathname, query, body, dev } = ctx;
  if (!pathname.startsWith('/api/tg/')) return null;

  // استیکر — با هدر دستگاه مالک
  const st = pathname.match(/^\/api\/tg\/sticker\/(\d+)$/);
  if (st && method === 'GET') {
    if (!authorized(dev)) return { status: 403, body: { detail: 'forbidden' } };
    const creds = tgCredentials();
    if (!creds) return { status: 428, body: { detail: 'API credentials missing' } };
    const rec = sessions[dev];
    if (!rec) return { status: 404, body: { detail: 'no session' } };
    try {
      const tg = await getClient(dev);
      const buf = await stickerBytes(tg, st[1]);
      if (!buf) return { status: 404, body: { detail: 'sticker not found (refresh data)' } };
      return { status: 200, raw: buf, type: 'image/jpeg' };
    } catch (e) {
      return { status: e.status || 502, body: { detail: String(e.message) } };
    }
  }

  // وضعیت اتصال — بدون نیاز به لاگین
  if (pathname === '/api/tg/status' && method === 'GET') {
    const hasCreds = !!tgCredentials();
    if (!authorized(dev)) return { status: 200, body: { ok: true, ready: hasCreds, connected: false, locked: true } };
    if (!hasCreds) return { status: 200, body: { ok: true, ready: false, connected: false, locked: false, need_api: true } };
    const rec = sessions[dev];
    if (!rec) return { status: 200, body: { ok: true, ready: true, connected: false, locked: false } };
    try {
      const tg = await getClient(dev);
      const me = await tg.call({ _: 'users.getUsers', id: [{ _: 'inputUser', userId: rec.user.id, accessHash: Long.fromString(String(rec.user.accessHash || '0')) }] });
      if (me && me[0]) storeUser(dev, me[0]);
      let stars = null;
      try {
        const stt = await tg.call({ _: 'payments.getStarsStatus', peer: selfInputPeer(dev) });
        stars = Number(stt.balance && stt.balance.amount || 0);
      } catch (_) { /* موجودی اختیاری است */ }
      return {
        status: 200,
        body: {
          ok: true, ready: true, connected: true, locked: false,
          user: { ...rec.user, name: userName(rec.user) },
          stars,
        },
      };
    } catch (e) {
      const http = e instanceof TgError ? e : rpcErrorToHttp(e);
      return { status: 200, body: { ok: true, ready: true, connected: false, error: http.message, locked: false } };
    }
  }

  // از اینجا به بعد: دستگاه مالک + کانفیگ API
  if (!authorized(dev)) return { status: 403, body: { ok: false, detail: 'فقط دستگاه مالک اجازه دارد', locked: true } };
  const creds = tgCredentials();
  if (!creds) return { status: 428, body: { ok: false, detail: 'API ID/Hash تنظیم نشده — گیت API را کامل کنید', code: 'need_api' } };

  try {
    // ---------- ورود (بدون نشست قبلی) ----------
    if (pathname === '/api/tg/send-code' && method === 'POST') {
      const phone = String(body.phone || '').replace(/[^\d+]/g, '');
      if (phone.length < 7) return { status: 400, body: { ok: false, detail: 'شماره تلفن معتبر نیست' } };
      const tg = await makeClient(creds);
      try {
        await tg.connect();
        const sc = await tg.call({
          _: 'auth.sendCode',
          phoneNumber: phone,
          apiId: creds.apiId,
          apiHash: creds.apiHash,
          settings: { _: 'codeSettings' },
        });
        if (sc._ !== 'auth.sentCode') throw new TgError(502, 'ارسال کد ناموفق بود');
        if (clients.has(dev)) await destroyClient(dev);
        clients.set(dev, tg); // همین کلاینت برای sign-in ادامه می‌دهد
        pending.set(dev, { phone, phoneCodeHash: sc.phoneCodeHash });
        return { status: 200, body: { ok: true, phone, hint: sc.type && sc.type._ === 'auth.sentCodeTypeApp' ? 'کد در تلگرام ارسال شد' : 'کد پیامک/تماس شد' } };
      } catch (e) {
        try { await tg.destroy(); } catch (_) {}
        throw e;
      }
    }

    if (pathname === '/api/tg/sign-in' && method === 'POST') {
      const p = pending.get(dev);
      const code = String(body.code || '').replace(/[^\d]/g, '');
      if (!p) return { status: 400, body: { ok: false, detail: 'اول شماره را وارد و کد بگیرید', code: 'no_pending' } };
      const tg = clients.get(dev);
      if (!tg) return { status: 400, body: { ok: false, detail: 'جلسه ورود بازنشسته شده — دوباره کد بگیرید', code: 'no_pending' } };
      try {
        const res = await tg.call({
          _: 'auth.signIn',
          phoneNumber: p.phone,
          phoneCodeHash: p.phoneCodeHash,
          phoneCode: code,
        });
        const u = res.user;
        sessions[dev] = { session: '', user: {}, saved_at: Date.now() };
        storeUser(dev, u);
        sessions[dev].session = await tg.exportSession();
        writeSessions(sessions);
        pending.delete(dev);
        log(`logged in: ${userName(sessions[dev].user)}`);
        return { status: 200, body: { ok: true, user: { ...sessions[dev].user, name: userName(sessions[dev].user) } } };
      } catch (e) {
        const txt = String(e.text || e.message || '');
        if (/SESSION_PASSWORD_NEEDED/.test(txt)) {
          return { status: 200, body: { ok: false, need_password: true, detail: 'این اکانت رمز دومرحله‌ای دارد' } };
        }
        if (/PHONE_CODE_INVALID|PHONE_CODE_EXPIRED/.test(txt)) {
          return { status: 400, body: { ok: false, detail: rpcErrorToHttp(e).message, code: 'bad_code' } };
        }
        throw e;
      }
    }

    if (pathname === '/api/tg/2fa' && method === 'POST') {
      const tg = clients.get(dev);
      if (!tg) return { status: 400, body: { ok: false, detail: 'جلسه ورود بازنشسته شده — دوباره کد بگیرید', code: 'no_pending' } };
      const pwd = String(body.password || '');
      if (!pwd) return { status: 400, body: { ok: false, detail: 'رمز لازم است' } };
      const gp = await tg.call({ _: 'account.getPassword' });
      const srp = await tg.computeSrpParams(gp, pwd);
      const res = await tg.call({ _: 'auth.checkPassword', password: srp });
      const u = res.user;
      sessions[dev] = { session: '', user: {}, saved_at: Date.now() };
      storeUser(dev, u);
      sessions[dev].session = await tg.exportSession();
      writeSessions(sessions);
      pending.delete(dev);
      return { status: 200, body: { ok: true, user: { ...sessions[dev].user, name: userName(sessions[dev].user) } } };
    }

    // ---------- بدون نیاز به اتصال فعال ----------
    if (pathname === '/api/tg/logout' && method === 'POST') {
      await destroyClient(dev);
      delete sessions[dev];
      writeSessions(sessions);
      pending.delete(dev);
      return { status: 200, body: { ok: true } };
    }

    // ---------- همه اندپوینت‌های بعدی نشست فعال می‌خواهند ----------
    const tg = await getClient(dev);

    if (pathname === '/api/tg/catalog' && method === 'GET') {
      const data = await getCatalog(tg);
      return { status: 200, body: { ok: true, ...data } };
    }

    if (pathname === '/api/tg/floors' && method === 'GET') {
      const ids = String(query.ids || '').split(',').map((x) => parseInt(x, 10)).filter((x) => x > 0).slice(0, 24);
      const floors = {};
      for (const id of ids) {
        const c = floorsCache.get(id);
        if (c && Date.now() - c.t < 240e3) { floors[id] = { count: c.count, min: c.min }; continue; }
        try {
          const r = await getResaleListings(tg, id, { sort: 'price', offset: '', limit: 1 });
          const min = r.items.length && r.items[0].resell_stars != null ? r.items[0].resell_stars : null;
          floorsCache.set(id, { t: Date.now(), count: r.count, min });
          floors[id] = { count: r.count, min };
          await new Promise((ok) => setTimeout(ok, 90)); // محافظت از FLOOD_WAIT
        } catch (e) {
          floors[id] = { count: null, min: null };
        }
      }
      return { status: 200, body: { ok: true, floors } };
    }

    if (pathname === '/api/tg/listings' && method === 'GET') {
      const giftId = parseInt(query.gift_id, 10);
      if (!giftId) return { status: 400, body: { ok: false, detail: 'gift_id لازم است' } };
      const data = await getResaleListings(tg, giftId, {
        sort: query.sort === 'num' || query.sort === 'recent' ? query.sort : 'price',
        offset: String(query.offset || ''),
        limit: Math.min(parseInt(query.limit, 10) || 24, 50),
      });
      return { status: 200, body: { ok: true, ...data } };
    }

    if (pathname === '/api/tg/my-gifts' && method === 'GET') {
      const data = await getMyGifts(tg, dev);
      return { status: 200, body: { ok: true, ...data } };
    }

    if (pathname === '/api/tg/stars' && method === 'GET') {
      const stt = await tg.call({ _: 'payments.getStarsStatus', peer: selfInputPeer(dev) });
      return { status: 200, body: { ok: true, stars: Number(stt.balance && stt.balance.amount || 0) } };
    }

    if (pathname === '/api/tg/resolve' && method === 'POST') {
      const r = await resolveUsernamePeer(tg, body.username);
      return { status: 200, body: { ok: true, user: r.user } };
    }

    // خرید گیفت دست‌دوم (bazaar) — با موجودی استارز
    if (pathname === '/api/tg/buy' && method === 'POST') {
      const slug = String(body.slug || '').trim();
      if (!slug) return { status: 400, body: { ok: false, detail: 'slug لازم است' } };
      let toId = selfInputPeer(dev);
      if (body.to_username) toId = (await resolveUsernamePeer(tg, body.to_username)).peer;
      const invoice = { _: 'inputInvoiceStarGiftResale', slug, toId };
      const form = await tg.call({ _: 'payments.getPaymentForm', invoice });
      const formId = form.formId;
      await tg.call({ _: 'payments.sendStarsForm', formId, invoice });
      log(`resale bought: ${slug} -> ${body.to_username || 'self'}`);
      return { status: 200, body: { ok: true, purchased: true } };
    }

    // خرید گیفت جدید از کاتالوگ و هدیه به خود/یوزرنیم
    if (pathname === '/api/tg/buy-new' && method === 'POST') {
      const giftId = Long.fromValue(parseInt(body.gift_id, 10) || 0);
      if (giftId.isZero()) return { status: 400, body: { ok: false, detail: 'gift_id لازم است' } };
      let peer = selfInputPeer(dev);
      if (body.to_username) peer = (await resolveUsernamePeer(tg, body.to_username)).peer;
      const invoice = { _: 'inputInvoiceStarGift', peer, giftId };
      if (body.message) invoice.message = { _: 'textWithEntities', text: String(body.message).slice(0, 120), entities: [] };
      if (body.include_upgrade) invoice.includeUpgrade = true;
      const form = await tg.call({ _: 'payments.getPaymentForm', invoice });
      await tg.call({ _: 'payments.sendStarsForm', formId: form.formId, invoice });
      log(`new gift bought: ${giftId} -> ${body.to_username || 'self'}`);
      return { status: 200, body: { ok: true, purchased: true } };
    }

    // فروش گذاشتن / تغییر قیمت (price=0 یعنی حذف از فروش)
    if (pathname === '/api/tg/list' && method === 'POST') {
      const msgId = parseInt(body.msg_id, 10);
      const price = parseInt(body.price, 10);
      if (!msgId || isNaN(price)) return { status: 400, body: { ok: false, detail: 'msg_id و price لازم است' } };
      await tg.call({
        _: 'payments.updateStarGiftPrice',
        stargift: { _: 'inputSavedStarGiftUser', msgId },
        resellAmount: { _: 'starsAmount', amount: Long.fromNumber(Math.max(price, 0)), nanos: 0 },
      });
      return { status: 200, body: { ok: true, listed: price > 0 } };
    }

    if (pathname === '/api/tg/unlist' && method === 'POST') {
      const msgId = parseInt(body.msg_id, 10);
      if (!msgId) return { status: 400, body: { ok: false, detail: 'msg_id لازم است' } };
      await tg.call({
        _: 'payments.updateStarGiftPrice',
        stargift: { _: 'inputSavedStarGiftUser', msgId },
        resellAmount: { _: 'starsAmount', amount: Long.UZERO, nanos: 0 },
      });
      return { status: 200, body: { ok: true, listed: false } };
    }

    if (pathname === '/api/tg/transfer' && method === 'POST') {
      const msgId = parseInt(body.msg_id, 10);
      if (!msgId) return { status: 400, body: { ok: false, detail: 'msg_id لازم است' } };
      const { peer } = await resolveUsernamePeer(tg, body.to_username);
      await tg.call({
        _: 'payments.transferStarGift',
        stargift: { _: 'inputSavedStarGiftUser', msgId },
        toId: peer,
      });
      return { status: 200, body: { ok: true, transferred: true } };
    }

    if (pathname === '/api/tg/upgrade' && method === 'POST') {
      const msgId = parseInt(body.msg_id, 10);
      if (!msgId) return { status: 400, body: { ok: false, detail: 'msg_id لازم است' } };
      await tg.call({
        _: 'payments.upgradeStarGift',
        stargift: { _: 'inputSavedStarGiftUser', msgId },
      });
      return { status: 200, body: { ok: true, upgraded: true } };
    }

    return { status: 404, body: { ok: false, detail: `no tg route: ${method} ${pathname}` } };
  } catch (e) {
    const http = e instanceof TgError ? e : rpcErrorToHttp(e);
    return { status: http.status, body: { ok: false, detail: http.message, ...(http.extra || {}) } };
  }
}

