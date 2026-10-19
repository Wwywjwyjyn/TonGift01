import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/core_providers.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet_sheet.dart';
import '../widgets/common.dart';

/// راه‌اندازی سرویس‌ها بعد از ورود به شل اصلی (یک‌بار)
void ensureWalletInit(WidgetRef ref, String backendUrl) {
  final svc = ref.read(tonConnectServiceProvider);
  if (svc.manager == null) {
    svc.init(
      manifestUrl: '$backendUrl/tonconnect-manifest.json',
      walletsListSource: '$backendUrl/ton-wallets.json',
    );
  }
}

/// دکمه کوچک اتصال کیف پول برای استفاده داخل صفحات
class WalletConnectButton extends ConsumerWidget {
  const WalletConnectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final s = ref.watch(settingsProvider).s;
    return YellowButton(
      label: wallet.isConnected ? '${s.connected} ✓' : s.connectWallet,
      onTap: () => showWalletSheet(context),
    );
  }
}
