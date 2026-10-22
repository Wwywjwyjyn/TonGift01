import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../core/strings.dart';
import '../providers/core_providers.dart';
import '../providers/wallet_provider.dart';
import '../providers/tg_provider.dart';
import '../widgets/wallet_sheet.dart';
import '../widgets/common.dart';
import 'market/market_screen.dart';
import 'stars_premium/stars_premium_screen.dart';
import 'inventory/inventory_screen.dart';
import 'cart/cart_screen.dart';
import 'history/history_screen.dart';
import 'owner/api_gate_screen.dart';
import 'setup_screen.dart';
import 'tg/tg_connect_screen.dart';
import 'tg/tg_profile_sheet.dart';
import '../providers/market_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/cart_provider.dart';
import 'wallet_init.dart' show ensureWalletInit;

/// شل اصلی — ۵ تب: بازار | استارز/پریمیوم | انبار | سبد | تاریخچه
/// دکمه‌های تلگرام و کیف پول بالا-راست + گیت API فقط برای اولین کاربر
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _idx = 0;
  bool _healthOk = true;
  bool _checked = false;
  bool _gateOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndCheck();
      ref.read(marketProvider.notifier).refresh();
      ref.read(ordersProvider.notifier).refresh();
    });

    // وقتی تلگرام وصل شد — کاتالوگ و انبار خودکار تازه شود
    ref.listenManual(tgSessionProvider.select((s) => s.connected), (prev, now) {
      if (!prev && now) {
        ref.read(tgCatalogProvider.notifier).refresh();
        ref.read(tgInventoryProvider.notifier).refresh();
        ref.read(tgSessionProvider.notifier).refreshStars();
      }
    });
  }

  Future<void> _initAndCheck() async {
    final url = ref.read(settingsProvider).backendUrl;
    if (url == null) return;
    ensureWalletInit(ref, url);
    ref.read(walletProvider.notifier).refreshBalance();
    // گیت اولین کاربر — فقط مالکِ در انتظار گیت را می‌بیند
    await ref.read(ownerGateProvider.notifier).check();
    _maybeOpenGate();
    // وضعیت تلگرام — بعد از گیت (تا مالکیت دستگاه اول تثبیت شود)
    ref.read(tgSessionProvider.notifier).check();
    final ok = await ref.read(apiProvider).health();
    if (!mounted) return;
    setState(() {
      _healthOk = ok;
      _checked = true;
    });
    if (!ok) {
      final s = ref.read(settingsProvider).s;
      toast(context, s.networkError, error: true);
    }
  }

  void _maybeOpenGate() {
    final gate = ref.read(ownerGateProvider);
    if (gate.shouldShow && !_gateOpened && mounted) {
      _gateOpened = true;
      ref.read(ownerGateProvider.notifier).dismissedThisSession(); // فقط یک‌بار در هر اجرا
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ApiGateScreen()));
    }
  }

  /// دکمه تلگرام در اپ‌بار — ورود یا اکانت متصل
  Widget _tgButton(BuildContext context, WidgetRef ref, S s) {
    final sess = ref.watch(tgSessionProvider);

    if (sess.connected) {
      return GestureDetector(
        onTap: () => showTgProfileSheet(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(AppColors.yellow).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.telegram_rounded, size: 15, color: Color(AppColors.yellow)),
              const SizedBox(width: 5),
              Text(
                sess.stars == null ? '…' : fmtStars(sess.stars!),
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
              ),
            ],
          ),
        ),
      );
    }

    return IconButton(
      tooltip: s.tgConnect,
      onPressed: (sess.phase == TgPhase.locked)
          ? null
          : () async {
              if (sess.phase == TgPhase.needApi) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ApiGateScreen()));
                return;
              }
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const TgConnectScreen()));
              ref.read(tgSessionProvider.notifier).check();
            },
      icon: sess.checking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)),
            )
          : const Icon(Icons.telegram_rounded, size: 23, color: Color(AppColors.yellow)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final wallet = ref.watch(walletProvider);
    final cartCount = ref.watch(cartProvider.select((c) => c.items.length));

    final pages = [
      const MarketScreen(),
      const StarsPremiumScreen(),
      const InventoryScreen(),
      const CartScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text([
          s.market,
          '${s.stars} & ${s.premium}',
          s.inventory,
          s.cart,
          s.history,
        ][_idx]),
        actions: [
          // دکمه تلگرام — ورود/اکانت
          _tgButton(context, ref, s),
          // دکمه اتصال کیف پول — بالا سمت راست
          GestureDetector(
            onTap: () => showWalletSheet(context),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: wallet.isConnected
                    ? const Color(AppColors.yellow).withOpacity(0.12)
                    : const Color(AppColors.yellow),
                borderRadius: BorderRadius.circular(12),
                border: wallet.isConnected
                    ? Border.all(color: const Color(AppColors.yellow).withOpacity(0.5))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    wallet.isConnected ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded,
                    size: 15,
                    color: wallet.isConnected ? const Color(AppColors.green) : const Color(0xFF111111),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    wallet.isConnected
                        ? shortAddr(wallet.address)
                        : s.connectWallet,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: wallet.isConnected ? const Color(AppColors.text) : const Color(0xFF111111),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => const _SettingsSheet(),
              );
            },
            icon: const Icon(Icons.settings_rounded, size: 21),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_checked && !_healthOk)
            Container(
              width: double.infinity,
              color: const Color(AppColors.red).withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(
                s.networkError,
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.red)),
              ),
            ),
          Expanded(child: IndexedStack(index: _idx, children: pages)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.storefront_rounded), label: s.market),
          BottomNavigationBarItem(icon: const Icon(Icons.star_rounded), label: s.stars),
          BottomNavigationBarItem(icon: const Icon(Icons.inventory_2_rounded), label: s.inventory),
          // سبد خرید با نشان تعداد
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_rounded),
                if (cartCount > 0)
                  Positioned(
                    top: -4,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.yellow),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 15),
                      child: Text(
                        '$cartCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                      ),
                    ),
                  ),
              ],
            ),
            label: s.cart,
          ),
          BottomNavigationBarItem(icon: const Icon(Icons.history_rounded), label: s.history),
        ],
      ),
    );
  }
}

/// شیت تنظیمات و ابزارها
class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).s;
    final st = ref.watch(settingsProvider);
    final gate = ref.watch(ownerGateProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.settings, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 17, fontWeight: FontWeight.w800)),
          const Divider(height: 22),
          _row(context, Icons.dns_rounded, s.backendUrl, st.backendUrl, () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen(canGoBack: true)));
          }),
          // وضعیت API تلگرام — فقط برای مالک معنا دارد
          if (gate.isOwner)
            _row(context, Icons.vpn_key_rounded, s.apiGateTitle,
                gate.claimed ? s.apiReady : s.optional, () {
              Navigator.pop(context);
            }),
          _row(context, Icons.language_rounded, s.language, st.fa ? 'فارسی' : 'English', () async {
            await ref.read(settingsProvider.notifier).setLang(st.fa ? 'en' : 'fa');
          }),
          _row(context, Icons.card_giftcard_rounded, s.premiumGiftInTg, st.multigiftRef.isEmpty ? s.optional : 'ref: ${st.multigiftRef}', () {
            Navigator.pop(context);
            _editMultigiftRef(context, ref);
          }),
          const Divider(height: 22),
          Text(
            s.noAdsNoBrand,
            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim), height: 1.9),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String title, String? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 19, color: const Color(AppColors.yellow)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5, fontWeight: FontWeight.w600))),
            if (value != null)
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.textDim)),
                ),
              ),
            const Icon(Icons.chevron_left_rounded, size: 18, color: Color(AppColors.textDim)),
          ],
        ),
      ),
    );
  }
}

void _editMultigiftRef(BuildContext context, WidgetRef ref) {
  final st = ref.read(settingsProvider);
  final s = st.s;
  final ctrl = TextEditingController(text: st.multigiftRef);
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.premiumGiftInTg,
            style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'ref…')),
          const SizedBox(height: 12),
          YellowButton(
            label: s.save,
            onTap: () async {
              await ref.read(settingsProvider.notifier).setMultigiftRef(ctrl.text);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}
