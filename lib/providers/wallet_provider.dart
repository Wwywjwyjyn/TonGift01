import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core_providers.dart';

enum WalletStatus { unknown, disconnected, connecting, connected }

class WalletState {
  final WalletStatus status;
  final String? address;
  final double balanceTon;
  final List<dynamic> wallets; // WalletApp list
  final String? pendingLink; // لینک اتصال فعال
  final String? error;

  const WalletState({
    this.status = WalletStatus.unknown,
    this.address,
    this.balanceTon = 0,
    this.wallets = const [],
    this.pendingLink,
    this.error,
  });

  bool get isConnected => status == WalletStatus.connected && (address?.isNotEmpty ?? false);

  WalletState copyWith({
    WalletStatus? status,
    String? address,
    double? balanceTon,
    List<dynamic>? wallets,
    String? pendingLink,
    String? error,
    bool clearPending = false,
    bool clearError = false,
  }) =>
      WalletState(
        status: status ?? this.status,
        address: address ?? this.address,
        balanceTon: balanceTon ?? this.balanceTon,
        wallets: wallets ?? this.wallets,
        pendingLink: clearPending ? null : (pendingLink ?? this.pendingLink),
        error: clearError ? null : (error ?? this.error),
      );
}

class WalletNotifier extends StateNotifier<WalletState> {
  final Ref ref;
  StreamSubscription? _sub;
  Timer? _poll;

  WalletNotifier(this.ref) : super(const WalletState()) {
    _bind();
  }

  void _bind() {
    final svc = ref.read(tonConnectServiceProvider);
    _sub?.cancel();
    // رویدادهای فوری TON Connect + بک‌آپ دوره‌ای سبک
    _sub = svc.events?.listen((_) => _sync(), onError: (_) => _sync());
    _poll = Timer.periodic(const Duration(milliseconds: 2500), (_) => _sync());
    _sync();
  }

  void _sync() {
    final svc = ref.read(tonConnectServiceProvider);
    final m = svc.manager;
    if (m == null) return;
    final addr = svc.address;
    final connected = svc.isConnected && (addr?.isNotEmpty ?? false);

    WalletStatus st;
    if (connected) {
      st = WalletStatus.connected;
    } else if (state.pendingLink != null) {
      st = WalletStatus.connecting;
    } else {
      st = WalletStatus.disconnected;
    }

    if (st != state.status ||
        addr != state.address ||
        m.wallets.length != state.wallets.length) {
      state = state.copyWith(
        status: st,
        address: addr,
        wallets: m.wallets,
      );
      if (connected && state.pendingLink != null) {
        state = state.copyWith(clearPending: true);
        _refreshBalance();
      }
    }
  }

  Future<void> refreshBalance() => _refreshBalance();

  Future<void> _refreshBalance() async {
    final addr = state.address;
    if (addr == null || addr.isEmpty) return;
    try {
      final r = await ref.read(apiProvider).walletBalance(addr);
      final t = (r is Map) ? (r['balance_ton'] as num?)?.toDouble() ?? 0 : 0.0;
      state = state.copyWith(balanceTon: t);
    } catch (_) {}
  }

  /// شروع اتصال با کیف پول انتخابی
  Future<void> connect(dynamic walletApp) async {
    state = state.copyWith(status: WalletStatus.connecting, clearError: true);
    try {
      final svc = ref.read(tonConnectServiceProvider);
      final link = await svc.generateLink(walletApp);
      if (link != null) {
        state = state.copyWith(pendingLink: link);
        await svc.openLink(link);
      }
    } catch (e) {
      state = state.copyWith(status: WalletStatus.disconnected, error: '$e', clearPending: true);
    }
  }

  Future<void> reopenPendingLink() async {
    final link = state.pendingLink;
    if (link != null) {
      await ref.read(tonConnectServiceProvider).openLink(link);
    }
  }

  Future<void> cancelPending() async {
    state = state.copyWith(clearPending: true, status: WalletStatus.disconnected);
  }

  Future<void> disconnect() async {
    await ref.read(tonConnectServiceProvider).disconnect();
    state = const WalletState(status: WalletStatus.disconnected, wallets: []);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) => WalletNotifier(ref));
