/// رشته‌های دوزبانه — انگلیسی پیش‌فرض، فارسی از تنظیمات
/// Bilingual strings — English by default, Persian switchable in Settings
class S {
  final bool fa;
  const S(this.fa);

  // ---------- عمومی ----------
  String get appTitle => fa ? 'بازار گیفت' : 'Gift Market';
  String get market => fa ? 'بازار' : 'Market';
  String get stars => fa ? 'استارز' : 'Stars';
  String get premium => fa ? 'پریمیوم' : 'Premium';
  String get inventory => fa ? 'انبار' : 'Inventory';
  String get orders => fa ? 'سفارش‌ها' : 'Orders';
  String get history => fa ? 'تاریخچه' : 'History';
  String get cart => fa ? 'سبد خرید' : 'Cart';
  String get rent => fa ? 'اجاره' : 'Rent';
  String get connectWallet => fa ? 'اتصال کیف پول' : 'Connect Wallet';
  String get disconnect => fa ? 'قطع اتصال' : 'Disconnect';
  String get myWallet => fa ? 'کیف پول من' : 'My Wallet';
  String get balance => fa ? 'موجودی' : 'Balance';
  String get all => fa ? 'همه' : 'All';
  String get tonTab => fa ? 'تون' : 'TON';
  String get starsTab => fa ? 'استارز' : 'Stars';
  String get collections => fa ? 'کالکشن‌ها' : 'Collections';
  String get searchHint => fa ? 'جستجوی گیفت، مدل، بک‌گراند…' : 'Search gift, model, backdrop…';
  String get settings => fa ? 'تنظیمات' : 'Settings';
  String get language => fa ? 'زبان' : 'Language';
  String get loading => fa ? 'در حال بارگذاری…' : 'Loading…';
  String get errorOccurred => fa ? 'خطا رخ داد' : 'An error occurred';
  String get networkError => fa ? 'خطای شبکه — بک‌اند در دسترس نیست' : 'Network error — backend unreachable';
  String get empty => fa ? 'چیزی یافت نشد' : 'Nothing found';
  String get pullRefresh => fa ? 'برای به‌روزرسانی بکش' : 'Pull to refresh';
  String get confirm => fa ? 'تأیید' : 'Confirm';
  String get cancel => fa ? 'انصراف' : 'Cancel';
  String get retry => fa ? 'تلاش مجدد' : 'Retry';
  String get later => fa ? 'بعداً' : 'Later';
  String get save => fa ? 'ذخیره' : 'Save';
  String get saved => fa ? 'ذخیره شد ✓' : 'Saved ✓';
  String get copy => fa ? 'کپی' : 'Copy';
  String get copied => fa ? 'کپی شد ✓' : 'Copied ✓';
  String get optional => fa ? 'اختیاری' : 'Optional';
  String get price => fa ? 'قیمت' : 'Price';
  String get items => fa ? 'تعداد' : 'Items';
  String get optionalField => fa ? 'اختیاری' : 'Optional';

  // ---------- مارکت ----------
  String get buyWithTon => fa ? 'خرید با TON' : 'Buy with TON';
  String get openInTelegram => fa ? 'مشاهده در تلگرام' : 'Open in Telegram';
  String get giftId => fa ? 'آیدی گیفت' : 'Gift ID';
  String get model => fa ? 'مدل' : 'Model';
  String get backdrop => fa ? 'بک‌گراند' : 'Backdrop';
  String get symbol => fa ? 'سمبل' : 'Symbol';
  String get seller => fa ? 'فروشنده' : 'Seller';
  String get floor => fa ? 'کف قیمت' : 'Floor';
  String get forRent => fa ? 'اجاره' : 'Rent';
  String get forSale => fa ? 'در فروش' : 'On Sale';
  String get owner => fa ? 'مالک' : 'Owner';
  String get rentPerDay => fa ? 'اجاره روزانه' : 'Rent / day';
  String get perDay => fa ? '/روز' : '/day';
  String get rentNow => fa ? 'اجاره می‌گیرم' : 'Rent Now';
  String get addToCart => fa ? 'افزودن به سبد' : 'Add to Cart';
  String get addedToCart => fa ? 'به سبد خرید اضافه شد ✓' : 'Added to cart ✓';
  String get inCart => fa ? 'در سبد' : 'In cart';
  String get paidPlanNeeded => fa
      ? 'فید فروش واقعی (TON/استارز) نیازمند فعال‌سازی پلن API مارکت‌اپ است. الان فید اجاره نمایش داده می‌شود.'
      : 'The real sale feed (TON/Stars) needs the Marketapp API plan. Showing the rent feed for now.';
  String get sortBy => fa ? 'مرتب‌سازی' : 'Sort by';
  String get sortRecentlyTouch => fa ? 'آخرین تغییر' : 'Recently touched';
  String get sortPriceLow => fa ? 'ارزان‌ترین' : 'Price: low to high';
  String get sortPriceHigh => fa ? 'گران‌ترین' : 'Price: high to low';
  String get sortDuration => fa ? 'مدت اجاره' : 'Duration';
  String get sortItemNum => fa ? 'شماره گیفت' : 'Item number';
  String get filters => fa ? 'فیلترها' : 'Filters';
  String get apply => fa ? 'اعمال' : 'Apply';
  String get reset => fa ? 'بازنشانی' : 'Reset';
  String get grid => fa ? 'شبکه‌ای' : 'Grid';
  String get list => fa ? 'لیستی' : 'List';
  String get giftsLoaded => fa ? 'گیفت بارگیری شد' : 'gifts loaded';
  String get loadingMore => fa ? 'بارگیری بیشتر…' : 'Loading more…';

  // ---------- سبد خرید ----------
  String get cartEmpty => fa ? 'سبد خرید خالی است' : 'Your cart is empty';
  String get cartEmptyDesc => fa
      ? 'از بازار گیفت‌ها را به سبد اضافه کن و یکجا پرداخت کن'
      : 'Add gifts from the market and pay for them one by one in a single flow';
  String get removeFromCart => fa ? 'حذف از سبد' : 'Remove';
  String get checkout => fa ? 'پرداخت سبد' : 'Checkout';
  String total(int n) => fa ? 'مجموع ($n گیفت)' : 'Total ($n gifts)';
  String get sequentialNote => fa
      ? 'هر گیفت با یک تراکنش جداگانه در کیف پولت پرداخت می‌شود'
      : 'Each gift is paid with a separate transaction in your wallet';
  String get buyNext => fa ? 'خرید مورد بعدی' : 'Buy next item';
  String get itemDone => fa ? 'انجام شد' : 'Done';
  String get itemFailed => fa ? 'ناموفق' : 'Failed';
  String get clearCart => fa ? 'خالی کردن سبد' : 'Clear cart';
  String get cartCleared => fa ? 'سبد خالی شد' : 'Cart cleared';

  // ---------- تاریخچه ----------
  String get historyTitle => fa ? 'تاریخچه' : 'History';
  String get filterAll => fa ? 'همه' : 'All';
  String get filterGifts => fa ? 'گیفت‌ها' : 'Gifts';
  String get filterStars => fa ? 'استارز' : 'Stars';
  String get filterPremium => fa ? 'پریمیوم' : 'Premium';
  String get filterRents => fa ? 'اجاره‌ها' : 'Rents';
  String get rentHistory => fa ? 'تاریخچه اجاره بازار' : 'Market rent history';
  String get historyEmpty => fa ? 'هنوز فعالیتی نیست' : 'No activity yet';
  String get historyEmptyDesc => fa
      ? 'خریدها، فروش‌ها و اجاره‌هایت اینجا دیده می‌شود'
      : 'Your purchases, sales and rentals will appear here';
  String get rentedBy => fa ? 'اجاره‌گیرنده' : 'Rented by';
  String get rentedFrom => fa ? 'اجاره از' : 'Rented from';

  // ---------- کالکشن‌ها ----------
  String get floorChart => fa ? 'چارت کف قیمت' : 'Floor price chart';
  String get touchChartHint => fa ? 'روی چارت بزن تا مقدار کف را ببینی' : 'Touch the chart to inspect the floor';
  String get collectingData => fa
      ? 'داده کف قیمت در حال جمع‌آوری روی بک‌اند است — با هر به‌روزرسانی نمودار کامل‌تر می‌شود'
      : 'Floor data is being collected on your backend — the chart fills up with every update';
  String get noFloorData => fa ? 'هنوز داده‌ای برای این بازه نیست' : 'No data for this range yet';
  String get rentFloor => fa ? 'کف اجاره' : 'Rent floor';
  String get range1D => fa ? '۱روز' : '1D';
  String get range1W => fa ? '۱هفته' : '1W';
  String get range1M => fa ? '۱ماه' : '1M';
  String get range3M => fa ? '۳ماه' : '3M';
  String get range6M => fa ? '۶ماه' : '6M';
  String get range1Y => fa ? '۱سال' : '1Y';

  // ---------- اجاره ----------
  String get rentTitle => fa ? 'اجاره گیفت' : 'Rent a Gift';
  String get rentMarket => fa ? 'بازار اجاره' : 'Rent market';
  String get durationDays => fa ? 'مدت (روز)' : 'Duration (days)';
  String get daysShort => fa ? 'روز' : 'd';
  String get perDayPrice => fa ? 'قیمت روزانه' : 'Per day';
  String get minDuration => fa ? 'حداقل' : 'Min';
  String get maxDuration => fa ? 'حداکثر' : 'Max';

  // ---------- استارز و پریمیوم ----------
  String get quantity => fa ? 'تعداد استارز' : 'Stars Quantity';
  String get starsCustom => fa ? 'دلخواه' : 'Custom';
  String get receiver => fa ? 'گیرنده' : 'Receiver';
  String get username => fa ? 'یوزرنیم' : 'Username';
  String get check => fa ? 'بررسی' : 'Check';
  String get enterUsername => fa ? 'یوزرنیم گیرنده را وارد کن' : 'Enter the receiver username';
  String get priceNotReady => fa ? 'قیمت هنوز آماده نیست' : 'Price is not ready yet';
  String get finalPrice => fa ? 'مبلغ نهایی' : 'Final Price';
  String get payNow => fa ? 'پرداخت با TON' : 'Pay with TON';
  String get months3 => fa ? '۳ ماهه' : '3 Months';
  String get months6 => fa ? '۶ ماهه' : '6 Months';
  String get months12 => fa ? 'یک‌ساله' : '1 Year';
  String get buyPremium => fa ? 'خرید پریمیوم' : 'Buy Premium';
  String get perMonth => fa ? 'در ماه' : '/mo';
  String get bestValue => fa ? 'بهترین ارزش' : 'Best value';
  String get serverResponseIncomplete => fa ? 'پاسخ سرور کامل نبود' : 'Server response was incomplete';
  String get termsShort => fa ? 'پرداخت‌ها مستقیم با کیف پول خودت انجام می‌شود' : 'Payments go directly with your own wallet';

  // ---------- گیت اولین کاربر (API ID / Hash) ----------
  String get apiGateTitle => fa ? 'API تلگرام' : 'Telegram API';
  String get apiGateDesc => fa
      ? 'برای خرید و دیدن گیفت استارزی، API ID و API Hash اکانت تلگرامت را وارد کن. این مقادیر فقط روی بک‌اند خودت ذخیره می‌شوند.'
      : 'To buy and view star gifts, enter your Telegram API ID and API Hash. These are stored only on your own backend.';
  String get apiGateOwnerNote => fa
      ? 'این فرم فقط برای اولین نفری که اپ را باز می‌کند نشان داده می‌شود — یعنی فقط خودت'
      : 'This form is shown only to the first person who opens the app — that is you alone';
  String get apiGateSkipNote => fa
      ? 'فعلاً رد کن — دفعه بعد که وارد شوی دوباره نشان داده می‌شود تا کاملش کنی'
      : 'Skip for now — it will show again next time you open the app until you complete it';
  String get apiId => fa ? 'API ID' : 'API ID';
  String get apiHash => fa ? 'API Hash' : 'API Hash';
  String get apiIdHint => fa ? 'مثال: 1234567' : 'e.g. 1234567';
  String get apiHashHint => fa ? '۳۲ کاراکتر هکس' : '32 hex characters';
  String get apiGateWhere => fa
      ? 'از my.telegram.org ← بخش API development tools می‌گیری'
      : 'Get it from my.telegram.org → API development tools';
  String get apiGateSave => fa ? 'ذخیره و ادامه' : 'Save & Continue';
  String get invalidApiHash => fa ? 'API Hash باید ۳۲ کاراکتر هکس باشد' : 'API Hash must be 32 hex characters';
  String get invalidApiId => fa ? 'API ID باید عدد باشد' : 'API ID must be a number';
  String get apiReady => fa ? 'API تلگرام آماده است ✓' : 'Telegram API is ready ✓';
  String get apiGateDone => fa
      ? 'عالی! دیگر این فرم نشان داده نمی‌شود'
      : 'Done! This form will not be shown again';

  // ---------- انبار ----------
  String get addToInventory => fa ? 'افزودن گیفت تلگرام' : 'Add Telegram Gift';
  String get sellGift => fa ? 'فروش گیفت' : 'Sell Gift';
  String get changePrice => fa ? 'تغییر قیمت' : 'Change Price';
  String get cancelSale => fa ? 'لغو فروش' : 'Cancel Sale';
  String get priceTon => fa ? 'قیمت (TON)' : 'Price (TON)';
  String get sellPriceHint => fa ? 'قیمت به TON' : 'Price in TON';
  String get myGifts => fa ? 'گیفت‌های من' : 'My Gifts';
  String get step1 => fa ? '۱. گیفت را در تلگرام باز کن' : '1. Open the gift in Telegram';
  String get step2 => fa ? '۲. روی سه‌نقطه بزن و «کپی لینک» را انتخاب کن' : '2. Tap ⋮ and choose “Copy Link”';
  String get step3 => fa ? '۳. لینک را اینجا بچسبان تا گیفت شناسایی شود' : '3. Paste the link here to detect the gift';
  String get openTelegram => fa ? 'باز کردن تلگرام' : 'Open Telegram';
  String get detectGift => fa ? 'تشخیص گیفت' : 'Detect Gift';
  String get pasteLinkHint => fa ? 'مثال: https://t.me/nft/PlushPepe-1234' : 'e.g. https://t.me/nft/PlushPepe-1234';
  String get notInYourWallet => fa ? 'این گیفت در کیف پول متصل شما نیست' : 'This gift is not in your connected wallet';

  // ---------- کیف پول / تراکنش ----------
  String get txConfirmTitle => fa ? 'تأیید تراکنش' : 'Confirm Transaction';
  String get txTo => fa ? 'به آدرس' : 'To';
  String get txAmount => fa ? 'مبلغ' : 'Amount';
  String get sendToWallet => fa ? 'ارسال به کیف پول' : 'Send to Wallet';
  String get txSent => fa ? 'تراکنش در کیف پول شما تأیید و به شبکه ارسال شد ✓' : 'Transaction confirmed in your wallet and sent ✓';
  String get txPendingWallet => fa ? 'کیف پول را باز کن و تراکنش را تأیید کن…' : 'Open your wallet and confirm the transaction…';
  String get txRejected => fa ? 'تراکنش رد شد یا خطا رخ داد' : 'Transaction rejected or failed';
  String get connected => fa ? 'متصل' : 'Connected';
  String get connecting => fa ? 'در حال اتصال…' : 'Connecting…';
  String get notConnected => fa ? 'وصل نیست' : 'Not connected';
  String get walletConnectedToast => fa ? 'کیف پول متصل شد ✓' : 'Wallet connected ✓';
  String get openWalletAgain => fa ? 'باز کردن دوباره کیف پول' : 'Open wallet again';
  String get waitingWallet => fa ? 'در انتظار تأیید کیف پول…' : 'Waiting for wallet…';
  String get backendUrl => fa ? 'آدرس بک‌اند' : 'Backend URL';
  String get testConn => fa ? 'تست و ادامه' : 'Test & Continue';
  String get setupTitle => fa ? 'اتصال به بک‌اند' : 'Connect Backend';
  String get setupDesc => fa
      ? 'آدرس بک‌اند خودت را وارد کن (سرور پراکسی با توکن امن). این مقدار فقط روی همین گوشی ذخیره می‌شود.'
      : 'Enter your backend URL (secure proxy with the token). Stored only on this device.';
  String get viewTx => fa ? 'مشاهده در اکسپلورر' : 'View in explorer';
  String get noWalletNeeded => fa ? 'بدون نیاز به ثبت‌نام' : 'No signup needed';

  // ---------- سفارش‌ها ----------
  String get myOrders => fa ? 'سفارش‌های من' : 'My Orders';
  String get orderTypeStars => fa ? 'خرید استارز' : 'Stars Purchase';
  String get orderTypePremium => fa ? 'خرید پریمیوم' : 'Premium Purchase';
  String get orderTypeGift => fa ? 'معامله گیفت' : 'Gift Trade';
  String get orderTypeRent => fa ? 'اجاره' : 'Rental';
  String get status => fa ? 'وضعیت' : 'Status';
  String get created => fa ? 'ایجاد شد' : 'Created';
  String get sent => fa ? 'ارسال به کیف پول' : 'Sent to wallet';
  String get confirmed => fa ? 'تأیید شد' : 'Confirmed';
  String get failed => fa ? 'ناموفق' : 'Failed';

  String get premiumGiftInTg => fa ? 'هدیه پریمیوم چندنفره در تلگرام' : 'Multi Gift Premium in Telegram';
  String get about => fa ? 'درباره' : 'About';
  String get noAdsNoBrand => fa ? 'بدون تبلیغ، بدون برند ثالث — خرید مستقیم از بک‌اند خودت' : 'No ads, no third-party branding — buys go through your own backend';
  String get giftNotFound => fa ? 'گیفت پیدا نشد' : 'Gift not found';
  String get from => fa ? 'از طرف' : 'From';
  String get you => fa ? 'شما' : 'You';
  String get myProfile => fa ? 'پروفایل من' : 'My Profile';

  // ---------- مارکت رسمی تلگرام (MTProto) ----------
  String get tgSource => fa ? 'گیفت تلگرام' : 'Telegram';
  String get tonSource => fa ? 'NFT تون' : 'TON NFT';
  String get tgMarket => fa ? 'مارکت رسمی تلگرام' : 'Official Telegram Market';
  String get tgConnect => fa ? 'ورود به تلگرام' : 'Connect Telegram';
  String get tgConnectDesc => fa
      ? 'برای دیدن و خرید گیفت‌های استارزی مارکت اصلی تلگرام، با اکانت تلگرامت وارد شو. ورود مستقیم با سرور خودت انجام می‌شود و نشست فقط همان‌جا ذخیره می‌شود.'
      : 'Sign in with your Telegram account to browse and buy Star gifts from the official market. Login goes directly through your own backend — the session stays there.';
  String get tgPhone => fa ? 'شماره تلفن' : 'Phone number';
  String get tgPhoneHint => fa ? 'مثل: +989121234567' : 'e.g. +14155552671';
  String get tgSendCode => fa ? 'ارسال کد' : 'Send Code';
  String get tgCodeTitle => fa ? 'کد ورود' : 'Login code';
  String get tgCodeHint => fa ? 'کد ۵ رقمی که تلگرام فرستاد' : 'The 5-digit code Telegram sent you';
  String get tgCodeSentTo => fa ? 'کد به این شماره رفت:' : 'Code sent to:';
  String get tg2faTitle => fa ? 'رمز دومرحله‌ای' : 'Two-step verification';
  String get tg2faHint => fa ? 'رمز اکانت تلگرامت را وارد کن' : 'Enter your Telegram password';
  String get tgContinue => fa ? 'ادامه' : 'Continue';
  String get tgAccount => fa ? 'اکانت تلگرام' : 'Telegram Account';
  String get tgStarsBalance => fa ? 'موجودی استارز' : 'Stars balance';
  String get tgTopUpHint => fa
      ? 'برای شارژ استارز، داخل اپ رسمی تلگرام بخش استارز را باز کن'
      : 'To top up Stars, open the Stars section in the official Telegram app';
  String get tgLogout => fa ? 'خروج از تلگرام' : 'Log out of Telegram';
  String get tgLogoutConfirm => fa ? 'نشست تلگرام از سرور پاک شود؟' : 'Remove the Telegram session from the server?';
  String get tgBuyNew => fa ? 'خرید جدید' : 'Buy New';
  String get tgBuyNewDesc => fa ? 'گیفت نو بخر و به خودت یا دوستانت هدیه بده' : 'Buy a fresh gift and send it to yourself or a friend';
  String get tgRecipient => fa ? 'گیرنده' : 'Recipient';
  String get tgRecipientMe => fa ? 'خودم' : 'Myself';
  String get tgRecipientOther => fa ? 'یوزرنیم دیگر' : 'Other username';
  String get tgMessage => fa ? 'پیام همراه هدیه' : 'Gift message';
  String get tgResale => fa ? 'بازار دست‌دوم' : 'Resale Market';
  String get tgResaleEmpty => fa ? 'هنوز هیچ‌یک از این گیفت فروش‌گذاری نشده' : 'No resellers for this gift yet';
  String tgListingsCount(int n) => fa ? '$n عدد در فروش' : '$n for sale';
  String get tgBuy => fa ? 'خرید با استارز' : 'Buy with Stars';
  String get tgBuyConfirmTitle => fa ? 'خرید گیفت' : 'Buy Gift';
  String get tgYourBalance => fa ? 'موجودی تو' : 'Your balance';
  String get tgAfterBuy => fa ? 'بعد از خرید' : 'After purchase';
  String get tgInsufficient => fa ? 'موجودی استارز کافی نیست — از داخل تلگرام شارژ کن' : 'Not enough Stars — top up inside the Telegram app';
  String get tgBought => fa ? 'خرید شد ✓ — در انبار تلگرامت است' : 'Purchased ✓ — it is in your Telegram inventory';
  String get tgBuyNewDone => fa ? 'گیفت ارسال شد ✓' : 'Gift sent ✓';
  String get tgSellTg => fa ? 'فروش‌گذاری در بازار' : 'List for Sale';
  String get tgSetPriceTg => fa ? 'قیمت به استارز' : 'Price in Stars';
  String get tgPriceRange => fa ? 'مجاز:' : 'Allowed:';
  String tgCommissionNote(String p) => fa
      ? 'بعد از فروش، ${p}٪ کمیسیون تلگرام کم می‌شود'
      : 'Telegram takes ${p}% commission after the sale';
  String tgListedForSale(int p) => fa ? 'با $p استارز فروش‌گذاری شد' : 'Listed for $p Stars';
  String get tgUnlistTg => fa ? 'حذف از فروش' : 'Remove from Sale';
  String get tgUnlistedDone => fa ? 'از فروش حذف شد' : 'Removed from sale';
  String get tgTransferredTo => fa ? 'انتقال به' : 'Transferred to';
  String get tgTransferTg => fa ? 'انتقال/هدیه به دوست' : 'Transfer / Gift to a Friend';
  String tgTransferFee(int f) => fa ? 'هزینه انتقال: $f استارز' : 'Transfer fee: $f Stars';
  String get tgTransferDone => fa ? 'انتقال انجام شد ✓' : 'Transferred ✓';
  String get tgUpgradeTg => fa ? 'آپگرید به گیفت یکتا' : 'Upgrade to Collectible';
  String tgUpgradeCost(int c) => fa ? 'هزینه آپگرید: $c استارز' : 'Upgrade cost: $c Stars';
  String get tgUpgradedDone => fa ? 'گیفت یکتا شد ✓' : 'Upgraded to collectible ✓';
  String get tgUpgrading => fa ? 'در حال آپگرید…' : 'Upgrading…';
  String get tgListedBadge => fa ? 'در فروش' : 'Listed';
  String get tgUnlistedBadge => fa ? 'در فروش نیست' : 'Not listed';
  String get tgCanResellSoon => fa ? 'امکان فروش‌گذاری بعداً باز می‌شود' : 'Reselling unlocks later for this gift';
  String get tgOnSaleBadge => fa ? 'قابل خرید' : 'Buyable';
  String get tgSoldOutBadge => fa ? 'تمام‌شده' : 'Sold out';
  String get tgAuctionBadge => fa ? 'مزایده' : 'Auction';
  String get tgConnectFirst => fa ? 'اول با تلگرام وارد شو' : 'Connect Telegram first';
  String get tgNeedApiSetup => fa
      ? 'اول از گیت API، API ID و API Hash تلگرامت را ذخیره کن'
      : 'First save your Telegram API ID and API Hash in the API gate';
  String get tgLockedMsg => fa ? 'این اپ فقط برای مالکش باز است' : 'This app is locked to its owner';
  String tgFloodWait(int s) => fa
      ? 'تلگرام محدودیت گذاشته — $s ثانیه دیگر تلاش کن'
      : 'Telegram rate limit — retry in $s seconds';
  String get tgNumber => fa ? 'شماره' : 'Number';
  String get tgRarity => fa ? 'کمیابی' : 'Rarity';
  String get tgReceived => fa ? 'دریافتی' : 'Received';
  String tgGiftsCount(int n) => fa ? '$n گیفت' : '$n gifts';
  String get tgRefresh => fa ? 'به‌روزرسانی' : 'Refresh';
  String get tgBuyMinNote => fa ? 'حداقل قیمت فروش را تلگرام تعیین می‌کند' : 'Telegram enforces a minimum resale price';
  String get tgFromCatalog => fa ? 'از کاتالوگ' : 'From catalog';
  String get tgOpenMarket => fa ? 'باز کردن مارکت تلگرام' : 'Open Telegram market';
}
