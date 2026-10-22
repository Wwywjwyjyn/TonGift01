# بک‌اند بازار گیفت — پراکسی امن Marketapp API + دروازه MTProto تلگرام

سرور Node.js. بخش پراکسی Marketapp بدون وابستگی است؛ بخش جدید «مارکت رسمی گیفت تلگرام» (MTProto) به دو پکیج نیاز دارد:

```bash
npm install        # @mtcute/node (لایه ۲۲۳ اسکیمای تلگرام) + long
```

## مارکت رسمی گیفت تلگرام (MTProto با API ID/Hash خودت)

جریان کامل، ۱۰۰٪ با اکانت تلگرام خود کاربر:

1. **گیت API** (قبلاً بوده): اولین دستگاه API ID/Hash را از my.telegram.org می‌گیرد و فقط روی سرور ذخیره می‌کند (owner.json).
2. **ورود به تلگرام داخل اپ**: شماره ← کد ← (رمز دومرحله‌ای) — نشست روی سرور در `tg_sessions.json` (با `TG_SESSION_KEY` رمزنگاری AES-256-CBC).
3. بعد از آن همه‌چیز از مارکت اصلی تلگرام می‌آید:

| مسیر اپ | متد MTProto | کار |
|---|---|---|
| `GET /api/tg/catalog` | `payments.getStarGifts` | کل کاتالوگ مارکت اصلی |
| `GET /api/tg/listings?gift_id&sort` | `payments.getResaleStarGifts` | گیفت‌های دست‌دوم دیگران |
| `GET /api/tg/floors?ids` | همان (limit=1) | کف قیمت هر نوع گیفت |
| `GET /api/tg/my-gifts` | `payments.getSavedStarGifts` | انبار من (حتی ذخیره‌نشده‌ها) |
| `GET /api/tg/stars` | `payments.getStarsStatus` | موجودی استارز |
| `POST /api/tg/buy` | `getPaymentForm` + `sendStarsForm` با `inputInvoiceStarGiftResale` | خرید از بازار دست‌دوم با استارز |
| `POST /api/tg/buy-new` | همان با `inputInvoiceStarGift` | خرید گیفت جدید و هدیه به خود/یوزرنیم |
| `POST /api/tg/list` | `payments.updateStarGiftPrice` | فروش‌گذاری / تغییر قیمت (price=0 یعنی حذف) |
| `POST /api/tg/unlist` | همان | حذف از فروش |
| `POST /api/tg/transfer` | `payments.transferStarGift` | انتقال گیفت به یوزرنیم |
| `POST /api/tg/upgrade` | `payments.upgradeStarGift` | آپگرید به گیفت یکتا |
| `GET /api/tg/sticker/:docId` | downloadAsBuffer | عکس استیکر (کش دیسک در tgcache/) |

- دسترسی: فقط دستگاه مالک (owner.json) — مگر `TG_OPEN_FOR_ALL=1`
- خطای FLOOD_WAIT تلگرام → پاسخ 429 با `retry_after`
- اگر `@mtcute/node` نصب نباشد، فقط بخش `/api/tg/*` غیرفعال می‌شود و بقیه بک‌اند مثل قبل کار می‌کند

## امنیت
- توکن API **فقط** در متغیر محیطی `MARKETAPP_API_TOKEN`
- فایل `.env` کنار `server.js` به‌صورت خودکار خوانده می‌شود (بدون وابستگی) و در `.gitignore` است
- توکن هرگز به کلاینت برنمی‌گردد و در کد اپ قرار نمی‌گیرد
- اپ موبایل فقط با این سرور حرف می‌زند
- api_id/api_hash و نشست‌های تلگرام هرگز به کلاینت برنمی‌گردند


## اجرا
```bash
# راه ۱: فایل .env را کنار server.js بگذار (همین الان پر شده) و:
node server.js

# راه ۲: متغیر محیطی مستقیم
MARKETAPP_API_TOKEN=توکن_خودت node server.js
```

## دیپلوی رایگان (Render)
1. این پوشه را در یک ریپو گیت بگذار (فایل `.env` به‌خاطر gitignore پوش نمی‌شود — توکن را در پنل ست کن)
2. render.com → New → Web Service → ریپو را وصل کن
3. Root Directory: `backend`
4. Build Command: خالی | Start Command: `node server.js`
5. Environment → Add: `MARKETAPP_API_TOKEN` = توکن خودت
6. بعد از دیپلوی، URL عمومی را در اپ وارد کن

## پوشش اندپوینت‌های Marketapp (تست‌شده با توکن فعلی)

### رایگان با همین توکن — همین حالا کار می‌کند
| اندپوینت اصلی | پراکسی اپ | وضعیت تست |
|---|---|---|
| `POST /v1/fragment/stars/price/` | `/api/stars/price` | ✓ ۲۰۰ |
| `POST /v1/fragment/stars/recipient/` | `/api/stars/recipient` | ✓ |
| `POST /v1/fragment/stars/buy/` | `/api/stars/buy` | ✓ |
| `POST /v1/fragment/premium/price/` | `/api/premium/price` | ✓ ۲۰۰ (۳/۶/۱۲ ماه) |
| `POST /v1/fragment/premium/recipient/` | `/api/premium/recipient` | ✓ |
| `POST /v1/fragment/premium/buy/` | `/api/premium/buy` | ✓ |
| `GET /v1/collections/gifts/` | `/api/collections/gifts` | ✓ ۲۰۰ (کف/حجم/مالکان) |
| `GET /v1/collections/{addr}/attributes/` | `/api/collections/attributes/:addr` | ✓ ۲۰۰ |
| `GET /v1/rent/gifts/` | `/api/rent/gifts` | ✓ ۲۰۰ (فید واقعی) |
| `GET /v1/rent/{cat}/history/` | `/api/rent/history` | ✓ ۲۰۰ |
| `GET /v1/rent/my-rented/` | `/api/rent/my-rented` | ✓ ۲۰۰ |
| `POST /v1/rent/{nft}/pay/` | `/api/rent/pay` | ✓ **تراکنش واقعی برگشت** |
| `POST /v1/rent/{nft}/extend/` | `/api/rent/extend` | wired |
| `POST /v1/rent/cancel/` | `/api/rent/cancel` | wired |
| `POST /v1/rent/gifts/rent-out/` | `/api/rent/rent-out` | wired |
| `POST /v1/rent/gifts/update-settings/` | `/api/rent/update-settings` | wired |
| `POST /v1/rent/{nft}/tonconnect/` | `/api/rent/tonconnect` | wired |
| `POST /v1/rent/{nft}/login-code/` + toggle | `/api/rent/login-code` | wired |
| `POST /v1/nfts/sale/` | `/api/nfts/sale` | ✓ رایگان (تراکنش) |
| `POST /v1/nfts/change_price/` | `/api/nfts/change_price` | ✓ رایگان (تراکنش) |
| `POST /v1/nfts/cancel_sale/` | `/api/nfts/cancel_sale` | ✓ **تراکنش واقعی برگشت** |

### نیاز به پلن API (فعلاً 402) — با فعال شدن پلن خودکار روشن می‌شود
| اندپوینت اصلی | پراکسی اپ | فال‌بک رایگان فعلی |
|---|---|---|
| `GET /v1/gifts/onsale/` (فید فروش) | `/api/gifts/onsale` | فید اجاره در اپ |
| `GET /v1/gifts/history/` | `/api/gifts/history` | — |
| `GET /v1/nfts/collections/{addr}/` | `/api/nfts/collection/:addr` | tonapi → toncenter (آیتم واقعی + عکس fragment) |
| `GET /v1/nfts/owner/{addr}/` | `/api/nfts/owner/:addr` | tonapi (انبار واقعی) |
| `GET /v1/nfts/{nft}/` | `/api/nfts/info/:addr` | tonapi |
| `POST /v1/nfts/buy/` | `/api/nfts/buy` | — (دکمه خرید پیام شفاف می‌دهد) |

فعال‌سازی پلن: **marketapp.org/api-token** — بعد از فعال‌سازی **هیچ تغییری در کد لازم نیست**؛
فید فروش واقعیِ بازار اصلی تلگرام (TON) و خرید NFT خودکار فعال می‌شوند
(`GET /api/health` فیلد `sale_feed` را برمی‌گرداند).

## سایر مسیرها
| مسیر | کار |
|---|---|
| `GET /api/health` | سلامت + توکن + وضعیت فید فروش (`sale_feed`) |
| `GET /tonconnect-manifest.json` | مانیفست TON Connect (هوست خودکار) |
| `GET /ton-wallets.json` | لیست ۳۸ کیف پول TON |
| `GET /icon.png` | آیکون اپ برای مانیفست |
| `POST /api/resolve-gift` `{link}` | تشخیص گیفت از لینک t.me (عکس واقعی + slug) |
| `GET /api/wallet/:address/balance` | موجودی TON (tonapi) |
| `GET /api/rate/irt` | نرخ TON/IRT نمایشی (والکس/نوبیتکس) |

## نکات فنی
- آدرس‌های raw (`0:…`) به فرمت استاندارد TON (EQ… با CRC-16/XMODEM) تبدیل می‌شوند — با وکتور شناخته‌شده تست شده
- پاسخ `transaction.messages[]` مستقیم به TON Connect اپ داده می‌شود؛ پرداخت مستقیم از کیف پول کاربر
- کش داخلی: کالکشن‌ها ۶۰ ثانیه، فید فروش ۳۰ ثانیه، اجاره ۳۰ ثانیه، نرخ ارز ۲ دقیقه، وضعیت پلن ۵ دقیقه
