import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../providers/core_providers.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet_sheet.dart';
import '../widgets/common.dart';
import 'market/market_screen.dart';
import 'stars/stars_screen.dart';
import 'inventory/inventory_screen.dart';
import 'premium/premium_screen.dart';
import 'orders/orders_screen.dart';
import 'setup_screen.dart';
import '../providers/market_provider.dart';
import '../providers/inventory_provider.dart';
import 'wallet_init.dart' show ensureWalletInit;

/// شل اصلی — ۴ تب + دکمه اتصال کیف پول بالا-راست (مثل MRKT)
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _idx = 0;
  bool _healthOk = true;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndCheck();
      ref.read(marketProvider.notifier).refresh();
      ref.read(ordersProvider.notifier).refresh();
    });
  }

  Future<void> _initAndCheck() async {
    final url = ref.read(settingsProvider).backendUrl;
    if (url == null) return;
    ensureWalletInit(ref, url);
    ref.read(walletProvider.notifier).refreshBalance();
    final ok = await ref.read(apiProvider).health();
    if (!mounted) return;
    setState(() {
      _healthOk = ok;
      _checked = true;
    });
    if (!ok) {
      toast(context, 'بک‌اند در دسترس نیست — آدرس را در تنظیمات چک کن', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final wallet = ref.watch(walletProvider);

    final pages = [
      const MarketScreen(),
      const StarsScreen(),
      const InventoryScreen(),
      const PremiumScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text([
          s.market,
          s.stars,
          s.inventory,
          s.premium,
        ][_idx]),
        actions: [
          // دکمه اتصال کیف پول — بالا سمت راست
          GestureDetector(
            onTap: () => showWalletSheet(context),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
              child: const Text(
                'اتصال بک‌اند برقرار نیست — داده‌ها بارگیری نمی‌شوند',
                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.red)),
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
          BottomNavigationBarItem(icon: const Icon(Icons.workspace_premium_rounded), label: s.premium),
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
    final ordersCount = ref.watch(ordersProvider).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.settings, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 17, fontWeight: FontWeight.w800)),
          const Divider(height: 22),
          _row(context, Icons.receipt_long_rounded, s.myOrders, ordersCount > 0 ? '$ordersCount سفارش' : null, () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
          }),
          _row(context, Icons.dns_rounded, s.backendUrl, st.backendUrl, () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen(canGoBack: true)));
          }),
          _row(context, Icons.card_giftcard_rounded, s.premiumGiftInTg, st.multigiftRef.isEmpty ? s.optional : 'ref: ${st.multigiftRef}', () {
            Navigator.pop(context);
            _editMultigiftRef(context, ref);
          }),
          _row(context, Icons.language_rounded, s.language, st.fa ? 'فارسی' : 'English', () async {
            await ref.read(settingsProvider.notifier).setLang(st.fa ? 'en' : 'fa');
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
  final ctrl = TextEditingController(text: st.multigiftRef);
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'کد ref برای tg://premium_multigift (اختیاری)',
            style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'ref…')),
          const SizedBox(height: 12),
          YellowButton(
            label: 'ذخیره',
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
