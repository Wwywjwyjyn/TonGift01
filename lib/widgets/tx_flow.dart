import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/inventory_provider.dart';
import '../providers/wallet_provider.dart';
import 'common.dart';
import 'wallet_sheet.dart';

/// جریان کامل یک تراکنش واقعی:
/// ۱) نمایش مبلغ/گیرنده  ۲) ارسال به کیف پول کاربر (TON Connect)
/// ۳) ثبت سفارش با وضعیت واقعی
/// خروجی: true یعنی تراکنش در کیف پول تأیید شد.
Future<bool> runTxFlow(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, dynamic> tx,
  required String title,
  required String subtitle,
  required OrderType type,
}) async {
  final s = ref.read(settingsProvider).s;
  final wallet = ref.read(walletProvider);

  if (!wallet.isConnected) {
    if (!context.mounted) return false;
    toast(context, 'اول کیف پول را وصل کن');
    await showWalletSheet(context);
    if (!(ref.read(walletProvider).isConnected)) return false;
  }

  // استخراج اطلاعات تراکنش از پاسخ API
  final msgs = (tx['messages'] as List?) ?? const [];
  String to = '';
  double amount = 0;
  String? payloadNote;
  if (msgs.isNotEmpty) {
    final m = msgs.first as Map;
    to = (m['address'] ?? '').toString();
    amount = nanoToTon(m['amount']);
    final p = m['payload'];
    if (p != null && p.toString().isNotEmpty) payloadNote = 'payload: ${p.toString()}';
  }

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _TxConfirmSheet(
      tx: tx,
      title: title,
      subtitle: subtitle,
      to: to,
      amount: amount,
      payloadNote: payloadNote,
      s: s,
    ),
  );

  if (ok != true) return false;

  // ثبت سفارش — ایجاد شده
  final orderId = 'ord_${DateTime.now().millisecondsSinceEpoch}';
  final orders = ref.read(ordersProvider.notifier);
  await orders.add(OrderRecord(
    id: orderId,
    type: type,
    title: title,
    subtitle: subtitle,
    amountTon: amount,
    status: OrderStatus.sentToWallet,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  ));

  // ارسال به کیف پول
  try {
    await ref.read(tonConnectServiceProvider).sendTransaction(tx);
    await orders.updateStatus(orderId, OrderStatus.confirmed);
    if (context.mounted) toast(context, s.txSent);
    return true;
  } catch (e) {
    await orders.updateStatus(orderId, OrderStatus.failed);
    if (context.mounted) toast(context, '${s.txRejected}: $e', error: true);
    return false;
  }
}

class _TxConfirmSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> tx;
  final String title;
  final String subtitle;
  final String to;
  final double amount;
  final String? payloadNote;
  final dynamic s;
  const _TxConfirmSheet({
    required this.tx,
    required this.title,
    required this.subtitle,
    required this.to,
    required this.amount,
    this.payloadNote,
    required this.s,
  });

  @override
  ConsumerState<_TxConfirmSheet> createState() => _TxConfirmSheetState();
}

class _TxConfirmSheetState extends ConsumerState<_TxConfirmSheet> {
  bool _sending = false;
  bool _done = false;
  bool _failed = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    // sendTransaction تا تأیید/رد کاربر در کیف پول منتظر می‌ماند
    try {
      await ref.read(tonConnectServiceProvider).sendTransaction(widget.tx);
      _done = true;
    } catch (_) {
      _failed = true;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    Navigator.pop(context, _done && !_failed);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _done
                ? s.txSent
                : _failed
                    ? s.txRejected
                    : s.txConfirmTitle,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _done
                  ? const Color(AppColors.green)
                  : _failed
                      ? const Color(AppColors.red)
                      : const Color(AppColors.text),
            ),
          ),
          const Divider(height: 20),
          if (!_done && !_failed) ...[
            Text(widget.title,
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.subtitle,
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Color(AppColors.textDim))),
            const SizedBox(height: 14),
            InfoRow(label: s.txAmount, value: '${fmtTon(widget.amount)} TON'),
            if (widget.to.isNotEmpty) InfoRow(label: s.txTo, value: widget.to, copyable: true),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(AppColors.yellow).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.25)),
              ),
              child: const Text(
                'پرداخت مستقیم با کیف پول خودت انجام می‌شود؛ فقط تراکنش را در کیف پول تأیید کن.',
                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, height: 1.8, color: Color(AppColors.yellow)),
              ),
            ),
            const SizedBox(height: 16),
            YellowButton(
              label: _sending ? s.txPendingWallet : s.sendToWallet,
              busy: _sending,
              onTap: _send,
            ),
            if (!_sending) ...[
              const SizedBox(height: 10),
              GhostButton(label: s.cancel, onTap: () => Navigator.pop(context, false)),
            ],
          ] else ...[
            Center(
              child: Icon(
                _done ? Icons.check_circle_rounded : Icons.error_rounded,
                color: _done ? const Color(AppColors.green) : const Color(AppColors.red),
                size: 54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
