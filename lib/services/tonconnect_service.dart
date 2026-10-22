import 'dart:async';
import 'package:darttonconnect_plus/ton_connect_manager.dart';
import 'package:darttonconnect_plus/models/wallet_app.dart';
import 'package:url_launcher/url_launcher.dart';

/// سرویس TON Connect — اتصال همه کیف‌پول‌ها (Tonkeeper، Telegram Wallet،
/// MyTonWallet، Tonhub، OKX و…) بدون هیچ ثبت‌نامی.
class TonConnectService {
  TonConnectManager? _manager;
  final List<Function()> _listeners = [];

  TonConnectManager? get manager => _manager;

  /// استریم رویدادها (اتصال، قطع، تراکنش…)
  Stream<dynamic>? get events => _manager?.messagesStream;

  /// مقداردهی اولیه — manifest از بک‌اند خودت سرو می‌شود
  void init({required String manifestUrl, String? walletsListSource}) {
    if (_manager != null) return;
    _manager = TonConnectManager(
      manifestUrl,
      walletsListSource: walletsListSource,
      logLevel: null,
    );
  }

  bool get isConnected => _manager?.isConnected ?? false;

  /// آدرس کیف پول متصل (raw مثل 0:abc… یا friendly)
  String? get address {
    final w = _manager?.connectedWalletInfo;
    if (w == null) return null;
    try {
      final acc = w.account;
      return acc?.address?.toString();
    } catch (_) {
      return null;
    }
  }

  /// گوش دادن به وضعیت اتصال/تراکنش
  void addListener(void Function() cb) => _listeners.add(cb);

  void _notify() {
    for (final l in _listeners) {
      try {
        l();
      } catch (_) {}
    }
  }

  List<WalletApp> get wallets => TonConnectManager.wallets;

  /// ساخت لینک اتصال و باز کردن کیف پول انتخابی
  Future<String?> generateLink(WalletApp wallet) async {
    if (_manager == null) return null;
    _manager!.generateWalletLink(wallet);
    for (var i = 0; i < 30 && _manager!.walletConnectionLink == null; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _manager!.walletConnectionLink;
  }

  Future<void> openLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// ارسال تراکنش خام (پاسخ buy/sale از API) — کاربر در کیف پول خودش امضا می‌کند
  Future<void> sendTransaction(Map<String, dynamic> transaction) async {
    await _manager?.sendTrxRaw(transaction: transaction);
    _notify();
  }

  Future<void> disconnect() async {
    await _manager?.disconnect();
    _notify();
  }
}
